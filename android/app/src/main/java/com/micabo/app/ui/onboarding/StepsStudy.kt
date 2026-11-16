package com.micabo.app.ui.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.i18n.t
import com.micabo.app.onboarding.LearningGoal
import com.micabo.app.onboarding.OnboardingModel
import com.micabo.app.onboarding.ScanExercise
import com.micabo.app.onboarding.StudyMethod
import com.micabo.app.onboarding.StudyWorry
import com.micabo.app.onboarding.SubjectDisplay
import com.micabo.app.onboarding.SubjectKind
import com.micabo.app.onboarding.WeeklyStudy
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Type
import com.micabo.app.ui.theme.display
import com.micabo.app.ui.theme.text
import com.micabo.app.ui.v3.IconTile
import com.micabo.app.ui.v3.LocalCompact
import com.micabo.app.ui.v3.MicaboIcons
import com.micabo.app.ui.v3.OnbScreen
import com.micabo.app.ui.v3.Panel
import com.micabo.app.ui.v3.V3Metric
import com.micabo.app.ui.v3.V3OptionRow
import com.micabo.app.ui.v3.V3Title
import com.micabo.app.ui.v3.figure
import com.micabo.app.ui.v3.subjectTone
import com.micabo.app.ui.v3.v3Card
import com.micabo.app.ui.v3.wash

// MARK: - Ce qui coince

fun goalIcon(goal: LearningGoal): ImageVector = when (goal) {
    LearningGoal.grades -> MicaboIcons.trophy
    LearningGoal.dreamSchool -> MicaboIcons.diploma
    LearningGoal.understand -> MicaboIcons.lightbulb
    LearningGoal.faster -> MicaboIcons.rocket
    LearningGoal.ahead -> MicaboIcons.flag
    LearningGoal.passYear -> MicaboIcons.diploma
    LearningGoal.language -> MicaboIcons.language
    LearningGoal.exam -> MicaboIcons.exam
    LearningGoal.competition -> MicaboIcons.flag
    LearningGoal.lectures -> MicaboIcons.book
    LearningGoal.profession -> MicaboIcons.diploma
    LearningGoal.curiosity -> MicaboIcons.brain
    LearningGoal.other -> MicaboIcons.star
}

fun worryIcon(worry: StudyWorry): ImageVector = when (worry) {
    StudyWorry.examStress -> MicaboIcons.alarm
    StudyWorry.hardLessons -> MicaboIcons.puzzle
    StudyWorry.homework -> MicaboIcons.quill
    StudyWorry.forgetting -> MicaboIcons.brain
    StudyWorry.noStart -> MicaboIcons.rocket
    StudyWorry.motivation -> MicaboIcons.flame
}

fun weeklyIcon(value: WeeklyStudy): ImageVector = when (value) {
    WeeklyStudy.underOne -> MicaboIcons.hourglass
    WeeklyStudy.oneToThree -> MicaboIcons.book
    WeeklyStudy.threeToSix -> MicaboIcons.flame
    WeeklyStudy.overSix -> MicaboIcons.rocket
}

fun methodIcon(value: StudyMethod): ImageVector = when (value) {
    StudyMethod.rereading -> MicaboIcons.book
    StudyMethod.notes -> MicaboIcons.notes
    StudyMethod.exercises -> MicaboIcons.quill
    StudyMethod.nothingFixed -> MicaboIcons.puzzle
}

@Composable
fun GoalStep(model: OnboardingModel) {
    val hardest = model.hardestSubject
    val say = if (hardest != null) t("ios.onb16.react.hardest", "subject" to SubjectDisplay.subject(hardest, appLanguageCode)) else t("ios.onb12.say.goal")
    Question(t("ios.onb10.q.goal"), say, if (hardest != null) MikaMood.HAPPY else MikaMood.IDLE, footer = {
        ChoiceFooter(model, enabled = model.mainGoal != null)
    }) {
        LearningGoal.offered(model.tier).forEach { goal ->
            V3OptionRow(t(goal.titleKey), selected = model.mainGoal == goal, icon = goalIcon(goal), onClick = { model.chooseGoal(goal) })
        }
    }
}

@Composable
fun worryReaction(worry: StudyWorry): String = when (worry) {
    StudyWorry.examStress -> t("ios.onb16.react.worry.examStress")
    StudyWorry.hardLessons -> t("ios.onb16.react.worry.hardLessons")
    StudyWorry.homework -> t("ios.onb12.react.worry.homework")
    StudyWorry.forgetting -> t("ios.onb12.react.worry.forgetting")
    StudyWorry.noStart -> t("ios.onb12.react.worry.noStart")
    StudyWorry.motivation -> t("ios.onb16.react.worry.motivation")
}

