package com.micabo.app.data

import android.net.Uri
import com.micabo.app.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

/** **Les liens YouTube** (`YouTubeLink`) : l'identifiant de la vidéo, ou rien. */
object YouTubeLink {
    private val hosts = setOf("youtube.com", "m.youtube.com", "music.youtube.com", "youtube-nocookie.com", "youtu.be")
    private val prefixes = setOf("shorts", "embed", "live", "v")
    private val idPattern = Regex("^[A-Za-z0-9_-]{11}$")

    fun videoId(raw: String): String? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return null
        val uri = runCatching { Uri.parse(if (trimmed.lowercase().startsWith("http")) trimmed else "https://$trimmed") }.getOrNull() ?: return null
        val host = uri.host?.lowercase()?.removePrefix("www.") ?: return null
        if (host !in hosts) return null
        val segments = uri.pathSegments.orEmpty()
        val query = runCatching { uri.getQueryParameter("v") }.getOrNull()
        val candidate = when {
            host == "youtu.be" -> segments.firstOrNull()
            segments.firstOrNull() == "watch" -> query
            segments.size >= 2 && segments[0] in prefixes -> segments[1]
            else -> query
        }
        return candidate?.takeIf { idPattern.matches(it) }
    }
}

/** La vidéo transcrite, prête à devenir un support. */
data class YouTubeTranscript(val title: String, val text: String)

/**
 * **Une vidéo YouTube** (`YouTubeImportService`) : les sous-titres lus d'abord sur le téléphone
 * — YouTube bloque les IP des serveurs, pas celle du téléphone —, puis la fonction
 * `youtube-transcript` en repli, qui sait aussi faire regarder la vidéo au modèle.
 */
class YouTubeImport(private val functions: SupabaseFunctions) {
    suspend fun transcript(link: String): YouTubeTranscript {
        val id = YouTubeLink.videoId(link) ?: throw ImportException(R.string.ios_yt_invalidLink)
        val languages = preferredLanguages()
        runCatching { OnDevice.transcript(id, languages) }.getOrNull()?.let { return it }
        val envelope = try {
            functions.call("youtube-transcript", buildJsonObject {
                put("url", link.trim())
                putJsonArray("languages") { languages.forEach { add(JsonPrimitive(it)) } }
            }, timeoutMs = 240_000)
        } catch (error: ApiException) {
            // Un compte gratuit sans sa leçon offerte (402 `import_pro`) : le paywall s'ouvre
            // (`LessonComposer`), au lieu d'un « pas de sous-titres » qui ne disait rien de vrai.
            if (error.opensPaywall) throw error
            // La porte injoignable (503) : une panne passagère, dite comme le réseau.
            if (error.status == 503) throw NetworkException(error)
            throw ImportException(
                when {
                    // Le plafond du jour des lectures par le modèle (code « quota », 429) : le dire
                    // tel quel, au lieu d'un « pas de sous-titres » qu'on réessaierait.
                    error.code == "quota" || error.isDailyLimit -> R.string.lesson_error_dailyLimit
                    // Sans session (401) : rien à voir avec la vidéo.
                    error.status == 401 -> R.string.x_error_generic
                    else -> when (error.code) {
                        "invalid_url" -> R.string.ios_yt_invalidLink
                        "unavailable" -> R.string.ios_yt_unavailable
                        "too_short" -> R.string.ios_yt_tooShort
                        else -> R.string.ios_yt_noCaptions
                    }
                },
            )
        }
        val video = envelope["video"] as? JsonObject
        val transcript = envelope["transcript"] as? JsonObject ?: throw ImportException(R.string.ios_yt_noCaptions)
        val text = transcript.str("text")
        if (text.length < 40) throw ImportException(R.string.ios_yt_tooShort)
        return YouTubeTranscript(title = video?.str("title").orEmpty(), text = text)
    }

