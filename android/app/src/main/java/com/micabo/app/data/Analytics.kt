package com.micabo.app.data

import android.content.Context
import android.util.Log
import androidx.core.content.edit
import com.micabo.app.BuildConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * **Les événements de l'app** (`Analytics` sur iPhone), dans la même table `app_events` :
 * une installation (`device_id`), des sessions (trente minutes de silence en ouvrent une
 * neuve), des noms courts et des étiquettes. Rien de ce que l'élève écrit ne part : des
 * compteurs, des sources, des écrans. Les lignes attendent un peu, puis partent par lots.
 */
class Analytics(context: Context, private val prefs: Prefs, private val auth: SupabaseAuth, private val isPro: () -> Boolean) {
    private val store = context.getSharedPreferences("micabo.analytics", Context.MODE_PRIVATE)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val lock = Mutex()
    private val pending = mutableListOf<JsonObject>()
    private var flushJob: Job? = null
    private var sessionId = UUID.randomUUID().toString()
    private var lastSeen = System.currentTimeMillis()

    private val deviceId: String = store.getString("device", null) ?: UUID.randomUUID().toString().also { id ->
        store.edit { putString("device", id) }
    }

    /** Au lancement : l'installation la toute première fois, puis l'ouverture. */
    fun start() {
        if (!store.getBoolean("installed", false)) {
            store.edit { putBoolean("installed", true) }
            track("app_installed")
        }
        track("app_opened")
    }

    /** Retour au premier plan : une nouvelle session après trente minutes d'absence. */
    fun resumed() {
        val now = System.currentTimeMillis()
        if (now - lastSeen > SESSION_GAP) {
            sessionId = UUID.randomUUID().toString()
            track("app_opened")
        }
        lastSeen = now
    }

    fun backgrounded() {
        lastSeen = System.currentTimeMillis()
        track("app_backgrounded")
        flushSoon(0)
    }

    fun track(name: String, props: Map<String, Any?> = emptyMap()) {
        val profile = prefs.profile.value
        val row = buildJsonObject {
            put("device_id", deviceId)
            put("session_id", sessionId)
            put("name", name)
            put("props", JsonObject(props.mapNotNull { (key, value) ->
                when (value) {
                    null -> null
                    is Boolean -> key to JsonPrimitive(value)
                    is Number -> key to JsonPrimitive(value)
                    else -> key to JsonPrimitive(value.toString().take(120))
                }
            }.toMap()))
            Locale.getDefault().country.uppercase().takeIf { it.length == 2 && it.all(Char::isLetter) }?.let { put("country", it) }
            profile.country.takeIf { it.isNotBlank() }?.let { put("school_country", it.take(16)) }
            put("locale", Locale.getDefault().toLanguageTag().take(16))
            put("platform", "android")
            put("app_version", "${BuildConfig.VERSION_NAME}+${BuildConfig.VERSION_CODE}".take(24))
            put("build", if (BuildConfig.DEBUG) "debug" else "release")
            put("is_pro", isPro())
            put("occurred_at", iso.format(Date()))
        }
        scope.launch {
            lock.withLock {
                pending.add(row)
                if (pending.size > MAX_PENDING) pending.subList(0, pending.size - MAX_PENDING).clear()
            }
            flushSoon(if (pending.size >= BATCH) 0 else 8_000)
        }
    }

    private fun flushSoon(delayMs: Long) {
        if (flushJob?.isActive == true && delayMs > 0) return
        flushJob = scope.launch {
            delay(delayMs)
            flush()
        }
    }

    private suspend fun flush() {
        val batch = lock.withLock { pending.toList().also { pending.clear() } }
        if (batch.isEmpty()) return
        val sent = runCatching {
            val token = runCatching { auth.accessToken() }.getOrDefault(SupabaseConfig.ANON_KEY)
            val connection = (URL("${SupabaseConfig.URL}/rest/v1/app_events").openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("apikey", SupabaseConfig.ANON_KEY)
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Prefer", "return=minimal")
            }
            try {
                connection.outputStream.use { it.write(JsonArray(batch).toString().toByteArray()) }
                connection.responseCode
            } finally {
                connection.disconnect()
            }
        }
        val status = sent.getOrNull()
        when {
            status != null && status in 200..299 -> Unit
            // Un refus du serveur (4xx) ne passera pas mieux plus tard : le lot est laissé.
            status != null && status in 400..499 -> Log.w(TAG, "Événements refusés : $status")
            // Pas de réseau : les lignes reviennent dans la file, pour le prochain envoi.
            else -> lock.withLock { pending.addAll(0, batch.takeLast(MAX_PENDING - pending.size.coerceAtMost(MAX_PENDING))) }
        }
    }

    private val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.ROOT).apply { timeZone = TimeZone.getTimeZone("UTC") }

    private companion object {
        const val TAG = "Analytics"
        const val SESSION_GAP = 30 * 60_000L
        const val BATCH = 20
        const val MAX_PENDING = 200
    }
}
