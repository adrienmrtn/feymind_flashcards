package com.micabo.app.ui.onboarding

import android.view.HapticFeedbackConstants
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.i18n.t
import com.micabo.app.onboarding.CommitHold
import com.micabo.app.onboarding.DailyLoad
import com.micabo.app.onboarding.DesiredGradeScale
import com.micabo.app.onboarding.FocusPlan
import com.micabo.app.onboarding.GradeGap
import com.micabo.app.onboarding.GradeTick
import com.micabo.app.onboarding.OnboardingModel
import com.micabo.app.onboarding.OnboardingStep
import com.micabo.app.onboarding.SubjectDisplay
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboGhostButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Type
import com.micabo.app.ui.theme.display
import com.micabo.app.ui.theme.text
import com.micabo.app.ui.v3.LocalCompact
import com.micabo.app.ui.v3.LocalStill
import com.micabo.app.ui.v3.MicaboIcons
import com.micabo.app.ui.v3.MikaRow
import com.micabo.app.ui.v3.OnbScreen
import com.micabo.app.ui.v3.Panel
import com.micabo.app.ui.v3.V3Chip
import com.micabo.app.ui.v3.V3Title
import com.micabo.app.ui.v3.XpPill
import com.micabo.app.ui.v3.figure
import com.micabo.app.ui.v3.v3Card
import kotlinx.coroutines.delay
import java.time.LocalDate

// MARK: - Les notes

/** **Le curseur à crans** (`OnbNotchSlider`) : la valeur en grand, les bornes du barème dessous. */
@Composable
fun NotchSlider(count: Int, index: Int, onIndex: (Int) -> Unit, lower: String, upper: String, value: String, qualifier: String? = null, tone: Color = Micabo.colors.accentBright) {
    val colors = Micabo.colors
    val view = LocalView.current
    val compact = LocalCompact.current
    Column(Modifier.fillMaxWidth().padding(top = if (compact) 8.dp else 28.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (compact) 18.dp else 30.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            LeftToRight { com.micabo.app.ui.v3.FitText(value, figure(64), tone, Modifier.fillMaxWidth().testTag("sliderValue"), TextAlign.Center) }
            if (qualifier != null) Text(qualifier, style = text(20.sp, FontWeight.SemiBold), color = colors.ink, textAlign = TextAlign.Center)
        }
        LeftToRight {
            Column {
                Slider(
                    value = index.toFloat(),
                    onValueChange = { raw ->
                        val next = Math.round(raw).coerceIn(0, count - 1)
                        if (next != index) {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            onIndex(next)
                        }
                    },
                    valueRange = 0f..(count - 1).coerceAtLeast(1).toFloat(),
                    steps = (count - 2).coerceAtLeast(0),
                    colors = SliderDefaults.colors(
                        thumbColor = Color.White,
                        activeTrackColor = colors.accent,
                        inactiveTrackColor = colors.stroke,
                        activeTickColor = Color.White.copy(alpha = 0.7f),
                        inactiveTickColor = colors.inkTertiary.copy(alpha = 0.7f),
                    ),
                    modifier = Modifier.fillMaxWidth().semantics { contentDescription = value },
                )
                Row(Modifier.fillMaxWidth()) {
                    Text(lower, style = text(17.sp, FontWeight.SemiBold), color = colors.inkSecondary)
                    Spacer(Modifier.weight(1f))
                    Text(upper, style = text(17.sp, FontWeight.SemiBold), color = colors.inkSecondary)
                }
            }
        }
    }
}

@Composable
private fun belowLabel(scale: DesiredGradeScale) = t("ios.averageBelow", "grade" to scale.choices.first().label)

@Composable
private fun gradeCaption(model: OnboardingModel): String? {
    val scale = model.gradeScale
    scale.unitKey?.let { return t(it) }
    return if (scale.lowerIsBetter) t("ios.onb5.grade.best", "best" to scale.best) else null
}

