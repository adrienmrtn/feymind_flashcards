package com.micabo.app.ui.lesson

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import com.micabo.app.data.ThemeStatus
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Eyebrow
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.components.Waiting
import com.micabo.app.ui.home.errorMessage
import com.micabo.app.data.ApiException
import com.micabo.app.data.NetworkException
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone

/** Garde le temps passé sur un écran de leçon (« X h de révision »). */
@Composable
fun TrackTime(lessonId: String) {
    val app = LocalApp.current
    DisposableEffect(lessonId) {
        val start = System.currentTimeMillis()
        onDispose { app.lessons.addTime(lessonId, (System.currentTimeMillis() - start) / 1000) }
    }
}

/**
 * **Un cercle Notes** : les notes du thème, puis sa question de fin. Le cercle est fait quand
 * la question a sa réponse.
 */
@Composable
fun NotesScreen(id: String, theme: Int) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val lessons by app.lessons.lessons.collectAsState()
    val lesson = lessons[id]
    val item = lesson?.themes?.getOrNull(theme)
    if (lesson == null || item == null) {
        LeaveWhenMissing()
        return
    }
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    val scroll = rememberScrollState()
    var answeredRight by rememberSaveable(id, theme) { mutableStateOf<Boolean?>(null) }
    var picked by rememberSaveable(id, theme) { mutableStateOf(-1) }
    val answered = answeredRight?.let { QuizAnswer(it, picked.takeIf { index -> index >= 0 }) }
    val final = item.questions.firstOrNull()
    TrackTime(id)

    fun finish() {
        app.lessons.complete(id, "notes:$theme")
        navigator.back()
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CloseButton(onClick = { navigator.back() })
            Spacer(Modifier.width(14.dp))
            val progress = if (scroll.maxValue == 0) 1f else scroll.value / scroll.maxValue.toFloat()
            ProgressBar(progress, Modifier.weight(1f), color = tone.vivid)
        }
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(scroll)
                .padding(horizontal = 20.dp),
        ) {
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Eyebrow(stringResource(R.string.lesson_notes_themeNumber, (theme + 1).toString()), tone.ink)
                    Spacer(Modifier.height(4.dp))
                    RichText(item.title, style = nunito(28.sp, FontWeight.Black, lineHeight = 32.sp), tintsKeywords = false)
                }
                Icon3D(item.icon, 72.dp)
            }
            Spacer(Modifier.height(20.dp))
            when {
                item.status == ThemeStatus.PENDING -> Waiting(stringResource(R.string.lesson_notes_writing), Modifier.fillMaxWidth())
                item.status == ThemeStatus.FAILED || item.notes == null -> FailedTheme(item.error) {
                    app.lessons.resume(id, retryFailed = true)
                }
                else -> {
                    item.notes?.let { ThemeNotesView(it, tone) }
                    if (final != null) {
                        Spacer(Modifier.height(30.dp))
                        Column(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(24.dp))
                                .background(colors.surface)
                                .border(2.dp, tone.vivid.copy(alpha = 0.4f), RoundedCornerShape(24.dp))
                                .padding(18.dp),
                        ) {
                            Text(stringResource(R.string.lesson_notes_question), style = nunito(20.sp, FontWeight.Black), color = colors.ink)
                            Spacer(Modifier.height(12.dp))
                            QuestionCard(
                                question = final,
                                tone = tone,
                                seed = (id.hashCode() + theme).toLong(),
                                answered = answered,
                                onAnswer = {
                                    picked = it.picked ?: -1
                                    answeredRight = it.right
                                },
                            )
                        }
                    }
                    Spacer(Modifier.height(24.dp))
                }
            }
        }
        if (item.status == ThemeStatus.READY && item.notes != null) {
            Box(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
                val ready = final == null || answered != null
                MicaboButton(
                    text = if (ready) stringResource(R.string.lesson_notes_finishStep) else stringResource(R.string.lesson_notes_answerToFinish),
                    enabled = ready,
                    color = colors.accent,
                    onClick = ::finish,
                )
            }
        }
    }
}

/** Une leçon supprimée pendant qu'on la lit : on revient au chemin. */
@Composable
fun LeaveWhenMissing() {
    val navigator = LocalNavigator.current
    androidx.compose.runtime.LaunchedEffect(Unit) { navigator.back() }
}

@Composable
fun FailedTheme(code: String, onRetry: () -> Unit) {
    val colors = Micabo.colors
    val error = when (code) {
        "network" -> NetworkException(Exception())
        "generic", "", "invalid" -> Exception()
        else -> ApiException(if (code == "daily_limit") 429 else 402, code, "")
    }
    Column(Modifier.fillMaxWidth().padding(vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Mika(MikaMood.SAD, 120.dp)
        Text(errorMessage(error), style = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp), color = colors.inkSecondary, textAlign = TextAlign.Center)
        AnimatedVisibility(visible = true, enter = fadeIn() + slideInVertically()) {
            MicaboButton(stringResource(R.string.lesson_path_retry), onClick = onRetry)
        }
    }
}