    private fun preferredLanguages(): List<String> {
        val out = linkedSetOf<String>()
        val device = android.os.LocaleList.getDefault()
        for (index in 0 until minOf(device.size(), 6)) device[index].language.takeIf { it.isNotEmpty() }?.let(out::add)
        Locale.getDefault().language.takeIf { it.isNotEmpty() }?.let(out::add)
        return out.toList().ifEmpty { listOf("fr") }
    }

    /** Le client Innertube iOS, exécuté sur le téléphone (`YouTubeOnDevice`). */
    private object OnDevice {
        private const val PLAYER = "https://www.youtube.com/youtubei/v1/player?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8&prettyPrint=false"
        private const val AGENT = "com.google.ios.youtube/20.10.38 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
        private const val MINIMUM = 400

        private data class Track(val code: String, val automatic: Boolean, val url: String)

        suspend fun transcript(id: String, languages: List<String>): YouTubeTranscript? = withContext(Dispatchers.IO) {
            val player = player(id, languages.firstOrNull() ?: "fr") ?: return@withContext null
            val title = (player["videoDetails"] as? JsonObject)?.str("title").orEmpty()
            val renderer = (player["captions"] as? JsonObject)?.get("playerCaptionsTracklistRenderer") as? JsonObject
            val tracks = (renderer?.get("captionTracks") as? JsonArray).orEmpty().mapNotNull { item ->
                val track = item as? JsonObject ?: return@mapNotNull null
                val url = track.str("baseUrl")
                val code = track.str("languageCode")
                if (url.isEmpty() || code.isEmpty()) null else Track(code, track.str("kind") == "asr", url)
            }
            for (track in ordered(tracks, languages)) {
                val text = captionText(track.url) ?: continue
                if (text.length >= MINIMUM) return@withContext YouTubeTranscript(title, text)
            }
            null
        }

        private fun player(id: String, language: String): JsonObject? {
            val body = buildJsonObject {
                put("videoId", id)
                put("contentCheckOk", true)
                put("racyCheckOk", true)
                putJsonObject("context") {
                    putJsonObject("client") {
                        put("clientName", "IOS")
                        put("clientVersion", "20.10.38")
                        put("deviceMake", "Apple")
                        put("deviceModel", "iPhone16,2")
                        put("osName", "iPhone")
                        put("osVersion", "18.3.2.22D82")
                        put("hl", language)
                        put("gl", "FR")
                    }
                }
            }
            val connection = (URL(PLAYER).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 20_000
                doOutput = true
                setRequestProperty("User-Agent", AGENT)
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("X-YouTube-Client-Name", "5")
                setRequestProperty("X-YouTube-Client-Version", "20.10.38")
            }
            return try {
                connection.outputStream.use { it.write(body.toString().toByteArray()) }
                if (connection.responseCode !in 200..299) return null
                val parsed = MicaboJson.parseToJsonElement(connection.inputStream.bufferedReader().use { it.readText() }).jsonObject
                val status = (parsed["playabilityStatus"] as? JsonObject)?.str("status")?.ifEmpty { null } ?: "OK"
                if (status != "OK" || parsed["videoDetails"] !is JsonObject) null else parsed
            } catch (error: Exception) {
                null
            } finally {
                connection.disconnect()
            }
        }

        private fun ordered(tracks: List<Track>, languages: List<String>): List<Track> {
            val out = linkedSetOf<Track>()
            for (language in languages) {
                tracks.firstOrNull { !it.automatic && same(it.code, language) }?.let(out::add)
                tracks.firstOrNull { it.automatic && same(it.code, language) }?.let(out::add)
            }
            out.addAll(tracks)
            return out.toList()
        }

        private fun same(a: String, b: String) =
            a.split('-', '_').first().equals(b.split('-', '_').first(), ignoreCase = true)

