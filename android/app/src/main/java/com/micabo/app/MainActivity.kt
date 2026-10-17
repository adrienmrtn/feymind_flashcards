package com.micabo.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import android.graphics.Color
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.micabo.app.data.Prefs
import com.micabo.app.i18n.AppLocale
import com.micabo.app.ui.MicaboRoot
import com.micabo.app.ui.theme.MicaboTheme

/**
 * **Micabo sur Android** : une seule activité, tout en Compose. La langue choisie dans l'app
 * s'applique ici, avant que le moindre texte ne soit lu.
 */
class MainActivity : ComponentActivity() {
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(AppLocale.wrap(newBase, Prefs.storedLanguage(newBase)))
    }

    override fun onStart() {
        super.onStart()
        val app = application as MicaboApplication
        app.analytics.resumed()
        app.syncSoon()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAuthCallback(intent)
    }

    /**
     * Le retour d'une connexion : `micabo://auth-callback?code=…` (Google, lien PKCE) ou un
     * fragment `#access_token=…&refresh_token=…`. Requête et fragment se lisent ensemble.
     */
    private fun handleAuthCallback(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme != "micabo" || uri.host != "auth-callback") return
        val values = mutableMapOf<String, String>()
        listOfNotNull(uri.encodedQuery, uri.encodedFragment).forEach { part ->
            part.split('&').forEach { pair ->
                val key = pair.substringBefore('=')
                val value = pair.substringAfter('=', "")
                if (key.isNotEmpty()) values[Uri.decode(key)] = Uri.decode(value)
            }
        }
        intent.data = null
        (application as MicaboApplication).completeSignIn(values)
    }

    override fun onStop() {
        (application as MicaboApplication).analytics.backgrounded()
        super.onStop()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as MicaboApplication
        if (savedInstanceState == null) handleAuthCallback(intent)
        setContent {
            val profile by app.prefs.profile.collectAsState()
            val dark = when (profile.theme) {
                "light" -> false
                "dark" -> true
                else -> isSystemInDarkTheme()
            }
            // Les icônes des barres du système suivent l'apparence choisie, pas celle du téléphone.
            LaunchedEffect(dark) {
                val style = if (dark) SystemBarStyle.dark(Color.TRANSPARENT) else SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT)
                enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
            }
            MicaboTheme(dark = dark) {
                MicaboRoot(app = app)
            }
        }
    }
}
