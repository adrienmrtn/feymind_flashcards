package com.micabo.app.ui.home

import androidx.activity.compose.BackHandler
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.saveable.rememberSaveable
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.ApiException
import com.micabo.app.data.CreationStage
import com.micabo.app.data.Exam
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
import java.util.Calendar
import java.util.TimeZone
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
    // Le cours n'est pas encore au serveur (409) : la synchronisation est relancée, on réessaie.
    error is ApiException && error.code == "course_unknown" -> stringResource(R.string.x_lesson_courseUnknown)
    else -> stringResource(R.string.lesson_error_generic)
}

/**
 * **Créer une leçon, après l'envoi** (`LessonCreationFlow`) : « As-tu un examen ? », la date si
 * oui, puis Mika prépare la leçon, au rythme du vrai travail (lire, découper, écrire, préparer
 * les questions). Le chemin s'ouvre dès que le premier thème est arrivé.
 */
@Composable
fun CreatingScreen(request: LessonRequest) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    var step by rememberSaveable { mutableStateOf("exam") }
    var examDate by remember { mutableStateOf<Long?>(null) }
    var stage by remember { mutableStateOf(CreationStage.READING) }
    var error by remember { mutableStateOf<Throwable?>(null) }
    var attempt by remember { mutableIntStateOf(0) }

    // Pendant la génération, ni croix ni retour, comme sur iPhone : quitter l'écran annulait
    // l'attente, et l'examen annoncé n'était jamais enregistré ni la barre vidée.
    BackHandler(enabled = step == "generating" && error == null) {}

    if (step == "generating") {
        LaunchedEffect(attempt) {
            error = null
            stage = CreationStage.READING
            val properties = mapOf("source" to request.source, "chars" to request.text.length, "images" to request.images.size, "exam" to (examDate != null), "lesson" to true)
            app.analytics.track("course_generation_started", properties)
            try {
                // Le même identifiant d'un essai à l'autre : le serveur a réservé la leçon sous lui.
                val id = app.lessons.create(request.copy(examDate = examDate)) { stage = it }
                // L'examen annoncé rejoint l'onglet Examens, sous le nom de la leçon (`LessonBuilder`).
                examDate?.let { date ->
                    app.exams.save(Exam(name = app.lessons.lesson(id)?.title.orEmpty(), date = date, lessonIds = listOf(id)))
                }
                haptics.success()
                app.analytics.track("course_imported", properties)
                app.composer.reset()
                navigator.replace(Screen.LessonPath(id))
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (failure: Throwable) {
                haptics.error()
                app.analytics.track("course_generation_failed", properties + ("code" to ((failure as? ApiException)?.code ?: failure.javaClass.simpleName)))
                if (failure is ApiException && failure.opensPaywall) {
                    navigator.replace(Screen.Paywall(failure.code))
                } else {
                    error = failure
                }
            }
        }
    }

    AnimatedContent(targetState = step, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "step") { shown ->
        when (shown) {
            "exam" -> ExamQuestion(
                onClose = { navigator.back() },
                onYes = { step = "date" },
                onNo = { step = "generating" },
            )
            "date" -> ExamDate(
                onClose = { navigator.back() },
                onPick = { date ->
                    examDate = date
                    step = "generating"
                },
            )
            else -> Generating(request, stage, error, onClose = { navigator.back() }, onRetry = { attempt += 1 })
        }
    }
}

@Composable
private fun ExamQuestion(onClose: () -> Unit, onYes: () -> Unit, onNo: () -> Unit) {
    val colors = Micabo.colors
    Column(
        Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(Modifier.fillMaxWidth()) { CloseButton(onClick = onClose) }
        Spacer(Modifier.weight(1f))
        Mika(MikaMood.THINK, 150.dp)
        Spacer(Modifier.height(20.dp))
        Text(
            stringResource(R.string.lesson_create_examQuestion),
            style = nunito(28.sp, FontWeight.Black, lineHeight = 32.sp),
            color = colors.ink,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.weight(1f))
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            MicaboButton(stringResource(R.string.lesson_create_examYes), onClick = onYes)
            MicaboSecondaryButton(stringResource(R.string.lesson_create_examNo), onClick = onNo)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ExamDate(onClose: () -> Unit, onPick: (Long) -> Unit) {
    val colors = Micabo.colors
    // Le sélecteur parle en minuit UTC ; l'examen se garde en minuit local.
    val tomorrowUtc = remember {
        val local = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(local.get(Calendar.YEAR), local.get(Calendar.MONTH), local.get(Calendar.DAY_OF_MONTH))
        }.timeInMillis
    }
    val state = rememberDatePickerState(
        initialSelectedDateMillis = tomorrowUtc + 13L * 24 * 3600 * 1000,
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long): Boolean = utcTimeMillis >= tomorrowUtc
        },
    )
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(20.dp)) {
        Row(Modifier.fillMaxWidth()) { CloseButton(onClick = onClose) }
        Text(
            stringResource(R.string.lesson_create_dateQuestion),
            style = nunito(26.sp, FontWeight.Black, lineHeight = 30.sp),
            color = colors.ink,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
        )
        DatePicker(
            state = state,
            title = null,
            headline = null,
            showModeToggle = false,
            colors = DatePickerDefaults.colors(
                containerColor = colors.canvas,
                selectedDayContainerColor = colors.accent,
                todayDateBorderColor = colors.accent,
                todayContentColor = colors.accent,
            ),
            modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()),
        )
        MicaboButton(
            stringResource(R.string.lesson_create_continue),
            enabled = state.selectedDateMillis != null,
            onClick = {
                val utc = state.selectedDateMillis ?: return@MicaboButton
                val day = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = utc }
                val local = Calendar.getInstance().apply {
                    clear()
                    set(day.get(Calendar.YEAR), day.get(Calendar.MONTH), day.get(Calendar.DAY_OF_MONTH))
                }
                onPick(local.timeInMillis)
            },
        )
    }
}

@Composable
private fun Generating(request: LessonRequest, stage: CreationStage, error: Throwable?, onClose: () -> Unit, onRetry: () -> Unit) {
    val colors = Micabo.colors
    Column(
        Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(Modifier.fillMaxWidth().height(44.dp)) {
            if (error != null) CloseButton(onClick = onClose)
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
                        Text(
                            // Les guillemets de la langue : « … » en français, “…” en anglais, „…“ en allemand.
                            stringResource(R.string.x_quoted, it),
                            style = nunito(16.sp, FontWeight.Bold),
                            color = colors.accent,
                            textAlign = TextAlign.Center,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
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
                    MicaboButton(stringResource(R.string.lesson_path_retry), onClick = onRetry)
                }
                MicaboSecondaryButton(stringResource(R.string.lesson_create_cancel), onClick = onClose)
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
    // Le halo respire par sa couche, pas par sa taille : la mise en page ne bouge pas à chaque image.
    Box(
        Modifier
            .size(190.dp)
            .graphicsLayer {
                scaleX = pulse
                scaleY = pulse
                rotationZ = angle
            }
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
