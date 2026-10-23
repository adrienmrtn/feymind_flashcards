package com.micabo.app.data

import android.util.Log
import com.micabo.app.i18n.AppLocale
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
 * **La synchronisation des leçons** (`CloudSync` sur iPhone), sous le compte de l'élève, ou
 * sous son compte invité tant qu'il ne s'est pas connecté.
 *
 * Les mêmes tables et les mêmes encodages que l'iPhone : une leçon est une ligne `courses`
 * (son chemin dans `path`, sa progression dans `progress`), ses thèmes des lignes `chapters`
 * (`notes`, `quiz`), ses cartes des lignes `flashcards` avec leur mémoire SM-2. Une leçon
 * écrite sur Android s'ouvre donc sur l'iPhone, et l'inverse.
 *
 * **L'invité synchronise aussi**, depuis le 23 octobre 2026. Jusque-là, rien ne partait sans
 * compte connecté - et presque personne ne se connecte sur Android : 116 invités en quatorze
 * jours, 32 leçons générées, zéro en base, un seul appareil connecté. Or le compte invité est
 * un vrai `auth.users` : le cloisonnement marche avec son jeton, et `begin_lesson` compte déjà
 * sa leçon offerte sous cet identifiant. Un élève qui réinstalle ou change de téléphone ne
 * perd plus rien. Quand il ouvre un vrai compte, le repère repart de zéro et tout ce qui est
 * ici remonte sous le compte (voir `sync`).
 *
 * Un passage tire d'abord ce qui a changé depuis la dernière fois (cinq minutes de marge pour
 * les horloges), puis pousse ce qui a changé ici ; la plus récente des deux versions gagne.
 * Une erreur laisse le repère où il était : tout repart au passage suivant - et elle est
 * **dite** (`onFailure`), parce qu'une synchro qui échoue dans un `Log.w` est une synchro dont
 * personne n'apprend l'échec.
 */