@Composable
fun WorriesStep(model: OnboardingModel) {
    val last = model.worriesInOrder.lastOrNull()
    Question(
        t("ios.onb16.q.worries"),
        if (last == null) t("ios.onb12.say.worries") else worryReaction(last),
        when (last) {
            null -> MikaMood.LOOK
            StudyWorry.examStress -> MikaMood.WINK
            else -> MikaMood.HAPPY
        },
        footer = { MicaboButton(t("common.continue"), onClick = { model.advance() }, enabled = model.worriesInOrder.isNotEmpty(), modifier = Modifier.testTag("cta")) },
    ) {
        StudyWorry.entries.forEach { worry ->
            V3OptionRow(t("ios.onb.worry.${worry.name}"), selected = worry in model.worriesInOrder, icon = worryIcon(worry), multiple = true, onClick = { model.toggleWorry(worry) })
        }
    }
}

@Composable
fun StudyHoursStep(model: OnboardingModel) {
    Question(t("ios.onb12.q.hours"), t("ios.onb12.react.worries"), MikaMood.HAPPY, footer = {
        ChoiceFooter(model, enabled = model.weeklyStudy != null)
    }) {
        WeeklyStudy.entries.forEach { value ->
            V3OptionRow(t(value.titleKey), selected = model.weeklyStudy == value, icon = weeklyIcon(value), onClick = { model.chooseWeekly(value) })
        }
    }
}

@Composable
fun StudyMethodStep(model: OnboardingModel) {
    val hours = model.weeklyStudy
    Question(
        t("ios.onb12.q.method"),
        if (hours == null) t("ios.onb12.say.method") else t(hours.reactionKey),
        if (hours == WeeklyStudy.overSix) MikaMood.SURPRISE else if (hours == null) MikaMood.IDLE else MikaMood.HAPPY,
        footer = { ChoiceFooter(model, enabled = model.studyMethod != null) },
    ) {
        StudyMethod.entries.forEach { value ->
            V3OptionRow(t(value.titleKey), selected = model.studyMethod == value, icon = methodIcon(value), onClick = { model.chooseMethod(value) })
        }
    }
}

/** Une ligne d'icône et de texte au corps (`SolutionMapStepView`, `FreeTrialIntroStepView`). */
@Composable
fun IconLine(icon: ImageVector, text: String, tone: Color = Micabo.colors.accentBright) {
    val colors = Micabo.colors
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        IconTile(icon, tone, size = 54.dp, iconSize = 30.dp, fill = colors.surface)
        Text(com.micabo.app.ui.v3.marked(text, colors.accentBright), style = Type.body, color = colors.ink, modifier = Modifier.weight(1f))
    }
}

@Composable
fun SolutionMapStep(model: OnboardingModel) {
    val name = model.displayName.trim()
    val lines = buildList {
        model.hardestSubject?.let { add(MicaboIcons.subject(SubjectKind.of(it)) to t("ios.onb16.recap.hardest", "subject" to SubjectDisplay.subject(it, appLanguageCode))) }
        model.worriesInOrder.firstOrNull()?.let { add(worryIcon(it) to t("ios.onb10.solutions.quote", "worry" to t("ios.onb.worry.${it.name}"))) }
        model.weeklyStudy?.let { add(MicaboIcons.hourglass to t("ios.onb12.recap.hours", "hours" to t(it.titleKey))) }
        model.studyMethod?.let { add(methodIcon(it) to t(it.recapKey)) }
    }.take(3)
    OnbScreen(
        centered = true,
        header = { V3Title(if (name.isEmpty()) t("ios.onb16.recap.titleNoName") else t("ios.onb16.recap.title", "name" to name), Modifier.padding(top = 16.dp)) },
        body = { Column(verticalArrangement = Arrangement.spacedBy(24.dp)) { lines.forEach { (icon, text) -> IconLine(icon, text) } } },
        footer = { MicaboButton(t("ios.onb12.recap.cta"), onClick = { model.advance() }, modifier = Modifier.testTag("cta")) },
    )
}

// MARK: - Comment Mika t'aide