@Composable
fun CurrentAverageStep(model: OnboardingModel) {
    val scale = model.gradeScale.scale
    val choices = listOf(GradeTick(DesiredGradeScale.BELOW_SCORE, belowLabel(scale))) + scale.choices
    val start = (choices.size - 1) / 2
    LaunchedEffect(Unit) { if (model.currentScore == null) model.setCurrent(choices[start].score) }
    val index = choices.indexOfFirst { it.score == model.currentScore }.takeIf { it >= 0 } ?: start
    Question(t("ios.onb12.q.current"), t("ios.onb12.say.current"), MikaMood.WINK, footer = {
        MicaboButton(t("common.continue"), onClick = { model.answerCurrentAverage(); model.advance() }, enabled = model.currentScore != null, modifier = Modifier.testTag("cta"))
    }) {
        NotchSlider(choices.size, index, { model.setCurrent(choices[it].score) }, choices.first().label, choices.last().label, choices[index].label)
        gradeCaption(model)?.let { Text(it, style = Type.mention, color = Micabo.colors.inkSecondary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()) }
    }
}

@Composable
fun gapTitle(gap: GradeGap): String {
    if (gap.size == GradeGap.Size.HOLD) return t("ios.onb10.target.hold", "target" to gap.to)
    val size = when (gap.size) {
        GradeGap.Size.SMALL -> "small"
        GradeGap.Size.MEDIUM -> "medium"
        else -> "large"
    }
    val amount = gap.amount ?: return t("ios.onb10.target.$size.plain")
    return if (gap.isWhole) t("ios.onb10.target.$size.points", "count" to amount) else t("ios.onb10.target.$size", "gap" to amount)
}

@Composable
fun gradeLabel(model: OnboardingModel, score: Int): String {
    val below = belowLabel(model.gradeScale.scale)
    return model.gradeLabel(score) { below }
}

@Composable
fun TargetAverageStep(model: OnboardingModel) {
    val choices = model.targetChoices
    val start = (choices.size - 1) / 2
    LaunchedEffect(Unit) { if (model.targetScore == null && choices.isNotEmpty()) model.targetScore = choices[start].score }
    val index = choices.indexOfFirst { it.score == model.targetScore }.takeIf { it >= 0 } ?: start
    val current = model.currentScore
    val target = model.targetScore
    val say = if (current != null && target != null) {
        gapTitle(GradeGap.of(current, target, model.gradeScale, gradeLabel(model, current), gradeLabel(model, target)))
    } else {
        t("ios.onb12.say.target")
    }
    Question(t("ios.onb10.q.target"), say, MikaMood.HAPPY, footer = {
        MicaboButton(t("common.continue"), onClick = { model.advance() }, enabled = model.targetScore != null, modifier = Modifier.testTag("cta"))
    }) {
        if (choices.isNotEmpty()) {
            NotchSlider(choices.size, index, { model.targetScore = choices[it].score }, choices.first().label, choices.last().label, choices[index].label, tone = Micabo.colors.green)
        }
        gradeCaption(model)?.let { Text(it, style = Type.mention, color = Micabo.colors.inkSecondary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()) }
    }
}

@Composable
fun StartingPointStep(model: OnboardingModel) {
    val colors = Micabo.colors
    val locale = currentLocale
    val target = model.targetScore?.let { gradeLabel(model, it) }
    val exam = model.datedExam
    val title = when {
        target != null && exam != null -> t("ios.onb10.start.title", "target" to target, "date" to Words.day(exam.second, locale))
        target != null -> t("ios.onb10.start.titleOpen", "target" to target, "time" to Words.duration(91, locale))
        exam != null -> t("ios.onb16.start.titleExam", "exam" to examTitle(exam.first))
        else -> t("ios.onb16.start.titleBare")
    }
    OnbScreen(
        header = {
            V3Title(title, Modifier.padding(top = 16.dp), size = 40, keyword = colors.green)
            MikaRow(t("ios.onb16.start.line"), MikaMood.PROUD, Modifier.padding(top = 12.dp))
        },
        body = {
            Column(Modifier.fillMaxWidth().padding(top = 16.dp).v3Card().padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                ProjectionChart(target, Modifier.fillMaxWidth().height(170.dp))
                Row(verticalAlignment = Alignment.Bottom) {
                    Column(Modifier.weight(1f)) {
                        model.currentScore?.let { Text(gradeLabel(model, it), style = text(17.sp, FontWeight.SemiBold), color = colors.ink) }
                        Text(t("ios.onb5.trial.today"), style = text(13.sp), color = colors.inkTertiary)
                    }
                    Text(exam?.let { Words.date(it.second, locale) } ?: t("ios.onb10.start.in", "time" to Words.duration(91, locale)), style = text(13.sp), color = colors.inkTertiary, textAlign = TextAlign.End)
                }
            }
        },
        footer = { MicaboButton(t("ios.onb12.start.cta"), onClick = { model.advance() }, modifier = Modifier.testTag("cta")) },
    )
}