class CloudSync(
    private val auth: SupabaseAuth,
    private val lessons: LessonRepository,
    private val exams: ExamRepository,
    private val prefs: Prefs,
    /** La série : les jours étudiés sur l'iPhone ou le site l'allument ici aussi (`review_logs`). */
    private val streak: Streak? = null,
    /** Appelé avec un mot court quand un passage échoue : la statistique `sync_failed`. */
    private val onFailure: (String) -> Unit = {},
    /** Appelé quand un passage aboutit, avec le nombre de leçons poussées : `sync_finished`. */
    private val onSuccess: (Int) -> Unit = {},
) {
    private val mutex = Mutex()
    private val _state = MutableStateFlow(SyncState(lastSuccess = prefs.syncWatermark))
    val state: StateFlow<SyncState> = _state.asStateFlow()

    /** Un passage complet ; rend vrai s'il a abouti. Sans compte ni invité, il ne fait rien. */
    suspend fun sync(): Boolean = mutex.withLock {
        // Le compte, sinon l'invité : le même choix que pour les fonctions et les événements.
        val user = auth.userId.lowercase()
        if (user.isEmpty()) return@withLock false
        _state.value = _state.value.copy(running = true, failed = false)
        var pushedLessons = 0
        val ok = withContext(Dispatchers.IO) {
            runCatching {
                lessons.ready()
                exams.ready()
                // Un autre compte que la dernière fois - l'invité qui vient de se connecter,
                // un camarade sur le même téléphone : le repère ne vaut plus rien. Tout ce qui
                // est ici monte sous lui, tout ce qu'il a redescend.
                val switched = prefs.syncUser != user
                if (switched) {
                    prefs.syncWatermark = 0
                    prefs.profileSignature = ""
                }
                // Le repère est pris avant les requêtes : ce qui change pendant le passage repartira.
                val started = System.currentTimeMillis()
                val since = prefs.syncWatermark
                val token = auth.accessToken()
                val pulled = pull(token, user, since, switched)
                pushedLessons = push(token, user, since, pulled)
                pushProfile(token, user)
                prefs.syncWatermark = started
                prefs.syncUser = user
                started
            }.onFailure {
                Log.w(TAG, "Synchronisation interrompue", it)
                onFailure(describe(it))
            }.getOrNull()
        }
        _state.value = if (ok != null) SyncState(running = false, lastSuccess = ok) else _state.value.copy(running = false, failed = true)
        if (ok != null) onSuccess(pushedLessons)
        ok != null
    }

    /** L'échec en un mot, sans texte d'élève : la famille, puis le statut HTTP s'il y en a. */
    private fun describe(error: Throwable): String = when (error) {
        is NetworkException -> "network"
        is IOException -> error.message?.let { message ->
            // « POST chapters 400: … » : on garde le verbe, la table et le statut.
            Regex("""^(GET|POST|PATCH) (\w+) (\d{3})""").find(message)?.let { "${it.groupValues[1].lowercase()}_${it.groupValues[2]}_${it.groupValues[3]}" }
        } ?: "io"
        else -> error.javaClass.simpleName.lowercase().take(40)
    }

    /** Après une déconnexion : le prochain compte repartira de zéro. Les leçons restent ici. */
    fun forget() {
        prefs.syncWatermark = 0
        prefs.syncUser = ""
        prefs.profileSignature = ""
        prefs.removeTombstones(prefs.tombstones)
        prefs.removeReviews(prefs.pendingReviews)
        _state.value = SyncState()
    }

    // MARK: - Le profil

    /**
     * **Le profil monte avec les leçons**, comme sur l'iPhone (`ProfileRecord`).
     *
     * Android n'écrivait jamais `profiles` : 95 comptes Android en quatorze jours, et pas un
     * `onboarding_completed_at`, pas un pays, pas un niveau en base. Seules les colonnes
     * qu'Android connaît partent, et seulement quand elles ont changé depuis la dernière
     * montée : un upsert de ces colonnes-là laisse le reste de la ligne - le nom d'utilisateur,
     * la langue des fiches choisie sur l'iPhone - tel quel.
     */
    private fun pushProfile(token: String, user: String) {
        val profile = prefs.profile.value
        val signature = signature(profile)
        if (signature == prefs.profileSignature) return
        val row = buildJsonObject {
            put("id", user)
            profile.name.trim().takeIf { it.isNotEmpty() }?.let { put("display_name", it.take(80)) }
            // Le registre, pas la marche : `study_level` est le `StudyLevel` de l'iPhone et du
            // site (« lycee », « licence »). Une marche (« upperSecondary ») n'y était lue par personne.
            profile.tier.takeIf { it.isNotEmpty() }?.let { put("study_level", Tiers.level(it)) }
            profile.country.takeIf { it.isNotEmpty() }?.let { put("country_code", it) }
            putJsonArray("learning_goals") { profile.goals.forEach { add(JsonPrimitive(it)) } }
            putJsonArray("subjects") { profile.subjects.forEach { add(JsonPrimitive(it)) } }
            // La base refuse hors de 1 à 240 minutes : un temps jamais choisi (0) faisait échouer
            // la montée du profil, et avec elle tout le passage, à chaque fois.
            profile.dailyMinutes.takeIf { it in 1..240 }?.let { put("daily_minutes", it) }
            if (profile.onboarded) put("onboarding_completed_at", iso(System.currentTimeMillis()))
            put("updated_at", iso(System.currentTimeMillis()))
        }
        upsert(token, "profiles", listOf(row))
        prefs.profileSignature = signature
    }

    /** L'empreinte de ce que le profil transporte (`ProfileRecord.signature`). */
    private fun signature(profile: Profile): String = listOf(
        profile.onboarded.toString(), profile.name, profile.tier, profile.country,
        profile.goals.sorted().joinToString(","), profile.subjects.sorted().joinToString(","),
        profile.dailyMinutes.toString(),
    ).joinToString("|")

    /**
     * **Le profil descend aussi** (`ProfileRecord.applyToLocalPreferences`). Il montait sans
     * jamais redescendre : un élève inscrit sur l'iPhone ou le site qui se connectait ici
     * refaisait tout l'accueil, et son pays, sa marche, ses buts restaient ceux du téléphone.
     *
     * Un champ vide ici prend celui du compte ; un champ rempli ne le prend que si le compte a
     * changé après (`updated_at` contre `Prefs.profileUpdatedAt`), et jamais par-dessus un
     * changement d'ici pas encore monté : un pays changé dans le profil ne revient pas à
     * l'ancien au passage suivant. Juste après la connexion à un compte (`switched`), le compte
     * gagne, comme sur l'iPhone (`recognizeExistingAccount`) : c'est lui que l'élève retrouve.
     * Une ligne jamais remplie - celle que l'inscription pose, la France et quinze minutes par
     * défaut - n'apprend rien et ne change rien. L'accueil fini ailleurs
     * (`onboarding_completed_at`) vaut accueil fini ici.
     *
     * La langue des fiches (`sheet_language`) n'a pas d'équivalent séparé ici : la langue de
     * l'élève est aussi celle de ses leçons. Elle ne la remplit que si elle n'a jamais été
     * choisie sur ce téléphone.
     */
    private fun pullProfile(token: String, user: String, switched: Boolean) {
        val row = selectAll(token, "profiles", "id=eq.$user").firstOrNull() ?: return
        if (row.str("onboarding_completed_at").isEmpty()) return
        val remoteUpdated = row.str("updated_at").takeIf { it.isNotEmpty() }?.let(::time) ?: 0
        val unpushed = prefs.profileSignature.isNotEmpty() && signature(prefs.profile.value) != prefs.profileSignature
        val newer = switched || (!unpushed && remoteUpdated > prefs.profileUpdatedAt)
        val name = row.str("display_name").trim().takeIf { it.isNotEmpty() }
        val tier = Tiers.fromLevel(row.str("study_level")).takeIf { it.isNotEmpty() }
        val country = row.str("country_code").lowercase().takeIf { COUNTRY.matches(it) || it == "other" }
        val goals = row.strings("learning_goals").toSet().takeIf { it.isNotEmpty() }
        val subjects = row.strings("subjects").toSet().takeIf { it.isNotEmpty() }
        val daily = row.int("daily_minutes")?.takeIf { it in 1..240 }
        val sheet = row.str("sheet_language")
        val language = AppLocale.entries.firstOrNull { sheet.isNotEmpty() && (it.content == sheet || it.code == sheet) }?.code
        fun <T> pick(local: T, empty: Boolean, remote: T?): T = if (remote != null && (empty || newer)) remote else local
        prefs.updateFromCloud { profile ->
            profile.copy(
                onboarded = true,
                name = pick(profile.name, profile.name.isBlank(), name),
                country = pick(profile.country, profile.country.isBlank(), country),
                tier = pick(profile.tier, profile.tier.isBlank(), tier),
                goals = pick(profile.goals, profile.goals.isEmpty(), goals),
                subjects = pick(profile.subjects, profile.subjects.isEmpty(), subjects),
                dailyMinutes = pick(profile.dailyMinutes, profile.dailyMinutes <= 0, daily),
                language = if (profile.language.isBlank() && language != null) language else profile.language,
            )
        }
        // Le compte a gagné : ce qui vient de descendre n'a pas à remonter. Plus vieux que le
        // téléphone, il a seulement rempli les vides, et la montée qui suit publie le reste.
        if (newer) prefs.profileSignature = signature(prefs.profile.value)
    }

    // MARK: - Tirer

    /**
     * Tire ce qui a changé ; rend les leçons recopiées en entier, avec leur date, pour que la
     * montée ne les renvoie pas telles quelles.
     */
    private fun pull(token: String, user: String, since: Long, switched: Boolean): Map<String, Long> {
        val from = iso(maxOf(0, since - OVERLAP))
        val applied = HashMap<String, Long>()
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
            // Un cours sans chemin (une ancienne fiche, un paquet de cartes) s'affiche aussi : il
            // était sauté, et ses cartes n'existaient pas sur Android.
            val path = row["path"] as? JsonObject
            if (local != null && local.updatedAt >= remoteUpdated) continue
            val chapters = selectAll(token, "chapters", "course_id=eq.$id&user_id=eq.$user&deleted_at=is.null&order=position.asc")
            val cards = selectAll(token, "flashcards", "course_id=eq.$id&user_id=eq.$user&deleted_at=is.null&order=position.asc")
            val lesson = (if (path != null) lessonFrom(row, path, chapters, cards, local) else legacyLessonFrom(row, chapters, cards, local)) ?: continue
            lessons.applyFromCloud(lesson.copy(updatedAt = remoteUpdated))
            applied[id] = remoteUpdated
        }

        pullCards(token, user, from, applied.keys)

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
            // Une colonne absente (une ligne d'avant qu'elle existe) garde ce qu'on avait ici.
            exams.applyFromCloud(
                Exam(
                    id = id,
                    name = row.str("name"),
                    date = day.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli(),
                    lessonIds = (row["course_ids"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull?.lowercase() },
                    updatedAt = remoteUpdated,
                    kind = row.str("kind").ifEmpty { local?.kind.orEmpty() }.ifEmpty { null },
                    intensity = row.str("intensity").ifEmpty { local?.intensity.orEmpty() }.ifEmpty { null },
                    targetScore = row.int("target_score") ?: local?.targetScore,
                    startingPoint = row.str("starting_point").ifEmpty { local?.startingPoint.orEmpty() }.ifEmpty { null },
                ),
            )
        }

        // Ni la série ni le profil ne font échouer le passage : les leçons sont déjà là.
        runCatching { pullReviewDays(token, user, from) }.onFailure { Log.w(TAG, "Série non relue", it) }
        runCatching { pullProfile(token, user, switched) }.onFailure { Log.w(TAG, "Profil non relu", it) }
        return applied
    }

    /**
     * **Les cartes descendent seules**, comme sur l'iPhone. Noter une carte sur l'iPhone ou le
     * site ne touche que sa ligne `flashcards`, pas `courses.updated_at` : relire les cartes
     * seulement sous les cours changés laissait ici, pour toujours, la mémoire d'avant.
     *
     * Carte par carte, la plus récente gagne : le `updated_at` du serveur contre la dernière
     * note posée ici (`CardReview.updatedAt`). Une carte inconnue rejoint son thème (ou le
     * dernier) ; une carte supprimée ou suspendue ailleurs s'en va. Les leçons recopiées en
     * entier à l'instant ont déjà leurs cartes.
     */
    private fun pullCards(token: String, user: String, from: String, fresh: Set<String>) {
        val rows = selectAll(token, "flashcards", "user_id=eq.$user&updated_at=gt.${encode(from)}&order=updated_at.asc")
        if (rows.isEmpty()) return
        val tombstones = prefs.tombstones
        rows.groupBy { it.str("course_id").lowercase() }.forEach { (courseId, group) ->
            if (courseId.isEmpty() || courseId in fresh || lessons.lesson(courseId) == null) return@forEach
            lessons.mergeFromCloud(courseId) { lesson -> mergeCards(lesson, group, tombstones) }
        }
    }

    /** Les cartes descendues, fondues dans la leçon. Sans effet de bord : la fusion peut être rejouée. */
    private fun mergeCards(lesson: Lesson, rows: List<JsonObject>, tombstones: Set<String>): Lesson {
        val chapterIndex = lesson.themes.withIndex().filter { it.value.id.isNotEmpty() }.associate { it.value.id.lowercase() to it.index }
        val cards = lesson.themes.mapIndexed { theme, value ->
            value.flashcards.mapIndexed { index, card -> card to lesson.progress.cards["$theme:$index"] }.toMutableList()
        }
        if (cards.isEmpty()) return lesson
        var changed = false
        for (row in rows) {
            val id = row.str("id").lowercase()
            if (id.isEmpty() || "card:$id" in tombstones) continue
            val remoteUpdated = time(row.str("updated_at"))
            val gone = row.str("deleted_at").isNotEmpty() || row.bool("is_suspended") == true
            var theme = -1
            var index = -1
            for ((position, list) in cards.withIndex()) {
                val found = list.indexOfFirst { it.first.id.lowercase() == id }
                if (found >= 0) {
                    theme = position
                    index = found
                    break
                }
            }
            if (index < 0) {
                if (gone) continue
                val entry = cardFrom(row) ?: continue
                val target = row.str("chapter_id").lowercase().takeIf { it.isNotEmpty() }?.let { chapterIndex[it] } ?: cards.lastIndex
                cards[target].add(entry)
                changed = true
                continue
            }
            val local = cards[theme][index]
            if (remoteUpdated <= (local.second?.updatedAt ?: 0)) continue
            if (gone) {
                cards[theme].removeAt(index)
                changed = true
                continue
            }
            // Une carte qu'Android ne sait pas montrer reste telle qu'elle était ici.
            val entry = cardFrom(row) ?: continue
            // La même carte, la même mémoire : rien à réécrire, seule la date diffère.
            if (entry.first == local.first && entry.second?.copy(updatedAt = 0) == local.second?.copy(updatedAt = 0)) continue
            cards[theme][index] = entry
            changed = true
        }
        return if (changed) lesson.withCards(cards) else lesson
    }

    /**
     * **Les jours étudiés ailleurs allument la série d'ici** (`review_logs`). L'historique monte
     * depuis Android ; il ne redescendait jamais, et la série d'un élève qui révise sur les deux
     * appareils se cassait les jours passés sur l'iPhone. Seule la date est lue : Android ne
     * garde pas l'historique lui-même, il n'en a pas l'usage.
     */
    private fun pullReviewDays(token: String, user: String, from: String) {
        val streak = streak ?: return
        val rows = selectAll(
            token,
            "review_logs",
            "user_id=eq.$user&reviewed_at=gt.${encode(from)}&order=reviewed_at.desc",
            select = "reviewed_at",
            maxRows = 10_000,
        )
        val days = rows.mapNotNull { row -> time(row.str("reviewed_at")).takeIf { it > 0 }?.let(streak::stampOf) }.toSet()
        streak.merge(days)
    }

    /**
     * Une ligne `flashcards` devenue carte, avec sa mémoire ; `null` pour une carte suspendue,
     * ou qu'Android ne sait pas montrer (une occlusion, qui a besoin de son schéma). Le `kind`
     * reste celui du serveur : un QCM reste un QCM (voir `Flashcard`).
     */
    private fun cardFrom(row: JsonObject): Pair<Flashcard, CardReview?>? {
        if (row.bool("is_suspended") == true) return null
        val kind = row.str("kind").ifEmpty { "basic" }
        if (kind == "occlusion") return null
        val card = Flashcard(
            kind = kind,
            front = row.str("front"),
            back = row.str("back"),
            id = row.str("id").lowercase(),
            choices = (row["choices"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull },
            correctChoice = row.int("correct_choice_index") ?: 0,
        )
        if (card.front.isBlank() || card.answer.isBlank()) return null
        val state = row.str("state").ifEmpty { CardState.NEW }
        val review = if (state == CardState.NEW) null else CardReview(
            state = state,
            interval = row.double("interval_days") ?: 0.0,
            ease = row.double("ease_factor") ?: Srs.STARTING_EASE,
            reps = row.int("repetitions") ?: 0,
            lapses = row.int("lapses") ?: 0,
            step = row.int("step_index") ?: 0,
            due = row.str("due_date").takeIf { it.isNotEmpty() }?.let(::time) ?: 0,
            updatedAt = row.str("updated_at").takeIf { it.isNotEmpty() }?.let(::time) ?: 0,
        )
        return card to review
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
            val entry = cardFrom(card) ?: continue
            val theme = card.str("chapter_id").lowercase().let { chapterIndex[it] } ?: themes.lastIndex
            byTheme[theme].add(entry)
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
            themes = themes,
            tone = TONES.indexOf(row.str("tone")).takeIf { it >= 0 } ?: 2,
            progress = Progress(done = done, quizScores = scores, seconds = seconds, finishedAt = finishedAt, missed = missed),
            examDate = local?.examDate ?: 0,
            chat = local?.chat.orEmpty(),
            visibility = row.str("visibility").ifEmpty { null },
        ).withCards(byTheme)
    }

    /**
     * **Un cours sans chemin, devenu leçon** (`Lesson.legacy`) : une ancienne fiche, ou un paquet
     * de cartes fait sur l'iPhone ou le site. Ses parties (`chapters`) font les thèmes, leurs
     * notes ou leur fiche se lisent ; sans partie, la fiche du cours fait un thème unique. Pas
     * de génération : tout est prêt, et les quiz sans question se passent d'un appui. Ce qui a
     * été fait ici sur le chemin reste ici ; ses cartes, elles, se révisent et remontent.
     */
    private fun legacyLessonFrom(row: JsonObject, chapterRows: List<JsonObject>, cardRows: List<JsonObject>, local: Lesson?): Lesson {
        val title = row.str("title")
        val chapterIndex = HashMap<String, Int>()
        val chapters = chapterRows.sortedBy { it.int("position") ?: 0 }
        val themes = if (chapters.isEmpty()) {
            listOf(
                Theme(
                    title = title,
                    status = ThemeStatus.READY,
                    notes = notesFromSheet(row["sheet"]) ?: ThemeNotes(oneLiner = row.str("summary")),
                ),
            )
        } else {
            chapters.mapIndexed { index, chapter ->
                val id = chapter.str("id").lowercase()
                chapterIndex[id] = index
                val notes = (chapter["notes"] as? JsonObject)?.let { runCatching { MicaboJson.decodeFromJsonElement<ThemeNotes>(it) }.getOrNull() }
                    ?: notesFromSheet(chapter["sheet"])
                    ?: ThemeNotes()
                val questions = ((chapter["quiz"] as? JsonObject)?.get("questions") as? JsonArray).orEmpty().mapNotNull { item ->
                    runCatching { MicaboJson.decodeFromJsonElement<Question>(item) }.getOrNull()?.takeIf { it.isValid }
                }
                Theme(
                    title = chapter.str("title").ifBlank { title },
                    id = id,
                    icon = chapter.str("icon").ifEmpty { "livre-ouvert" },
                    status = ThemeStatus.READY,
                    notes = notes,
                    questions = questions,
                )
            }
        }
        val byTheme = MutableList(themes.size) { mutableListOf<Pair<Flashcard, CardReview?>>() }
        for (card in cardRows) {
            val entry = cardFrom(card) ?: continue
            val theme = card.str("chapter_id").lowercase().takeIf { it.isNotEmpty() }?.let { chapterIndex[it] } ?: themes.lastIndex
            byTheme[theme].add(entry)
        }
        val id = row.str("id").lowercase()
        return Lesson(
            id = id,
            title = title,
            subject = row.str("subject"),
            icon = local?.icon ?: "livre-ouvert",
            createdAt = row.str("created_at").takeIf { it.isNotEmpty() }?.let(::time) ?: System.currentTimeMillis(),
            openedAt = row.str("last_opened_at").takeIf { it.isNotEmpty() }?.let(::time) ?: local?.openedAt ?: 0,
            language = row.str("language").ifEmpty { local?.language ?: "en" },
            // La provenance brute : un paquet (`deck`), un exemple, la bibliothèque ne consomment
            // pas la leçon offerte (`Lesson.usesFreeLesson`). Elle ne remonte jamais d'ici.
            source = if (row.bool("is_from_library") == true) "library" else row.str("source").ifEmpty { "text" },
            topic = local?.topic.orEmpty(),
            contextText = row.str("context_text"),
            intro = Intro(lines = listOfNotNull(row.str("summary").trim().takeIf { it.isNotEmpty() })),
            singleQuiz = true,
            themes = themes,
            tone = local?.tone ?: TONES.indexOf(row.str("tone")).takeIf { it >= 0 } ?: Math.floorMod(id.hashCode(), TONES.size),
            progress = local?.progress ?: Progress(),
            examDate = local?.examDate ?: 0,
            chat = local?.chat.orEmpty(),
            visibility = row.str("visibility").ifEmpty { null },
            legacy = true,
        ).withCards(byTheme)
    }

    /**
     * La fiche d'un ancien cours (`CourseSheet`), lue comme des notes. Ses quatre blocs passent
     * presque tels quels : le titre de partie devient un sous-titre, une liste numérotée des
     * étapes ; un bloc d'avant la refonte retombe sur son texte (`NoteBlock.parse`).
     */
    private fun notesFromSheet(sheet: JsonElement?): ThemeNotes? {
        val blocks = ((sheet as? JsonObject)?.get("blocks") as? JsonArray).orEmpty().mapNotNull { item ->
            val block = item as? JsonObject ?: return@mapNotNull null
            when (block.str("type")) {
                "heading" -> buildJsonObject {
                    put("type", "subtitle")
                    put("text", block.str("text"))
                }
                "list" -> if (block.bool("ordered") == true && block.strings("items").size >= 2) JsonObject(block + ("type" to JsonPrimitive("steps"))) else block
                else -> block
            }
        }
        return if (blocks.isEmpty()) null else ThemeNotes(blocks = blocks)
    }

    // MARK: - Pousser

    /**
     * Pousse ce qui a changé ; rend le nombre de leçons montées. Une leçon qui vient de
     * descendre en entier (`pulled`), et n'a pas bougé depuis, ne remonte pas : elle serait
     * renvoyée telle qu'Android la décrit, et ce qu'il ne tient pas de sa progression s'y perdrait.
     */
    private fun push(token: String, user: String, since: Long, pulled: Map<String, Long>): Int {
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

        val changed = lessons.lessons.value.values.filter { it.updatedAt > since && pulled[it.id] != it.updatedAt }
        for (lesson in changed) {
            val stamped = lesson.stamped()
            // Un ancien cours ou un paquet : seules ses cartes remontent (`Lesson.legacy`).
            if (!stamped.legacy) {
                upsert(token, "courses", listOf(courseRow(stamped, user)))
                upsert(token, "chapters", stamped.themes.mapIndexed { index, theme -> chapterRow(stamped, theme, index, user) })
            }
            upsert(token, "flashcards", cardRows(stamped, user))
        }

        // Les cartes notées, après les cartes elles-mêmes (`card_id` y renvoie).
        val reviews = prefs.pendingReviews.toList()
        reviews.chunked(200).forEach { chunk ->
            val rows = chunk.mapNotNull { line ->
                (runCatching { MicaboJson.parseToJsonElement(line) }.getOrNull() as? JsonObject)?.let { JsonObject(it + ("user_id" to JsonPrimitive(user))) }
            }
            val result = if (rows.isEmpty()) null else request(
                "POST",
                "review_logs",
                JsonArray(rows).toString(),
                token,
                mapOf("Prefer" to "resolution=ignore-duplicates,return=minimal"),
            )
            // Un refus (une carte supprimée entre-temps) ne passera pas mieux plus tard : le lot est laissé.
            if (result != null && result.status >= 500) throw IOException("POST review_logs ${result.status}")
            prefs.removeReviews(chunk)
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
                    // Rendus tels qu'ils sont descendus ; absents, la base garde les siens.
                    exam.kind?.let { put("kind", it) }
                    exam.intensity?.let { put("intensity", it) }
                    exam.targetScore?.let { put("target_score", it) }
                    exam.startingPoint?.let { put("starting_point", it) }
                    put("updated_at", iso(exam.updatedAt))
                }
            })
        }
        return changed.size
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
        // Une visibilité jamais lue ni choisie ici ne part pas : celle de l'iPhone reste.
        lesson.visibility?.let { put("visibility", it) }
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

    /**
     * Les lignes `flashcards`. Le `kind` part tel qu'il est gardé, QCM compris, avec ses
     * propositions : c'est l'iPhone ou le site qui décident comment montrer une carte, pas ce
     * qu'Android sait en afficher. Les colonnes qu'Android ne tient pas (l'indice, le schéma,
     * le groupe) ne partent pas, et restent telles quelles au serveur (`merge-duplicates`).
     *
     * Pour un ancien cours, ni le chapitre ni le rang ne partent : ses thèmes ne sont pas
     * forcément des lignes `chapters`, et l'ordre de ses cartes appartient à l'iPhone.
     */
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
                    if (!lesson.legacy) {
                        put("chapter_id", theme.id.lowercase())
                        put("position", position++)
                    }
                    put("front", card.front)
                    put("back", card.back)
                    put("kind", card.kind.takeIf { it in CARD_KINDS } ?: "basic")
                    if (card.kind == "choice" && card.choices.isNotEmpty()) {
                        putJsonArray("choices") { card.choices.forEach { add(JsonPrimitive(it)) } }
                        put("correct_choice_index", card.correctChoice)
                    }
                    put("state", review.state)
                    put("due_date", if (review.due > 0) iso(review.due) else now)
                    put("interval_days", review.interval)
                    put("ease_factor", review.ease)
                    put("repetitions", review.reps)
                    put("lapses", review.lapses)
                    put("step_index", review.step)
                    // La note la plus récente date la carte, même si la leçon a bougé avant elle.
                    put("updated_at", iso(maxOf(lesson.updatedAt, review.updatedAt)))
                }
            }
        }
    }

    // MARK: - PostgREST

    /** Toutes les lignes d'un filtre, page après page ; `maxRows` borne un historique sans fin. */
    private fun selectAll(token: String, table: String, filter: String, select: String = "*", maxRows: Int = Int.MAX_VALUE): List<JsonObject> {
        val out = mutableListOf<JsonObject>()
        var offset = 0
        while (true) {
            val result = request("GET", "$table?select=$select&$filter&limit=$PAGE&offset=$offset", null, token)
            if (result.status !in 200..299) throw IOException("GET $table ${result.status}: ${result.body.take(160)}")
            val page = MicaboJson.parseToJsonElement(result.body).jsonArray.mapNotNull { it as? JsonObject }
            out.addAll(page)
            if (page.size < PAGE || out.size >= maxRows) return out
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
        val COUNTRY = Regex("^[a-z]{2}$")
        /** Les formes de carte de l'iPhone et du site (`CardKind`) : une autre repart en recto verso. */
        val CARD_KINDS = setOf("basic", "cloze", "choice", "occlusion")

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
