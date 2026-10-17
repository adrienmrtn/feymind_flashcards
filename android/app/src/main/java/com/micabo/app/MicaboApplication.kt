package com.micabo.app

import android.app.Application
import com.micabo.app.data.Analytics
import com.micabo.app.data.AudioImport
import com.micabo.app.data.AuthException
import com.micabo.app.data.Billing
import com.micabo.app.data.CloudSync
import com.micabo.app.data.ExamRepository
import com.micabo.app.data.LessonComposer
import com.micabo.app.data.LessonRepository
import com.micabo.app.data.MikaChat
import com.micabo.app.data.Prefs
import com.micabo.app.data.Social
import com.micabo.app.data.Streak
import com.micabo.app.data.SupabaseAuth
import com.micabo.app.data.SupabaseFunctions
import com.micabo.app.data.YouTubeImport
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** L'app et ses services, créés une fois. */
class MicaboApplication : Application() {
    lateinit var prefs: Prefs
        private set
    lateinit var auth: SupabaseAuth
        private set
    lateinit var lessons: LessonRepository
        private set
    lateinit var billing: Billing
        private set
    lateinit var functions: SupabaseFunctions
        private set
    lateinit var streak: Streak
        private set
    lateinit var mika: MikaChat
        private set
    lateinit var exams: ExamRepository
        private set
    lateinit var analytics: Analytics
        private set
    /** La barre de l'accueil et ses supports : ils survivent au paywall et aux leçons ouvertes. */
    lateinit var composer: LessonComposer
        private set

    lateinit var sync: CloudSync
        private set
    lateinit var social: Social
        private set

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var lastSyncAttempt = 0L

    /** Le résultat d'une connexion, pour le profil : rien, réussie, ou la phrase de l'échec. */
    private val _signIn = MutableStateFlow<SignInEvent?>(null)
    val signIn: StateFlow<SignInEvent?> = _signIn.asStateFlow()

    fun signInSeen() {
        _signIn.value = null
    }

    /**
     * Synchronise bientôt, sans insister : au retour au premier plan, au plus toutes les deux
     * minutes. Sans compte connecté, rien ne part.
     */
    fun syncSoon(force: Boolean = false) {
        if (auth.account.value == null) return
        val now = System.currentTimeMillis()
        if (!force && now - lastSyncAttempt < 2 * 60_000L) return
        lastSyncAttempt = now
        scope.launch { sync.sync() }
    }

    /** Le retour de Google ou du lien du courriel (`micabo://auth-callback`). */
    fun completeSignIn(query: Map<String, String>) {
        scope.launch {
            val guest = auth.guestId
            _signIn.value = runCatching { auth.handleCallback(query) }.fold(
                onSuccess = { account ->
                    analytics.track("signed_in", mapOf("provider" to if (query.containsKey("code")) "pkce" else "link"))
                    withContext(Dispatchers.Main) { billing.follow(account.userId, fromGuest = guest.isNotEmpty()) }
                    // Les leçons de ce téléphone montent sous le compte, celles du compte descendent.
                    prefs.syncWatermark = 0
                    sync.sync()
                    SignInEvent.Success
                },
                onFailure = { error ->
                    analytics.track("sign_in_failed", mapOf("reason" to ((error as? AuthException)?.code ?: error.javaClass.simpleName)))
                    SignInEvent.Failure(error)
                },
            )
        }
    }

    /** Se déconnecter : une dernière synchronisation, puis l'invité reprend. Les leçons restent. */
    suspend fun signOut() {
        runCatching { sync.sync() }
        auth.signOut()
        sync.forget()
        social.reset()
        analytics.track("signed_out")
        withContext(Dispatchers.Main) { billing.follow(auth.guestId, fromGuest = false) }
    }

    /** Supprimer son compte : tout part côté serveur, l'invité reprend. */
    suspend fun deleteAccount() {
        auth.deleteAccount()
        sync.forget()
        social.reset()
        withContext(Dispatchers.Main) { billing.follow(auth.guestId, fromGuest = false) }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        prefs = Prefs(this)
        auth = SupabaseAuth(prefs)
        functions = SupabaseFunctions(auth)
        streak = Streak(this)
        lessons = LessonRepository(this, functions, prefs, streak)
        mika = MikaChat(functions, lessons, prefs)
        exams = ExamRepository(this, prefs)
        // Avant les événements : chacun lit `isPro`, et un `lateinit` encore vide ferait planter.
        billing = Billing(this) {
            runCatching { auth.accessToken() }
            auth.userId.ifEmpty { null }
        }
        analytics = Analytics(this, prefs, auth) { billing.isPro.value }
        sync = CloudSync(auth, lessons, exams, prefs)
        social = Social(auth)
        composer = LessonComposer(this, YouTubeImport(functions), AudioImport(functions)) { name, props -> analytics.track(name, props) }
        analytics.start()
        // Le compte invité s'ouvre tout de suite : il doit exister avant un achat, pour que
        // l'abonnement ait un propriétaire. Sans réseau, il s'ouvrira au premier appel.
        scope.launch {
            runCatching { auth.accessToken() }
            withContext(Dispatchers.Main) { billing.start(auth.userId.ifEmpty { null }) }
            syncSoon(force = true)
        }
    }

    companion object {
        lateinit var instance: MicaboApplication
            private set
    }
}

/** Le retour d'une connexion. */
sealed interface SignInEvent {
    data object Success : SignInEvent
    data class Failure(val error: Throwable) : SignInEvent
}
