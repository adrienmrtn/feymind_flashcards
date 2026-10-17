package com.micabo.app.ui.exams

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.ApiException
import com.micabo.app.data.ExamGrade
import com.micabo.app.data.MockResult
import com.micabo.app.data.Paper
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboSecondaryButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.home.errorMessage
import com.micabo.app.ui.lesson.QuestionCard
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.text.plainText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

private val DURATIONS = listOf(15, 30, 45, 60)

/**
 * **L'examen blanc** (`MockExamFlow`) : la durée et les leçons, puis Mika écrit une copie neuve
 * au format de l'examen ; le chrono tourne, les réponses restent cachées ; à la fin, la note au
 * barème du pays, leçon par leçon, et le corrigé. Le premier est offert, puis Pro.
 */
@Composable
fun MockExamScreen(examId: String?) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val scope = rememberCoroutineScope()
    val haptics = rememberHaptics()
    val isPro by app.billing.isPro.collectAsState()
    val exam = remember(examId) { app.exams.exam(examId) }
    var phase by remember { mutableStateOf("setup") }
    var paper by remember { mutableStateOf<Paper?>(null) }
    var failure by remember { mutableStateOf<Throwable?>(null) }
    var result by remember { mutableStateOf<MockResult?>(null) }
    val answers = remember { mutableStateMapOf<Int, Boolean>() }
    val picked = remember { mutableStateMapOf<Int, Int>() }

    fun begin(lessonIds: List<String>, minutes: Int) {
        if (!isPro && app.prefs.mockFreeUsed) {
            navigator.push(Screen.Paywall("pro_required"))
            return
        }
        phase = "writing"
        failure = null
        scope.launch {
            try {
                val written = app.lessons.examPaper(exam?.name ?: "", exam, lessonIds, minutes)
                if (!isPro) app.prefs.mockFreeUsed = true
                answers.clear()
                picked.clear()
                paper = written
                haptics.success()
                phase = "running"
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (error: Throwable) {
                if (error is ApiException && error.opensPaywall) {
                    app.prefs.mockFreeUsed = true
                    phase = "setup"
                    navigator.push(Screen.Paywall("pro_required"))
                } else {
                    failure = error
                    phase = "failed"
                }
            }
        }
    }

    AnimatedContent(targetState = phase, transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(180)) }, label = "mock") { shown ->
        when (shown) {
            "setup" -> Setup(exam?.name, exam?.lessonIds.orEmpty(), showsFree = !isPro && !app.prefs.mockFreeUsed, onClose = { navigator.back() }, onBegin = ::begin)
            "writing" -> Writing()
            "failed" -> Failed(failure, onRetry = { phase = "setup" }, onClose = { navigator.back() })
            "running" -> paper?.let { current ->
                Running(current, answers, picked, onQuit = { navigator.back() }, onSubmit = { seconds ->
                    val graded = current.result(answers.toMap(), seconds)
                    app.exams.record(graded)
                    app.streak.record()
                    result = graded
                    phase = "result"
                })
            }
            else -> {
                val current = paper
                val graded = result
                if (current != null && graded != null) Result(current, graded, answers, picked, onDone = { navigator.back() })
            }
        }
    }
}

