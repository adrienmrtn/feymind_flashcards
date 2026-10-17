package com.micabo.app.ui.lesson

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.rememberCoroutineScope
import com.micabo.app.data.ApiException
import com.micabo.app.data.Question
import kotlinx.coroutines.launch
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.Lesson
import com.micabo.app.data.PathCircle
import com.micabo.app.data.pathCircles
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboSecondaryButton
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.components.Waiting
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone
import kotlin.random.Random

/**
 * Les questions d'un quiz : les questions de réserve des thèmes du palier (la première de
 * chaque thème est sa question de fin, déjà posée), mélangées, puis les questions de fin si
 * la réserve ne suffit pas.
 */
fun quizQuestions(lesson: Lesson, circle: String, seed: Long): List<Pair<Int, Question>> {
    val target = lesson.pathCircles().firstOrNull { it.id == circle }
    val themes = when (target) {
        is PathCircle.QuizCircle -> target.themes
        is PathCircle.FinalCircle -> target.themes
        else -> lesson.themes.indices.toList()
    }
    val count = when (target) {
        is PathCircle.QuizCircle -> (themes.size * 3).coerceIn(4, 8)
        is PathCircle.FinalCircle -> 10
        else -> 15
    }
    val random = Random(seed)
    val pool = themes.mapNotNull { index -> lesson.themes.getOrNull(index)?.let { index to it } }
    val reserve = pool.flatMap { (index, theme) -> theme.questions.drop(1).map { index to it } }.filter { it.second.isValid }.shuffled(random)
    val finals = pool.mapNotNull { (index, theme) -> theme.questions.firstOrNull()?.let { index to it } }.filter { it.second.isValid }.shuffled(random)
    return (reserve + finals).distinctBy { it.second.prompt }.take(count)
}

/** **Un quiz** : celui d'un palier, le quiz final, ou tout le quiz de la leçon. */
@Composable
fun QuizScreen(id: String, circle: String) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val lessons by app.lessons.lessons.collectAsState()
    val lesson = lessons[id]
    if (lesson == null) {
        LeaveWhenMissing()
        return
    }
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    val haptics = rememberHaptics()
    val seed = rememberSaveable { System.currentTimeMillis() }
    val available = lesson.readyThemes
    // Un lot de nouvelles questions remplace la série en cours (`LessonPracticeView`).
    var fresh by remember { mutableStateOf<List<Pair<Int, Question>>?>(null) }
    var round by rememberSaveable { mutableIntStateOf(0) }
    val drawn = remember(id, circle, available) { quizQuestions(lesson, circle, seed) }
    val questions = fresh ?: drawn
    var index by rememberSaveable { mutableIntStateOf(0) }
    var right by rememberSaveable { mutableIntStateOf(0) }
    var streak by rememberSaveable { mutableIntStateOf(0) }
    var answeredRight by rememberSaveable { mutableStateOf<Boolean?>(null) }
    var picked by rememberSaveable { mutableIntStateOf(-1) }
    TrackTime(id)

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CloseButton(onClick = { navigator.back() })
            Spacer(Modifier.width(14.dp))
            ProgressBar(if (questions.isEmpty()) 0f else index / questions.size.toFloat(), Modifier.weight(1f), color = tone.vivid)
            AnimatedVisibility(visible = streak >= 2, enter = scaleIn() + fadeIn(), exit = fadeOut()) {
                Text(
                    "🔥 $streak",
                    style = nunito(16.sp, FontWeight.Black),
                    color = colors.flame,
                    modifier = Modifier.padding(start = 10.dp),
                )
            }
        }
        if (questions.isEmpty()) {
            Waiting(stringResource(R.string.lesson_quiz_empty), Modifier.fillMaxSize())
        } else if (index >= questions.size) {
            Results(lesson, circle, right, questions.size, onFresh = { batch ->
                fresh = batch
                round += 1
                index = 0
                right = 0
                streak = 0
            })
        } else {
        AnimatedContent(
            targetState = index,
            transitionSpec = {
                (slideInHorizontally(tween(320)) { it / 2 } + fadeIn(tween(260))) togetherWith
                    (slideOutHorizontally(tween(320)) { -it / 2 } + fadeOut(tween(200)))
            },
            modifier = Modifier.weight(1f),
            label = "question",
        ) { shown ->
            val (theme, question) = questions[shown.coerceAtMost(questions.lastIndex)]
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 12.dp),
            ) {
                QuestionCard(
                    question = question,
                    tone = tone,
                    seed = seed + shown,
                    answered = if (shown == index) answeredRight?.let { QuizAnswer(it, picked.takeIf { p -> p >= 0 }) } else null,
                    onAnswer = { answer ->
                        picked = answer.picked ?: -1
                        answeredRight = answer.right
                        if (answer.right) {
                            right += 1
                            streak += 1
                        } else {
                            streak = 0
                            app.lessons.missed(lesson.id, theme)
                        }
                    },
                )
                Spacer(Modifier.height(24.dp))
            }
        }
        Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
            AnimatedVisibility(visible = answeredRight != null, enter = fadeIn() + slideInVertically { it }) {
                MicaboButton(
                    text = if (index == questions.lastIndex) stringResource(R.string.lesson_quiz_seeScore) else stringResource(R.string.lesson_quiz_continue),
                    color = if (answeredRight == true) colors.correct else colors.accent,
                    onClick = {
                        haptics.tap()
                        answeredRight = null
                        picked = -1
                        index += 1
                    },
                )
            }
        }
        }
    }
}

