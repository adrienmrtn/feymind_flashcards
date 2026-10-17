package com.micabo.app.data

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import java.io.IOException
import java.net.URLEncoder
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId

/** Où en est la synchronisation, pour le profil. */
data class SyncState(val running: Boolean = false, val lastSuccess: Long = 0, val failed: Boolean = false)

/**
 * **La synchronisation des leçons** (`CloudSync` sur iPhone), quand l'élève est connecté.
 *
 * Les mêmes tables et les mêmes encodages que l'iPhone : une leçon est une ligne `courses`
 * (son chemin dans `path`, sa progression dans `progress`), ses thèmes des lignes `chapters`
 * (`notes`, `quiz`), ses cartes des lignes `flashcards` avec leur mémoire SM-2. Une leçon
 * écrite sur Android s'ouvre donc sur l'iPhone, et l'inverse.
 *
 * Un passage tire d'abord ce qui a changé depuis la dernière fois (cinq minutes de marge pour
 * les horloges), puis pousse ce qui a changé ici ; la plus récente des deux versions gagne.
 * Une erreur laisse le repère où il était : tout repart au passage suivant.
 */
class CloudSync(
    private val auth: SupabaseAuth,
    private val lessons: LessonRepository,
    private val exams: ExamRepository,
    private val prefs: Prefs,
) {
    private val mutex = Mutex()
    private val _state = MutableStateFlow(SyncState(lastSuccess = prefs.syncWatermark))
    val state: StateFlow<SyncState> = _state.asStateFlow()

    /** Un passage complet ; rend vrai s'il a abouti. Sans compte connecté, il ne fait rien. */
    suspend fun sync(): Boolean = mutex.withLock {
        val account = auth.account.value ?: return@withLock false
        _state.value = _state.value.copy(running = true, failed = false)
        val ok = withContext(Dispatchers.IO) {
            runCatching {
                lessons.ready()
                exams.ready()
                // Le repère est pris avant les requêtes : ce qui change pendant le passage repartira.
                val started = System.currentTimeMillis()
                val since = prefs.syncWatermark
                val token = auth.accessToken()
                val user = account.userId.lowercase()
                pull(token, user, since)
                push(token, user, since)
                prefs.syncWatermark = started
                started
            }.onFailure { Log.w(TAG, "Synchronisation interrompue", it) }.getOrNull()
        }
        _state.value = if (ok != null) SyncState(running = false, lastSuccess = ok) else _state.value.copy(running = false, failed = true)
        ok != null
    }

    /** Après une déconnexion : le prochain compte repartira de zéro. Les leçons restent ici. */
    fun forget() {
        prefs.syncWatermark = 0
        prefs.removeTombstones(prefs.tombstones)
        _state.value = SyncState()
    }

    // MARK: - Tirer

    private fun pull(token: String, user: String, since: Long) {
        val from = iso(maxOf(0, since - OVERLAP))
        val courses = selectAll(token, "courses", "user_id=eq.$user&updated_at=gt.${encode(from)}&order=updated_at.asc")
        val tombstones = prefs.tombstones
        for (row in courses) {
            val id = row.str("id").lowercase()
            if (id.isEmpty() || "course:$id" in tombstones) continue
            val local = lessons.lesson(id)
            val remoteUpdated = time(row.str("updated_at"))
            val deletedAt = row.str("deleted_at").takeIf { it.isNotEmpty() }?.let(::time)
            if (deletedAt != null) {
                if (local != null && deletedAt >= local.updatedAt) lessons.removeFromCloud(id)
                continue
            }
            // Un cours qui n'est pas une leçon (ancienne fiche, paquet) ne s'affiche pas ici.
            val path = row["path"] as? JsonObject ?: continue
            if (local != null && local.updatedAt >= remoteUpdated) continue
            val chapters = selectAll(token, "chapters", "course_id=eq.$id&user_id=eq.$user&deleted_at=is.null&order=position.asc")
            val cards = selectAll(token, "flashcards", "course_id=eq.$id&user_id=eq.$user&deleted_at=is.null&order=position.asc")
            val lesson = lessonFrom(row, path, chapters, cards, local) ?: continue
            lessons.applyFromCloud(lesson.copy(updatedAt = remoteUpdated))
        }

        val remoteExams = selectAll(token, "exams", "user_id=eq.$user&updated_at=gt.${encode(from)}&order=updated_at.asc")
        for (row in remoteExams) {
            val id = row.str("id").lowercase()
            if (id.isEmpty() || "exam:$id" in tombstones) continue
            val local = exams.exam(id)
            val remoteUpdated = time(row.str("updated_at"))
            val deletedAt = row.str("deleted_at").takeIf { it.isNotEmpty() }?.let(::time)
            if (deletedAt != null) {
                if (local != null && deletedAt >= local.updatedAt) exams.removeFromCloud(id)
                continue
            }
            if (local != null && local.updatedAt >= remoteUpdated) continue
            val day = runCatching { LocalDate.parse(row.str("exam_date").take(10)) }.getOrNull() ?: continue
            exams.applyFromCloud(
                Exam(
                    id = id,
                    name = row.str("name"),
                    date = day.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli(),
                    lessonIds = (row["course_ids"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull?.lowercase() },
                    updatedAt = remoteUpdated,
                ),
            )
        }
    }

    /** Une ligne `courses` et ses thèmes et cartes, devenus une leçon. */
    private fun lessonFrom(row: JsonObject, path: JsonObject, chapterRows: List<JsonObject>, cardRows: List<JsonObject>, local: Lesson?): Lesson? {
        val points = (path["points"] as? JsonArray).orEmpty().map { item -> (item as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull } }
        val chapterIndex = HashMap<String, Int>()
        val themes = chapterRows.sortedBy { it.int("position") ?: 0 }.mapIndexed { index, chapter ->
            val id = chapter.str("id").lowercase()
            chapterIndex[id] = index
            val notes = (chapter["notes"] as? JsonObject)?.let { runCatching { MicaboJson.decodeFromJsonElement<ThemeNotes>(it) }.getOrNull() }
            val questions = ((chapter["quiz"] as? JsonObject)?.get("questions") as? JsonArray).orEmpty().mapNotNull { item ->
                runCatching { MicaboJson.decodeFromJsonElement<Question>(item) }.getOrNull()
            }
            val status = chapter.str("status").takeIf { it in setOf(ThemeStatus.PENDING, ThemeStatus.READY, ThemeStatus.FAILED) }
                ?: if (notes != null) ThemeStatus.READY else ThemeStatus.PENDING
            Theme(
                title = chapter.str("title"),
                id = id,
                icon = chapter.str("icon").ifEmpty { "livre-ouvert" },
                points = points.getOrElse(index) { emptyList() },
                status = status,
                notes = notes,
                questions = questions,
            )
        }
        if (themes.isEmpty()) return null

        // Les cartes, rangées dans leur thème ; une carte sans thème va au dernier.
        val byTheme = MutableList(themes.size) { mutableListOf<Pair<Flashcard, CardReview?>>() }
        for (card in cardRows) {
            if (card.bool("is_suspended") == true) continue
            val theme = card.str("chapter_id").lowercase().let { chapterIndex[it] } ?: themes.lastIndex
            val choices = (card["choices"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
            val back = card.str("back").ifBlank { choices.getOrNull(card.int("correct_choice_index") ?: 0).orEmpty() }
            val front = card.str("front")
            if (front.isBlank() || back.isBlank()) continue
            val kind = if (card.str("kind") == "cloze" && front.contains(GAP_MARK)) "cloze" else "basic"
            val state = card.str("state").ifEmpty { CardState.NEW }
            val review = if (state == CardState.NEW) null else CardReview(
                state = state,
                interval = card.double("interval_days") ?: 0.0,
                ease = card.double("ease_factor") ?: Srs.STARTING_EASE,
                reps = card.int("repetitions") ?: 0,
                lapses = card.int("lapses") ?: 0,
                step = card.int("step_index") ?: 0,
                due = card.str("due_date").takeIf { it.isNotEmpty() }?.let(::time) ?: 0,
            )
            byTheme[theme].add(Flashcard(kind = kind, front = front, back = back, id = card.str("id").lowercase()) to review)
        }
        val cards = mutableMapOf<String, CardReview>()
        val filled = themes.mapIndexed { index, theme ->
            byTheme[index].forEachIndexed { position, (_, review) -> if (review != null) cards["$index:$position"] = review }
            theme.copy(flashcards = byTheme[index].map { it.first })
        }

        val progressJson = row["progress"] as? JsonObject
        val done = (progressJson?.get("done") as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull }.toSet()
        val scores = (progressJson?.get("quizScores") as? JsonObject).orEmpty().mapNotNull { (key, value) ->
            val pair = (value as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.intOrNull }
            if (pair != null && pair.size == 2) key to pair else null
        }.toMap()
        val seconds = (progressJson?.get("seconds") as? JsonObject).orEmpty().values.sumOf { (it as? JsonPrimitive)?.doubleOrNull ?: 0.0 }.toLong()
        val missed = (progressJson?.get("missed") as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull }
            .mapNotNull { chapterIndex[it.substringBefore(':').lowercase()] }.toSet()
        val finishedAt = progressJson?.str("finishedAt")?.takeIf { it.isNotEmpty() }?.let(::time) ?: 0

        val intro = path["intro"] as? JsonObject
        val groups = (path["groups"] as? JsonArray).orEmpty().mapNotNull { item ->
            val group = item as? JsonObject ?: return@mapNotNull null
            Group(group.str("name"), (group["themes"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.intOrNull })
        }
        return Lesson(
            id = row.str("id").lowercase(),
            title = row.str("title"),
            subject = row.str("subject"),
            icon = row.str("icon").ifEmpty { path.str("icon").ifEmpty { "livre-ouvert" } },
            createdAt = row.str("created_at").takeIf { it.isNotEmpty() }?.let(::time) ?: System.currentTimeMillis(),
            openedAt = row.str("last_opened_at").takeIf { it.isNotEmpty() }?.let(::time) ?: local?.openedAt ?: 0,
            language = row.str("language").ifEmpty { local?.language ?: "en" },
            source = sourceFromCourse(row.str("source")),
            topic = local?.topic.orEmpty(),
            contextText = row.str("context_text"),
            intro = Intro(
                lines = (intro?.get("lines") as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull },
                minutes = intro?.int("minutes") ?: 0,
            ),
            takeaways = (path["takeaways"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull },
            groups = groups,
            shortened = path.bool("shortened") == true,
            singleQuiz = path.bool("singleQuiz") == true,
            themes = filled,
            tone = TONES.indexOf(row.str("tone")).takeIf { it >= 0 } ?: 2,
            progress = Progress(done = done, quizScores = scores, seconds = seconds, finishedAt = finishedAt, missed = missed, cards = cards),
            examDate = local?.examDate ?: 0,
            chat = local?.chat.orEmpty(),
        )
    }

    // MARK: - Pousser

    private fun push(token: String, user: String, since: Long) {
        // Les suppressions d'abord : un cours supprimé ne doit pas revenir.
        val tombstones = prefs.tombstones
        if (tombstones.isNotEmpty()) {
            val now = iso(System.currentTimeMillis())
            val done = mutableListOf<String>()
            for (entry in tombstones) {
                val table = when (entry.substringBefore(':')) {
                    "course" -> "courses"
                    "card" -> "flashcards"
                    "exam" -> "exams"
                    else -> null
                }
                val id = entry.substringAfter(':')
                if (table == null || id.isEmpty()) {
                    done.add(entry)
                    continue
                }
                val result = request("PATCH", "$table?id=eq.$id&user_id=eq.$user", buildJsonObject {
                    put("deleted_at", now)
                    put("updated_at", now)
                }.toString(), token, mapOf("Prefer" to "return=minimal"))
                if (result.status in 200..299) done.add(entry) else throw IOException("PATCH $table ${result.status}")
            }
            prefs.removeTombstones(done)
        }

        for (lesson in lessons.lessons.value.values.filter { it.updatedAt > since }) {
            val stamped = lesson.stamped()
            upsert(token, "courses", listOf(courseRow(stamped, user)))
            upsert(token, "chapters", stamped.themes.mapIndexed { index, theme -> chapterRow(stamped, theme, index, user) })
            upsert(token, "flashcards", cardRows(stamped, user))
        }

        val changedExams = exams.exams.value.filter { it.updatedAt > since }
        if (changedExams.isNotEmpty()) {
            upsert(token, "exams", changedExams.map { exam ->
                buildJsonObject {
                    put("id", exam.id.lowercase())
                    put("user_id", user)
                    put("name", exam.name)
                    put("exam_date", Instant.ofEpochMilli(exam.date).atZone(ZoneId.systemDefault()).toLocalDate().toString())
                    putJsonArray("course_ids") { exam.lessonIds.forEach { add(JsonPrimitive(it.lowercase())) } }
                    put("updated_at", iso(exam.updatedAt))
                }
            })
        }
    }

    /**
     * La ligne `courses`. Seules les colonnes que l'app tient partent : la visibilité, le
     * dossier ou l'emoji choisis sur l'iPhone restent tels quels (`merge-duplicates`).
     */
    private fun courseRow(lesson: Lesson, user: String): JsonObject = buildJsonObject {
        put("id", lesson.id.lowercase())
        put("user_id", user)
        put("title", lesson.title)
        put("subject", lesson.subject.ifBlank { null })
        put("source", sourceForCourse(lesson.source))
        put("language", lesson.language.takeIf { LANGUAGE.matches(it) } ?: "en")
        put("raw_text", lesson.topic)
        put("context_text", lesson.contextText)
        put("created_at", iso(lesson.createdAt.takeIf { it > 0 } ?: lesson.updatedAt))
        put("updated_at", iso(lesson.updatedAt))
        if (lesson.openedAt > 0) put("last_opened_at", iso(lesson.openedAt))
        put("tone", TONES[((lesson.tone % 5) + 5) % 5])
        put("icon", lesson.icon)
        putJsonObject("path") {
            put("version", 1)
            put("icon", lesson.icon)
            putJsonObject("intro") {
                putJsonArray("lines") { lesson.intro.lines.forEach { add(JsonPrimitive(it)) } }
                put("minutes", lesson.intro.minutes)
            }
            putJsonArray("takeaways") { lesson.takeaways.forEach { add(JsonPrimitive(it)) } }
            putJsonArray("groups") {
                lesson.groups.forEach { group ->
                    add(buildJsonObject {
                        put("name", group.name)
                        putJsonArray("themes") { group.themes.forEach { add(JsonPrimitive(it)) } }
                    })
                }
            }
            put("shortened", lesson.shortened)
            put("singleQuiz", lesson.singleQuiz)
            put(
                "status",
                when {
                    lesson.isWriting -> "generating"
                    lesson.themes.isNotEmpty() && lesson.themes.all { it.status == ThemeStatus.FAILED } -> "failed"
                    else -> "ready"
                },
            )
            putJsonArray("points") { lesson.themes.forEach { theme -> add(buildJsonArray { theme.points.forEach { add(JsonPrimitive(it)) } }) } }
        }
        putJsonObject("progress") {
            val progress = lesson.progress
            putJsonArray("done") { progress.done.forEach { add(JsonPrimitive(it)) } }
            put("inCircle", 0.0)
            putJsonObject("quizScores") {
                progress.quizScores.filterValues { it.size == 2 }.forEach { (key, value) ->
                    put(key, buildJsonArray { value.forEach { add(JsonPrimitive(it)) } })
                }
            }
            // L'iPhone note les fautes par question ; ici par thème : la première question du thème en tient lieu.
            putJsonArray("missed") { progress.missed.mapNotNull { lesson.themes.getOrNull(it)?.id }.forEach { add(JsonPrimitive("$it:0")) } }
            putJsonObject("seconds") { put("notes", progress.seconds.toDouble()) }
            if (progress.finishedAt > 0) put("finishedAt", Instant.ofEpochSecond(progress.finishedAt / 1000).toString())
        }
    }

    private fun chapterRow(lesson: Lesson, theme: Theme, index: Int, user: String): JsonObject = buildJsonObject {
        put("id", theme.id.lowercase())
        put("user_id", user)
        put("course_id", lesson.id.lowercase())
        put("position", index)
        put("title", theme.title)
        put("icon", theme.icon)
        put("status", theme.status)
        put("updated_at", iso(lesson.updatedAt))
        val notes = theme.notes
        if (notes != null) {
            putJsonObject("notes") {
                put("oneLiner", notes.oneLiner)
                put("blocks", JsonArray(notes.blocks))
                putJsonArray("takeaways") { notes.takeaways.forEach { add(JsonPrimitive(it)) } }
            }
        } else {
            put("notes", JsonNull)
        }
        putJsonObject("quiz") {
            putJsonArray("questions") {
                theme.questions.forEachIndexed { number, question ->
                    add(buildJsonObject {
                        put("id", "${theme.id.lowercase()}:$number")
                        put("kind", question.kind)
                        put("prompt", question.prompt)
                        putJsonArray("choices") { question.choices.forEach { add(JsonPrimitive(it)) } }
                        put("answer", question.answer)
                        put("why", question.why)
                        putJsonArray("matches") { question.matches.forEach { add(JsonPrimitive(it)) } }
                        put("difficulty", question.difficulty.coerceIn(1, 3))
                    })
                }
            }
        }
    }

    private fun cardRows(lesson: Lesson, user: String): List<JsonObject> {
        var position = 0
        val now = iso(System.currentTimeMillis())
        return lesson.themes.flatMapIndexed { themeIndex, theme ->
            theme.flashcards.mapIndexed { cardIndex, card ->
                val review = lesson.progress.cards["$themeIndex:$cardIndex"] ?: CardReview()
                buildJsonObject {
                    put("id", card.id.lowercase())
                    put("user_id", user)
                    put("course_id", lesson.id.lowercase())
                    put("chapter_id", theme.id.lowercase())
                    put("front", card.front)
                    put("back", card.back)
                    put("position", position++)
                    put("kind", if (card.kind == "cloze" && card.front.contains(GAP_MARK)) "cloze" else "basic")
                    put("state", review.state)
                    put("due_date", if (review.due > 0) iso(review.due) else now)
                    put("interval_days", review.interval)
                    put("ease_factor", review.ease)
                    put("repetitions", review.reps)
                    put("lapses", review.lapses)
                    put("step_index", review.step)
                    put("updated_at", iso(lesson.updatedAt))
                }
            }
        }
    }

    // MARK: - PostgREST

    private fun selectAll(token: String, table: String, filter: String): List<JsonObject> {
        val out = mutableListOf<JsonObject>()
        var offset = 0
        while (true) {
            val result = request("GET", "$table?select=*&$filter&limit=$PAGE&offset=$offset", null, token)
            if (result.status !in 200..299) throw IOException("GET $table ${result.status}: ${result.body.take(160)}")
            val page = MicaboJson.parseToJsonElement(result.body).jsonArray.mapNotNull { it as? JsonObject }
            out.addAll(page)
            if (page.size < PAGE) return out
            offset += PAGE
        }
    }

    /** Un upsert par lots de mêmes clés : PostgREST refuse un tableau aux clés mêlées (PGRST102). */
    private fun upsert(token: String, table: String, rows: List<JsonObject>) {
        if (rows.isEmpty()) return
        rows.groupBy { it.keys.sorted() }.values.forEach { group ->
            group.chunked(200).forEach { chunk ->
                val result = request(
                    "POST",
                    table,
                    JsonArray(chunk).toString(),
                    token,
                    mapOf("Prefer" to "resolution=merge-duplicates,return=minimal"),
                )
                if (result.status !in 200..299) throw IOException("POST $table ${result.status}: ${result.body.take(160)}")
            }
        }
    }

    private fun request(method: String, path: String, body: String?, token: String, headers: Map<String, String> = emptyMap()): HttpResult =
        try {
            http(method, "${SupabaseConfig.URL}/rest/v1/$path", body, token, 30_000, headers)
        } catch (error: IOException) {
            throw NetworkException(error)
        }

    private companion object {
        const val TAG = "CloudSync"
        const val PAGE = 1000
        /** Cinq minutes de marge : deux horloges ne disent jamais tout à fait la même heure. */
        const val OVERLAP = 5 * 60_000L
        /** Les teintes des leçons, dans l'ordre de l'iPhone (`LessonTone`). */
        val TONES = listOf("yellow", "mint", "blue", "pink", "lilac")
        val LANGUAGE = Regex("^[a-z]{2}(-[A-Za-z0-9]{2,3})?$")
        const val GAP_MARK = "…"

        fun encode(value: String): String = URLEncoder.encode(value, "UTF-8")

        /** L'heure ISO avec les millisecondes, en UTC. */
        fun iso(time: Long): String = Instant.ofEpochMilli(time).toString()

        /** Une date du serveur (`2026-10-17T16:38:14.123456+00:00`), ou une date seule. */
        fun time(value: String): Long = runCatching { OffsetDateTime.parse(value).toInstant().toEpochMilli() }
            .recoverCatching { Instant.parse(value).toEpochMilli() }
            .recoverCatching { LocalDate.parse(value.take(10)).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli() }
            .getOrDefault(0)

        /** Les sources des leçons, ramenées à celles que l'iPhone connaît (`LessonSourceKind.courseSource`). */
        fun sourceForCourse(source: String): String = when (source) {
            "pdf", "photo", "docx", "youtube" -> source
            else -> "text"
        }

        fun sourceFromCourse(source: String): String = when (source) {
            "pdf", "photo", "docx", "youtube" -> source
            else -> "text"
        }
    }
}

private fun JsonObject.bool(key: String): Boolean? = (this[key] as? JsonPrimitive)?.contentOrNull?.toBooleanStrictOrNull()

private fun JsonObject.double(key: String): Double? = (this[key] as? JsonPrimitive)?.doubleOrNull
