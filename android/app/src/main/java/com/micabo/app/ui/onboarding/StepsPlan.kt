package com.micabo.app.ui.onboarding

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Circle
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.i18n.t
import com.micabo.app.onboarding.FirstLessonChoice
import com.micabo.app.onboarding.FocusPlan
import com.micabo.app.onboarding.OnboardingModel
import com.micabo.app.onboarding.OnboardingStep
import com.micabo.app.onboarding.SubjectDisplay
import com.micabo.app.onboarding.TrialDates
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboGhostButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Type
import com.micabo.app.ui.theme.display
import com.micabo.app.ui.theme.text
import com.micabo.app.ui.v3.ChapterOpener
import com.micabo.app.ui.v3.IconTile
import com.micabo.app.ui.v3.LocalCompact
import com.micabo.app.ui.v3.LocalStill
import com.micabo.app.ui.v3.MicaboIcons
import com.micabo.app.ui.v3.OnbScreen
import com.micabo.app.ui.v3.Panel
import com.micabo.app.ui.v3.Reassurance
import com.micabo.app.ui.v3.V3Check
import com.micabo.app.ui.v3.V3Metric
import com.micabo.app.ui.v3.V3OptionRow
import com.micabo.app.ui.v3.V3Title
import com.micabo.app.ui.v3.XpPill
import com.micabo.app.ui.v3.figure
import com.micabo.app.ui.v3.v3Card
import com.micabo.app.ui.v3.wash

// MARK: - Ton plan

/** Les lignes du plan qui se construit (`planLines`). */
@Composable
fun planLines(model: OnboardingModel): List<String> {
    val locale = currentLocale
    return buildList {
        val year = model.schoolYear
        if (year != null) add(t("ios.onb10.build.class", "class" to year.title))
        else model.classLabel?.let { add(t("ios.onb10.build.level", "class" to it)) }
        if (model.subjects.isNotEmpty()) add(t("ios.onb10.build.subjects", "count" to model.subjects.size))
        model.hardestSubject?.let { add(t("ios.onb12.build.hardest", "subject" to SubjectDisplay.subject(it, appLanguageCode))) }
        model.targetScore?.let { target ->
            val to = gradeLabel(model, target)
            val range = model.currentScore?.let { Words.range(gradeLabel(model, it), to, locale) } ?: to
            add(t("ios.onb12.build.goal", "range" to range))
        }
        model.datedExam?.let { add(t("ios.onb10.build.exam", "exam" to examTitle(it.first), "date" to Words.day(it.second, locale))) }
        add(t("ios.onb10.build.daily", "min" to model.minutesPerDay, "hour" to Words.hour(model.reminderHour, locale)))
        when (model.firstLessonChoice) {
            FirstLessonChoice.TOPIC -> model.firstLessonSubject?.let { add(t("ios.onb10.build.lesson", "topic" to it)) }
            FirstLessonChoice.IMPORT -> add(t("ios.onb10.build.lessonImport"))
            null -> Unit
        }
    }
}

/** **Mika prépare ton plan** : le seul chargement du parcours, 4,4 s, qui avance seul. */
@Composable
fun PlanBuildingStep(model: OnboardingModel, previewProgress: Float? = null) {
    val colors = Micabo.colors
    val still = LocalStill.current
    val progress = remember { Animatable(previewProgress ?: if (still) 1f else 0f) }
    val haptics = rememberHaptics()
    LaunchedEffect(Unit) {
        if (previewProgress != null || still) return@LaunchedEffect
        progress.animateTo(1f, tween(4_400, easing = LinearEasing))
        kotlinx.coroutines.delay(400)
        if (model.step == OnboardingStep.planBuilding) {
            haptics.success()
            model.advance()
        }
    }
    val lines = planLines(model)
    val checked = minOf(lines.size, (progress.value * lines.size + 0.0001f).toInt())
    OnbScreen(
        centered = true,
        header = {},
        body = {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Mika(MikaMood.WRITE, if (LocalCompact.current) 80.dp else 120.dp)
                V3Title(t("ios.onb15.build.title"), align = TextAlign.Center)
                val percent = java.text.NumberFormat.getPercentInstance(currentLocale).format((progress.value * 100).toInt() / 100.0)
                LeftToRight { Text(percent, style = figure(48), color = colors.accentBright) }
                Column(Modifier.fillMaxWidth().v3Card().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    lines.forEachIndexed { index, line ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            val (icon, tint) = when {
                                index < checked -> Icons.Rounded.CheckCircle to colors.green
                                index == checked -> Icons.Rounded.RadioButtonUnchecked to colors.accent
                                else -> Icons.Rounded.Circle to colors.stroke
                            }
                            Icon(icon, null, tint = tint, modifier = Modifier.size(24.dp))
                            Text(line, style = text(17.sp, FontWeight.SemiBold, 22.sp), color = if (index < checked) colors.ink else if (index == checked) colors.inkSecondary else colors.inkTertiary)
                        }
                    }
                }
            }
        },
    )
}

