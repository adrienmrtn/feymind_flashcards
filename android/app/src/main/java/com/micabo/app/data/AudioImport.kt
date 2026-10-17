package com.micabo.app.data

import android.content.Context
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Base64
import com.micabo.app.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.io.File

/**
 * **Un cours enregistré** : au micro, ou depuis un fichier audio du téléphone. L'iPhone le
 * transcrit sur place ; Android l'envoie à `transcribe-audio`, compressé (AAC mono 16 kHz à
 * 24 kb/s : une heure et demie tient sous la limite du serveur), et reçoit le texte.
 */
class AudioImport(private val functions: SupabaseFunctions) {
    /** Transcrit un fichier et le rend comme un support. */
    suspend fun transcribe(context: Context, uri: Uri, name: String, language: String): ImportedDocument = withContext(Dispatchers.IO) {
        val size = runCatching {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else -1L
            } ?: -1L
        }.getOrDefault(-1L)
        if (size > MAX_BYTES) throw ImportException(R.string.lesson_audio_tooLong)
        val bytes = runCatching { context.contentResolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull()
            ?: throw ImportException(R.string.lesson_audio_unreadable)
        if (bytes.size > MAX_BYTES) throw ImportException(R.string.lesson_audio_tooLong)
        if (bytes.size < 2_000) throw ImportException(R.string.lesson_audio_empty)
        val type = context.contentResolver.getType(uri)?.takeIf { it.startsWith("audio/") } ?: "audio/mp4"
        val envelope = try {
            functions.call("transcribe-audio", buildJsonObject {
                put("audio", Base64.encodeToString(bytes, Base64.NO_WRAP))
                put("mimeType", type)
                put("language", language)
            }, timeoutMs = 320_000)
        } catch (error: ApiException) {
            if (error.opensPaywall) throw error
            throw ImportException(
                when (error.code) {
                    "too_long" -> R.string.lesson_audio_tooLong
                    "too_short" -> R.string.lesson_audio_empty
                    else -> R.string.lesson_audio_unreadable
                },
            )
        }
        val text = (envelope["transcript"] as? JsonObject)?.str("text").orEmpty()
        if (text.length < 40) throw ImportException(R.string.lesson_audio_empty)
        ImportedDocument(text = text, images = emptyList(), name = name, source = "audio")
    }

    companion object {
        /** Ce que le serveur accepte, base64 compris (`transcribe-audio`). */
        const val MAX_BYTES = 18L * 1024 * 1024
        const val MAX_MINUTES = 90
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
