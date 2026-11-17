package com.micabo.app.data

import android.content.Context
import android.util.Log
import androidx.core.content.edit
import com.micabo.app.BuildConfig
import com.micabo.app.i18n.AppLocale
import com.micabo.app.onboarding.OnboardingModel
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
import kotlinx.serialization.json.jsonArray
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
    /** Les préférences de l'app, où le parcours d'accueil garde ses réponses. */
    private val answers = context.getSharedPreferences("micabo", Context.MODE_PRIVATE)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val lock = Mutex()
    private val pending = mutableListOf<JsonObject>()
    private var flushJob: Job? = null
    private var sessionId = UUID.randomUUID().toString()
    private var lastSeen = System.currentTimeMillis()

    /** Le lot parti au serveur, sans réponse encore : gardé sur le disque avec la file. */
    private val inFlight = mutableListOf<JsonObject>()

    private val deviceId: String = store.getString("device", null) ?: UUID.randomUUID().toString().also { id ->
        store.edit { putString("device", id) }
    }

    init {
        // **La file survit à une app tuée**, comme sur iPhone : les lignes qui n'étaient pas
        // parties (Android tue l'app en arrière-plan, le paywall ouvre Google Play) repartent au
        // lancement suivant, avec leur heure d'origine.
        store.getString(QUEUE, null)?.let { saved ->
            runCatching { MicaboJson.parseToJsonElement(saved).jsonArray.mapNotNull { it as? JsonObject } }
                .getOrNull()
                ?.let { pending.addAll(it.takeLast(MAX_PENDING)) }
        }
    }

    /** La file sur le disque : ce qui attend, et le lot en route. Appelé sous `lock`. */
    private fun persist() {
        val rows = (inFlight + pending).takeLast(MAX_PENDING)
        store.edit { if (rows.isEmpty()) remove(QUEUE) else putString(QUEUE, JsonArray(rows).toString()) }
    }

    /** Au lancement : l'installation la toute première fois, puis l'ouverture. */
    fun start() {
        if (!store.getBoolean("installed", false)) {
            store.edit { putBoolean("installed", true) }
            track("app_installed")
        }
        track("app_opened", openingProps())
    }

    /**
     * Ce que porte chaque ouverture : la langue choisie dans l'app (la colonne `locale`, elle,
     * est celle du téléphone) et le genre donné à l'accueil, s'il l'a été.
     */
    private fun openingProps(): Map<String, Any?> = mapOf(
        "ui_language" to AppLocale.resolved(prefs.profile.value.language).code,
        "gender" to answers.getString(OnboardingModel.GENDER_KEY, null),
    )

    /** Retour au premier plan : une nouvelle session après trente minutes d'absence. */
    fun resumed() {
        val now = System.currentTimeMillis()
        if (now - lastSeen > SESSION_GAP) {
            sessionId = UUID.randomUUID().toString()
            track("app_opened", openingProps())
        }
        lastSeen = now
    }

    fun backgrounded() {
        lastSeen = System.currentTimeMillis()
        track("app_backgrounded")
        flushSoon(0)
    }

    fun track(name: String, props: Map<String, Any?> = emptyMap()) {
        // Les tests et leurs rendus (Robolectric) n'envoient rien : la CI polluait la vraie table.
        if (isTestRun) return
        // La table refuse un nom hors de sa forme, et avec lui tout le lot où il voyage.
        if (!NAME.matches(name)) {
            Log.w(TAG, "Nom d'événement refusé : $name")
            return
        }
        val profile = prefs.profile.value
        val labels = props.mapNotNull { (key, value) ->
            when (value) {
                null -> null
                is Boolean -> key.take(40) to JsonPrimitive(value)
                // NaN et l'infini ne sont pas du JSON : le lot entier serait refusé.
                is Double -> if (value.isFinite()) key.take(40) to JsonPrimitive(value) else null
                is Float -> if (value.isFinite()) key.take(40) to JsonPrimitive(value) else null
                is Number -> key.take(40) to JsonPrimitive(value)
                else -> key.take(40) to JsonPrimitive(value.toString().take(120))
            }
        }.toMap()
        // Deux mille caractères au plus, comme la contrainte de `props` : au-delà, on garde les premiers.
        var kept = labels
        while (kept.isNotEmpty() && JsonObject(kept).toString().length > MAX_PROPS) {
            kept = kept.entries.toList().dropLast(1).associate { it.key to it.value }
        }
        val row = buildJsonObject {
            put("device_id", deviceId)
            put("session_id", sessionId)
            put("name", name)
            put("props", JsonObject(kept))
            Locale.getDefault().country.uppercase().takeIf { it.length == 2 && it.all(Char::isLetter) }?.let { put("country", it) }
            profile.country.takeIf { it.isNotBlank() }?.let { put("school_country", it.take(16)) }
            put("locale", Locale.getDefault().toLanguageTag().take(16))
            put("platform", "android")
            put("app_version", "${BuildConfig.VERSION_NAME}+${BuildConfig.VERSION_CODE}".take(24))
            put("build", if (BuildConfig.DEBUG) "debug" else "release")
            put("is_pro", isPro())
            put("occurred_at", now())
        }
        scope.launch {
            lock.withLock {
                pending.add(row)
                if (pending.size > MAX_PENDING) pending.subList(0, pending.size - MAX_PENDING).clear()
                persist()
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
        if (isTestRun) return
        val batch = lock.withLock {
            pending.toList().also {
                pending.clear()
                inFlight.addAll(it)
            }
        }
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
        lock.withLock {
            batch.forEach { inFlight.remove(it) }
            when {
                status != null && status in 200..299 -> Unit
                // Un refus du serveur (4xx) ne passera pas mieux plus tard : le lot est laissé.
                status != null && status in 400..499 -> Log.w(TAG, "Événements refusés : $status")
                // Pas de réseau : les lignes reviennent dans la file, pour le prochain envoi.
                else -> pending.addAll(0, batch.takeLast(MAX_PENDING - pending.size.coerceAtMost(MAX_PENDING)))
            }
            persist()
        }
    }

    /** Un format neuf à chaque ligne : `SimpleDateFormat` partagé entre fils mélange les dates. */
    private fun now(): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.ROOT).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date())

    companion object {
        /**
         * **Une machine de test** : Robolectric (son empreinte, ou sa classe chargée), ou une
         * instrumentation JUnit. Lu une fois.
         */
        val isTestRun: Boolean by lazy {
            listOf("org.robolectric.Robolectric", "androidx.test.platform.app.InstrumentationRegistry", "org.junit.runner.JUnitCore")
                .any { runCatching { Class.forName(it) }.isSuccess } ||
                runCatching { android.os.Build.FINGERPRINT == "robolectric" }.getOrDefault(false)
        }

        private const val TAG = "Analytics"
        private const val SESSION_GAP = 30 * 60_000L
        private const val BATCH = 20
        private const val MAX_PENDING = 200
        private const val MAX_PROPS = 1_900
        private const val QUEUE = "queue"
        private val NAME = Regex("^[a-z][a-z0-9_]{1,46}[a-z0-9]$")
    }
}
