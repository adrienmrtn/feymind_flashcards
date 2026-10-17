package com.micabo.app.ui.lessons

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.Lesson
import com.micabo.app.data.dueCards
import com.micabo.app.data.pathCircles
import com.micabo.app.data.startOfDay
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.TAB_BAR_SPACE
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.components.TypingDots
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.text.plainText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone
import java.text.Normalizer

/** Le texte d'une recherche : sans accents ni majuscules. */
private fun folded(text: String): String =
    Normalizer.normalize(text, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase()

/** Les jours qui restent avant l'examen d'une leçon, s'il est à venir. */
fun Lesson.examDaysLeft(now: Long = System.currentTimeMillis()): Int? =
    upcomingExam(now)?.let { ((startOfDay(it) - startOfDay(now) + 3_600_000L) / 86_400_000L).toInt() }

/**
 * **L'onglet Leçons** (`CoursesListView`) : toutes les leçons, la plus récente d'abord, avec
 * une recherche dès qu'il y en a quelques-unes. Un appui long ouvre renommer et supprimer.
 */
@Composable
fun LessonsScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val lessons by app.lessons.lessons.collectAsState()
    var query by rememberSaveable { mutableStateOf("") }
    var deleting by remember { mutableStateOf<Lesson?>(null) }
    var renaming by remember { mutableStateOf<Lesson?>(null) }
    val sorted = remember(lessons) { lessons.values.sortedByDescending { maxOf(it.openedAt, it.createdAt) } }
    val shown = remember(sorted, query) {
        val needle = folded(query.trim())
        if (needle.isEmpty()) sorted else sorted.filter { folded(it.title).contains(needle) || folded(it.subject).contains(needle) }
    }
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = top + 16.dp, bottom = bottom + TAB_BAR_SPACE + 16.dp),
    ) {
        item {
            Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.lesson_tab_lessons), style = nunito(34.sp, FontWeight.Black), color = colors.ink)
                Spacer(Modifier.width(10.dp))
                if (sorted.isNotEmpty()) {
                    Box(Modifier.clip(CircleShape).background(colors.accentSoft).padding(horizontal = 10.dp, vertical = 3.dp)) {
                        Text(sorted.size.toString(), style = nunito(15.sp, FontWeight.ExtraBold), color = colors.accent)
                    }
                }
            }
        }
        if (sorted.size > 3) {
            item {
                Row(
                    Modifier
                        .padding(start = 20.dp, end = 20.dp, top = 16.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(colors.surface)
                        .border(1.5.dp, colors.stroke, RoundedCornerShape(16.dp))
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Search, null, tint = colors.inkTertiary, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(10.dp))
                    Box(Modifier.weight(1f)) {
                        if (query.isEmpty()) Text(stringResource(R.string.ios_searchCourse), style = nunito(16.sp, FontWeight.Medium), color = colors.inkTertiary)
                        BasicTextField(
                            value = query,
                            onValueChange = { query = it.take(80) },
                            singleLine = true,
                            textStyle = nunito(16.sp, FontWeight.SemiBold).copy(color = colors.ink),
                            cursorBrush = SolidColor(colors.accent),
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        }
        item { Spacer(Modifier.height(14.dp)) }
        if (sorted.isEmpty()) {
            item { EmptyLessons(onCreate = { navigator.home() }) }
        } else if (shown.isEmpty()) {
            item {
                Text(
                    stringResource(R.string.ios_libraryNoSearch),
                    style = nunito(16.sp, FontWeight.SemiBold),
                    color = colors.inkSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(24.dp),
                )
            }
        }
        items(shown, key = { it.id }) { lesson ->
            LessonRow(
                lesson,
                onOpen = { navigator.push(Screen.LessonPath(lesson.id)) },
                onRename = { renaming = lesson },
                onDelete = { deleting = lesson },
                modifier = Modifier.animateItem(),
            )
        }
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
    renaming?.let { lesson ->
        RenameDialog(lesson.title, onDismiss = { renaming = null }, onSave = { title ->
            app.lessons.rename(lesson.id, title)
            renaming = null
        })
    }
}

/** « Renommer la leçon ». */
@Composable
fun RenameDialog(current: String, onDismiss: () -> Unit, onSave: (String) -> Unit) {
    val colors = Micabo.colors
    var title by rememberSaveable { mutableStateOf(plainText(current)) }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        title = { Text(stringResource(R.string.lesson_menu_renameTitle), style = nunito(20.sp, FontWeight.ExtraBold)) },
        text = {
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(colors.canvas)
                    .border(1.5.dp, colors.stroke, RoundedCornerShape(14.dp))
                    .padding(14.dp),
            ) {
                if (title.isEmpty()) Text(stringResource(R.string.lesson_menu_renamePlaceholder), style = nunito(16.sp), color = colors.inkTertiary)
                BasicTextField(
                    value = title,
                    onValueChange = { title = it.take(120) },
                    singleLine = true,
                    textStyle = nunito(16.sp, FontWeight.SemiBold).copy(color = colors.ink),
                    cursorBrush = SolidColor(colors.accent),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Done),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(title) }, enabled = title.isNotBlank()) {
                Text(stringResource(R.string.lesson_menu_save), style = nunito(16.sp, FontWeight.ExtraBold), color = colors.accent)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold)) }
        },
    )
}

