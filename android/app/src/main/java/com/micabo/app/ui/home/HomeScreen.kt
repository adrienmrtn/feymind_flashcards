package com.micabo.app.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.micabo.app.R
import com.micabo.app.data.Lesson
import com.micabo.app.data.LessonComposer
import com.micabo.app.data.currentCircle
import com.micabo.app.data.learnedCards
import com.micabo.app.ui.TAB_BAR_SPACE
import com.micabo.app.ui.lesson.circleTitle
import com.micabo.app.ui.streak.StreakPill
import com.micabo.app.ui.streak.StreakSheet
import com.micabo.app.data.pathCircles
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.CircleIconButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.components.TypingDots
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.text.plainText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone

/**
 * **L'accueil** (`HomeView`) : la série en haut, la grande question, la barre et ses supports,
 * les trois chiffres de l'élève et « Reprendre » sur la dernière leçon ouverte.
 */
@Composable
fun HomeScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val lessons by app.lessons.lessons.collectAsState()
    val composer = app.composer
    val isPro by app.billing.isPro.collectAsState()
    var full by remember { mutableStateOf(false) }
    var streakSheet by remember { mutableStateOf(false) }
    val focus = LocalFocusManager.current
    val stats = remember(lessons) { HomeStats.of(lessons.values) }
    val resume = remember(lessons) { lessons.values.filter { it.openedAt > 0 }.maxByOrNull { it.openedAt } }

    // La porte du gratuit, côté app (`LessonAllowance.gate`) : les imports sont Pro, et la leçon
    // offerte ne se crée qu'une fois. Le serveur tient la même porte ; celle-ci évite un appel refusé.
    fun send() {
        if (!composer.canSend) return
        focus.clearFocus()
        when {
            !isPro && composer.needsPro -> navigator.push(Screen.Paywall("import_pro"))
            !isPro && lessons.isNotEmpty() -> navigator.push(Screen.Paywall("free_limit"))
            else -> navigator.push(Screen.Creating(composer.request(examDate = null)))
        }
    }

    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = top + 8.dp, bottom = bottom + TAB_BAR_SPACE + 16.dp),
    ) {
        item {
            Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                Image(
                    painterResource(R.mipmap.ic_launcher_foreground_art),
                    contentDescription = null,
                    modifier = Modifier.size(36.dp).clip(RoundedCornerShape(10.dp)),
                )
                Spacer(Modifier.width(10.dp))
                Text(stringResource(R.string.app_name), style = nunito(24.sp, FontWeight.Black), color = colors.ink)
                Spacer(Modifier.weight(1f))
                StreakPill(onClick = { streakSheet = true })
            }
        }
        item {
            Row(Modifier.padding(start = 20.dp, end = 20.dp, top = 22.dp), verticalAlignment = Alignment.Bottom) {
                RichText(
                    stringResource(R.string.lesson_home_title),
                    style = nunito(30.sp, FontWeight.Black, lineHeight = 34.sp),
                    color = colors.ink,
                    modifier = Modifier.weight(1f),
                )
                Mika(MikaMood.IDLE, 84.dp)
            }
        }
        item {
            ComposerCard(composer, onSend = ::send)
        }
        item {
            SourceRow(composer, isPro = isPro, onFull = { full = true })
        }
        if (lessons.isNotEmpty()) {
            item { StatsCard(stats) }
        }
        resume?.let { lesson ->
            item { ResumeCard(lesson, onOpen = { navigator.push(Screen.LessonPath(lesson.id)) }) }
        }
    }

    if (full) {
        AlertDialog(
            onDismissRequest = { full = false },
            text = { Text(stringResource(R.string.lesson_home_supportsFull, LessonComposer.MAX_SUPPORTS.toString()), style = nunito(16.sp)) },
            confirmButton = { TextButton(onClick = { full = false }) { Text("OK", style = nunito(16.sp, FontWeight.ExtraBold)) } },
            containerColor = colors.surface,
        )
    }
    if (streakSheet) {
        StreakSheet(
            onDismiss = { streakSheet = false },
            onStudy = {
                streakSheet = false
                resume?.let { navigator.push(Screen.LessonPath(it.id)) }
            },
        )
    }
}