        private fun captionText(base: String): String? {
            fetch(base, "json3")?.let(::fromJson3)?.takeIf { it.isNotEmpty() }?.let { return it }
            fetch(base, null)?.let(::fromXml)?.takeIf { it.isNotEmpty() }?.let { return it }
            fetch(base, "vtt")?.let(::fromVtt)?.takeIf { it.isNotEmpty() }?.let { return it }
            return null
        }

        private fun fetch(base: String, format: String?): String? {
            val uri = Uri.parse(base)
            val builder = uri.buildUpon().clearQuery()
            uri.queryParameterNames.filter { it != "fmt" }.forEach { name -> uri.getQueryParameters(name).forEach { builder.appendQueryParameter(name, it) } }
            if (format != null) builder.appendQueryParameter("fmt", format)
            val connection = (URL(builder.build().toString()).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 20_000
                setRequestProperty("User-Agent", AGENT)
            }
            return try {
                if (connection.responseCode !in 200..299) null else connection.inputStream.bufferedReader().use { it.readText() }
            } catch (error: Exception) {
                null
            } finally {
                connection.disconnect()
            }
        }

        private fun fromJson3(raw: String): String? {
            if (!raw.trimStart().startsWith("{")) return null
            val events = runCatching { MicaboJson.parseToJsonElement(raw).jsonObject["events"] as? JsonArray }.getOrNull() ?: return null
            val lines = events.mapNotNull { item ->
                val event = item as? JsonObject ?: return@mapNotNull null
                if ((event["aAppend"] as? JsonPrimitive)?.intOrNull == 1) return@mapNotNull null
                (event["segs"] as? JsonArray).orEmpty()
                    .mapNotNull { (it as? JsonObject)?.str("utf8") }
                    .joinToString("")
                    .replace("\n", " ")
                    .trim()
                    .takeIf { it.isNotEmpty() }
            }
            return clean(lines)
        }

        private fun fromXml(xml: String): String? {
            if (!Regex("<(?:timedtext|transcript|text)\\b").containsMatchIn(xml)) return null
            val lines = Regex("<(?:text|p)\\b[^>]*>([\\s\\S]*?)</(?:text|p)>").findAll(xml).map { match ->
                decode(match.groupValues[1].replace(Regex("<[^>]+>"), " ")).replace(Regex("\\s+"), " ").trim()
            }.filter { it.isNotEmpty() }.toList()
            return clean(lines)
        }

        /** WebVTT : les lignes dites, sans l'en-tête, les numéros ni les horodatages. */
        private fun fromVtt(vtt: String): String? {
            val normalized = vtt.replace("\r\n", "\n")
            val header = Regex("^\uFEFF?WEBVTT[^\n]*").find(normalized) ?: return null
            val body = normalized.substring(header.range.last + 1)
            val lines = body.split("\n\n").mapNotNull { block ->
                block.split("\n").map { it.trim() }.filter { line ->
                    line.isNotEmpty() && "-->" !in line && !line.matches(Regex("\\d+")) &&
                        !line.startsWith("kind:", ignoreCase = true) && !line.startsWith("language:", ignoreCase = true)
                }.joinToString(" ")
                    .replace(Regex("<[^>]+>"), " ")
                    .replace(Regex("\\s+"), " ")
                    .trim()
                    .takeIf { it.isNotEmpty() }
            }
            return clean(lines)
        }

        private fun clean(lines: List<String>): String {
            val kept = mutableListOf<String>()
            for (raw in lines) {
                val line = decode(raw).replace(Regex("\\[[^\\]\\n]{1,25}\\]"), " ").replace(Regex("\\s+"), " ").trim()
                if (line.isEmpty() || kept.lastOrNull() == line) continue
                kept.add(line)
            }
            return kept.joinToString(" ")
                .replace(Regex("\\s+([,.;:!?])"), "$1")
                .replace(Regex("\\s{2,}"), " ")
                .trim()
        }

        private fun decode(value: String) = value
            .replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"")
            .replace("&#39;", "'").replace("&#039;", "'").replace("&apos;", "'").replace("&nbsp;", " ")
    }
}