@Composable
private fun EmptyLessons(onCreate: () -> Unit) {
    val colors = Micabo.colors
    Column(
        Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(24.dp))
            .combinedClickableCompat(onCreate)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Mika(MikaMood.SLEEP, 110.dp)
        Spacer(Modifier.height(10.dp))
        Text(stringResource(R.string.lesson_lessons_emptyTitle), style = nunito(19.sp, FontWeight.ExtraBold), color = colors.ink, textAlign = TextAlign.Center)
        Spacer(Modifier.height(6.dp))
        Text(
            stringResource(R.string.lesson_lessons_emptyBody),
            style = nunito(15.sp, FontWeight.Medium, lineHeight = 21.sp),
            color = colors.inkSecondary,
            textAlign = TextAlign.Center,
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
private fun Modifier.combinedClickableCompat(onClick: () -> Unit): Modifier = combinedClickable(onClick = onClick)

/** Une leçon de la liste : son icône, où en est l'élève, les cartes à revoir, l'examen. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun LessonRow(lesson: Lesson, onOpen: () -> Unit, onRename: () -> Unit, onDelete: () -> Unit, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    val haptics = rememberHaptics()
    var menu by remember { mutableStateOf(false) }
    val circles = remember(lesson) { lesson.pathCircles() }
    val done = circles.count { it.id in lesson.progress.done }
    val finished = lesson.progress.finishedAt > 0
    val due = remember(lesson) { lesson.dueCards() }
    val examDays = remember(lesson) { lesson.examDaysLeft() }
    val status = when {
        finished -> stringResource(R.string.lesson_lessons_finished)
        lesson.isWriting && lesson.readyThemes == 0 -> stringResource(R.string.lesson_path_writing)
        done == 0 -> stringResource(R.string.lesson_lessons_toOpen)
        else -> stringResource(R.string.lesson_lessons_circle, (done + 1).coerceAtMost(circles.size).toString(), circles.size.toString())
    }
    Box(modifier) {
        Row(
            Modifier
                .padding(horizontal = 20.dp, vertical = 6.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp))
                .combinedClickable(onClick = { haptics.selection(); onOpen() }, onLongClick = { haptics.tap(); menu = true })
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
                    Text(status, style = nunito(14.sp, FontWeight.SemiBold), color = if (finished) colors.correctInk else colors.inkSecondary, maxLines = 1)
                    if (lesson.isWriting) {
                        Spacer(Modifier.width(8.dp))
                        TypingDots(tone.vivid)
                    }
                }
                if (due > 0 || examDays != null) {
                    Spacer(Modifier.height(6.dp))
                    Row {
                        if (due > 0) Badge(stringResource(R.string.lesson_lessons_due, due.toString()), colors.accentWash, colors.accent)
                        if (due > 0 && examDays != null) Spacer(Modifier.width(6.dp))
                        if (examDays != null) Badge(stringResource(R.string.lesson_lessons_examDays, examDays.toString()), colors.cautionSoft, colors.caution)
                    }
                }
                Spacer(Modifier.height(8.dp))
                ProgressBar(if (circles.isEmpty()) 0f else done / circles.size.toFloat(), height = 8.dp, color = if (finished) colors.correct else tone.vivid)
            }
        }
        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }, containerColor = colors.surface) {
            DropdownMenuItem(
                text = { Text(stringResource(R.string.lesson_menu_rename), style = nunito(16.sp, FontWeight.Bold)) },
                onClick = { menu = false; onRename() },
            )
            DropdownMenuItem(
                text = { Text(stringResource(R.string.lesson_menu_delete), style = nunito(16.sp, FontWeight.Bold), color = colors.wrong) },
                onClick = { menu = false; onDelete() },
            )
        }
    }
}

@Composable
private fun Badge(text: String, background: androidx.compose.ui.graphics.Color, ink: androidx.compose.ui.graphics.Color) {
    Text(
        text,
        style = nunito(12.sp, FontWeight.ExtraBold),
        color = ink,
        maxLines = 1,
        modifier = Modifier.clip(RoundedCornerShape(50)).background(background).padding(horizontal = 9.dp, vertical = 3.dp),
    )
}
