package com.micabo.app.ui.focus

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.micabo.app.R
import com.micabo.app.data.FocusTimer
import com.micabo.app.data.XpRules
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboSecondaryButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.xp.ProgressRing
import com.micabo.app.ui.xp.XpBadge
import kotlinx.coroutines.delay

/**
 * **Le minuteur** : Mika au centre d'un anneau qui se vide, vingt-cinq minutes, une pause, un
 * arrêt (confirmé). L'écran reste allumé tant que la séance court ; le temps se recalcule depuis
 * l'heure du départ (`FocusTimer`), il n'y a donc ni service ni permission. Au bout : la fête,
 * et `focusSession`.
 */
@Composable
fun FocusScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    val view = LocalView.current
    val state by app.focus.state.collectAsState()
    var now by remember { mutableLongStateOf(app.focus.now()) }
    var done by rememberSaveable { mutableStateOf(false) }
    var confirmStop by remember { mutableStateOf(false) }
    val running = state.active && !state.paused

    // Une seconde après l'autre, recalée sur l'heure du départ : sans dérive, et le retour
    // d'arrière-plan tombe juste. À zéro, la séance se termine (une seule fois).
    LaunchedEffect(state) {
        while (true) {
            now = app.focus.now()
            if (state.active && app.focus.finishIfDue()) {
                done = true
                haptics.success()
                break
            }
            if (!running) break
            delay(1_000 - state.elapsed(now) % 1_000)
        }
    }

    // L'écran ne s'éteint pas pendant la séance ; il le peut de nouveau en pause ou en partant.
    DisposableEffect(running) {
        view.keepScreenOn = running
        onDispose { view.keepScreenOn = false }
    }

    BackHandler(enabled = state.active) { confirmStop = true }

    val remaining = if (state.active) state.remaining(now) else FocusTimer.DURATION
    val seconds = ((remaining + 999) / 1_000).toInt()
    val progress = remaining.toFloat() / FocusTimer.DURATION

    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CloseButton(onClick = { if (state.active) confirmStop = true else navigator.back() })
            Spacer(Modifier.width(12.dp))
            Text(stringResource(R.string.kx_focus_title), style = nunito(22.sp, FontWeight.Black), color = colors.ink)
        }
        Column(
            Modifier.weight(1f).fillMaxWidth().padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            ProgressRing(progress, 280.dp, 18.dp, if (state.paused) colors.inkTertiary else colors.accent) {
                Mika(if (state.paused) MikaMood.SLEEP else if (running) MikaMood.THINK else MikaMood.IDLE, 150.dp)
            }
            Spacer(Modifier.height(24.dp))
            Text(
                "%02d:%02d".format(seconds / 60, seconds % 60),
                style = nunito(56.sp, FontWeight.Black, lineHeight = 60.sp),
                color = if (state.paused) colors.inkSecondary else colors.ink,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                when {
                    state.paused -> stringResource(R.string.kx_focus_paused)
                    running -> stringResource(R.string.kx_focus_running)
                    else -> stringResource(R.string.kx_focus_subtitle, XpRules.FOCUS_MINUTES.toString())
                },
                style = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp),
                color = colors.inkSecondary,
                textAlign = TextAlign.Center,
            )
        }
        Column(Modifier.padding(horizontal = 20.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (!state.active) {
                MicaboButton(stringResource(R.string.kx_focus_start), onClick = { app.focus.start() })
            } else {
                MicaboButton(
                    stringResource(if (state.paused) R.string.kx_focus_resume else R.string.kx_focus_pause),
                    onClick = { if (state.paused) app.focus.resume() else app.focus.pause() },
                    color = if (state.paused) colors.accent else colors.toneVivid[0],
                )
                MicaboSecondaryButton(stringResource(R.string.kx_focus_stop), onClick = { confirmStop = true }, color = colors.wrong)
            }
        }
    }

    if (confirmStop) {
        AlertDialog(
            onDismissRequest = { confirmStop = false },
            containerColor = colors.surface,
            title = { Text(stringResource(R.string.kx_focus_stopTitle), style = nunito(20.sp, FontWeight.ExtraBold)) },
            text = { Text(stringResource(R.string.kx_focus_stopBody), style = nunito(16.sp)) },
            confirmButton = {
                TextButton(onClick = {
                    confirmStop = false
                    app.focus.stop()
                    navigator.back()
                }) { Text(stringResource(R.string.kx_focus_stop), color = colors.wrong, style = nunito(16.sp, FontWeight.ExtraBold)) }
            },
            dismissButton = {
                TextButton(onClick = { confirmStop = false }) { Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold)) }
            },
        )
    }

    if (done) {
        FocusDone(onDismiss = {
            done = false
            navigator.back()
        })
    }
}

/** **La fête de fin de séance** : Mika qui saute, le temps tenu, l'XP gagnée. */
@Composable
private fun FocusDone(onDismiss: () -> Unit) {
    val colors = Micabo.colors
    val pop = remember { Animatable(0.4f) }
    LaunchedEffect(Unit) { pop.animateTo(1f, spring(dampingRatio = 0.45f, stiffness = 220f)) }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier
                .padding(20.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(30.dp))
                .background(colors.canvas)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(Modifier.graphicsLayer { scaleX = pop.value; scaleY = pop.value }) {
                Mika(MikaMood.CELEBRATE, 150.dp)
            }
            Spacer(Modifier.height(12.dp))
            Text(stringResource(R.string.kx_focus_doneTitle), style = nunito(26.sp, FontWeight.Black, lineHeight = 30.sp), color = colors.ink, textAlign = TextAlign.Center)
            Spacer(Modifier.height(8.dp))
            Text(
                stringResource(R.string.kx_focus_doneBody, XpRules.FOCUS_MINUTES.toString()),
                style = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp),
                color = colors.inkSecondary,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(12.dp))
            XpBadge(XpRules.FOCUS_SESSION)
            Spacer(Modifier.height(18.dp))
            MicaboButton(stringResource(R.string.lesson_quiz_finish), onClick = onDismiss)
        }
    }
}