/** **La courbe qui monte**, d'aujourd'hui à la date visée, l'objectif au bout. */
@Composable
private fun ProjectionChart(target: String?, modifier: Modifier) {
    val colors = Micabo.colors
    LeftToRight {
        Box(modifier) {
            Canvas(Modifier.fillMaxWidth().fillMaxHeight()) {
                val path = Path().apply {
                    moveTo(8f, size.height * 0.82f)
                    cubicTo(size.width * 0.35f, size.height * 0.8f, size.width * 0.55f, size.height * 0.5f, size.width - 24f, size.height * 0.16f)
                }
                for (row in 1..3) {
                    val y = size.height * row / 4f
                    drawLine(colors.stroke, Offset(0f, y), Offset(size.width, y), strokeWidth = 1.5f)
                }
                drawPath(path, colors.green, style = Stroke(width = 5.dp.toPx(), cap = StrokeCap.Round))
                drawCircle(colors.accent, 7.dp.toPx(), Offset(8f, size.height * 0.82f))
                drawCircle(colors.green, 9.dp.toPx(), Offset(size.width - 24f, size.height * 0.16f))
            }
            if (target != null) {
                Text(target, style = display(22.sp), color = colors.onYellow, modifier = Modifier.align(Alignment.TopEnd).clip(CircleShape).background(colors.green).padding(horizontal = 10.dp, vertical = 3.dp))
            }
        }
    }
}

@Composable
fun DailyTimeStep(model: OnboardingModel) {
    val locale = currentLocale
    LaunchedEffect(Unit) { if (model.dailyMinutes == null) model.dailyMinutes = 15 }
    val minutes = DailyLoad.nearestStep(model.dailyMinutes ?: 15)
    val qualifier = when {
        minutes < 10 -> "ios.onb10.time.5"
        minutes < 15 -> "ios.onb10.time.10"
        minutes < 30 -> "ios.onb10.time.15"
        minutes < 60 -> "ios.onb10.time.30"
        else -> "ios.onb16.time.max"
    }
    Question(t("ios.onb12.q.time"), t("ios.onb12.say.time"), MikaMood.IDLE, footer = {
        MicaboButton(t("common.continue"), onClick = { model.advance() }, modifier = Modifier.testTag("cta"))
    }) {
        NotchSlider(
            DailyLoad.steps.size,
            DailyLoad.stepIndex(minutes),
            { model.dailyMinutes = DailyLoad.minutes(it) },
            Words.minutes(DailyLoad.minimumMinutes, locale),
            Words.minutes(DailyLoad.maximumMinutes, locale),
            Words.minutes(minutes, locale),
            qualifier = t(qualifier),
        )
    }
}

// MARK: - Ton organisation

