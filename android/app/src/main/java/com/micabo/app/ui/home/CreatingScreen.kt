package com.micabo.app.ui.home

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.ApiException
import com.micabo.app.data.CreationStage
import com.micabo.app.data.LessonRequest
import com.micabo.app.data.NetworkException
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboSecondaryButton
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import kotlin.coroutines.cancellation.CancellationException

/** Le message d'un échec, dans la langue de l'app. */
@Composable
fun errorMessage(error: Throwable): String = when {
    error is NetworkException -> stringResource(R.string.x_error_network)
    error is ApiException && error.isDailyLimit -> stringResource(R.string.lesson_error_dailyLimit)
    error is ApiException && error.code == "free_limit" -> stringResource(R.string.lesson_error_freeLimit)
    error is ApiException && error.code == "import_pro" -> stringResource(R.string.lesson_error_importPro)
    error is ApiException && error.code == "pro_required" -> stringResource(R.string.lesson_error_proRequired)
    error is ApiException && error.code == "forbidden" -> stringResource(R.string.lesson_error_forbidden)
    else -> stringResource(R.string.lesson_error_generic)
}

/**
 * **Mika prépare la leçon** : les quatre étapes du vrai travail (lire, découper, écrire,
 * préparer les questions). Le chemin s'ouvre dès que le premier thème est arrivé.
 */
@Composable
fun CreatingScreen(request: LessonRequest) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    var stage by remember { mutableStateOf(CreationStage.READING) }
    var error by remember { mutableStateOf<Throwable?>(null) }
    var attempt by remember { mutableIntStateOf(0) }

    LaunchedEffect(attempt) {
        error = null
        try {
            val id = app.lessons.create(request) { stage = it }
            haptics.success()
            navigator.replace(Screen.LessonPath(id))
        } catch (cancel: CancellationException) {
            throw cancel
        } catch (failure: Throwable) {
            haptics.error()
            if (failure is ApiException && failure.opensPaywall) {
                navigator.replace(Screen.Paywall(failure.code))
            } else {
                error = failure
            }
        }
    }

    Column(
        Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(Modifier.fillMaxWidth()) {
            CloseButton(onClick = { navigator.back() })
        }
        Spacer(Modifier.weight(0.6f))
        AnimatedContent(targetState = error, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "state") { failure ->
            if (failure == null) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(contentAlignment = Alignment.Center) {
                        Halo()
                        Mika(MikaMood.THINK, 150.dp)
                    }
                    Spacer(Modifier.height(18.dp))
                    Text(
                        stringResource(R.string.lesson_create_generatingTitle),
                        style = nunito(26.sp, FontWeight.Black, lineHeight = 30.sp),
                        color = colors.ink,
                        textAlign = TextAlign.Center,
                    )
                    request.topic?.let {
                        Spacer(Modifier.height(6.dp))
                        Text("« $it »", style = nunito(16.sp, FontWeight.Bold), color = colors.accent, textAlign = TextAlign.Center)
                    }
                    Spacer(Modifier.height(28.dp))
                    Stages(stage, fromTopic = request.topic != null)
                }
            } else {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Mika(MikaMood.SAD, 140.dp)
                    Spacer(Modifier.height(18.dp))
                    Text(
                        stringResource(R.string.lesson_create_failedTitle),
                        style = nunito(24.sp, FontWeight.Black),
                        color = colors.ink,
                        textAlign = TextAlign.Center,
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(errorMessage(failure), style = nunito(16.sp, FontWeight.Medium, lineHeight = 22.sp), color = colors.inkSecondary, textAlign = TextAlign.Center)
                }
            }
        }
        Spacer(Modifier.weight(1f))
        if (error != null) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if ((error as? ApiException)?.isDailyLimit != true) {
                    MicaboButton(stringResource(R.string.lesson_path_retry), onClick = { attempt += 1 })
                }
                MicaboSecondaryButton(stringResource(R.string.lesson_create_cancel), onClick = { navigator.back() })
            }
        }
    }
}

@Composable
private fun Halo() {
    val colors = Micabo.colors
    val transition = rememberInfiniteTransition(label = "halo")
    val angle by transition.animateFloat(0f, 360f, infiniteRepeatable(tween(6000, easing = LinearEasing)), label = "angle")
    val pulse by transition.animateFloat(0.92f, 1.06f, infiniteRepeatable(tween(1400), RepeatMode.Reverse), label = "pulse")
    Box(
        Modifier
            .size((190 * pulse).dp)
            .rotate(angle)
            .clip(CircleShape)
            .background(
                androidx.compose.ui.graphics.Brush.sweepGradient(
                    listOf(colors.accentWash, colors.accentSoft, colors.tonePale[4], colors.accentWash),
                ),
            ),
    )
}

@Composable
private fun Stages(stage: CreationStage, fromTopic: Boolean) {
    val colors = Micabo.colors
    val labels = listOf(
        if (fromTopic) R.string.lesson_create_stageTopic else R.string.lesson_create_stageReading,
        R.string.lesson_create_stageCutting,
        R.string.lesson_create_stageWriting,
        R.string.lesson_create_stageQuestions,
    )
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        labels.forEachIndexed { index, label ->
            val done = index < stage.ordinal
            val active = index == stage.ordinal
            val ink by animateColorAsState(if (done || active) colors.ink else colors.inkTertiary, label = "ink")
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier
                        .size(26.dp)
                        .clip(CircleShape)
                        .background(if (done) colors.correct else if (active) colors.accentSoft else colors.surfaceMuted),
                    contentAlignment = Alignment.Center,
                ) {
                    when {
                        done -> Icon(Icons.Filled.Check, null, tint = colors.onInk, modifier = Modifier.size(16.dp))
                        active -> CircularProgressIndicator(color = colors.accent, strokeWidth = 2.dp, modifier = Modifier.size(16.dp))
                    }
                }
                Spacer(Modifier.width(12.dp))
                Text(stringResource(label), style = nunito(16.sp, if (active) FontWeight.ExtraBold else FontWeight.SemiBold), color = ink)
            }
        }
    }
}
