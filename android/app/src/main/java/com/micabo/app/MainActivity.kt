package com.micabo.app

import android.content.Context
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
        (application as MicaboApplication).analytics.resumed()
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