/** Le fil de ce soir : la première leçon choisie, sinon sa matière la plus dure, jamais un titre inventé. */
@Composable
fun tonightTopic(model: OnboardingModel): String = when (model.firstLessonChoice) {
    FirstLessonChoice.TOPIC -> model.firstLessonSubject
    FirstLessonChoice.IMPORT -> t("ios.onb10.plan.lessonImport")
    null -> null
} ?: model.focusSubject?.let { SubjectDisplay.subject(it, appLanguageCode) }
    ?: model.subjects.sorted().firstOrNull()?.let { SubjectDisplay.subject(it, appLanguageCode) }
    ?: t("ios.onb11.plan.lesson")

/** **Le plan prêt**, comme un objet : ce soir, cette semaine, l'objectif. */
@Composable
fun ProfileSummaryStep(model: OnboardingModel) {
    val colors = Micabo.colors
    val locale = currentLocale
    val compact = LocalCompact.current
    val name = model.displayName.trim()
    val sessions = FocusPlan.sessionLengths(model.minutesPerDay)
    val minutes = sessions.first()
    val exam = model.datedExam
    val target = model.targetScore?.let { gradeLabel(model, it) }
    val goal = when {
        target != null && exam != null -> target to t("ios.onb12.plan.goalDetail", "exam" to examTitle(exam.first), "date" to Words.day(exam.second, locale))
        target != null -> target to t("ios.onb12.plan.goalOpen", "time" to Words.duration(91, locale))
        exam != null -> examTitle(exam.first) to Words.date(exam.second, locale)
        else -> null
    }
    OnbScreen(
        header = {
            Mika(MikaMood.CELEBRATE, if (compact) 84.dp else 120.dp, Modifier.fillMaxWidth())
            V3Title(if (name.isEmpty()) t("ios.onb10.plan.titleNoName") else t("ios.onb10.plan.title", "name" to name), Modifier.padding(top = 4.dp), size = 40, align = TextAlign.Center)
        },
        body = {
            Column(Modifier.padding(top = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                PlanBlock(t("ios.onb12.plan.tonightLabel"), Words.hour(model.reminderHour, locale), t("ios.onb12.plan.tonightDetail", "topic" to tonightTopic(model), "min" to minutes), colors.accentBright, highlighted = true)
                PlanBlock(
                    t("ios.onb12.plan.weekLabel"),
                    "${7 * sessions.size}",
                    if (sessions.size > 1) t("ios.onb16.plan.weekSplit", "min" to minutes, "count" to sessions.size) else t("ios.onb12.plan.weekDetail", "min" to minutes),
                    colors.ink,
                    highlighted = false,
                )
                if (goal != null) PlanBlock(t("ios.onb12.plan.goalLabel"), goal.first, goal.second, colors.green, highlighted = false)
            }
        },
        footer = { MicaboButton(t("ios.deckBuild.seePlan"), onClick = { model.advance() }, modifier = Modifier.testTag("cta")) },
    )
}

@Composable
private fun PlanBlock(label: String, value: String, detail: String, tone: Color, highlighted: Boolean) {
    val colors = Micabo.colors
    Row(
        Modifier.fillMaxWidth().v3Card(selected = highlighted).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        com.micabo.app.ui.v3.FitText(value, figure(if (LocalCompact.current) 34 else 40), tone, Modifier.widthIn(min = 76.dp, max = 160.dp))
        Column(Modifier.weight(1f)) {
            Text(label, style = text(17.sp, FontWeight.SemiBold), color = colors.inkSecondary)
            Text(detail, style = text(17.sp, FontWeight.SemiBold, 22.sp), color = colors.ink)
        }
    }
}

// MARK: - Ta première leçon : le récit

/** Une page du récit (`OnbStoryStage`) : le titre, un panneau, « Continuer ». */
@Composable
fun StoryStage(title: String, model: OnboardingModel, cta: String? = null, ctaIcon: ImageVector? = null, panel: @Composable () -> Unit) {
    OnbScreen(
        centered = true,
        header = { V3Title(title, Modifier.padding(top = 16.dp)) },
        body = { panel() },
        footer = { MicaboButton(cta ?: t("common.continue"), onClick = { model.advance() }, icon = ctaIcon, modifier = Modifier.testTag("cta")) },
    )
}

@Composable
fun StoryCreateStep(model: OnboardingModel) {
    val colors = Micabo.colors
    StoryStage(t("ios.onb15.story.create.title"), model, cta = t("ios.onb14.story.create.cta"), ctaIcon = Icons.Rounded.AutoAwesome) {
        Panel {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(OnbSource.PDF, OnbSource.PHOTO).forEach { source ->
                    val tone = source.tone()
                    Row(
                        Modifier.heightIn(min = 44.dp).clip(CircleShape).background(wash(tone)).padding(horizontal = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Icon(source.icon, null, tint = tone, modifier = Modifier.size(22.dp))
                        Text(t(source.titleKey), style = text(15.sp, FontWeight.SemiBold), color = colors.ink)
                        Icon(Icons.Rounded.CheckCircle, null, tint = colors.green, modifier = Modifier.size(16.dp))
                    }
                }
            }
            Text(
                t(model.story.questionKey),
                style = Type.body,
                color = colors.ink,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 110.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(colors.canvas)
                    .border(2.dp, colors.accent, RoundedCornerShape(16.dp))
                    .padding(16.dp),
            )
        }
    }
}

@Composable
fun StoryPathStep(model: OnboardingModel) {
    val colors = Micabo.colors
    val compact = LocalCompact.current
    val story = model.story
    val nodes = listOf(
        Triple(MicaboIcons.scroll, colors.iconBlue, t(story.node1Key)),
        Triple(MicaboIcons.flag, colors.iconPink, t(story.node2Key)),
        Triple(MicaboIcons.quiz, colors.iconGreen, t("lesson.nav.quiz")),
        Triple(MicaboIcons.cards, colors.iconLilac, t("lesson.nav.flashcards")),
        Triple(MicaboIcons.alarm, colors.iconYellow, t("ios.onb14.story.node.review")),
    )
    StoryStage(t("ios.onb15.story.path.title"), model) {
        Panel {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(MicaboIcons.book, null, tint = colors.accentBright, modifier = Modifier.size(26.dp))
                Text(t(story.lessonKey), style = display(24.sp), color = colors.ink)
            }
            LeftToRight {
                // Le chemin en zigzag : chaque étape à sa hauteur (un libellé long passe à la
                // ligne), le trait pointillé passe par le centre des pastilles.
                val centers = remember { mutableStateMapOf<Int, Offset>() }
                var origin by remember { mutableStateOf(Offset.Zero) }
                BoxWithConstraints(Modifier.fillMaxWidth().onGloballyPositioned { origin = it.positionInRoot() }) {
                    val width = maxWidth
                    Canvas(Modifier.matchParentSize()) {
                        val points = nodes.indices.mapNotNull { centers[it]?.minus(origin) }
                        if (points.size == nodes.size) {
                            val path = Path()
                            points.forEachIndexed { index, point -> if (index == 0) path.moveTo(point.x, point.y) else path.lineTo(point.x, point.y) }
                            drawPath(path, colors.accent.copy(alpha = 0.55f), style = Stroke(width = 4.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2.dp.toPx(), 9.dp.toPx()))))
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(if (compact) 10.dp else 16.dp)) {
                        nodes.forEachIndexed { index, (icon, tone, label) ->
                            Row(
                                Modifier.padding(start = width * (if (index % 2 == 0) 0.04f else 0.24f)),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                Box(
                                    Modifier
                                        .size(54.dp)
                                        .onGloballyPositioned { centers[index] = it.positionInRoot() + Offset(it.size.width / 2f, it.size.height / 2f) }
                                        .clip(CircleShape)
                                        .background(wash(tone))
                                        .border(2.5.dp, tone.copy(alpha = 0.7f), CircleShape),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Icon(icon, null, tint = tone, modifier = Modifier.size(28.dp))
                                }
                                Text(label, style = text(17.sp, FontWeight.SemiBold, 21.sp), color = if (index == 4) colors.yellow else colors.ink, modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun StoryPracticeStep(model: OnboardingModel) {
    val colors = Micabo.colors
    val compact = LocalCompact.current
    val story = model.story
    StoryStage(t("ios.onb16.story.practice.title"), model) {
        Panel(padding = 20.dp) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("${t("lesson.nav.quiz")} · ${t(story.lessonKey)}", style = Type.mention, color = colors.inkSecondary, modifier = Modifier.weight(1f))
                XpPill(10)
            }
            Text(t(story.quizKey), style = display(30.sp), color = colors.ink)
            LeftToRight {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    story.years.forEach { year ->
                        val right = year == story.rightYear
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .heightIn(min = if (compact) 50.dp else 60.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .background(if (right) colors.greenWash else colors.surfaceMuted)
                                .border(2.dp, if (right) colors.green else Color.Transparent, RoundedCornerShape(16.dp)),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(year, style = figure(28), color = if (right) colors.green else colors.ink)
                            if (right) {
                                Spacer(Modifier.width(8.dp))
                                Icon(Icons.Rounded.CheckCircle, null, tint = colors.green, modifier = Modifier.size(22.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun StoryAskStep(model: OnboardingModel) {
    val colors = Micabo.colors
    val story = model.story
    StoryStage(t("ios.onb16.story.ask.title"), model) {
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.fillMaxWidth().padding(start = 44.dp), contentAlignment = Alignment.CenterEnd) {
                Text(t(story.askQuestionKey), style = Type.body, color = Color.White, modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(colors.accent).padding(horizontal = 16.dp, vertical = 13.dp))
            }
            Row(Modifier.padding(end = 8.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Mika(MikaMood.HAPPY, 40.dp)
                Text(t(story.askAnswerKey), style = Type.body, color = colors.ink, modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(colors.surface).padding(horizontal = 16.dp, vertical = 14.dp))
            }
        }
    }
}

@Composable
fun StoryCloseStep(model: OnboardingModel) =
    ChapterOpener(t("ios.onb15.story.close.title"), t("ios.onb14.story.close.title"), MikaMood.CELEBRATE, t("common.continue")) { model.advance() }

/** **« Et toi, ta première leçon, ce sera quoi ? »** Rien ne s'écrit ici : l'accueil la proposera. */
@Composable
fun FirstLessonStep(model: OnboardingModel) {
    val colors = Micabo.colors
    val choice = model.firstLessonChoice
    val subject = model.firstLessonSubject
    val bubble = when {
        choice == FirstLessonChoice.IMPORT -> t("ios.onb14.lesson.reactImport")
        choice == FirstLessonChoice.TOPIC && subject != null -> t("ios.onb10.react.lesson.topic", "topic" to subject)
        else -> t("ios.onb14.lesson.ask")
    }
    val reacted = choice == FirstLessonChoice.IMPORT || subject != null
    Question(t("ios.onb15.lesson.q"), bubble, if (reacted) MikaMood.HAPPY else MikaMood.WINK, footer = {
        MicaboButton(t("common.continue"), onClick = model::confirmFirstLesson, enabled = model.hasAnsweredFirstLesson, modifier = Modifier.testTag("cta"))
        MicaboGhostButton(t("ios.onb14.lesson.later"), onClick = model::skipFirstLesson)
    }) {
        if (choice == FirstLessonChoice.TOPIC) {
            Column(Modifier.fillMaxWidth().v3Card(selected = true, radius = V3Metric.radiusInner).padding(horizontal = 16.dp, vertical = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Icon(MicaboIcons.quill, null, tint = colors.accentBright, modifier = Modifier.size(26.dp))
                    Text(t("ios.onb14.lesson.topic"), style = Type.option, color = colors.ink, modifier = Modifier.weight(1f))
                    V3Check(true)
                }
                Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(colors.canvas).border(1.5.dp, colors.accent, RoundedCornerShape(14.dp)).padding(horizontal = 14.dp, vertical = 12.dp)) {
                    if (model.firstLessonTopic.isEmpty()) Text(t("ios.onb16.lesson.hint"), style = text(17.sp, FontWeight.SemiBold), color = colors.inkTertiary)
                    BasicTextField(
                        value = model.firstLessonTopic,
                        onValueChange = { model.firstLessonTopic = it.take(120) },
                        textStyle = text(17.sp, FontWeight.SemiBold).copy(color = colors.ink),
                        cursorBrush = SolidColor(colors.accent),
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Done),
                        modifier = Modifier.fillMaxWidth().testTag("topicField"),
                    )
                }
            }
        } else {
            V3OptionRow(t("ios.onb14.lesson.topic"), selected = false, subtitle = t("ios.onb16.lesson.hint"), icon = MicaboIcons.quill, onClick = { model.firstLessonChoice = FirstLessonChoice.TOPIC })
        }
        V3OptionRow(t("ios.onb14.lesson.import"), selected = choice == FirstLessonChoice.IMPORT, subtitle = t("ios.onb14.lesson.importHint"), icon = MicaboIcons.photo, onClick = { model.firstLessonChoice = FirstLessonChoice.IMPORT })
    }
}

// MARK: - L'essai

/** L'article du français devant un examen : « le Bac », « l'Abitur », « les A-levels » (`PaywallProfile.frenchArticled`). */
fun frenchArticled(name: String): String {
    val first = name.split(' ').firstOrNull() ?: name
    val acronym = first.length > 1 && first == first.uppercase()
    val plain = com.micabo.app.onboarding.WorldCountries.fold(first)
    if (!acronym && plain.endsWith("s") && plain != "concours") return "les $name"
    if (!acronym && plain.firstOrNull()?.let { it in "aeiouyh" } == true) return "l'$name"
    return "le $name"
}

/** **« On veut que tu essaies Micabo Pro gratuitement »** : ce que l'essai ouvre, pour lui. */
@Composable
fun FreeTrialIntroStep(model: OnboardingModel) {
    val compact = LocalCompact.current
    val french = currentLocale.language == "fr"
    val lesson = when (model.firstLessonChoice) {
        FirstLessonChoice.TOPIC -> model.firstLessonSubject?.let { t("ios.onb12.trial.unlock.lesson", "topic" to it) } ?: t("ios.pay11.row.lessons")
        FirstLessonChoice.IMPORT -> t("ios.onb12.trial.unlock.import")
        null -> t("ios.pay11.row.lessons")
    }
    val mika = model.focusSubject?.let { t("ios.onb12.trial.unlock.mika", "subject" to SubjectDisplay.subject(it, appLanguageCode)) } ?: t("ios.pay11.row.mika")
    val exam = model.datedExam?.let { examTitle(it.first) }?.let { t("ios.onb12.trial.unlock.exam", "exam" to if (french) frenchArticled(it) else it) } ?: t("ios.pay11.row.exams")
    OnbScreen(
        centered = true,
        header = { V3Title(t("ios.onb12.trial.wantTitle"), Modifier.padding(top = 16.dp)) },
        body = {
            Column(verticalArrangement = Arrangement.spacedBy(if (compact) 20.dp else 28.dp)) {
                IconLine(MicaboIcons.book, lesson)
                IconLine(MicaboIcons.mika, mika)
                IconLine(MicaboIcons.exam, exam)
            }
        },
        footer = {
            Reassurance(t("ios.pay10.nothingToday"))
            MicaboButton(t("common.continue"), onClick = { model.advance() }, modifier = Modifier.testTag("cta"))
        },
    )
}

/**
 * **« On t'enverra un rappel avant la fin de ton essai »** : la frise d'aujourd'hui à la fin,
 * aux mêmes dates que le paywall (`TrialDates`). Le rappel n'est promis qu'une fois permis.
 */
@Composable
fun TrialOfferStep(model: OnboardingModel, host: OnboardingHost, now: Long = System.currentTimeMillis(), previewPermission: Boolean? = null) {
    val context = LocalContext.current
    var permission by remember { mutableStateOf(previewPermission ?: NotificationAsk.granted(context).takeIf { it }) }
    var asked by remember { mutableStateOf(false) }
    val days = host.trialDays
    val promises = permission != false && TrialDates.reminder(now, days) != null
    val ask = rememberNotificationAsk { granted ->
        permission = granted
        asked = true
        host.track("onboarding_trial_reminder", mapOf("granted" to granted))
        model.advance()
    }
    val locale = currentLocale
    val end = TrialDates.dayText(TrialDates.end(now, days), locale)
    val reminder = TrialDates.reminder(now, days)?.let { TrialDates.dayText(it, locale) } ?: end
    OnbScreen(
        centered = true,
        header = { V3Title(t(if (promises) "ios.onb12.trial.remindTitle" else "ios.onb12.trialOffer.anytime"), Modifier.padding(top = 16.dp)) },
        body = {
            TrialTimeline(
                listOf(
                    Milestone(MicaboIcons.unlock, t("ios.onb5.trial.today"), t("ios.onb14.trial.today"), current = true),
                    Milestone(MicaboIcons.bell, t("ios.onb7.trial.reminder", "date" to reminder), t(if (promises) "ios.paywall.step.reminderDetail" else "ios.onb5.trial.reminderOff"), current = false),
                    Milestone(MicaboIcons.star, t("ios.onb7.trial.billing", "date" to end), t("ios.onb7.trial.billingDetail"), current = false),
                ),
            )
        },
        footer = {
            when (permission) {
                true -> {
                    Reassurance(t("ios.onb12.trial.granted"))
                    MicaboButton(t("common.continue"), onClick = { model.advance() }, modifier = Modifier.testTag("cta"))
                }
                false -> {
                    Reassurance(t("ios.onb12.trial.denied"))
                    MicaboButton(t("common.continue"), onClick = { model.advance() }, modifier = Modifier.testTag("cta"))
                }
                null -> MicaboButton(t("ios.onb12.trial.enable"), onClick = ask, modifier = Modifier.testTag("cta"))
            }
        },
    )
}

data class Milestone(val icon: ImageVector, val title: String, val detail: String, val current: Boolean)

@Composable
fun TrialTimeline(milestones: List<Milestone>) {
    val colors = Micabo.colors
    Column(Modifier.padding(horizontal = 6.dp)) {
        milestones.forEachIndexed { index, milestone ->
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                val tint = if (milestone.current) colors.accentBright else colors.yellow
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    IconTile(milestone.icon, tint, size = 46.dp, iconSize = 22.dp, radius = 23.dp)
                    if (index < milestones.lastIndex) Box(Modifier.width(2.dp).height(34.dp).background(colors.stroke))
                }
                Column(Modifier.weight(1f).padding(top = 10.dp, bottom = if (index < milestones.lastIndex) 22.dp else 0.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(milestone.title, style = text(20.sp, FontWeight.Bold, 25.sp), color = colors.ink)
                    Text(milestone.detail, style = Type.detail, color = colors.ink)
                }
            }
        }
    }
}
