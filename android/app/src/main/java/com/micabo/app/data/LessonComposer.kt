package com.micabo.app.data

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.micabo.app.R
import com.micabo.app.i18n.AppLocale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.UUID

/** Une icône d'import sous la barre (`LessonComposer.Kind`). */
enum class SupportKind { PDF, PHOTO, AUDIO, YOUTUBE, TEXT }

/** Un support déposé dans la barre : en lecture, prêt, ou illisible. */
data class Support(
    val id: String,
    val kind: SupportKind,
    val title: String,
    val document: ImportedDocument? = null,
    /** La phrase de l'échec, si le support n'a pas pu être lu. */
    val failure: Int? = null,
) {
    val isReading: Boolean get() = document == null && failure == null
    val isReady: Boolean get() = document != null
}

/**
 * **Ce que l'élève prépare sur l'accueil** (`LessonComposer` sur iPhone) : un sujet tapé, et
 * jusqu'à cinq supports lus sur le téléphone dès qu'on les dépose. Un PDF illisible le dit sur
 * sa pastille, pas trente secondes plus tard. Il vit dans l'app, pas dans l'écran : ouvrir le
 * paywall ou une leçon ne fait rien perdre.
 */
class LessonComposer(
    private val context: Context,
    private val youtube: YouTubeImport,
    private val audio: AudioImport? = null,
    private val track: (String, Map<String, Any?>) -> Unit = { _, _ -> },
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    /** Les lectures en cours : retirer un support arrête la sienne (un PDF de quarante pages à l'OCR). */
    private val jobs = mutableMapOf<String, Job>()

    var draft by mutableStateOf("")
    val supports = mutableStateListOf<Support>()

    val hasRoom: Boolean get() = supports.size < MAX_SUPPORTS
    val isReading: Boolean get() = supports.any { it.isReading }
    val ready: List<Support> get() = supports.filter { it.isReady }
    private val topic: String get() = draft.trim()

    /** Un sujet d'au moins deux lettres, ou des supports lus. */
    val canSend: Boolean get() = !isReading && (ready.isNotEmpty() || topic.length >= 2)

    /** D'où vient la leçon : la porte du gratuit et le serveur la lisent. */
    val source: String
        get() {
            val kinds = ready.mapNotNull { it.document?.source }.toSet()
            return when {
                kinds.isEmpty() -> "topic"
                kinds.size == 1 -> kinds.first()
                else -> "mixed"
            }
        }

    /** Les imports sont Pro ; un texte collé, non (`LessonSourceKind.isImport`). */
    val needsPro: Boolean get() = source != "topic" && source != "text"

    /** Une phrase dans la langue de l'app, pas celle du téléphone : le contexte de l'app ne la suit pas. */
    private fun localized(id: Int, vararg args: Any): String =
        AppLocale.wrap(context, Prefs.storedLanguage(context)).getString(id, *args)

    fun remove(id: String) {
        jobs.remove(id)?.cancel()
        supports.removeAll { it.id == id }
    }

    fun reset() {
        jobs.values.forEach { it.cancel() }
        jobs.clear()
        draft = ""
        supports.clear()
    }

    private fun read(kind: SupportKind, title: String, work: suspend () -> ImportedDocument) {
        if (!hasRoom) return
        val id = UUID.randomUUID().toString()
        supports.add(Support(id, kind, title))
        jobs[id] = scope.launch {
            val outcome = runCatching { work() }
            jobs.remove(id)
            val index = supports.indexOfFirst { it.id == id }
            if (index < 0) return@launch
            val document = outcome.getOrNull()
            if (document != null && document.isUsable) {
                track("import_document_read", mapOf("kind" to document.source, "chars" to document.text.length, "pages" to document.images.size))
            } else {
                track("import_document_failed", mapOf("kind" to kind.name.lowercase()))
            }
            supports[index] = when {
                document != null && document.isUsable -> supports[index].copy(title = document.name, document = document)
                else -> supports[index].copy(failure = failureMessage(outcome.exceptionOrNull()))
            }
        }
    }

    /** La phrase d'un échec : celle de l'import, le réseau, ou « illisible ». */
    private fun failureMessage(error: Throwable?): Int = when (error) {
        is ImportException -> error.messageRes
        is NetworkException -> R.string.x_error_network
        else -> R.string.lesson_import_unreadable
    }

    fun addFile(uri: Uri) {
        val name = displayName(context, uri)
        val type = context.contentResolver.getType(uri).orEmpty()
        val isWord = type.contains("wordprocessingml") || uri.toString().endsWith(".docx", ignoreCase = true)
        read(SupportKind.PDF, name ?: if (isWord) "Word" else "PDF") {
            if (isWord) DocxImport.read(context, uri) else PdfImport.read(context, uri)
        }
    }

    fun addPhotos(uris: List<Uri>) {
        if (uris.isEmpty()) return
        val name = if (uris.size == 1) localized(R.string.ios_photo_courseName) else localized(R.string.ios_photo_scanName, uris.size.toString())
        read(SupportKind.PHOTO, name) { PhotoImport.read(context, uris, name) }
    }

    /** Un enregistrement ou un fichier audio : le serveur le transcrit (`transcribe-audio`). */
    fun addAudio(uri: Uri, fromRecorder: Boolean) {
        val transcriber = audio ?: return
        val name = if (fromRecorder) localized(R.string.lesson_import_recordingName) else displayName(context, uri) ?: localized(R.string.lesson_import_audio)
        val language = AppLocale.resolved(Prefs.storedLanguage(context)).content
        read(SupportKind.AUDIO, name) {
            try {
                transcriber.transcribe(context, uri, name, language)
            } finally {
                // L'enregistrement du micro ne sert plus une fois transcrit (ou refusé).
                if (fromRecorder) uri.path?.let { java.io.File(it).delete() }
            }
        }
    }

    fun addYouTube(link: String) {
        read(SupportKind.YOUTUBE, localized(R.string.lesson_import_youtube)) {
            val video = youtube.transcript(link)
            ImportedDocument(
                text = video.text,
                images = emptyList(),
                name = video.title.ifBlank { localized(R.string.lesson_import_youtube) },
                source = "youtube",
            )
        }
    }

    fun addText(text: String) {
        val name = localized(R.string.lesson_import_pastedName)
        read(SupportKind.TEXT, name) { ImportedDocument(text = text, images = emptyList(), name = name, source = "text") }
    }

    /** Le cours d'un ami, repris : son texte devient un support, sous son titre. */
    fun addShared(title: String, text: String) {
        val name = title.ifBlank { localized(R.string.lesson_import_pastedName) }
        read(SupportKind.TEXT, name) { ImportedDocument(text = text, images = emptyList(), name = name, source = "text") }
    }

    /**
     * Tout ce qui part au serveur (`LessonComposer.creation`). Un sujet seul part comme sujet ;
     * avec des supports, ce qui est tapé devient la consigne de l'élève, en tête du texte.
     */
    fun request(examDate: Long?): LessonRequest {
        val supports = ready
        if (supports.isEmpty()) return LessonRequest(topic = topic, text = "", examDate = examDate)
        val parts = mutableListOf<String>()
        if (topic.isNotEmpty()) parts.add(localized(R.string.lesson_import_instruction, topic))
        supports.mapNotNull { it.document }.filter { it.text.isNotBlank() }.forEach { document ->
            parts.add(if (supports.size > 1) "--- ${document.name} ---\n${document.text}" else document.text)
        }
        return LessonRequest(
            topic = null,
            text = parts.joinToString("\n\n").take(LessonRepository.MAX_TEXT),
            sourceName = supports.singleOrNull()?.document?.name,
            images = withinBudget(supports.mapNotNull { it.document }.flatMap { it.images }),
            source = source,
            examDate = examDate,
        )
    }

    /** Six pages au plus, et pas plus de signes que le serveur n'en garde (`acceptedImages`). */
    private fun withinBudget(images: List<String>): List<String> {
        val kept = mutableListOf<String>()
        var total = 0
        for (image in images) {
            if (kept.size >= MAX_IMAGES || total + image.length > MAX_IMAGE_CHARS) break
            total += image.length
            kept.add(image)
        }
        return kept
    }

    companion object {
        const val MAX_SUPPORTS = 5
        const val MAX_IMAGES = 6
        const val MAX_IMAGE_CHARS = 4_000_000
    }
}