@Composable
fun PlanDemoStep(model: OnboardingModel, today: LocalDate = LocalDate.now(), previewDay: Int? = null) {
    val colors = Micabo.colors
    var day by remember { mutableStateOf(previewDay) }
    val selected = day ?: 0
    val subjects = model.orderedSubjects.map { SubjectDisplay.subject(it, appLanguageCode) }
    val subject = if (subjects.isEmpty()) t("ios.onb11.plan.lesson") else subjects[selected % subjects.size]
    val kinds = listOf(MicaboIcons.notes to t("ios.onb12.plan.kind.lesson"), MicaboIcons.quiz to t("ios.onb12.plan.kind.quiz"), MicaboIcons.cards to t("ios.onb12.plan.kind.cards"))
    val kind = kinds[selected % kinds.size]
    val examDay = model.datedExam?.second
    val event = examDay?.let { java.time.temporal.ChronoUnit.DAYS.between(today, it).toInt() }?.takeIf { it in 0..6 }
    DemoStage(t("ios.onb15.plan.title", "min" to model.minutesPerDay), t("ios.onb12.plan.play"), day != null, onPlay = { day = 1 }, onContinue = { model.advance() }) {
        Panel(padding = 16.dp) {
            WeekStrip(today, selected, event = event, onPick = { day = it })
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(colors.surfaceMuted).padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(kind.first, null, tint = colors.accentBright, modifier = Modifier.size(30.dp))
                Column(Modifier.weight(1f)) {
                    Text(subject, style = display(24.sp), color = colors.ink)
                    Text(kind.second, style = Type.detail, color = colors.ink)
                }
                Text(
                    t("ios.quiz.time.short", "n" to FocusPlan.sessionLength(model.minutesPerDay)),
                    style = text(17.sp, FontWeight.SemiBold),
                    color = colors.accentBright,
                    maxLines = 1,
                    modifier = Modifier.clip(CircleShape).background(colors.accentWash).padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
        }
    }
}

/** **« Tu peux aussi travailler en sessions qui te rapportent de l'XP »** (lot 16). */
@Composable
fun FocusDemoStep(model: OnboardingModel, previewDone: Boolean = false) {
    val colors = Micabo.colors
    val compact = LocalCompact.current
    val haptics = rememberHaptics()
    val minutes = FocusPlan.demoMinutes(model.minutesPerDay)
    val fill = remember { Animatable(if (previewDone) 1f else 0f) }
    var started by remember { mutableStateOf(previewDone) }
    var done by remember { mutableStateOf(previewDone) }
    LaunchedEffect(started) {
        if (started && !done) {
            fill.animateTo(1f, tween(1_800, easing = LinearEasing))
            haptics.success()
            done = true
        }
    }
    DemoStage(t("ios.onb16.focus.title"), t("ios.onb12.focus.play"), done, onPlay = { if (!started) { haptics.tap(); started = true } }, onContinue = { model.advance() }) {
        Panel {
            Box(Modifier.size(if (compact) 190.dp else 230.dp).align(Alignment.CenterHorizontally), contentAlignment = Alignment.Center) {
                Canvas(Modifier.fillMaxWidth().fillMaxHeight()) {
                    val stroke = 14.dp.toPx()
                    val inset = stroke / 2
                    drawArc(colors.stroke, 0f, 360f, false, Offset(inset, inset), Size(size.width - stroke, size.height - stroke), style = Stroke(stroke))
                    drawArc(if (done) colors.green else colors.accent, -90f, 360f * fill.value, false, Offset(inset, inset), Size(size.width - stroke, size.height - stroke), style = Stroke(stroke, cap = StrokeCap.Round))
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    LeftToRight {
                        val left = ((1f - fill.value) * minutes * 60).toInt()
                        com.micabo.app.ui.v3.FitText("%d:%02d".format(left / 60, left % 60), figure(52), colors.ink)
                    }
                    model.focusSubject?.let { Text(SubjectDisplay.subject(it, appLanguageCode), style = text(17.sp, FontWeight.SemiBold), color = colors.ink) }
                }
            }
            if (done) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.CheckCircle, null, tint = colors.green, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(t("ios.onb12.focus.finished"), style = text(17.sp, FontWeight.SemiBold), color = colors.green)
                    Spacer(Modifier.width(10.dp))
                    XpPill(FocusPlan.demoXp(model.minutesPerDay))
                }
            } else {
                Text(t("ios.onb12.focus.fast"), style = Type.mention, color = colors.inkTertiary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            }
        }
    }
}

/** Le message du rappel, comme la notification le dira (`NotificationsStepView.message`). */
@Composable
fun reminderMessage(model: OnboardingModel): String {
    val subject = (model.focusSubject ?: model.subjects.sorted().firstOrNull())?.let { SubjectDisplay.subject(it, appLanguageCode) }
    val name = model.displayName.trim()
    val vars = arrayOf("name" to name, "count" to model.cardsPerDay, "subject" to (subject ?: ""), "min" to model.minutesPerDay)
    if (name.isEmpty() || subject == null) return t("ios.onb10.notif.bodyPlain", *vars)
    if (model.examChoice == com.micabo.app.onboarding.ExamChoice.Test) return t("ios.onb10.notif.bodyTest", *vars)
    return t("ios.onb10.notif.body", *vars)
}

