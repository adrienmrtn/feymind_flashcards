package com.micabo.app

import android.app.Application
import com.micabo.app.data.Billing
import com.micabo.app.data.LessonComposer
import com.micabo.app.data.LessonRepository
import com.micabo.app.data.Prefs
import com.micabo.app.data.SupabaseAuth
import com.micabo.app.data.SupabaseFunctions
import com.micabo.app.data.YouTubeImport
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
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
    /** La barre de l'accueil et ses supports : ils survivent au paywall et aux leçons ouvertes. */
    lateinit var composer: LessonComposer
        private set

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        instance = this
        prefs = Prefs(this)
        auth = SupabaseAuth(prefs)
        functions = SupabaseFunctions(auth)
        lessons = LessonRepository(this, functions, prefs)
        composer = LessonComposer(this, YouTubeImport(functions))
        billing = Billing(this)
        // Le compte invité s'ouvre tout de suite : il doit exister avant un achat, pour que
        // l'abonnement ait un propriétaire. Sans réseau, il s'ouvrira au premier appel.
        scope.launch {
            runCatching { auth.accessToken() }
            withContext(Dispatchers.Main) { billing.start(auth.userId.ifEmpty { null }) }
        }
    }

    companion object {
        lateinit var instance: MicaboApplication
            private set
    }
}
