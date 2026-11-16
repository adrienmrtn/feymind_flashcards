package com.micabo.app.ui.onboarding

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat

/** **La permission des notifications** (Android 13 et plus ; avant, elle est donnée). */
object NotificationAsk {
    fun granted(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
}

/** Une demande de permission à lancer d'un bouton : `onResult(true)` quand elle est donnée. */
@Composable
fun rememberNotificationAsk(onResult: (Boolean) -> Unit): () -> Unit {
    val context = LocalContext.current
    val latest by rememberUpdatedState(onResult)
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> latest(granted) }
    return {
        if (NotificationAsk.granted(context)) {
            latest(true)
        } else {
            runCatching { launcher.launch(Manifest.permission.POST_NOTIFICATIONS) }.onFailure { latest(false) }
        }
    }
}
