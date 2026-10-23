package com.micabo.app.data

import android.content.Context
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.util.Base64
import com.micabo.app.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.io.File
import java.io.OutputStream

/**
 * **Un cours enregistré** : au micro, ou depuis un fichier audio du téléphone. L'iPhone le
 * transcrit sur place ; Android l'envoie à `transcribe-audio`, compressé (AAC mono 16 kHz à
 * 24 kb/s : une heure et demie tient sous la limite du serveur), et reçoit le texte.
 *
 * **L'envoi se fait au fil de l'eau.** La fonction ne lit qu'un JSON (`audio` en base64,
 * `mimeType`, `language`) : on n'y touche pas, mais le corps n'est plus construit en mémoire.
 * Avant, le fichier entier, sa version base64 puis la chaîne JSON coexistaient (plus de 60 Mo
 * pour un cours d'une heure et demie), et les petits téléphones manquaient de mémoire. Le
 * fichier est maintenant lu par morceaux, encodé morceau par morceau, et écrit directement sur
 * la connexion (`SupabaseFunctions.callStreaming`).
 */
class AudioImport(private val functions: SupabaseFunctions) {
    /** Transcrit un fichier et le rend comme un support. */
    suspend fun transcribe(context: Context, uri: Uri, name: String, language: String): ImportedDocument = withContext(Dispatchers.IO) {
        // Un fichier du téléphone (un `content://`) est d'abord copié dans le cache, par
        // morceaux : on connaît alors sa taille exacte, et l'envoi peut être rejoué.
        var copied: File? = null
        try {
            val file = localFile(uri) ?: copyToCache(context, uri).also { copied = it }
            val size = file.length()
            if (size > MAX_BYTES) throw ImportException(R.string.lesson_audio_tooLong)
            if (size < 2_000) throw ImportException(R.string.lesson_audio_empty)
            val type = context.contentResolver.getType(uri)?.takeIf { it.startsWith("audio/") } ?: "audio/mp4"
            val head = "{\"audio\":\"".toByteArray(Charsets.UTF_8)
            val tail = ("\",\"mimeType\":" + JsonPrimitive(type).toString() + ",\"language\":" + JsonPrimitive(language).toString() + "}").toByteArray(Charsets.UTF_8)
            // La longueur exacte du base64 sans retour à la ligne, remplissage compris.
            val encoded = 4 * ((size + 2) / 3)
            val envelope = try {
                functions.callStreaming("transcribe-audio", head.size + encoded + tail.size, timeoutMs = 320_000) { output ->
                    output.write(head)
                    writeBase64(file, output)
                    output.write(tail)
                }
            } catch (error: ApiException) {
                // Pro seulement (402 `import_pro`) : le paywall s'ouvre (`LessonComposer`).
                if (error.opensPaywall) throw error
                // La porte injoignable (503) : une panne passagère, dite comme le réseau.
                if (error.status == 503) throw NetworkException(error)
                throw ImportException(
                    when {
                        error.code == "quota" || error.isDailyLimit -> R.string.lesson_error_dailyLimit
                        error.status == 401 -> R.string.x_error_generic
                        error.code == "too_long" -> R.string.lesson_audio_tooLong
                        error.code == "too_short" -> R.string.lesson_audio_empty
                        else -> R.string.lesson_audio_unreadable
                    },
                )
            }
            val text = (envelope["transcript"] as? JsonObject)?.str("text").orEmpty()
            if (text.length < 40) throw ImportException(R.string.lesson_audio_empty)
            ImportedDocument(text = text, images = emptyList(), name = name, source = "audio")
        } finally {
            copied?.delete()
        }
    }

    /** Le fichier lui-même, pour un enregistrement du micro (`file://`). */
    private fun localFile(uri: Uri): File? =
        if (uri.scheme == "file") uri.path?.let { File(it) }?.takeIf { it.isFile && it.canRead() } else null