@Composable
private fun Setup(examName: String?, examLessons: List<String>, showsFree: Boolean, onClose: () -> Unit, onBegin: (List<String>, Int) -> Unit) {
    val app = LocalApp.current
    val colors = Micabo.colors
    val lessons by app.lessons.lessons.collectAsState()
    val ready = remember(lessons) { lessons.values.filter { it.readyThemes > 0 }.sortedByDescending { maxOf(it.openedAt, it.createdAt) } }
    var minutes by remember { mutableIntStateOf(30) }
    var chosen by remember {
        mutableStateOf(examLessons.filter { id -> ready.any { it.id == id } }.toSet().ifEmpty { ready.take(1).map { it.id }.toSet() })
    }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) { CloseButton(onClick = onClose) }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Icon3D("sablier", 72.dp)
            Text(examName?.ifBlank { null } ?: stringResource(R.string.lesson_exam_mockTitle), style = nunito(30.sp, FontWeight.Black, lineHeight = 34.sp), color = colors.ink)
            Text(stringResource(R.string.lesson_exam_setupBody), style = nunito(16.sp, FontWeight.Medium, lineHeight = 22.sp), color = colors.inkSecondary)
            Text(stringResource(R.string.lesson_exam_duration), style = nunito(15.sp, FontWeight.ExtraBold), color = colors.inkSecondary, modifier = Modifier.padding(top = 8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                DURATIONS.forEach { value ->
                    val on = value == minutes
                    Pressable(onClick = { minutes = value }, modifier = Modifier.weight(1f)) {
                        Column(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(16.dp))
                                .background(if (on) colors.accent else colors.surface)
                                .border(1.5.dp, if (on) colors.accent else colors.stroke, RoundedCornerShape(16.dp))
                                .padding(vertical = 12.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text(value.toString(), style = nunito(22.sp, FontWeight.Black), color = if (on) colors.onInk else colors.ink)
                            Text(stringResource(R.string.ios_minutesShort), style = nunito(12.sp, FontWeight.Bold), color = if (on) colors.onInk else colors.inkSecondary)
                        }
                    }
                }
            }
            Text(stringResource(R.string.lesson_exam_questionCount, Paper.questionCount(minutes).toString()), style = nunito(14.sp, FontWeight.Bold), color = colors.inkSecondary)
            Text(stringResource(R.string.lesson_exam_lessons), style = nunito(15.sp, FontWeight.ExtraBold), color = colors.inkSecondary, modifier = Modifier.padding(top = 8.dp))
            if (ready.isEmpty()) NoLessons()
            ready.forEach { lesson ->
                val on = lesson.id in chosen
                Pressable(onClick = {
                    chosen = if (on) chosen - lesson.id else if (chosen.size < 8) chosen + lesson.id else chosen
                }) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(18.dp))
                            .background(if (on) colors.accentWash else colors.surface)
                            .border(2.dp, if (on) colors.accent else colors.stroke, RoundedCornerShape(18.dp))
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon3D(lesson.icon, 34.dp)
                        Spacer(Modifier.width(12.dp))
                        Text(plainText(lesson.title), style = nunito(16.sp, FontWeight.Bold), color = colors.ink, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                        if (on) Icon(Icons.Filled.Check, null, tint = colors.accent, modifier = Modifier.size(20.dp))
                    }
                }
            }
            Column(
                Modifier
                    .padding(top = 8.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(colors.surface)
                    .border(1.5.dp, colors.stroke, RoundedCornerShape(20.dp))
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                listOf(R.string.lesson_exam_rule_timer to "reveil", R.string.lesson_exam_rule_hidden to "cadenas", R.string.lesson_exam_rule_grade to "diplome").forEach { (rule, icon) ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon3D(icon, 28.dp)
                        Spacer(Modifier.width(10.dp))
                        Text(stringResource(rule), style = nunito(14.sp, FontWeight.SemiBold, lineHeight = 19.sp), color = colors.ink)
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }
        Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            if (showsFree) {
                Text(stringResource(R.string.lesson_exam_freeOne), style = nunito(14.sp, FontWeight.Bold), color = colors.correctInk)
                Spacer(Modifier.height(8.dp))
            }
            MicaboButton(stringResource(R.string.lesson_exam_begin), enabled = chosen.isNotEmpty(), onClick = { onBegin(chosen.toList(), minutes) })
        }
    }
}

@Composable
private fun Writing() {
    val colors = Micabo.colors
    Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(1f))
        Mika(MikaMood.THINK, 160.dp)
        Spacer(Modifier.height(16.dp))
        Text(stringResource(R.string.lesson_exam_writing), style = nunito(24.sp, FontWeight.Black), color = colors.ink, textAlign = TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Text(stringResource(R.string.lesson_exam_writingSub), style = nunito(16.sp, FontWeight.Medium), color = colors.inkSecondary, textAlign = TextAlign.Center)
        Spacer(Modifier.height(16.dp))
        CircularProgressIndicator(color = colors.accent)
        Spacer(Modifier.weight(1.4f))
    }
}

@Composable
private fun Failed(error: Throwable?, onRetry: () -> Unit, onClose: () -> Unit) {
    val colors = Micabo.colors
    Column(Modifier.fillMaxSize().navigationBarsPadding().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(1f))
        Mika(MikaMood.SAD, 140.dp)
        Spacer(Modifier.height(16.dp))
        Text(stringResource(R.string.lesson_exam_failed), style = nunito(22.sp, FontWeight.Black), color = colors.ink, textAlign = TextAlign.Center)
        if (error != null) {
            Spacer(Modifier.height(8.dp))
            Text(errorMessage(error), style = nunito(15.sp, FontWeight.Medium), color = colors.inkSecondary, textAlign = TextAlign.Center)
        }
        Spacer(Modifier.weight(1f))
        MicaboButton(stringResource(R.string.lesson_path_retry), onClick = onRetry)
        Spacer(Modifier.height(10.dp))
        MicaboSecondaryButton(stringResource(R.string.lesson_create_cancel), onClick = onClose)
    }
}

