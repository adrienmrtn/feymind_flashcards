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
import com.micabo.app.data.LessonRequest
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
    var draft by rememberSaveable { mutableStateOf("") }
    var pasting by rememberSaveable { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<Lesson?>(null) }
    val focus = LocalFocusManager.current
    val context = androidx.compose.ui.platform.LocalContext.current

    fun send() {
        val topic = draft.trim()
        if (topic.length < 2) return
        focus.clearFocus()
        draft = ""
        navigator.push(Screen.Creating(LessonRequest(topic = topic, text = "")))
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
            Composer(draft = draft, onDraft = { draft = it }, onSend = ::send)
        }
        item {
            Sources(onPaste = { pasting = true }, onLocked = { navigator.push(Screen.Paywall("import_pro")) })
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

    if (pasting) {
        PasteDialog(
            onDismiss = { pasting = false },
            onSubmit = { text ->
                pasting = false
                val instruction = draft.trim()
                draft = ""
                val pastedName = context.getString(R.string.lesson_import_pastedName)
                val body = if (instruction.isNotEmpty()) context.getString(R.string.lesson_import_instruction, instruction) + "\n\n" + text else text
                navigator.push(Screen.Creating(LessonRequest(topic = null, text = body, sourceName = pastedName)))
            },
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
private fun Composer(draft: String, onDraft: (String) -> Unit, onSend: () -> Unit) {
    val colors = Micabo.colors
    val canSend = draft.trim().length >= 2
    Column(
        Modifier
            .padding(horizontal = 20.dp, vertical = 14.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(colors.surface)
            .border(2.dp, if (canSend) colors.accent.copy(alpha = 0.5f) else colors.stroke, RoundedCornerShape(24.dp))
            .padding(18.dp)
            .animateContentSize(),
    ) {
        Box {
            if (draft.isEmpty()) {
                Text(stringResource(R.string.lesson_home_placeholder), style = nunito(19.sp, FontWeight.SemiBold), color = colors.inkTertiary)
            }
            BasicTextField(
                value = draft,
                onValueChange = { if (it.length <= 400) onDraft(it) },
                textStyle = nunito(19.sp, FontWeight.SemiBold).copy(color = colors.ink),
                cursorBrush = SolidColor(colors.accent),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Send),
                keyboardActions = androidx.compose.foundation.text.KeyboardActions(onSend = { onSend() }),
                modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp),
            )
        }
        AnimatedVisibility(visible = canSend, enter = fadeIn() + scaleIn(initialScale = 0.9f), exit = fadeOut() + scaleOut(targetScale = 0.9f)) {
            Column {
                Spacer(Modifier.height(12.dp))
                MicaboButton(stringResource(R.string.lesson_home_send), onClick = onSend, icon = Icons.AutoMirrored.Filled.ArrowForward)
            }
        }
    }
}

private data class SourceChip(val icon: String, val title: Int, val subtitle: Int, val locked: Boolean)

@Composable
private fun Sources(onPaste: () -> Unit, onLocked: () -> Unit) {
    val colors = Micabo.colors
    val chips = listOf(
        SourceChip("texte", R.string.lesson_import_text, R.string.lesson_import_textSub, false),
        SourceChip("pdf", R.string.lesson_import_pdf, R.string.lesson_import_pdfSub, true),
        SourceChip("fiche", R.string.lesson_import_photo, R.string.lesson_import_photoSub, true),
        SourceChip("reveil", R.string.lesson_import_audio, R.string.lesson_import_audioSub, true),
        SourceChip("fusee", R.string.lesson_import_youtube, R.string.lesson_import_youtubeSub, true),
    )
    LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        items(chips) { chip ->
            Pressable(onClick = { if (chip.locked) onLocked() else onPaste() }) {
                Column(
                    Modifier
                        .width(138.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(colors.surface)
                        .border(1.5.dp, colors.stroke, RoundedCornerShape(20.dp))
                        .padding(14.dp),
                ) {
                    Row(verticalAlignment = Alignment.Top) {
                        Icon3D(chip.icon, 40.dp)
                        Spacer(Modifier.weight(1f))
                        if (chip.locked) {
                            Box(Modifier.clip(CircleShape).background(colors.cautionSoft).padding(5.dp)) {
                                Icon(Icons.Filled.Lock, null, tint = colors.caution, modifier = Modifier.size(13.dp))
                            }
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(stringResource(chip.title), style = nunito(16.sp, FontWeight.ExtraBold), color = colors.ink)
                    Text(
                        stringResource(chip.subtitle),
                        style = nunito(13.sp, FontWeight.Medium, lineHeight = 17.sp),
                        color = colors.inkSecondary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
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

@Composable
private fun PasteDialog(onDismiss: () -> Unit, onSubmit: (String) -> Unit) {
    val colors = Micabo.colors
    var text by rememberSaveable { mutableStateOf("") }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier
                .padding(16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(colors.canvas)
                .padding(20.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon3D("texte", 40.dp)
                Spacer(Modifier.width(10.dp))
                Text(stringResource(R.string.lesson_import_textTitle), style = nunito(21.sp, FontWeight.Black), color = colors.ink)
            }
            Spacer(Modifier.height(14.dp))
            Box(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 180.dp, max = 320.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(colors.surface)
                    .border(1.5.dp, colors.stroke, RoundedCornerShape(18.dp))
                    .padding(14.dp),
            ) {
                if (text.isEmpty()) {
                    Text(stringResource(R.string.lesson_import_textPlaceholder), style = nunito(16.sp, FontWeight.Medium), color = colors.inkTertiary)
                }
                BasicTextField(
                    value = text,
                    onValueChange = { text = it.take(60_000) },
                    textStyle = nunito(16.sp, FontWeight.Medium, lineHeight = 22.sp).copy(color = colors.ink),
                    cursorBrush = SolidColor(colors.accent),
                    modifier = Modifier.fillMaxSize(),
                )
            }
            Spacer(Modifier.height(8.dp))
            Text(
                if (text.trim().length < 40) stringResource(R.string.x_paste_tooShort) else "${text.length} / 60 000",
                style = nunito(13.sp, FontWeight.SemiBold),
                color = colors.inkTertiary,
            )
            Spacer(Modifier.height(14.dp))
            MicaboButton(stringResource(R.string.lesson_home_send), onClick = { onSubmit(text.trim()) }, enabled = text.trim().length >= 40)
            TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold), color = colors.inkSecondary)
            }
        }
    }
}