    /** La copie d'un fichier du téléphone, arrêtée dès qu'elle dépasse la limite. */
    private fun copyToCache(context: Context, uri: Uri): File {
        val target = File(context.cacheDir, "upload-${System.currentTimeMillis()}.audio")
        try {
            val input = runCatching { context.contentResolver.openInputStream(uri) }.getOrNull()
                ?: throw ImportException(R.string.lesson_audio_unreadable)
            input.use { source ->
                target.outputStream().buffered(64 * 1024).use { sink ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) break
                        total += read
                        if (total > MAX_BYTES) throw ImportException(R.string.lesson_audio_tooLong)
                        sink.write(buffer, 0, read)
                    }
                }
            }
            return target
        } catch (error: ImportException) {
            target.delete()
            throw error
        } catch (error: java.io.IOException) {
            target.delete()
            throw ImportException(R.string.lesson_audio_unreadable)
        }
    }

    /**
     * Le fichier en base64, par morceaux d'un multiple de trois octets : aucun remplissage au
     * milieu, et le résultat est exactement celui d'un seul encodage du fichier entier.
     */
    private fun writeBase64(file: File, output: OutputStream) {
        file.inputStream().buffered(CHUNK).use { input ->
            val buffer = ByteArray(CHUNK)
            while (true) {
                // Remplit le morceau en entier (sauf à la fin du fichier) : un morceau court au
                // milieu mettrait un remplissage `=` au milieu du base64.
                var filled = 0
                while (filled < CHUNK) {
                    val read = input.read(buffer, filled, CHUNK - filled)
                    if (read < 0) break
                    filled += read
                }
                if (filled == 0) break
                output.write(Base64.encode(buffer, 0, filled, Base64.NO_WRAP))
                if (filled < CHUNK) break
            }
        }
    }

    companion object {
        /**
         * Ce que le serveur accepte : 25 millions de caractères de base64 (`MAX_AUDIO_CHARS`),
         * soit un peu moins de 18,75 millions d'octets. 18 Mio (18 874 368 octets) donnaient
         * 25,2 millions de caractères, refusés.
         */
        const val MAX_BYTES = 18_000_000L
        const val MAX_MINUTES = 90
        /** Un morceau d'encodage : un multiple de trois, 48 Kio. */
        private const val CHUNK = 3 * 16 * 1024
    }
}

/** **Le micro** : un enregistrement AAC dans le cache, jusqu'à quatre-vingt-dix minutes. */
class ClassRecorder(private val context: Context) {
    private var recorder: MediaRecorder? = null
    var file: File? = null
        private set
    private var startedAt = 0L

    val elapsedMs: Long get() = if (recorder == null) 0 else System.currentTimeMillis() - startedAt

    /** Démarre ; rend faux si le micro n'a pas pu s'ouvrir. */
    fun start(onLimit: () -> Unit): Boolean {
        stopQuietly()
        val output = File(context.cacheDir, "recording-${System.currentTimeMillis()}.m4a")
        val created = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(context) else @Suppress("DEPRECATION") MediaRecorder()
        return try {
            created.setAudioSource(MediaRecorder.AudioSource.MIC)
            created.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            created.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            created.setAudioChannels(1)
            created.setAudioSamplingRate(16_000)
            created.setAudioEncodingBitRate(24_000)
            created.setMaxDuration(AudioImport.MAX_MINUTES * 60_000)
            created.setOnInfoListener { _, what, _ ->
                if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) onLimit()
            }
            created.setOutputFile(output.absolutePath)
            created.prepare()
            created.start()
            recorder = created
            file = output
            startedAt = System.currentTimeMillis()
            true
        } catch (error: Exception) {
            runCatching { created.release() }
            output.delete()
            false
        }
    }

    /** Arrête et rend le fichier, ou rien si l'enregistrement a échoué. */
    fun stop(): File? {
        val current = recorder ?: return null
        recorder = null
        val stopped = runCatching { current.stop() }.isSuccess
        runCatching { current.release() }
        return file?.takeIf { stopped && it.length() > 2_000 }
    }

    fun stopQuietly() {
        recorder?.let { runCatching { it.stop() }; runCatching { it.release() } }
        recorder = null
    }
}
