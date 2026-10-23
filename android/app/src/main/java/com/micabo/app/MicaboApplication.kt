package com.micabo.app

import android.app.Application
import com.micabo.app.data.Analytics
import com.micabo.app.data.AudioImport
import com.micabo.app.data.AuthException
import com.micabo.app.data.Billing
import com.micabo.app.data.CloudSync
import com.micabo.app.data.DailyReminder
import com.micabo.app.data.ExamRepository
import com.micabo.app.data.GiftOffer
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
import kotlinx.coroutines.flow.drop
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
    /** Le cadeau du paywall refermé, et le tarif réduit qu'il ouvre. */
    lateinit var gift: GiftOffer
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
     * minutes. Sous le compte, sinon sous l'invité ; sans l'un ni l'autre (pas encore de
     * réseau au tout premier lancement), rien ne part.
     */
    fun syncSoon(force: Boolean = false) {
        if (auth.userId.isEmpty()) return
        val now = System.currentTimeMillis()
        if (!force && now - lastSyncAttempt < 2 * 60_000L) return
        lastSyncAttempt = now
        scope.launch { sync.sync() }
    }

    /**
     * Les rappels du jour, reposés au lancement et en partant : c'est là que les leçons et le
     * travail de la journée sont à jour. Seulement pour qui n'a jamais activé l'essai gratuit.
     */
    fun rescheduleReminders() {
        scope.launch {
            lessons.ready()
            streak.refresh()
            val eligible = !billing.isPro.value && !billing.everHadPro.value
            DailyReminder.reschedule(this@MicaboApplication, lessons.lessons.value.values, eligible, streak.status.value.studiedToday)
        }
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
        gift = GiftOffer(this)
        analytics = Analytics(this, prefs, auth) { billing.isPro.value }
        // Une synchro qui échoue se compte : avant, elle finissait dans un `Log.w` que personne
        // ne lit, et l'app Android n'avait poussé aucun cours en base sans que rien le dise.
        sync = CloudSync(
            auth, lessons, exams, prefs,
            onFailure = { reason -> analytics.track("sync_failed", mapOf("reason" to reason, "user" to if (auth.account.value == null) "guest" else "account")) },
            onSuccess = { pushed -> analytics.track("sync_finished", mapOf("courses" to pushed, "user" to if (auth.account.value == null) "guest" else "account")) },
        )
        social = Social(auth)
        composer = LessonComposer(this, YouTubeImport(functions), AudioImport(functions)) { name, props -> analytics.track(name, props) }
        analytics.start()
        // Le compte invité s'ouvre tout de suite : il doit exister avant un achat, pour que
        // l'abonnement ait un propriétaire. Sans réseau, il s'ouvrira au premier appel.
        scope.launch {
            runCatching { auth.accessToken() }
            withContext(Dispatchers.Main) { billing.start(auth.userId.ifEmpty { null }) }
            syncSoon(force = true)
            rescheduleReminders()
        }
        // Un essai ou un abonnement qui commence efface les rappels, pour de bon.
        scope.launch {
            billing.everHadPro.drop(1).collect { rescheduleReminders() }
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