@Composable
fun NotificationsStep(model: OnboardingModel, host: OnboardingHost) {
    val colors = Micabo.colors
    val locale = currentLocale
    var choosing by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { if (model.studyHour == null) model.studyHour = OnboardingModel.DEFAULT_HOUR }
    val hour = Words.hour(model.reminderHour, locale)
    val ask = rememberNotificationAsk { granted ->
        host.track("onboarding_notifications", mapOf("granted" to granted))
        model.advance()
    }
    OnbScreen(
        header = {
            V3Title(t("ios.onb15.notif.title", "hour" to hour), Modifier.padding(top = 16.dp))
            MikaRow(t("ios.onb7.notif.one"), MikaMood.WINK, Modifier.padding(top = 12.dp))
        },
        body = {
            Row(Modifier.padding(top = 20.dp).fillMaxWidth().v3Card().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Mika(MikaMood.HAPPY, 48.dp)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Row {
                        Text("Micabo", style = text(17.sp, FontWeight.SemiBold), color = colors.ink, modifier = Modifier.weight(1f))
                        Text(hour, style = Type.mention, color = colors.inkTertiary)
                    }
                    Text(reminderMessage(model), style = text(17.sp, FontWeight.SemiBold, 23.sp), color = colors.ink)
                }
            }
            Box(Modifier.fillMaxWidth().padding(top = 18.dp), contentAlignment = Alignment.Center) {
                V3Chip(t("ios.onb10.notif.change", "hour" to hour), onClick = { choosing = true }, icon = Icons.Rounded.Schedule)
            }
        },
        footer = {
            MicaboButton(t("ios.onb10.notif.enable"), onClick = ask, modifier = Modifier.testTag("cta"))
            MicaboGhostButton(t("ios.onb10.later"), onClick = { model.advance() })
        },
    )
    if (choosing) {
        AlertDialog(
            onDismissRequest = { choosing = false },
            title = { Text(t("ios.onb10.hour.title")) },
            text = {
                Column(Modifier.heightIn(max = 360.dp).verticalScroll(rememberScrollState())) {
                    (5..23).forEach { value ->
                        Text(
                            Words.hour(value, locale),
                            style = text(19.sp, if (value == model.reminderHour) FontWeight.Bold else FontWeight.Normal),
                            color = if (value == model.reminderHour) colors.accentBright else colors.ink,
                            modifier = Modifier.fillMaxWidth().clickable { model.studyHour = value; choosing = false }.padding(vertical = 10.dp),
                        )
                    }
                }
            },
            confirmButton = { TextButton(onClick = { choosing = false }) { Text(t("ios.done")) } },
        )
    }
}

/** La promesse de l'élève, entre guillemets (`studentPromise`). */
@Composable
fun studentPromise(model: OnboardingModel): String {
    val name = model.displayName.trim()
    val exam = model.datedExam
    val minutes = model.minutesPerDay
    if (exam != null) {
        val date = Words.day(exam.second, currentLocale)
        return if (name.isNotEmpty()) t("ios.onb12.commit.me", "name" to name, "min" to minutes, "date" to date) else t("ios.onb12.commit.meNoName", "min" to minutes, "date" to date)
    }
    return if (name.isNotEmpty()) t("ios.onb12.commit.meAny", "name" to name, "min" to minutes) else t("ios.onb12.commit.meAnyNoName", "min" to minutes)
}

/**
 * **L'engagement : un vrai maintien** (lot 15). Le bouton du pied, d'une seule identité stable
 * (le geste n'est jamais recréé pendant l'appui), se remplit en 1,5 s ; la vibration monte d'un
 * cran tous les 0,15 s ; lâché trop tôt, il se vide en douceur. Un appui court ne valide jamais.
 */