/** **Les trois chiffres de l'accueil** (`HomeStats`) : tout est mesuré, rien n'est estimé. */
data class HomeStats(val seconds: Long, val learnedLessons: Int, val learnedCards: Int) {
    companion object {
        fun of(lessons: Collection<Lesson>): HomeStats = HomeStats(
            seconds = lessons.sumOf { it.progress.seconds },
            learnedLessons = lessons.count { it.progress.finishedAt > 0 },
            learnedCards = lessons.sumOf { it.learnedCards() },
        )
    }
}

/** « 12 min » sous l'heure, « 1,5 h » sous dix heures, « 14 h » au-delà. */
@Composable
private fun formattedTime(seconds: Long): String {
    val minutes = Math.round(seconds / 60.0).toInt()
    if (minutes < 60) return stringResource(R.string.lesson_home_minutes, minutes.toString())
    val hours = seconds / 3600.0
    val value = if (hours < 10) {
        java.text.NumberFormat.getNumberInstance().apply { maximumFractionDigits = 1; minimumFractionDigits = 0 }.format(Math.round(hours * 10) / 10.0)
    } else {
        Math.round(hours).toString()
    }
    return stringResource(R.string.lesson_home_hours, value)
}

@Composable
private fun StatsCard(stats: HomeStats) {
    val colors = Micabo.colors
    Row(
        Modifier
            .padding(start = 20.dp, end = 20.dp, top = 26.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(24.dp))
            .padding(vertical = 18.dp, horizontal = 8.dp),
    ) {
        Stat("sablier", formattedTime(stats.seconds), stringResource(R.string.lesson_home_statTime), Modifier.weight(1f))
        Stat("diplome", stats.learnedLessons.toString(), stringResource(R.string.lesson_home_statLessons), Modifier.weight(1f))
        Stat("cartes", stats.learnedCards.toString(), stringResource(R.string.lesson_home_statCards), Modifier.weight(1f))
    }
}

@Composable
private fun Stat(icon: String, value: String, label: String, modifier: Modifier) {
    val colors = Micabo.colors
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Icon3D(icon, 34.dp)
        Spacer(Modifier.height(6.dp))
        Text(value, style = nunito(22.sp, FontWeight.Black), color = colors.ink, maxLines = 1)
        Text(
            label,
            style = nunito(13.sp, FontWeight.SemiBold, lineHeight = 16.sp),
            color = colors.inkSecondary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            maxLines = 2,
        )
    }
}

/** **« Reprendre »** : la dernière leçon ouverte, et le cercle où elle attend. */
@Composable
private fun ResumeCard(lesson: Lesson, onOpen: () -> Unit) {
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    val circles = remember(lesson) { lesson.pathCircles() }
    val done = circles.count { it.id in lesson.progress.done }
    val current = remember(lesson) { lesson.currentCircle() }
    val percent = if (circles.isEmpty()) 0f else done / circles.size.toFloat()
    Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 26.dp)) {
        Text(stringResource(R.string.lesson_home_resume), style = nunito(22.sp, FontWeight.Black), color = colors.ink)
        Spacer(Modifier.height(12.dp))
        Pressable(onClick = onOpen) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(24.dp))
                    .background(tone.pale)
                    .border(1.5.dp, tone.vivid.copy(alpha = 0.35f), RoundedCornerShape(24.dp))
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.size(64.dp).clip(RoundedCornerShape(18.dp)).background(colors.surface), contentAlignment = Alignment.Center) {
                    Icon3D(lesson.icon, 48.dp)
                }
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        plainText(lesson.title),
                        style = nunito(18.sp, FontWeight.ExtraBold, lineHeight = 22.sp),
                        color = tone.ink,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        if (current == null) {
                            stringResource(R.string.lesson_home_resumeDone)
                        } else {
                            stringResource(R.string.lesson_home_resumeCircle, (circles.indexOf(current) + 1).toString(), circleTitle(lesson, current))
                        },
                        style = nunito(14.sp, FontWeight.SemiBold),
                        color = colors.inkSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Spacer(Modifier.height(10.dp))
                    ProgressBar(percent, height = 8.dp, color = tone.vivid)
                }
            }
        }
    }
}
