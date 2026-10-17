package com.micabo.app.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.put
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

internal data class HttpResult(val status: Int, val body: String)

/** Un appel HTTP à Supabase : la clé publiable, le jeton, et ce que PostgREST attend en plus. */
internal fun http(
    method: String,
    url: String,
    body: String?,
    bearer: String,
    timeoutMs: Int = 30_000,
    headers: Map<String, String> = emptyMap(),
): HttpResult {
    val connection = (URL(url).openConnection() as HttpURLConnection).apply {
        requestMethod = method
        connectTimeout = 20_000
        readTimeout = timeoutMs
        doOutput = body != null
        setRequestProperty("Content-Type", "application/json")
        setRequestProperty("Accept", "application/json")
        setRequestProperty("apikey", SupabaseConfig.ANON_KEY)
        setRequestProperty("Authorization", "Bearer $bearer")
        setRequestProperty("X-Client-Info", "micabo-android")
        headers.forEach { (key, value) -> setRequestProperty(key, value) }
    }
    try {
        if (body != null) connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
        val status = connection.responseCode
        val stream = if (status in 200..299) connection.inputStream else connection.errorStream
        val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
        return HttpResult(status, text)
    } finally {
        connection.disconnect()
    }
}

private fun post(url: String, body: String, bearer: String, timeoutMs: Int): HttpResult =
    http("POST", url, body, bearer, timeoutMs)

/** Le compte de l'élève, quand il s'est connecté : son adresse et son nom, pour le profil. */
data class Account(val userId: String, val email: String, val name: String)

/** Une connexion refusée : la phrase de GoTrue, ou un code connu (`providerNotEnabled`…). */
class AuthException(val code: String, message: String) : Exception(message)

/**
 * **Les comptes** (`AuthController` sur iPhone). Le compte invité d'abord : une inscription
 * anonyme GoTrue la première fois, puis le jeton rafraîchi quand il expire ; c'est lui qui
 * porte la leçon offerte et l'abonnement tant que l'élève ne s'est pas connecté. Puis le
 * vrai compte (Google, lien par courriel) : quand il existe, c'est son jeton qui part, et
 * c'est sous lui que les leçons se synchronisent. Le compte invité reste de côté.
 */
class SupabaseAuth(private val prefs: Prefs) {
    private val mutex = Mutex()

    private val _account = MutableStateFlow(readAccount())
    /** Le compte connecté, ou `null` pour un invité. */
    val account: StateFlow<Account?> = _account.asStateFlow()

    /** L'utilisateur qui parle au serveur : le compte connecté, sinon l'invité. */
    val userId: String get() = _account.value?.userId ?: prefs.userId

    val guestId: String get() = prefs.userId

    private fun readAccount(): Account? = prefs.accountUser.takeIf { it.isNotEmpty() && prefs.accountRefresh.isNotEmpty() }
        ?.let { Account(it, prefs.accountEmail, prefs.accountName) }

    /** À relire après « Tout effacer ». */
    fun reload() {
        _account.value = readAccount()
    }

    suspend fun accessToken(forceRefresh: Boolean = false): String = mutex.withLock {
        withContext(Dispatchers.IO) {
            if (_account.value != null) {
                accountToken(forceRefresh)?.let { return@withContext it }
            }
            guestToken(forceRefresh)
        }
    }

    /** Le jeton du compte ; `null` quand GoTrue l'a oublié (le compte est alors déconnecté). */
    private fun accountToken(forceRefresh: Boolean): String? {
        val now = System.currentTimeMillis()
        val access = prefs.accountAccess
        if (!forceRefresh && access.isNotEmpty() && prefs.accountExpiresAt - 60_000 > now) return access
        val renewed = runCatching {
            request("token?grant_type=refresh_token", buildJsonObject { put("refresh_token", JsonPrimitive(prefs.accountRefresh)) })
        }
        renewed.getOrNull()?.let { return keepAccount(it) }
        val error = renewed.exceptionOrNull()
        // Hors ligne ou GoTrue en panne : la session reste, on réessaiera.
        if (error is NetworkException) throw error
        if (error is ApiException && (error.status >= 500 || error.status == 429)) throw error
        // Une session que GoTrue ne connaît plus : le compte se déconnecte, l'invité reprend.
        forgetAccount()
        return null
    }