@Composable
private fun Running(
    paper: Paper,
    answers: MutableMap<Int, Boolean>,
    picked: MutableMap<Int, Int>,
    onQuit: () -> Unit,
    onSubmit: (Int) -> Unit,
) {
    val colors = Micabo.colors
    val total = paper.minutes * 60
    var left by remember { mutableIntStateOf(total) }
    var index by remember { mutableIntStateOf(0) }
    var round by remember { mutableIntStateOf(0) }
    var confirmQuit by remember { mutableStateOf(false) }
    var confirmSubmit by remember { mutableStateOf(false) }
    val tone = colors.tone(2)

    LaunchedEffect(Unit) {
        while (left > 0) {
            delay(1_000)
            left -= 1
        }
        onSubmit(total)
    }
    BackHandler { confirmQuit = true }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CloseButton(onClick = { confirmQuit = true })
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.lesson_exam_questionOf, (index + 1).toString(), paper.items.size.toString()), style = nunito(14.sp, FontWeight.ExtraBold), color = colors.inkSecondary)
                Spacer(Modifier.height(4.dp))
                ProgressBar(answers.size / paper.items.size.toFloat(), color = tone.vivid, height = 8.dp)
            }
            Spacer(Modifier.width(12.dp))
            val urgent = left < total / 5
            Text(
                "%d:%02d".format(left / 60, left % 60),
                style = nunito(18.sp, FontWeight.Black),
                color = if (urgent) colors.caution else colors.ink,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (urgent) colors.cautionSoft else colors.surface)
                    .border(1.5.dp, if (urgent) colors.caution.copy(alpha = 0.4f) else colors.stroke, RoundedCornerShape(12.dp))
                    .padding(horizontal = 10.dp, vertical = 5.dp),
            )
        }
        AnimatedContent(
            targetState = index to round,
            transitionSpec = { fadeIn(tween(220)) togetherWith fadeOut(tween(160)) },
            modifier = Modifier.weight(1f),
            label = "examQuestion",
        ) { (shown, _) ->
            val item = paper.items[shown]
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp)) {
                if (shown in answers) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Check, null, tint = colors.accent, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(stringResource(R.string.lesson_exam_saved), style = nunito(14.sp, FontWeight.ExtraBold), color = colors.accent, modifier = Modifier.weight(1f))
                        TextButton(onClick = {
                            answers.remove(shown)
                            picked.remove(shown)
                            round += 1
                        }) { Text(stringResource(R.string.lesson_exam_change), style = nunito(14.sp, FontWeight.ExtraBold), color = colors.accent) }
                    }
                    Spacer(Modifier.height(8.dp))
                }
                QuestionCard(
                    question = item.question,
                    tone = tone,
                    seed = paper.id.hashCode().toLong() + shown,
                    answered = null,
                    reveal = false,
                    onAnswer = { answer ->
                        answers[shown] = answer.right
                        answer.picked?.let { picked[shown] = it } ?: picked.remove(shown)
                        if (shown < paper.items.lastIndex) index = shown + 1 else round += 1
                    },
                )
            }
        }
        Row(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            if (index > 0) {
                Box(Modifier.weight(1f)) {
                    MicaboSecondaryButton(stringResource(R.string.lesson_exam_previous), onClick = { index -= 1 })
                }
            }
            Box(Modifier.weight(1f)) {
                if (index < paper.items.lastIndex) {
                    MicaboButton(stringResource(if (index in answers) R.string.lesson_exam_next else R.string.lesson_exam_skip), onClick = { index += 1 })
                } else {
                    MicaboButton(stringResource(R.string.lesson_exam_submit), color = colors.correct, onClick = {
                        if (answers.size < paper.items.size) confirmSubmit = true else onSubmit(total - left)
                    })
                }
            }
        }
    }

    if (confirmQuit) {
        AlertDialog(
            onDismissRequest = { confirmQuit = false },
            containerColor = colors.surface,
            text = { Text(stringResource(R.string.lesson_exam_quitConfirm), style = nunito(16.sp)) },
            confirmButton = { TextButton(onClick = onQuit) { Text(stringResource(R.string.lesson_exam_quit), color = colors.wrong, style = nunito(16.sp, FontWeight.ExtraBold)) } },
            dismissButton = { TextButton(onClick = { confirmQuit = false }) { Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold)) } },
        )
    }
    if (confirmSubmit) {
        val missing = paper.items.size - answers.size
        AlertDialog(
            onDismissRequest = { confirmSubmit = false },
            containerColor = colors.surface,
            text = { Text(pluralStringResource(R.plurals.lesson_exam_submitConfirm, missing, missing), style = nunito(16.sp)) },
            confirmButton = {
                TextButton(onClick = { confirmSubmit = false; onSubmit(total - left) }) {
                    Text(stringResource(R.string.lesson_exam_submit), color = colors.accent, style = nunito(16.sp, FontWeight.ExtraBold))
                }
            },
            dismissButton = { TextButton(onClick = { confirmSubmit = false }) { Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold)) } },
        )
    }
}

