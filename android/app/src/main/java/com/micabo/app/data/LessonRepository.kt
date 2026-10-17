package com.micabo.app.data

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.Serializable
import java.io.File
import java.util.UUID

/** Ce que l'élève demande : un sujet tapé, ou des supports mis à plat (`LessonCreation`). */
data class LessonRequest(
    val topic: String?,
    val text: String,
    val sourceName: String? = null,
    /** Les pages en `data:image/jpeg;base64,…`, six au plus. */
    val images: List<String> = emptyList(),
    /** topic, text, pdf, photo, youtube, docx, mixed : le serveur en tire la porte du gratuit. */
    val source: String = if (topic != null) "topic" else "text",
    /** Le jour de l'examen, en millisecondes, s'il y en a un. */
    val examDate: Long? = null,
    /**
     * L'identifiant de la leçon, gardé d'un essai à l'autre : le serveur réserve la leçon sous
     * cet identifiant (`begin_lesson`). Un identifiant neuf à chaque « Réessayer » la comptait
     * comme une seconde leçon, et la leçon offerte finissait sur le paywall.
     */
    val id: String = UUID.randomUUID().toString().lowercase(),
)

/** Les étapes de l'écran de génération, reliées au vrai travail (`LessonBuilder.Stage`). */
enum class CreationStage { READING, CUTTING, WRITING, QUESTIONS }

@Serializable
private data class PlanTheme(val title: String = "", val icon: String = "livre-ouvert", val symbol: String = "", val points: List<String> = emptyList())

@Serializable
private data class Plan(
    val title: String = "",
    val subject: String = "",
    val icon: String = "livre-ouvert",
    val themes: List<PlanTheme> = emptyList(),
    val groups: List<Group> = emptyList(),
    val intro: Intro = Intro(),
    val takeaways: List<String> = emptyList(),
    val shortened: Boolean = false,
    val singleQuiz: Boolean = false,
)

@Serializable
private data class WrittenTheme(
    val notes: ThemeNotes? = null,
    val questions: List<Question> = emptyList(),
    val flashcards: List<Flashcard> = emptyList(),
)

/**
 * **Les leçons de l'élève** : gardées sur le téléphone, une par fichier JSON, et écrites pendant
 * qu'on les lit. Le plan d'abord (une dizaine de secondes), puis les thèmes, quatre à la fois ;
 * chaque cercle se remplit quand le sien arrive. Le travail vit ici, pas dans un écran : on
 * peut quitter la leçon, les thèmes continuent de s'écrire.
 */