    private fun guestToken(forceRefresh: Boolean): String {
        val now = System.currentTimeMillis()
        val access = prefs.accessToken
        if (!forceRefresh && access.isNotEmpty() && prefs.expiresAt - 60_000 > now) return access
        val refresh = prefs.refreshToken
        if (refresh.isNotEmpty()) {
            val renewed = runCatching {
                request("token?grant_type=refresh_token", buildJsonObject { put("refresh_token", JsonPrimitive(refresh)) })
            }
            renewed.getOrNull()?.let { return keepGuest(it) }
            val error = renewed.exceptionOrNull()
            // Un jeton oublié par GoTrue : un nouveau compte invité. Une panne réseau, ou de
            // GoTrue lui-même (5xx, 429) : on réessaiera. Sans ça, un 503 passager jetait le
            // compte invité, et avec lui l'abonnement et la leçon offerte.
            if (error is NetworkException) throw error
            if (error is ApiException && (error.status >= 500 || error.status == 429)) throw error
            prefs.clearSession()
        }
        return keepGuest(request("signup", buildJsonObject { put("data", JsonObject(emptyMap())) }))
    }

    private fun keepGuest(payload: JsonObject): String {
        val access = payload.str("access_token")
        if (access.isEmpty()) throw ApiException(500, "auth", "No session")
        prefs.accessToken = access
        prefs.refreshToken = payload.str("refresh_token")
        prefs.expiresAt = System.currentTimeMillis() + expiresIn(payload) * 1000
        (payload["user"] as? JsonObject)?.str("id")?.takeIf { it.isNotEmpty() }?.let { prefs.userId = it }
        return access
    }

    private fun keepAccount(payload: JsonObject): String {
        val access = payload.str("access_token")
        val user = payload["user"] as? JsonObject
        val id = user?.str("id").orEmpty().ifEmpty { prefs.accountUser }
        if (access.isEmpty() || id.isEmpty()) throw ApiException(500, "auth", "No session")
        prefs.accountAccess = access
        payload.str("refresh_token").takeIf { it.isNotEmpty() }?.let { prefs.accountRefresh = it }
        prefs.accountExpiresAt = System.currentTimeMillis() + expiresIn(payload) * 1000
        prefs.accountUser = id
        if (user != null) {
            user.str("email").takeIf { it.isNotEmpty() }?.let { prefs.accountEmail = it }
            val metadata = user["user_metadata"] as? JsonObject
            val name = metadata?.let { it.str("full_name").ifEmpty { it.str("name") }.ifEmpty { it.str("display_name") } }.orEmpty()
            if (name.isNotEmpty()) prefs.accountName = name
        }
        _account.value = readAccount()
        return access
    }

    private fun expiresIn(payload: JsonObject): Long =
        runCatching { payload["expires_in"]!!.jsonPrimitive.long }.getOrDefault(3600L)

    private fun forgetAccount() {
        prefs.clearAccount()
        _account.value = null
    }

    // MARK: - Se connecter (`SupabaseAuthClient`, `OAuthFlows`)

    /** La page Google de Supabase, en PKCE : le vérificateur ne quitte pas le téléphone. */
    fun googleUrl(): String {
        val verifier = Pkce.verifier()
        prefs.pkceVerifier = verifier
        return "${SupabaseConfig.URL}/auth/v1/authorize?provider=google" +
            "&redirect_to=" + java.net.URLEncoder.encode(REDIRECT, "UTF-8") +
            "&code_challenge=" + Pkce.challenge(verifier) +
            "&code_challenge_method=s256"
    }

    /** Envoie le lien de connexion ; il rouvre l'app par `micabo://auth-callback`. */
    suspend fun sendMagicLink(email: String) = withContext(Dispatchers.IO) {
        val verifier = Pkce.verifier()
        prefs.pkceVerifier = verifier
        authRequest("otp?redirect_to=" + java.net.URLEncoder.encode(REDIRECT, "UTF-8"), buildJsonObject {
            put("email", email.trim())
            put("create_user", true)
            put("code_challenge", Pkce.challenge(verifier))
            put("code_challenge_method", "s256")
        })
    }