/** Une démo jouable (`OnbDemoStage`) : le bouton joue la démo, puis devient « Continuer ». */
@Composable
fun DemoStage(title: String, playLabel: String?, played: Boolean, onPlay: () -> Unit, onContinue: () -> Unit, panel: @Composable ColumnScope.() -> Unit) {
    OnbScreen(
        centered = true,
        header = { V3Title(title, Modifier.padding(top = 16.dp)) },
        // La démo est une illustration : son texte suit le réglage du téléphone jusqu'à 130 %,
        // puis garde ses proportions (sinon « Mathématiques » se casse en trois morceaux).
        body = { com.micabo.app.ui.v3.CappedFontScale { Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, content = panel) } },
        footer = {
            MicaboButton(if (played || playLabel == null) t("common.continue") else playLabel, onClick = { if (played) onContinue() else onPlay() }, modifier = Modifier.testTag("cta"))
        },
    )
}

/** **« Mika a été créé pour t'aider à organiser tes cours »** : la pile en vrac, puis rangée. */
@Composable
fun OriginStep(model: OnboardingModel, previewTidy: Boolean = false) {
    var tidy by remember { mutableStateOf(previewTidy) }
    val haptics = rememberHaptics()
    val compact = LocalCompact.current
    val colors = Micabo.colors
    val pile = listOf(
        Triple(MicaboIcons.pdf, colors.iconPink, Triple(-0.36f, -0.30f, -14f)),
        Triple(MicaboIcons.notes, colors.iconLilac, Triple(0.02f, -0.42f, 7f)),
        Triple(MicaboIcons.text, colors.iconYellow, Triple(0.36f, -0.28f, 11f)),
        Triple(MicaboIcons.audio, colors.iconGreen, Triple(-0.38f, 0.22f, -7f)),
        Triple(MicaboIcons.photo, colors.iconBlue, Triple(0.38f, 0.26f, 12f)),
    )
    DemoStage(t("ios.onb16.origin.title"), t("ios.onb16.origin.play"), tidy, onPlay = { haptics.success(); tidy = true }, onContinue = { model.advance() }) {
        Crossfade(tidy, label = "origin", modifier = Modifier.clickable(enabled = !tidy) { haptics.success(); tidy = true }) { arranged ->
            if (!arranged) {
                val side: Dp = if (compact) 250.dp else 300.dp
                val tile: Dp = if (compact) 58.dp else 70.dp
                LeftToRight {
                    Box(Modifier.size(side, side * 0.95f), contentAlignment = Alignment.Center) {
                        Mika(MikaMood.SURPRISE, if (compact) 120.dp else 150.dp)
                        pile.forEach { (icon, tone, place) ->
                            val (x, y, angle) = place
                            Box(
                                Modifier
                                    .offset(side * x, side * y)
                                    .rotate(angle)
                                    .size(tile)
                                    .clip(RoundedCornerShape(20.dp))
                                    .background(wash(tone))
                                    .border(1.5.dp, colors.stroke, RoundedCornerShape(20.dp)),
                                contentAlignment = Alignment.Center,
                            ) { Icon(icon, null, tint = tone, modifier = Modifier.size(tile * 0.5f)) }
                        }
                    }
                }
            } else {
                val subjects = model.orderedSubjects.take(4)
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Mika(MikaMood.HAPPY, if (compact) 96.dp else 124.dp)
                    Column(
                        Modifier.fillMaxWidth().offset(y = (-14).dp).v3Card(selected = true).padding(18.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text(t("ios.onb15.origin.yours"), style = display(26.sp), color = colors.ink)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            pile.forEach { (icon, tone, _) -> IconTile(icon, tone, size = 40.dp, iconSize = 22.dp, radius = 12.dp) }
                        }
                        subjects.forEach { subject ->
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Icon(MicaboIcons.subject(SubjectKind.of(subject)), null, tint = subjectTone(subject), modifier = Modifier.size(26.dp))
                                Text(SubjectDisplay.subject(subject, appLanguageCode), style = text(17.sp, FontWeight.SemiBold), color = colors.ink)
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Le titre de la leçon de démonstration : sa matière, jamais un titre inventé. */
@Composable
fun demoLessonTitle(model: OnboardingModel): String =
    model.focusSubject?.let { SubjectDisplay.subject(it, appLanguageCode) } ?: t("ios.onb11.plan.lesson")

/** **« Tes cours deviennent des leçons »** : toutes les sources entrent, une leçon sort. */
@Composable
fun LessonDemoStep(model: OnboardingModel, previewPlayed: Boolean = false) {
    var played by remember { mutableStateOf(previewPlayed) }
    val haptics = rememberHaptics()
    val compact = LocalCompact.current
    val colors = Micabo.colors
    DemoStage(t("ios.onb14.lesson.title"), t("ios.onb12.lesson.play"), played, onPlay = { haptics.success(); played = true }, onContinue = { model.advance() }) {
        SourceStrip(tile = if (compact) 50 else 58)
        Funnel(OnbSource.entries.size, played, Modifier.fillMaxWidth().height(if (compact) 40.dp else 60.dp))
        if (!played) {
            Box(
                Modifier.fillMaxWidth().heightIn(min = if (compact) 150.dp else 190.dp).dashedBorder(colors.stroke),
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Rounded.AutoAwesome, null, tint = colors.inkTertiary, modifier = Modifier.size(34.dp)) }
        } else {
            Column(Modifier.fillMaxWidth().v3Card(selected = true).padding(18.dp), verticalArrangement = Arrangement.spacedBy(if (compact) 10.dp else 14.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Icon(MicaboIcons.book, null, tint = colors.accentBright, modifier = Modifier.size(26.dp))
                    Text(demoLessonTitle(model), style = display(26.sp), color = colors.ink)
                }
                listOf(
                    Triple(MicaboIcons.notes, colors.iconBlue, t("ios.onb11.lesson.notes")),
                    Triple(MicaboIcons.quiz, colors.iconGreen, t("ios.onb11.lesson.quiz")),
                    Triple(MicaboIcons.cards, colors.iconLilac, t("ios.onb16.lesson.cards")),
                ).forEach { (icon, tone, label) ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        IconTile(icon, tone, size = 40.dp, iconSize = 22.dp, radius = 12.dp)
                        Text(label, style = text(17.sp, FontWeight.SemiBold), color = colors.ink, modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

private fun Modifier.dashedBorder(color: Color) = drawBehind {
    drawRoundRect(
        color,
        style = Stroke(width = 2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 7.dp.toPx()))),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(22.dp.toPx()),
    )
}

/** Les cinq sources qui convergent vers la leçon (`OnbFunnel`). */
@Composable
fun Funnel(count: Int, on: Boolean, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    LeftToRight {
        Canvas(modifier) {
            val path = Path()
            for (index in 0 until count) {
                val x = size.width * (index * 2 + 1) / (count * 2)
                path.moveTo(x, 4f)
                path.quadraticTo(x, size.height * 0.75f, size.width / 2, size.height - 2f)
            }
            drawPath(
                path,
                if (on) colors.accent else colors.stroke,
                style = Stroke(width = if (on) 3.dp.toPx() else 2.dp.toPx(), cap = StrokeCap.Round, pathEffect = if (on) null else PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 6.dp.toPx()))),
            )
        }
    }
}

/** **Le scanner** (lot 15) : un exercice de maths de sa classe, étape par étape. */
@Composable
fun ScanDemoStep(model: OnboardingModel, previewStage: Int? = null) {
    var stage by remember { mutableIntStateOf(previewStage ?: 0) }
    val haptics = rememberHaptics()
    val compact = LocalCompact.current
    val colors = Micabo.colors
    val exercise = ScanExercise.forTier(model.tier)
    val label = when (stage) {
        0 -> t("ios.onb12.scan.play")
        1, 2 -> t("ios.onb12.scan.next")
        else -> t("common.continue")
    }
    val captured = stage >= 1
    DemoStage(t("ios.onb16.scan.title"), label, stage >= 3, onPlay = { haptics.tap(); stage += 1 }, onContinue = { model.advance() }) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.fillMaxWidth().v3Card(), contentAlignment = Alignment.Center) {
                Viewfinder(if (captured) colors.green else colors.pink, Modifier.matchParentSize().padding(10.dp))
                Column(
                    Modifier.padding(horizontal = 20.dp, vertical = if (captured) 22.dp else if (compact) 44.dp else 64.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    LeftToRight {
                        if (exercise.problem != null) {
                            com.micabo.app.ui.v3.FitText(exercise.problem, figure(40), colors.ink)
                        } else {
                            RightTriangle(Modifier.size(240.dp, if (compact && captured) 120.dp else 150.dp))
                        }
                    }
                    if (captured) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Icon(Icons.Rounded.CheckCircle, null, tint = colors.green, modifier = Modifier.size(20.dp))
                            Text(t("ios.onb12.scan.recognized"), style = text(17.sp, FontWeight.SemiBold), color = colors.green)
                        }
                    }
                }
            }
            if (captured) {
                Panel {
                    exercise.steps.take(minOf(stage, 2)).forEachIndexed { index, (key, formula) ->
                        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                            Box(Modifier.size(30.dp).clip(CircleShape).background(colors.accent), contentAlignment = Alignment.Center) {
                                Text("${index + 1}", style = text(17.sp, FontWeight.SemiBold), color = Color.White)
                            }
                            Column(Modifier.weight(1f)) {
                                Text(t(key), style = text(17.sp, FontWeight.SemiBold), color = colors.accentBright)
                                LeftToRight { com.micabo.app.ui.v3.FitText(formula, figure(28), colors.ink) }
                            }
                        }
                    }
                    if (stage >= 3) {
                        LeftToRight {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Icon(Icons.Rounded.CheckCircle, null, tint = colors.green, modifier = Modifier.size(30.dp))
                                com.micabo.app.ui.v3.FitText(exercise.resultKey?.let { t(it) } ?: exercise.result, figure(32), colors.green)
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Le triangle rectangle de Pythagore : 6, 8, et l'hypoténuse à trouver. */
@Composable
fun RightTriangle(modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    BoxWithConstraints(modifier) {
        val w = maxWidth
        val h = maxHeight
        Canvas(Modifier.matchParentSize()) {
            val a = Offset(size.width * 0.14f, size.height * 0.82f)
            val b = Offset(size.width * 0.14f, size.height * 0.12f)
            val c = Offset(size.width * 0.86f, size.height * 0.82f)
            val path = Path().apply { moveTo(a.x, a.y); lineTo(b.x, b.y); lineTo(c.x, c.y); close() }
            drawPath(path, colors.ink, style = Stroke(width = 4.dp.toPx()))
            val mark = Path().apply { moveTo(a.x, a.y - 18f); lineTo(a.x + 18f, a.y - 18f); lineTo(a.x + 18f, a.y) }
            drawPath(mark, colors.inkSecondary, style = Stroke(width = 2.5f))
        }
        Text("6", style = figure(28), color = colors.ink, modifier = Modifier.offset(w * 0.14f - 26.dp, h * 0.42f))
        Text("8", style = figure(28), color = colors.ink, modifier = Modifier.offset(w * 0.48f, h * 0.84f))
        Text("?", style = figure(32), color = colors.accentBright, modifier = Modifier.offset(w * 0.54f, h * 0.30f))
    }
}

/** **Ce que dit la recherche** : Kestin et al., Scientific Reports, 2025. Sans logo. */
@Composable
fun ResearchStep(model: OnboardingModel) {
    val colors = Micabo.colors
    val compact = LocalCompact.current
    OnbScreen(
        centered = true,
        header = { V3Title(t("ios.onb15.research.title"), Modifier.padding(top = 16.dp)) },
        body = {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Column(Modifier.fillMaxWidth().v3Card().padding(20.dp), verticalArrangement = Arrangement.spacedBy(if (compact) 14.dp else 20.dp)) {
                    ResearchBar(t("ios.onb15.research.class"), 0.42f, "×1", strong = false)
                    ResearchBar(t("ios.onb15.research.ai"), 0.84f, t("ios.research.badge"), strong = true)
                    Text(t("ios.onb15.research.faster"), style = Type.body, color = colors.ink)
                }
                Text(t("ios.onb15.research.source"), style = Type.mention, color = colors.inkSecondary, modifier = Modifier.padding(horizontal = 4.dp))
            }
        },
        footer = { MicaboButton(t("common.continue"), onClick = { model.advance() }, modifier = Modifier.testTag("cta")) },
    )
}

@Composable
private fun ResearchBar(label: String, share: Float, badge: String, strong: Boolean) {
    val colors = Micabo.colors
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = text(17.sp, FontWeight.SemiBold), color = colors.ink)
        LeftToRight {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.weight(1f).height(30.dp)) {
                    Box(Modifier.fillMaxWidth(share).height(30.dp).clip(RoundedCornerShape(9.dp)).background(if (strong) colors.accent else colors.inkTertiary))
                }
                com.micabo.app.ui.v3.FitText(badge, figure(if (strong) 44 else 28), if (strong) colors.accentBright else colors.inkSecondary, Modifier.width(72.dp))
            }
        }
    }
}