@Composable
private fun Result(paper: Paper, result: MockResult, answers: Map<Int, Boolean>, picked: Map<Int, Int>, onDone: () -> Unit) {
    val app = LocalApp.current
    val colors = Micabo.colors
    val profile by app.prefs.profile.collectAsState()
    val passed = ExamGrade.passes(result.fraction)
    val wrong = remember(answers) { paper.items.indices.filter { answers[it] != true } }
    var added by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.height(20.dp))
            Mika(if (passed) MikaMood.CELEBRATE else MikaMood.IDLE, 140.dp)
            Box(
                Modifier
                    .padding(top = 10.dp)
                    .size(150.dp)
                    .clip(CircleShape)
                    .background(if (passed) colors.correctSoft else colors.wrongSoft),
                contentAlignment = Alignment.Center,
            ) {
                Text(ExamGrade.label(result.fraction, profile.country), style = nunito(38.sp, FontWeight.Black), color = if (passed) colors.correctInk else colors.wrongInk)
            }
            Spacer(Modifier.height(12.dp))
            Text(
                stringResource(if (passed) R.string.lesson_exam_passed else R.string.lesson_exam_notYet),
                style = nunito(22.sp, FontWeight.Black, lineHeight = 26.sp),
                color = colors.ink,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                "${result.correct} / ${result.total} · " + stringResource(R.string.lesson_exam_time, ((result.seconds + 59) / 60).toString(), result.minutes.toString()),
                style = nunito(15.sp, FontWeight.Bold),
                color = colors.inkSecondary,
            )
            if (result.lessons.size > 1) {
                Spacer(Modifier.height(20.dp))
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(colors.surface).border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp)).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(stringResource(R.string.lesson_exam_byLesson), style = nunito(18.sp, FontWeight.Black), color = colors.ink)
                    result.lessons.forEach { score ->
                        Column {
                            Row {
                                Text(plainText(score.title), style = nunito(14.sp, FontWeight.Bold), color = colors.ink, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text("${score.correct}/${score.total}", style = nunito(14.sp, FontWeight.ExtraBold), color = colors.inkSecondary)
                            }
                            Spacer(Modifier.height(4.dp))
                            ProgressBar(score.fraction.toFloat(), height = 8.dp, color = if (score.fraction >= 0.5) colors.correct else colors.wrong)
                        }
                    }
                }
            }
            if (wrong.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                if (added) {
                    Text(stringResource(R.string.lesson_exam_cardsAdded), style = nunito(15.sp, FontWeight.ExtraBold), color = colors.correctInk)
                } else {
                    MicaboSecondaryButton(pluralStringResource(R.plurals.lesson_exam_addCards, wrong.size, wrong.size), onClick = {
                        app.lessons.addMistakeCards(paper, wrong)
                        added = true
                    })
                }
            }
            Spacer(Modifier.height(22.dp))
            Text(stringResource(R.string.lesson_exam_corrections), style = nunito(20.sp, FontWeight.Black), color = colors.ink, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(10.dp))
            paper.items.forEachIndexed { index, item ->
                val right = answers[index] == true
                val mine = picked[index]?.let { item.question.choices.getOrNull(it) }
                Column(
                    Modifier
                        .padding(bottom = 10.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(18.dp))
                        .background(colors.surface)
                        .border(1.5.dp, if (right) colors.correct.copy(alpha = 0.4f) else colors.wrong.copy(alpha = 0.4f), RoundedCornerShape(18.dp))
                        .padding(14.dp),
                ) {
                    Row(verticalAlignment = Alignment.Top) {
                        Icon(if (right) Icons.Filled.Check else Icons.Filled.Close, null, tint = if (right) colors.correct else colors.wrong, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        RichText(item.question.prompt, style = nunito(15.sp, FontWeight.ExtraBold, lineHeight = 20.sp))
                    }
                    Spacer(Modifier.height(6.dp))
                    if (!right) {
                        Text(
                            when {
                                index !in answers -> stringResource(R.string.lesson_exam_unanswered)
                                mine != null -> stringResource(R.string.lesson_exam_yourAnswer, plainText(mine))
                                else -> stringResource(R.string.lesson_exam_unanswered)
                            },
                            style = nunito(13.sp, FontWeight.SemiBold),
                            color = colors.wrongInk,
                        )
                    }
                    Text(stringResource(R.string.lesson_exam_rightAnswer, plainText(item.question.answerText)), style = nunito(13.sp, FontWeight.SemiBold), color = colors.correctInk)
                    if (item.question.why.isNotBlank()) {
                        Spacer(Modifier.height(4.dp))
                        RichText(item.question.why, style = nunito(13.sp, FontWeight.Medium, lineHeight = 18.sp), color = colors.inkSecondary)
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }
        Box(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
            MicaboButton(stringResource(R.string.lesson_exam_done), onClick = onDone)
        }
    }
}
