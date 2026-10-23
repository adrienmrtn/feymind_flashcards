package com.micabo.app.ui.home

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.micabo.app.R
import com.micabo.app.data.RecordingService
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboSecondaryButton
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import kotlinx.coroutines.delay

/**
 * **Enregistrer son cours** (`VoiceRecorder`) : le micro jusqu'à quatre-vingt-dix minutes, ou
 * un fichier audio du téléphone. L'enregistrement arrive ensuite dans la barre, comme un
 * support, pendant que Mika le transcrit.
 *
 * Le micro tourne dans un service de premier plan (`RecordingService`) : écran verrouillé ou
 * app quittée, il continue, et la notification permet de l'arrêter. La feuille ne fait que
 * le démarrer, l'arrêter et le montrer ; l'enregistrement fini rejoint la barre par le service
 * (`RecordingService.onRecorded`), même si elle a été refermée. Tant qu'elle est ouverte,
 * l'écran reste allumé : un élève qui pose son téléphone sur la table voit le temps tourner.
 */
@Composable
fun AudioSheet(onDismiss: () -> Unit, onPickFile: () -> Unit) {
    val colors = Micabo.colors
    val context = LocalContext.current
    val state by RecordingService.state.collectAsState()
    val recording = state.recording
    var elapsed by remember { mutableLongStateOf(0L) }
    var denied by remember { mutableStateOf(false) }
    var startFailed by remember { mutableStateOf(false) }
    val failed = startFailed || state.failed
    // Ouvert pendant l'enregistrement : la feuille se ferme quand il est fini.
    var wasRecording by remember { mutableStateOf(recording) }

    fun stop() {
        RecordingService.stop(context)
    }

    fun start() {
        startFailed = false
        RecordingService.clearFailure()
        if (!RecordingService.start(context)) startFailed = true
    }

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) start() else denied = true
    }

    // L'écran reste allumé tant que la feuille est ouverte.
    val view = LocalView.current
    DisposableEffect(view) {
        val before = view.keepScreenOn
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = before }
    }
    // Fini (par le bouton, la notification ou la limite) : l'enregistrement est déjà dans la barre.
    LaunchedEffect(recording) {
        if (recording) {
            wasRecording = true
        } else if (wasRecording && !state.failed) {
            onDismiss()
        }
    }
    LaunchedEffect(recording, state.startedAt) {
        while (recording) {
            elapsed = System.currentTimeMillis() - state.startedAt
            delay(500)
        }
        elapsed = 0
    }

    val transition = rememberInfiniteTransition(label = "rec")
    val pulse by transition.animateFloat(0.85f, 1.15f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "pulse")

    Dialog(onDismissRequest = { if (!recording) { RecordingService.clearFailure(); onDismiss() } }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.BottomCenter) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(28.dp))
                    .background(colors.canvas)
                    .padding(22.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon3D("reveil", 40.dp)
                    Spacer(Modifier.width(10.dp))
                    Text(stringResource(R.string.lesson_import_recordTitle), style = nunito(21.sp, FontWeight.Black), color = colors.ink)
                }
                Spacer(Modifier.height(8.dp))
                Text(stringResource(R.string.x_record_limit), style = nunito(14.sp, FontWeight.SemiBold, lineHeight = 19.sp), color = colors.inkSecondary, textAlign = TextAlign.Center)
                Spacer(Modifier.height(20.dp))
                Box(contentAlignment = Alignment.Center) {
                    Box(
                        Modifier
                            .size(120.dp)
                            .graphicsLayer { val s = if (recording) pulse else 1f; scaleX = s; scaleY = s }
                            .clip(CircleShape)
                            .background(if (recording) colors.wrongSoft else colors.accentWash),
                    )
                    Box(Modifier.size(64.dp).clip(CircleShape).background(if (recording) colors.wrong else colors.accent))
                }
                Spacer(Modifier.height(14.dp))
                val seconds = elapsed / 1000
                Text("%d:%02d".format(seconds / 60, seconds % 60), style = nunito(30.sp, FontWeight.Black), color = colors.ink)
                when {
                    denied -> Text(stringResource(R.string.lesson_audio_micDenied), style = nunito(14.sp, FontWeight.Bold), color = colors.wrongInk, textAlign = TextAlign.Center)
                    failed -> Text(stringResource(R.string.lesson_audio_unreadable), style = nunito(14.sp, FontWeight.Bold), color = colors.wrongInk, textAlign = TextAlign.Center)
                }
                Spacer(Modifier.height(18.dp))
                if (recording) {
                    MicaboButton(stringResource(R.string.lesson_import_recordStop), onClick = ::stop, color = colors.wrong)
                } else {
                    MicaboButton(stringResource(R.string.lesson_import_record), onClick = {
                        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) start()
                        else permission.launch(Manifest.permission.RECORD_AUDIO)
                    })
                    Spacer(Modifier.height(10.dp))
                    MicaboSecondaryButton(stringResource(R.string.lesson_import_audioFile), onClick = onPickFile)
                    TextButton(onClick = { RecordingService.clearFailure(); onDismiss() }) {
                        Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold), color = colors.inkSecondary)
                    }
                }
            }
        }
    }
}
