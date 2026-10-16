package com.micabo.app.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.long
import kotlinx.serialization.json.jsonPrimitive
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * **Le backend de Micabo** : le projet Supabase de l'app iPhone (`AppConfig.swift`), sa clé
 * publiable — publique par nature —, et les fonctions Edge.
 */
object SupabaseConfig {
    const val URL = "https://khuzodsrznanzhwlbjbx.supabase.co"
    const val ANON_KEY =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtodXpvZHNyem5hbnpod2xiamJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5NDg1MzIsImV4cCI6MjEwMTUyNDUzMn0.-PBadJI6rdYgoHisEfP54CN126IiT9DNIXR4J-vNYLw"
}

/** Un refus du serveur : son statut, son `code` (`free_limit`, `daily_limit`…), sa phrase. */
class ApiException(val status: Int, val code: String, message: String) : Exception(message) {
    /** Les refus qui se règlent en passant à Pro : ils ouvrent le paywall. */
    val opensPaywall: Boolean get() = code == "free_limit" || code == "import_pro" || code == "pro_required"
    val isDailyLimit: Boolean get() = code == "daily_limit" || status == 429
}

/** Pas de réseau, ou une réponse coupée. */
class NetworkException(cause: Throwable) : Exception(cause.message, cause)

private data class HttpResult(val status: Int, val body: String)

private fun post(url: String, body: String, bearer: String, timeoutMs: Int): HttpResult {
    val connection = (URL(url).openConnection() as HttpURLConnection).apply {
        requestMethod = "POST"
        connectTimeout = 20_000
        readTimeout = timeoutMs
        doOutput = true
        setRequestProperty("Content-Type", "application/json")
        setRequestProperty("Accept", "application/json")
        setRequestProperty("apikey", SupabaseConfig.ANON_KEY)
        setRequestProperty("Authorization", "Bearer $bearer")
        setRequestProperty("X-Client-Info", "micabo-android")
    }
    try {
        connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
        val status = connection.responseCode
        val stream = if (status in 200..299) connection.inputStream else connection.errorStream
        val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        return HttpResult(status, text)
    } finally {
        connection.disconnect()
    }
}

/**
 * **Le compte invité**, comme sur iPhone (`AuthController.guestAccessToken`) : une inscription
 * anonyme GoTrue la première fois, puis le jeton rafraîchi quand il expire. Les fonctions
 * Edge exigent un vrai utilisateur : c'est lui qui porte la leçon offerte et l'abonnement.
 */
class SupabaseAuth(private val prefs: Prefs) {
    private val mutex = Mutex()

    val userId: String get() = prefs.userId

    suspend fun accessToken(forceRefresh: Boolean = false): String = mutex.withLock {
        withContext(Dispatchers.IO) {
            val now = System.currentTimeMillis()
            val access = prefs.accessToken
            if (!forceRefresh && access.isNotEmpty() && prefs.expiresAt - 60_000 > now) return@withContext access
            val refresh = prefs.refreshToken
            if (refresh.isNotEmpty()) {
                val renewed = runCatching {
                    request("token?grant_type=refresh_token", buildJsonObject { put("refresh_token", kotlinx.serialization.json.JsonPrimitive(refresh)) })
                }
                renewed.getOrNull()?.let { return@withContext keep(it) }
                val error = renewed.exceptionOrNull()
                // Un jeton oublié par GoTrue : un nouveau compte invité. Une panne réseau : on réessaiera.
                if (error is NetworkException) throw error
                prefs.clearSession()
            }
            keep(request("signup", buildJsonObject { put("data", JsonObject(emptyMap())) }))
        }
    }

    private fun keep(payload: JsonObject): String {
        val access = payload.str("access_token")
        if (access.isEmpty()) throw ApiException(500, "auth", "No session")
        val expiresIn = runCatching { payload["expires_in"]!!.jsonPrimitive.long }.getOrDefault(3600L)
        prefs.accessToken = access
        prefs.refreshToken = payload.str("refresh_token")
        prefs.expiresAt = System.currentTimeMillis() + expiresIn * 1000
        val user = payload["user"] as? JsonObject
        user?.str("id")?.takeIf { it.isNotEmpty() }?.let { prefs.userId = it }
        return access
    }

    private fun request(path: String, body: JsonObject): JsonObject {
        val result = try {
            post("${SupabaseConfig.URL}/auth/v1/$path", body.toString(), SupabaseConfig.ANON_KEY, 30_000)
        } catch (error: IOException) {
            throw NetworkException(error)
        }
        val payload = runCatching { MicaboJson.parseToJsonElement(result.body).jsonObject }.getOrNull() ?: JsonObject(emptyMap())
        if (result.status !in 200..299) {
            val message = payload.str("msg").ifEmpty { payload.str("error_description") }.ifEmpty { payload.str("message") }
            throw ApiException(result.status, payload.str("error_code").ifEmpty { payload.str("error") }, message)
        }
        return payload
    }
}

/** L'appel à une fonction Edge, avec le jeton de l'invité ; un 401 rafraîchit et réessaie une fois. */
class SupabaseFunctions(private val auth: SupabaseAuth) {
    suspend fun call(function: String, payload: JsonObject, timeoutMs: Int = 150_000): JsonObject = withContext(Dispatchers.IO) {
        var token = runCatching { auth.accessToken() }.getOrElse { error ->
            if (error is NetworkException) throw error
            SupabaseConfig.ANON_KEY
        }
        var attempt = 0
        while (true) {
            val result = try {
                post("${SupabaseConfig.URL}/functions/v1/$function", payload.toString(), token, timeoutMs)
            } catch (error: IOException) {
                throw NetworkException(error)
            }
            val body = runCatching { MicaboJson.parseToJsonElement(result.body).jsonObject }.getOrNull()
            if (result.status in 200..299) {
                return@withContext body ?: throw ApiException(result.status, "invalid", "")
            }
            if (result.status == 401 && attempt == 0) {
                attempt += 1
                token = runCatching { auth.accessToken(forceRefresh = true) }.getOrDefault(token)
                continue
            }
            throw ApiException(result.status, body?.str("code").orEmpty(), body?.str("error").orEmpty())
        }
        @Suppress("UNREACHABLE_CODE")
        throw IllegalStateException()
    }
}
