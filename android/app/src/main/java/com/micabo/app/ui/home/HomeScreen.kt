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
 * **L'accueil** : la grande question, « Qu'est-ce que tu veux apprendre aujourd'hui ? », un
 * champ, un texte à coller, et les leçons de l'élève.
 */
@Composable
fun HomeScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val lessons by app.lessons.lessons.collectAsState()
    val sorted = remember(lessons) { lessons.values.sortedByDescending { maxOf(it.openedAt, it.createdAt) } }
    val composer = app.composer
    val isPro by app.billing.isPro.collectAsState()
    var deleting by remember { mutableStateOf<Lesson?>(null) }
    var full by remember { mutableStateOf(false) }
    val focus = LocalFocusManager.current

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
        contentPadding = PaddingValues(top = top + 8.dp, bottom = bottom + 32.dp),
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
                CircleIconButton(Icons.Filled.Settings, stringResource(R.string.lesson_profile_settings), onClick = { navigator.push(Screen.Settings) })
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
        item {
            Row(Modifier.padding(start = 20.dp, end = 20.dp, top = 30.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.lesson_tab_lessons), style = nunito(22.sp, FontWeight.Black), color = colors.ink)
                Spacer(Modifier.width(8.dp))
                if (sorted.isNotEmpty()) {
                    Box(Modifier.clip(CircleShape).background(colors.accentSoft).padding(horizontal = 9.dp, vertical = 2.dp)) {
                        Text(sorted.size.toString(), style = nunito(14.sp, FontWeight.ExtraBold), color = colors.accent)
                    }
                }
            }
        }
        if (sorted.isEmpty()) {
            item { EmptyLessons() }
        }
        items(sorted, key = { it.id }) { lesson ->
            LessonRow(
                lesson,
                onOpen = { navigator.push(Screen.LessonPath(lesson.id)) },
                onDelete = { deleting = lesson },
                modifier = Modifier.animateItem(),
            )
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

    deleting?.let { lesson ->
        AlertDialog(
            onDismissRequest = { deleting = null },
            title = { Text(stringResource(R.string.lesson_menu_deleteTitle), style = nunito(20.sp, FontWeight.ExtraBold)) },
            text = { Text(stringResource(R.string.lesson_menu_deleteMessage), style = nunito(16.sp)) },
            confirmButton = {
                TextButton(onClick = {
                    app.lessons.delete(lesson.id)
                    deleting = null
                }) { Text(stringResource(R.string.lesson_menu_delete), color = colors.wrong, style = nunito(16.sp, FontWeight.ExtraBold)) }
            },
            dismissButton = {
                TextButton(onClick = { deleting = null }) { Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold)) }
            },
            containerColor = colors.surface,
        )
    }
}

@Composable
private fun EmptyLessons() {
    val colors = Micabo.colors
    Column(
        Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(24.dp))
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Mika(MikaMood.SLEEP, 110.dp)
        Spacer(Modifier.height(10.dp))
        Text(stringResource(R.string.lesson_lessons_emptyTitle), style = nunito(19.sp, FontWeight.ExtraBold), color = colors.ink)
        Spacer(Modifier.height(6.dp))
        Text(
            stringResource(R.string.x_lessons_emptyBody),
            style = nunito(15.sp, FontWeight.Medium, lineHeight = 21.sp),
            color = colors.inkSecondary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun LessonRow(lesson: Lesson, onOpen: () -> Unit, onDelete: () -> Unit, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    val haptics = rememberHaptics()
    val circles = remember(lesson) { lesson.pathCircles() }
    val done = circles.count { it.id in lesson.progress.done }
    val finished = lesson.progress.finishedAt > 0
    val status = when {
        finished -> stringResource(R.string.lesson_lessons_finished)
        lesson.isWriting && lesson.readyThemes == 0 -> stringResource(R.string.lesson_path_writing)
        done == 0 -> stringResource(R.string.lesson_lessons_toOpen)
        else -> stringResource(R.string.lesson_lessons_circle, (done + 1).coerceAtMost(circles.size).toString(), circles.size.toString())
    }
    Row(
        modifier
            .padding(horizontal = 20.dp, vertical = 6.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp))
            .combinedClickable(onClick = { haptics.selection(); onOpen() }, onLongClick = { haptics.tap(); onDelete() })
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(62.dp).clip(RoundedCornerShape(18.dp)).background(tone.pale), contentAlignment = Alignment.Center) {
            Icon3D(lesson.icon, 46.dp)
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(
                plainText(lesson.title),
                style = nunito(17.sp, FontWeight.ExtraBold, lineHeight = 21.sp),
                color = colors.ink,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(4.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(status, style = nunito(14.sp, FontWeight.SemiBold), color = if (finished) colors.correctInk else colors.inkSecondary)
                if (lesson.isWriting) {
                    Spacer(Modifier.width(8.dp))
                    TypingDots(tone.vivid)
                }
            }
            Spacer(Modifier.height(8.dp))
            ProgressBar(if (circles.isEmpty()) 0f else done / circles.size.toFloat(), height = 8.dp, color = if (finished) colors.correct else tone.vivid)
        }
    }
}