class LessonRepository(
    context: Context,
    private val functions: SupabaseFunctions,
    private val prefs: Prefs,
    private val streak: Streak,
) {
    private val directory = File(context.filesDir, "lessons").apply { mkdirs() }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val diskLock = Mutex()
    private val writing = MutableStateFlow<Set<String>>(emptySet())
    private val dirty: MutableSet<String> = java.util.concurrent.ConcurrentHashMap.newKeySet()
    private val themeLimiter = Semaphore(PARALLEL_THEMES)

    private val _lessons = MutableStateFlow<Map<String, Lesson>>(emptyMap())
    val lessons: StateFlow<Map<String, Lesson>> = _lessons.asStateFlow()

    /** Les fichiers sont lus : la synchronisation ne compare qu'une liste complète. */
    private val loadedFromDisk = CompletableDeferred<Unit>()

    suspend fun ready() = loadedFromDisk.await()

    init {
        scope.launch(Dispatchers.IO) {
            val loaded = directory.listFiles { file -> file.extension == "json" }.orEmpty().mapNotNull { file ->
                runCatching { MicaboJson.decodeFromString(Lesson.serializer(), file.readText()) }
                    .onFailure { Log.w(TAG, "Leçon illisible : ${file.name}", it) }
                    .getOrNull()
            }
            // Les leçons d'avant la synchronisation reçoivent leurs identifiants de thèmes et de
            // cartes, et une date de modification : sans elle, elles ne monteraient jamais.
            val stamped = loaded.map { lesson ->
                lesson.stamped().let { if (it.updatedAt > 0) it else it.copy(updatedAt = lesson.createdAt.takeIf { c -> c > 0 } ?: System.currentTimeMillis()) }
            }
            _lessons.update { current -> stamped.associateBy { it.id } + current }
            stamped.zip(loaded).filter { (new, old) -> new !== old }.forEach { persist(it.first.id) }
            loadedFromDisk.complete(Unit)
            // Une app fermée en route : les thèmes restés en préparation reprennent.
            loaded.filter { it.isWriting }.forEach { resume(it.id) }
        }
    }

    fun lesson(id: String): Lesson? = _lessons.value[id]

    private fun save(lesson: Lesson) {
        val stamped = lesson.stamped().copy(updatedAt = System.currentTimeMillis())
        _lessons.update { it + (stamped.id to stamped) }
        persist(stamped.id)
    }

    /** Une leçon venue du serveur : gardée telle quelle, avec sa date ; la conversation locale reste. */
    fun applyFromCloud(lesson: Lesson) {
        _lessons.update { map ->
            val local = map[lesson.id]
            map + (lesson.id to lesson.copy(chat = local?.chat ?: lesson.chat))
        }
        persist(lesson.id)
    }

    /** Une leçon supprimée sur un autre appareil. */
    fun removeFromCloud(id: String) {
        _lessons.update { it - id }
        scope.launch(Dispatchers.IO) { diskLock.withLock { File(directory, "$id.json").delete() } }
    }

    /**
     * Écrit la dernière version de la leçon. Une écriture déjà prévue suffit : dix cartes notées
     * d'affilée ne réécrivent pas dix fois le fichier (le texte de référence pèse jusqu'à 60 Ko).
     */
    private fun persist(id: String) {
        if (!dirty.add(id)) return
        scope.launch(Dispatchers.IO) {
            diskLock.withLock {
                dirty.remove(id)
                val latest = _lessons.value[id] ?: return@withLock
                runCatching {
                    val temp = File(directory, "${latest.id}.json.tmp")
                    temp.writeText(MicaboJson.encodeToString(Lesson.serializer(), latest))
                    temp.renameTo(File(directory, "${latest.id}.json"))
                }.onFailure { Log.w(TAG, "Leçon non enregistrée", it) }
            }
        }
    }

    /**
     * Change une leçon d'un seul geste atomique : quatre thèmes qui arrivent en même temps ne
     * s'écrasent plus (un thème fini restait « en préparation »). `change` peut être rejoué :
     * il doit rester sans effet de bord.
     */
    fun modify(id: String, change: (Lesson) -> Lesson) {
        var found = false
        _lessons.update { map ->
            val current = map[id]
            found = current != null
            if (current == null) map else map + (id to change(current).stamped().copy(updatedAt = System.currentTimeMillis()))
        }
        if (found) persist(id)
    }

    fun delete(id: String) {
        // La suppression part au serveur à la prochaine synchronisation : la leçon et ses cartes.
        _lessons.value[id]?.let { lesson -> prefs.addTombstones(listOf("course:$id") + lesson.themes.flatMap { it.flashcards }.map { "card:${it.id}" }) }
        _lessons.update { it - id }
        scope.launch(Dispatchers.IO) { diskLock.withLock { File(directory, "$id.json").delete() } }
    }

    fun deleteAll() {
        _lessons.value = emptyMap()
        scope.launch(Dispatchers.IO) { diskLock.withLock { directory.listFiles().orEmpty().forEach { it.delete() } } }
    }

    fun markOpened(id: String) = modify(id) { it.copy(openedAt = System.currentTimeMillis()) }

    /** Une étape finie : elle allume aussi la journée de la série (`LessonSession.complete`). */
    fun complete(id: String, circle: String, score: List<Int>? = null) {
        streak.record()
        modify(id) { lesson ->
            val progress = lesson.progress
            val scores = if (score != null) progress.quizScores + (circle to score) else progress.quizScores
            val done = progress.done + circle
            val finished = circle == "final" && progress.finishedAt == 0L
            lesson.copy(progress = progress.copy(done = done, quizScores = scores, finishedAt = if (finished) System.currentTimeMillis() else progress.finishedAt))
        }
    }

    /** Recommence le chemin ; le temps passé et la mémoire des cartes restent. */
    fun restart(id: String) = modify(id) { it.copy(progress = Progress(seconds = it.progress.seconds, cards = it.progress.cards)) }

    /** Qui voit la leçon : ses amis, ou personne. */
    fun setVisibility(id: String, visibility: String) = modify(id) { it.copy(visibility = visibility) }

    /** Une carte notée : son prochain rappel, et la journée de la série. */
    fun review(id: String, key: String, rating: Rating) {
        streak.record()
        val before = lesson(id)?.progress?.cards?.get(key) ?: CardReview()
        modify(id) { lesson ->
            val card = lesson.progress.cards[key] ?: CardReview()
            lesson.copy(progress = lesson.progress.copy(cards = lesson.progress.cards + (key to Srs.schedule(card, rating))))
        }
        // Hors de `modify` : sa transformation peut être rejouée, la note ne doit partir qu'une fois.
        val lesson = lesson(id) ?: return
        logReview(lesson, key, before, lesson.progress.cards[key] ?: return, rating)
    }

    /** La note, pour `review_logs` : elle montera à la prochaine synchronisation, compte ouvert. */
    private fun logReview(lesson: Lesson, key: String, before: CardReview, after: CardReview, rating: Rating) {
        if (prefs.accountUser.isEmpty()) return
        val theme = key.substringBefore(':').toIntOrNull() ?: return
        val index = key.substringAfter(':').toIntOrNull() ?: return
        val cardId = lesson.themes.getOrNull(theme)?.flashcards?.getOrNull(index)?.id?.takeIf { it.isNotEmpty() } ?: return
        prefs.queueReview(buildJsonObject {
            put("id", newId())
            put("card_id", cardId.lowercase())
            put("reviewed_at", java.time.Instant.now().toString())
            put("rating", rating.ordinal + 1)
            put("state_before", before.state)
            put("previous_interval_days", before.interval)
            put("new_interval_days", after.interval)
            put("ease_after", after.ease)
        }.toString())
    }

    /** Une réponse fausse : son thème passe en tête de l'entraînement suivant. */
    fun missed(id: String, theme: Int) = modify(id) { it.copy(progress = it.progress.copy(missed = it.progress.missed + theme)) }

    /**
     * **De nouvelles questions** (`LessonBuilder.practice`) : dix, loin de celles déjà posées,
     * surtout là où l'élève se trompe. Elles rejoignent leurs thèmes et ressortent dans les
     * quiz suivants. Rend les questions ajoutées, avec leur thème.
     */
    suspend fun practice(id: String, count: Int = 10): List<Pair<Int, Question>> {
        val lesson = _lessons.value[id] ?: return emptyList()
        val profile = prefs.profile.value
        val payload = buildJsonObject {
            audience(profile, language = lesson.language, exam = lesson.upcomingExam()?.let { examLine(lesson.title, it) })
            put("stage", "practice")
            put("lessonId", id)
            put("lessonTitle", lesson.title)
            put("subject", lesson.subject)
            putJsonArray("practiceThemes") {
                lesson.themes.forEach { theme ->
                    add(buildJsonObject {
                        put("title", theme.title)
                        put("notes", theme.flatNotes().take(2_000))
                    })
                }
            }
            putJsonArray("focus") { lesson.progress.missed.sorted().forEach { add(JsonPrimitive(it)) } }
            putJsonArray("avoid") { lesson.themes.flatMap { it.questions }.map { it.prompt.take(200) }.takeLast(80).forEach { add(JsonPrimitive(it)) } }
            put("count", count)
        }
        val envelope = functions.call("generate-lesson", payload)
        val generated = (envelope["questions"] as? JsonArray).orEmpty().mapNotNull { item ->
            val raw = item as? JsonObject ?: return@mapNotNull null
            val theme = raw.int("theme") ?: 0
            val question = runCatching { MicaboJson.decodeFromJsonElement<Question>(raw) }.getOrNull() ?: return@mapNotNull null
            if (theme in lesson.themes.indices && question.isValid) theme to question else null
        }
        if (generated.isNotEmpty()) {
            modify(id) { current ->
                current.copy(themes = current.themes.mapIndexed { index, theme ->
                    val added = generated.filter { it.first == index }.map { it.second }
                    if (added.isEmpty()) theme else theme.copy(questions = theme.questions + added)
                })
            }
        }
        return generated
    }

    /**
     * **Une copie d'examen blanc** (`LessonBuilder.examPaper`), écrite au format de l'examen
     * visé, sur huit leçons au plus. Rien n'est gardé : la copie se joue tout de suite.
     */
    suspend fun examPaper(title: String, exam: Exam?, lessonIds: List<String>, minutes: Int): Paper {
        val chosen = lessonIds.mapNotNull { _lessons.value[it] }.filter { it.readyThemes > 0 }.take(8)
        if (chosen.isEmpty()) throw ApiException(400, "invalid", "")
        val paperId = UUID.randomUUID().toString().lowercase()
        val profile = prefs.profile.value
        val payload = buildJsonObject {
            audience(profile, language = chosen.first().language, exam = exam?.let { examLine(it.name, it.date) })
            put("stage", "exam")
            put("lessonId", paperId)
            put("examTitle", title)
            put("minutes", minutes)
            put("count", Paper.questionCount(minutes))
            putJsonArray("lessons") {
                chosen.forEach { lesson ->
                    add(buildJsonObject {
                        put("title", lesson.title)
                        put("subject", lesson.subject)
                        putJsonArray("themes") {
                            lesson.themes.take(14).forEach { theme ->
                                add(buildJsonObject {
                                    put("title", theme.title)
                                    put("notes", theme.flatNotes().take(2_000))
                                })
                            }
                        }
                    })
                }
            }
        }
        val envelope = functions.call("generate-lesson", payload, timeoutMs = 180_000)
        val generated = envelope["exam"] as? JsonObject ?: throw ApiException(502, "invalid", "")
        val items = (generated["questions"] as? JsonArray).orEmpty().mapNotNull { item ->
            val raw = item as? JsonObject ?: return@mapNotNull null
            val question = runCatching { MicaboJson.decodeFromJsonElement<Question>(raw) }.getOrNull()?.takeIf { it.isValid } ?: return@mapNotNull null
            val lesson = raw.int("lesson")?.takeIf { it in chosen.indices } ?: 0
            val theme = raw.int("theme")?.takeIf { it in chosen[lesson].themes.indices } ?: 0
            PaperItem(question, lesson, theme)
        }
        if (items.isEmpty()) throw ApiException(502, "invalid", "")
        return Paper(
            id = paperId,
            examId = exam?.id,
            title = generated.str("title").ifBlank { title },
            minutes = minutes,
            lessons = chosen.map { it.id to it.title },
            items = items,
        )
    }

    /** Les erreurs d'une copie deviennent des flashcards, dans le thème d'où vient chaque question. */
    fun addMistakeCards(paper: Paper, wrong: List<Int>) {
        wrong.mapNotNull { paper.items.getOrNull(it) }.groupBy { paper.lessons.getOrNull(it.lesson)?.first }.forEach { (lessonId, items) ->
            if (lessonId == null) return@forEach
            modify(lessonId) { lesson ->
                lesson.copy(themes = lesson.themes.mapIndexed { index, theme ->
                    val cards = items.filter { it.theme == index }.map { Flashcard(front = it.question.prompt, back = it.question.answerText) }
                    if (cards.isEmpty()) theme else theme.copy(flashcards = theme.flashcards + cards)
                })
            }
        }
    }

    fun rename(id: String, title: String) {
        val clean = title.trim().take(120)
        if (clean.isNotEmpty()) modify(id) { it.copy(title = clean) }
    }

    fun addTime(id: String, seconds: Long) {
        if (seconds <= 0 || seconds > 6 * 3600) return
        modify(id) { it.copy(progress = it.progress.copy(seconds = it.progress.seconds + seconds)) }
    }

    // MARK: - Créer

    /**
     * Écrit le plan, crée la leçon et lance ses thèmes. Rend l'identifiant dès que le premier
     * thème est arrivé, ou dès que tous ont échoué : l'intro se lit de toute façon.
     */
    suspend fun create(request: LessonRequest, onStage: (CreationStage) -> Unit): String =
        // Le travail vit dans la portée du dépôt : quitter l'écran n'annule pas une leçon déjà
        // réservée par le serveur, elle apparaîtra dans la liste.
        scope.async { createNow(request, onStage) }.await()

    private suspend fun createNow(request: LessonRequest, onStage: (CreationStage) -> Unit): String {
        val id = request.id
        val profile = prefs.profile.value
        onStage(CreationStage.READING)
        val payload = buildJsonObject {
            audience(profile, exam = request.examDate?.let { examLine(null, it) })
            put("stage", "plan")
            put("lessonId", id)
            put("source", request.source)
            put("text", request.text.take(MAX_TEXT))
            putJsonArray("images") { request.images.forEach { add(JsonPrimitive(it)) } }
            put("sourceName", request.sourceName.orEmpty())
            if (request.topic != null) put("topic", request.topic.take(400))
        }
        val envelope = functions.call("generate-lesson", payload)
        val plan = MicaboJson.decodeFromJsonElement<Plan>(envelope["plan"] ?: throw ApiException(502, "invalid", ""))
        if (plan.themes.isEmpty()) throw ApiException(502, "invalid", "")
        onStage(CreationStage.CUTTING)

        val previousTone = _lessons.value.values.maxByOrNull { it.createdAt }?.tone ?: -1
        val now = System.currentTimeMillis()
        val lesson = Lesson(
            id = id,
            title = plan.title.ifBlank { request.topic ?: request.sourceName.orEmpty() },
            subject = plan.subject,
            icon = plan.icon,
            createdAt = now,
            openedAt = now,
            language = contentLanguage(profile),
            source = request.source,
            topic = request.topic.orEmpty(),
            contextText = envelope.str("contextText"),
            intro = plan.intro,
            takeaways = plan.takeaways,
            groups = plan.groups,
            shortened = plan.shortened,
            singleQuiz = plan.singleQuiz,
            themes = plan.themes.map { Theme(title = it.title, icon = it.icon, points = it.points) },
            tone = (previousTone + 1) % 5,
            examDate = request.examDate ?: 0,
        )
        save(lesson)

        onStage(CreationStage.WRITING)
        val first = CompletableDeferred<Unit>()
        scope.launch {
            writeThemes(id, retryFailed = false) { first.complete(Unit) }
            first.complete(Unit)
        }
        // Au plus deux minutes d'attente : le chemin s'ouvre de toute façon.
        withTimeoutOrNull(120_000) { first.await() }
        onStage(CreationStage.QUESTIONS)
        return id
    }

    /** Relance les thèmes restés en préparation (app fermée en route), ou ceux en échec. */
    fun resume(id: String, retryFailed: Boolean = false) {
        scope.launch { writeThemes(id, retryFailed) {} }
    }

    private suspend fun writeThemes(id: String, retryFailed: Boolean, onFirst: () -> Unit) {
        val lesson = _lessons.value[id] ?: return
        // Choisis et réservés d'un même geste : deux relances simultanées (la reprise au
        // lancement et « Réessayer ») ne demandent pas deux fois le même thème.
        var wanted: List<Int> = emptyList()
        writing.update { current ->
            wanted = (_lessons.value[id] ?: lesson).themes.withIndex().filter { (index, theme) ->
                "$id:$index" !in current && (theme.status == ThemeStatus.PENDING || (retryFailed && theme.status == ThemeStatus.FAILED))
            }.map { it.index }
            current + wanted.map { index -> "$id:$index" }
        }
        if (wanted.isEmpty()) return
        if (retryFailed) {
            modify(id) { current ->
                current.copy(themes = current.themes.mapIndexed { index, theme ->
                    if (index in wanted) theme.copy(status = ThemeStatus.PENDING, error = "") else theme
                })
            }
        }
        val jobs = wanted.map { index ->
            scope.launch {
                try {
                    themeLimiter.withPermit {
                        val written = writeTheme(id, index)
                        modify(id) { current ->
                            current.copy(themes = current.themes.mapIndexed { i, theme ->
                                if (i == index) {
                                    theme.copy(
                                        status = ThemeStatus.READY,
                                        notes = written.notes,
                                        questions = written.questions.filter { it.isValid },
                                        flashcards = written.flashcards.filter { it.front.isNotBlank() && it.back.isNotBlank() },
                                        error = "",
                                    )
                                } else theme
                            })
                        }
                        onFirst()
                    }
                } catch (error: Throwable) {
                    if (error is kotlinx.coroutines.CancellationException) throw error
                    Log.w(TAG, "Thème $index en échec", error)
                    val code = (error as? ApiException)?.code.orEmpty()
                    modify(id) { current ->
                        current.copy(themes = current.themes.mapIndexed { i, theme ->
                            if (i == index) theme.copy(status = ThemeStatus.FAILED, error = code.ifEmpty { if (error is NetworkException) "network" else "generic" }) else theme
                        })
                    }
                } finally {
                    writing.update { it - "$id:$index" }
                }
            }
        }
        jobs.forEach { it.join() }
    }

    private suspend fun writeTheme(id: String, index: Int): WrittenTheme {
        val lesson = _lessons.value[id] ?: throw IllegalStateException("Leçon absente")
        val profile = prefs.profile.value
        val payload = buildJsonObject {
            audience(profile, language = lesson.language, exam = lesson.upcomingExam()?.let { examLine(lesson.title, it) })
            put("stage", "theme")
            put("lessonId", id)
            put("lessonTitle", lesson.title)
            put("themeIndex", index)
            putJsonArray("themes") { lesson.themes.forEach { add(JsonPrimitive(it.title)) } }
            put("context", lesson.contextText.take(60_000))
            put("subject", lesson.subject)
            if (lesson.themes.any { it.points.isNotEmpty() }) {
                putJsonArray("points") {
                    lesson.themes.forEach { theme -> add(JsonArray(theme.points.map { JsonPrimitive(it) })) }
                }
            }
            if (lesson.intro.lines.isNotEmpty()) putJsonArray("objectives") { lesson.intro.lines.forEach { add(JsonPrimitive(it)) } }
            put("source", lesson.source)
        }
        // Une panne passagère se réessaie une fois avant d'afficher « Réessayer ».
        var lastError: Throwable? = null
        repeat(2) { attempt ->
            try {
                val envelope = functions.call("generate-lesson", payload)
                val theme = envelope["theme"] ?: throw ApiException(502, "invalid", "")
                val written = MicaboJson.decodeFromJsonElement<WrittenTheme>(theme)
                if (written.notes == null) throw ApiException(502, "invalid", "")
                return written
            } catch (error: ApiException) {
                if (error.status in 400..499) throw error
                lastError = error
            } catch (error: NetworkException) {
                lastError = error
            }
            if (attempt == 0) kotlinx.coroutines.delay(1_500)
        }
        throw lastError ?: IllegalStateException()
    }

    // MARK: - Pour qui on écrit

    private fun contentLanguage(profile: Profile): String =
        com.micabo.app.i18n.AppLocale.resolved(profile.language).content

    /** L'examen tel que le serveur le lit (`LessonBuilder.examLine`). */
    private fun examLine(name: String?, date: Long): String {
        val day = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.ROOT).format(java.util.Date(date))
        return if (name.isNullOrBlank()) "un examen, le $day" else "l'examen « $name », le $day"
    }

    private fun JsonObjectBuilder.audience(profile: Profile, language: String = contentLanguage(profile), exam: String? = null) {
        if (!exam.isNullOrBlank()) put("exam", exam)
        put("level", levelOf(profile.tier))
        put("country", profile.country.ifBlank { "other" })
        put("schoolStage", Tiers.englishName(profile.tier))
        put("language", language)
        if (profile.tier.isNotBlank()) put("tier", profile.tier)
        profile.currentScore?.let { put("currentScore", it) }
        profile.targetScore?.let { put("targetScore", it) }
        if (profile.worries.isNotEmpty()) putJsonArray("worries") { profile.worries.forEach { add(JsonPrimitive(it)) } }
        putJsonArray("kinds") { listOf("choice", "truefalse", "gap", "order", "match").forEach { add(JsonPrimitive(it)) } }
    }

    fun levelOf(tier: String): String = when (tier) {
        "lowerSecondary", "upperSecondary" -> "lycee"
        "preUniversity" -> "prepa"
        "undergraduate" -> "licence"
        "graduate" -> "master"
        "health" -> "sante"
        "competitive" -> "concours"
        else -> "other"
    }

    suspend fun flush() = withContext(Dispatchers.IO) { diskLock.withLock { } }

    companion object {
        private const val TAG = "Lessons"
        const val PARALLEL_THEMES = 4
        const val MAX_TEXT = 60_000
    }
}

/** Les marches d'études (`EducationTier`), dans l'ordre de l'échelle. */
object Tiers {
    val all = listOf("lowerSecondary", "upperSecondary", "preUniversity", "undergraduate", "graduate", "health", "competitive", "other")

    fun englishName(tier: String): String = when (tier) {
        "lowerSecondary" -> "Middle school"
        "upperSecondary" -> "High school"
        "preUniversity" -> "Pre-university"
        "undergraduate" -> "University, bachelor"
        "graduate" -> "University, master"
        "health" -> "Medicine, health"
        "competitive" -> "Competitive exam"
        else -> ""
    }
}
