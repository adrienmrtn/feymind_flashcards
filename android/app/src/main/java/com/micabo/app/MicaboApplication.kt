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
import com.micabo.app.data.RecordingService
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
            // Avant de quitter l'invité : le jeton qui fera passer ses lignes au compte
            // (`create_guest_claim`, avec la session invitée). Le transfert lui-même ouvre le
            // premier passage sous le compte (`CloudSync.claimGuest`), puis tout remonte.
            sync.prepareGuestClaim()
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

    /**
     * **Se déconnecter**, comme sur l'iPhone : une dernière montée, la session se ferme, le
     * téléphone se vide des leçons, examens et de la série du compte, et un invité neuf prend
     * la place (`CloudSync.leaveAccount`). Les cours restent sur le compte, ils ne restent plus
     * ici à remonter sous l'invité, puis sous le compte suivant (`ios_signOutMsg`). Ce que la
     * dernière montée n'a pas pu pousser (hors ligne) est mis de côté pour ce compte et revient
     * à sa prochaine connexion. Le profil reste : l'accueil ne se rouvre pas.
     */
    suspend fun signOut() {
        val pushed = sync.leaveAccount(deleting = false) { auth.signOut() }
        afterLeaving()
        analytics.track("signed_out", mapOf("pushed" to pushed))
    }

    /** Ce qui suit la sortie d'un compte, hors synchronisation : l'écran repart d'un invité neuf. */
    private suspend fun afterLeaving() {
        social.reset()
        withContext(Dispatchers.Main) {
            composer.reset()
            billing.follow(auth.guestId, fromGuest = false)
        }
        rescheduleReminders()
        syncSoon(force = true)
    }

    /**
     * **Tout effacer** (le profil) : les leçons, les examens, le profil et les réglages quittent
     * ce téléphone. Un compte connecté se déconnecte, et ses leçons restent sur le serveur ; ce
     * qui attendait de monter pour lui est mis de côté pour sa prochaine connexion.
     *
     * Chaque leçon, carte et examen laisse une pierre tombale : sous l'invité, la suppression
     * part au serveur, et la synchronisation suivante ne redescend plus ce qui vient d'être
     * effacé. Le dernier utilisateur synchronisé reste connu (`Prefs.reset` garde `sync.*`), et
     * le profil du serveur ne referme pas l'accueil qui recommence (`Prefs.profileErased`).
     */
    fun eraseEverything() {
        auth.account.value?.userId?.let { sync.park(it) }
        lessons.deleteAll()
        exams.reset(tombstones = true)
        val language = prefs.profile.value.language
        val theme = prefs.profile.value.theme
        prefs.reset()
        prefs.profileErased = true
        auth.reload()
        sync.erased()
        billing.follow(auth.guestId, fromGuest = false)
        prefs.update { it.copy(language = language, theme = theme) }
        streak.reset()
        composer.reset()
    }

    /**
     * **Supprimer son compte** : tout part côté serveur, puis le téléphone se vide comme à la
     * déconnexion et un invité neuf prend la place (`CloudSync.leaveAccount`) - le message
     * promet « tes cours seront effacés ». Une suppression qui échoue lève son erreur, et rien
     * n'a changé ici.
     */
    suspend fun deleteAccount() {
        sync.leaveAccount(deleting = true) { auth.deleteAccount() }
        afterLeaving()
        analytics.track("account_deleted")
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
            streak = streak,
            onFailure = { reason -> analytics.track("sync_failed", mapOf("reason" to reason, "user" to if (auth.account.value == null) "guest" else "account")) },
            onSuccess = { pushed -> analytics.track("sync_finished", mapOf("courses" to pushed, "user" to if (auth.account.value == null) "guest" else "account")) },
        )
        // Un cours que le serveur ne connaît pas encore (`course_unknown`) : synchroniser tout de suite.
        lessons.onCourseUnknown = { syncSoon(force = true) }
        // Une session de compte perdue : ce qui attendait de monter pour lui est mis de côté.
        auth.onAccountLost = { account -> sync.park(account) }
        social = Social(auth)
        composer = LessonComposer(this, YouTubeImport(functions), AudioImport(functions)) { name, props -> analytics.track(name, props) }
        // L'enregistrement du micro, fini (le bouton, la notification, la limite) : il rejoint la
        // barre comme un support, même écran verrouillé ou feuille refermée.
        RecordingService.onRecorded = { file -> composer.addAudio(android.net.Uri.fromFile(file), fromRecorder = true) }
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