@Composable
private fun Results(lesson: Lesson, circle: String, right: Int, total: Int, onFresh: (List<Pair<Int, Question>>) -> Unit) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val isPro by app.billing.isPro.collectAsState()
    var writing by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }

    // Sans abonnement, un lot est offert ; le suivant ouvre le paywall. Le serveur tient la même
    // porte (`begin_extra`) : celle-ci évite un appel pour rien.
    fun more() {
        if (!isPro && app.prefs.practiceFreeUsed) {
            navigator.push(Screen.Paywall("pro_required"))
            return
        }
        writing = true
        failed = false
        scope.launch {
            try {
                val batch = app.lessons.practice(lesson.id)
                if (!isPro) app.prefs.practiceFreeUsed = true
                writing = false
                if (batch.isEmpty()) failed = true else {
                    haptics.success()
                    onFresh(batch)
                }
            } catch (cancel: kotlin.coroutines.cancellation.CancellationException) {
                throw cancel
            } catch (error: Throwable) {
                writing = false
                if (error is ApiException && error.opensPaywall) {
                    app.prefs.practiceFreeUsed = true
                    navigator.push(Screen.Paywall("pro_required"))
                } else {
                    failed = true
                }
            }
        }
    }

    if (writing) {
        Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.weight(1f))
            Mika(MikaMood.THINK, 160.dp)
            Spacer(Modifier.height(16.dp))
            Text(stringResource(R.string.lesson_practice_writing), style = nunito(24.sp, FontWeight.Black, lineHeight = 28.sp), color = colors.ink, textAlign = TextAlign.Center)
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.lesson_practice_writingSub), style = nunito(16.sp, FontWeight.Medium, lineHeight = 22.sp), color = colors.inkSecondary, textAlign = TextAlign.Center)
            Spacer(Modifier.height(16.dp))
            CircularProgressIndicator(color = colors.accent)
            Spacer(Modifier.weight(1.4f))
        }
        return
    }
    val percent = if (total == 0) 0 else Math.round(right * 100f / total)
    val shown by animateIntAsState(percent, tween(900), label = "percent")
    val final = circle == "final"
    LaunchedEffect(Unit) {
        haptics.success()
        if (circle.isNotEmpty()) app.lessons.complete(lesson.id, circle, listOf(right, total))
    }
    val message = when {
        percent >= 80 -> R.string.lesson_quiz_great
        percent >= 50 -> R.string.lesson_quiz_good
        else -> R.string.lesson_quiz_keepGoing
    }
    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(24.dp))
            Mika(if (percent >= 50) MikaMood.CELEBRATE else MikaMood.IDLE, 170.dp)
            Spacer(Modifier.height(10.dp))
            Text(
                if (final) stringResource(R.string.lesson_finished_title) else stringResource(message),
                style = nunito(28.sp, FontWeight.Black, lineHeight = 32.sp),
                color = colors.ink,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(20.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Stat(stringResource(R.string.lesson_finished_score), "$shown %", colors.correct, Modifier.weight(1f))
                Stat(stringResource(R.string.lesson_quiz_fullTitle), "$right / $total", colors.accent, Modifier.weight(1f))
            }
            if (final && lesson.takeaways.isNotEmpty()) {
                Spacer(Modifier.height(22.dp))
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(22.dp))
                        .background(colors.surface)
                        .border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp))
                        .padding(18.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(stringResource(R.string.lesson_conclusion_title), style = nunito(19.sp, FontWeight.Black), color = colors.ink)
                    lesson.takeaways.forEach { line ->
                        Row {
                            Icon(Icons.Filled.Check, null, tint = colors.correct, modifier = Modifier.padding(top = 3.dp).size(18.dp))
                            Spacer(Modifier.width(10.dp))
                            RichText(line, style = nunito(16.sp, FontWeight.Medium, lineHeight = 23.sp))
                        }
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
        }
        Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (final && lesson.flashcards.isNotEmpty()) {
                MicaboButton(stringResource(R.string.lesson_finished_cards), onClick = { navigator.replace(Screen.Flashcards(lesson.id)) })
                MicaboSecondaryButton(stringResource(R.string.lesson_finished_back), onClick = { navigator.home() })
            } else if (circle.isEmpty()) {
                if (failed) {
                    Text(stringResource(R.string.lesson_practice_failed), style = nunito(14.sp, FontWeight.Bold), color = colors.wrongInk, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                }
                MicaboButton(stringResource(if (failed) R.string.lesson_practice_retry else R.string.lesson_practice_more), onClick = ::more, icon = Icons.Filled.Refresh)
                MicaboSecondaryButton(stringResource(R.string.lesson_practice_back), onClick = { navigator.back() })
            } else {
                MicaboButton(stringResource(R.string.lesson_quiz_finish), onClick = { navigator.back() })
            }
        }
    }
}

@Composable
private fun Stat(label: String, value: String, color: androidx.compose.ui.graphics.Color, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    Column(
        modifier
            .clip(RoundedCornerShape(20.dp))
            .background(colors.surface)
            .border(2.dp, color.copy(alpha = 0.5f), RoundedCornerShape(20.dp))
            .padding(vertical = 16.dp, horizontal = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(label.uppercase(), style = nunito(12.sp, FontWeight.ExtraBold).copy(letterSpacing = 1.sp), color = color, textAlign = TextAlign.Center, maxLines = 1)
        Spacer(Modifier.height(6.dp))
        Text(value, style = nunito(26.sp, FontWeight.Black), color = colors.ink)
    }
}
