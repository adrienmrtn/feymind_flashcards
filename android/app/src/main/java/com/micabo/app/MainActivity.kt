package com.micabo.app

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
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

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MicaboTheme {
                MicaboRoot(app = application as MicaboApplication)
            }
        }
    }
}