@Composable
fun CommitmentStep(model: OnboardingModel, previewHold: Float? = null) {
    val colors = Micabo.colors
    val compact = LocalCompact.current
    val view = LocalView.current
    val name = model.displayName.trim()
    val fill = remember { Animatable(if (model.hasCommitted) 1f else 0f) }
    var pressing by remember { mutableStateOf(false) }
    var encourages by remember { mutableStateOf(false) }
    var signedHere by remember { mutableStateOf(false) }
    val hold = remember { CommitHold() }
    val committed = model.hasCommitted

    fun commit() {
        if (model.hasCommitted) return
        hold.cancel()
        view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
        signedHere = true
        model.commit()
    }

    LaunchedEffect(pressing) {
        if (model.hasCommitted) return@LaunchedEffect
        if (pressing) {
            val remaining = ((1f - fill.value) * CommitHold.DURATION_MS).toInt().coerceAtLeast(50)
            fill.animateTo(1f, tween(remaining, easing = LinearEasing))
            if (pressing) commit()
        } else if (fill.value > 0f) {
            fill.animateTo(0f, tween(350))
        }
    }
    // La vibration qui monte, un cran tous les 0,15 s tant que le doigt est posé.
    LaunchedEffect(pressing) {
        var level = 0
        while (pressing && !model.hasCommitted && level < 10) {
            view.performHapticFeedback(
                when {
                    level < 4 -> HapticFeedbackConstants.CLOCK_TICK
                    level < 8 -> HapticFeedbackConstants.KEYBOARD_TAP
                    else -> HapticFeedbackConstants.VIRTUAL_KEY
                },
            )
            level++
            delay(150)
        }
    }
    LaunchedEffect(signedHere) {
        if (signedHere) {
            delay(900)
            if (model.step == OnboardingStep.commitment) model.advance()
        }
    }

    val shown = previewHold ?: fill.value
    val title = when {
        committed -> if (name.isEmpty()) t("ios.onb12.commit.doneNoName") else t("ios.onb12.commit.done", "name" to name)
        name.isEmpty() -> t("ios.onb15.commit.titleNoName")
        else -> t("ios.onb15.commit.title", "name" to name)
    }
    val label = when {
        committed -> t("ios.onb15.commit.signed")
        pressing || (previewHold ?: 0f) > 0.2f -> t("ios.onb15.commit.holding")
        encourages -> t("ios.onb15.commit.again")
        else -> t("ios.onb12.commit.hold")
    }
    val mood = when {
        committed -> MikaMood.CELEBRATE
        pressing -> MikaMood.THINK
        encourages -> MikaMood.WINK
        else -> MikaMood.IDLE
    }
    OnbScreen(
        centered = true,
        header = { V3Title(title, Modifier.padding(top = 16.dp), keyword = if (committed) colors.green else colors.accentBright) },
        body = {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (compact) 14.dp else 24.dp)) {
                Text(studentPromise(model), style = text(22.sp, FontWeight.Medium, 29.sp), color = colors.ink, textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = 330.dp))
                Mika(mood, if (compact) 130.dp else 180.dp)
            }
        },
        footer = {
            if (committed && !signedHere) {
                MicaboButton(t("common.continue"), onClick = { model.advance() }, modifier = Modifier.testTag("cta"))
            } else {
                val accessibilityLabel = t("ios.onb12.commit.hold")
                BoxWithConstraints(
                    Modifier
                        .fillMaxWidth()
                        .heightIn(min = 64.dp)
                        .clip(CircleShape)
                        .background(colors.ink)
                        .testTag("commitHold")
                        .semantics {
                            contentDescription = label
                            customActions = listOf(CustomAccessibilityAction(accessibilityLabel) { commit(); true })
                        }
                        .pointerInput(Unit) {
                            awaitEachGesture {
                                val down = awaitFirstDown(requireUnconsumed = false)
                                if (model.hasCommitted) return@awaitEachGesture
                                hold.press(System.currentTimeMillis())
                                encourages = false
                                pressing = true
                                val limit = 60.dp.toPx()
                                var cancelled = false
                                while (true) {
                                    val event = awaitPointerEvent()
                                    val change = event.changes.firstOrNull { it.id == down.id } ?: break
                                    if (!change.pressed) break
                                    if ((change.position - down.position).getDistance() > limit) {
                                        cancelled = true
                                        break
                                    }
                                }
                                val held = hold.progress(System.currentTimeMillis())
                                hold.cancel()
                                if (!model.hasCommitted) encourages = held > 0.05f || cancelled
                                pressing = false
                            }
                        },
                ) {
                    val width = maxWidth
                    HoldLabel(label, committed, colors.canvas, Modifier.fillMaxWidth())
                    Box(Modifier.matchParentSize()) {
                        Box(
                            Modifier.fillMaxHeight().fillMaxWidth(shown.coerceIn(0f, 1f)).clipToBounds().background(if (committed) colors.green else colors.accent),
                            contentAlignment = Alignment.CenterStart,
                        ) {
                            HoldLabel(label, committed, Color.White, Modifier.wrapContentWidth(Alignment.Start, unbounded = true).width(width))
                        }
                    }
                }
            }
        },
    )
}

@Composable
private fun HoldLabel(label: String, committed: Boolean, color: Color, modifier: Modifier) {
    Row(modifier.padding(horizontal = 20.dp, vertical = 12.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        Icon(if (committed) Icons.Rounded.Verified else Icons.Rounded.TouchApp, null, tint = color, modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(10.dp))
        Text(label, style = Type.button, color = color, textAlign = TextAlign.Center)
    }
}
