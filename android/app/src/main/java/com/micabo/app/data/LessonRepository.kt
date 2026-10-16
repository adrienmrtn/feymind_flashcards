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

/** Ce que l'élève demande : un sujet tapé, ou un texte collé. */
data class LessonRequest(val topic: String?, val text: String, val sourceName: String? = null) {
    val source: String get() = if (topic != null) "topic" else "text"
}

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
) {
    private val directory = File(context.filesDir, "lessons").apply { mkdirs() }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val diskLock = Mutex()
    private val writing = MutableStateFlow<Set<String>>(emptySet())
    private val themeLimiter = Semaphore(PARALLEL_THEMES)

    private val _lessons = MutableStateFlow<Map<String, Lesson>>(emptyMap())
    val lessons: StateFlow<Map<String, Lesson>> = _lessons.asStateFlow()

    init {
        scope.launch(Dispatchers.IO) {
            val loaded = directory.listFiles { file -> file.extension == "json" }.orEmpty().mapNotNull { file ->
                runCatching { MicaboJson.decodeFromString(Lesson.serializer(), file.readText()) }
                    .onFailure { Log.w(TAG, "Leçon illisible : ${file.name}", it) }
                    .getOrNull()
            }
            _lessons.update { current -> loaded.associateBy { it.id } + current }
        }
    }

    fun lesson(id: String): Lesson? = _lessons.value[id]

    private fun save(lesson: Lesson) {
        _lessons.update { it + (lesson.id to lesson) }
        scope.launch(Dispatchers.IO) {
            diskLock.withLock {
                val latest = _lessons.value[lesson.id] ?: return@withLock
                runCatching {
                    val temp = File(directory, "${latest.id}.json.tmp")
                    temp.writeText(MicaboJson.encodeToString(Lesson.serializer(), latest))
                    temp.renameTo(File(directory, "${latest.id}.json"))
                }.onFailure { Log.w(TAG, "Leçon non enregistrée", it) }
            }
        }
    }

    fun modify(id: String, change: (Lesson) -> Lesson) {
        val current = _lessons.value[id] ?: return
        save(change(current))
    }

    fun delete(id: String) {
        _lessons.update { it - id }
        scope.launch(Dispatchers.IO) { diskLock.withLock { File(directory, "$id.json").delete() } }
    }

    fun deleteAll() {
        _lessons.value = emptyMap()
        scope.launch(Dispatchers.IO) { diskLock.withLock { directory.listFiles().orEmpty().forEach { it.delete() } } }
    }

    fun markOpened(id: String) = modify(id) { it.copy(openedAt = System.currentTimeMillis()) }

    fun complete(id: String, circle: String, score: List<Int>? = null) = modify(id) { lesson ->
        val progress = lesson.progress
        val scores = if (score != null) progress.quizScores + (circle to score) else progress.quizScores
        val done = progress.done + circle
        val finished = circle == "final" && progress.finishedAt == 0L
        lesson.copy(progress = progress.copy(done = done, quizScores = scores, finishedAt = if (finished) System.currentTimeMillis() else progress.finishedAt))
    }

    fun restart(id: String) = modify(id) { it.copy(progress = Progress(seconds = it.progress.seconds)) }

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
        val id = UUID.randomUUID().toString().lowercase()
        val profile = prefs.profile.value
        onStage(CreationStage.READING)
        val payload = buildJsonObject {
            audience(profile)
            put("stage", "plan")
            put("lessonId", id)
            put("source", request.source)
            put("text", request.text.take(MAX_TEXT))
            putJsonArray("images") {}
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
        val wanted = lesson.themes.withIndex().filter { (index, theme) ->
            val key = "$id:$index"
            key !in writing.value && (theme.status == ThemeStatus.PENDING || (retryFailed && theme.status == ThemeStatus.FAILED))
        }.map { it.index }
        if (wanted.isEmpty()) return
        writing.update { it + wanted.map { index -> "$id:$index" } }
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
            audience(profile, language = lesson.language)
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

    private fun JsonObjectBuilder.audience(profile: Profile, language: String = contentLanguage(profile)) {
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

    private fun levelOf(tier: String): String = when (tier) {
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