    /**
     * Le retour de Google ou du lien (`AuthController.handle`) : un jeton de rafraîchissement,
     * un `token_hash`, ou un code PKCE. Rend le compte ouvert.
     */
    suspend fun handleCallback(query: Map<String, String>): Account = mutex.withLock {
        withContext(Dispatchers.IO) {
            query["error_description"]?.let { throw AuthException("callback", it.replace('+', ' ')) }
            val payload = when {
                !query["refresh_token"].isNullOrEmpty() ->
                    authRequest("token?grant_type=refresh_token", buildJsonObject { put("refresh_token", query.getValue("refresh_token")) })
                !query["token_hash"].isNullOrEmpty() ->
                    authRequest("verify", buildJsonObject {
                        put("token_hash", query.getValue("token_hash"))
                        put("type", query["type"] ?: "magiclink")
                    })
                !query["code"].isNullOrEmpty() && prefs.pkceVerifier.isNotEmpty() ->
                    authRequest("token?grant_type=pkce", buildJsonObject {
                        put("auth_code", query.getValue("code"))
                        put("code_verifier", prefs.pkceVerifier)
                    })
                else -> throw AuthException("invalid", "")
            }
            keepAccount(payload)
            prefs.pkceVerifier = ""
            _account.value ?: throw AuthException("invalid", "")
        }
    }

    /** Se déconnecter : la session se ferme chez GoTrue, l'invité reprend. */
    suspend fun signOut() = withContext(Dispatchers.IO) {
        val access = prefs.accountAccess
        if (access.isNotEmpty()) runCatching { http("POST", "${SupabaseConfig.URL}/auth/v1/logout", "{}", access) }
        mutex.withLock { forgetAccount() }
    }

    /** Supprimer son compte (`delete_own_account`) : tout part en cascade côté serveur. */
    suspend fun deleteAccount() = withContext(Dispatchers.IO) {
        val token = accessToken()
        if (_account.value == null) return@withContext
        val result = try {
            http("POST", "${SupabaseConfig.URL}/rest/v1/rpc/delete_own_account", "{}", token)
        } catch (error: IOException) {
            throw NetworkException(error)
        }
        if (result.status !in 200..299) throw ApiException(result.status, "delete", result.body.take(200))
        mutex.withLock { forgetAccount() }
    }

    /** Les erreurs de GoTrue, lues comme sur iPhone (`SupabaseAuthClient.mapError`). */
    private fun authRequest(path: String, body: JsonObject): JsonObject = try {
        request(path, body)
    } catch (error: ApiException) {
        val text = error.message.orEmpty()
        val code = when {
            error.code == "validation_failed" && text.contains("provider", ignoreCase = true) -> "providerNotEnabled"
            error.status == 400 && text.contains("provider is not enabled", ignoreCase = true) -> "providerNotEnabled"
            error.code == "email_not_confirmed" -> "emailNotConfirmed"
            error.code == "over_email_send_rate_limit" || error.status == 429 -> "rateLimited"
            else -> error.code
        }
        throw AuthException(code, text)
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

    companion object {
        /** Le retour des connexions, le même que sur iPhone (déjà autorisé chez Supabase). */
        const val REDIRECT = "micabo://auth-callback"
    }
}

/** **PKCE** (`OAuthFlows`) : un vérificateur de 64 octets, et son empreinte SHA-256. */
object Pkce {
    private val random = java.security.SecureRandom()

    private fun encode(bytes: ByteArray): String =
        android.util.Base64.encodeToString(bytes, android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP)

    fun verifier(): String = ByteArray(64).also(random::nextBytes).let(::encode)

    fun challenge(verifier: String): String =
        encode(java.security.MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.US_ASCII)))
}

/** L'appel à une fonction Edge, avec le jeton de l'invité ; un 401 rafraîchit et réessaie une fois. */
class SupabaseFunctions(private val auth: SupabaseAuth) {
    suspend fun call(function: String, payload: JsonObject, timeoutMs: Int = 150_000): JsonObject = withContext(Dispatchers.IO) {
        var token = runCatching { auth.accessToken() }.getOrElse { error ->
            if (error is NetworkException) throw error
            // GoTrue en panne passagère : réessayer plus tard, pas appeler en anonyme (le
            // serveur y verrait un compte sans abonnement et ouvrirait le paywall).
            if (error is ApiException && (error.status >= 500 || error.status == 429)) throw NetworkException(error)
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
