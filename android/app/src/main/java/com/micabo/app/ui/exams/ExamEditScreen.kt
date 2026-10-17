package com.micabo.app.ui.exams

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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
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
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.MicaboApplication
import com.micabo.app.R
import com.micabo.app.data.Exam
import com.micabo.app.data.startOfDay
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.text.plainText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import java.util.Calendar
import java.util.TimeZone

/** Minuit UTC du même jour calendaire qu'un minuit local : la langue du sélecteur de date. */
internal fun localToUtcDay(local: Long): Long {
    val day = Calendar.getInstance().apply { timeInMillis = local }
    return Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
        clear()
        set(day.get(Calendar.YEAR), day.get(Calendar.MONTH), day.get(Calendar.DAY_OF_MONTH))
    }.timeInMillis
}

internal fun utcToLocalDay(utc: Long): Long {
    val day = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = utc }
    return Calendar.getInstance().apply {
        clear()
        set(day.get(Calendar.YEAR), day.get(Calendar.MONTH), day.get(Calendar.DAY_OF_MONTH))
    }.timeInMillis
}

/**
 * Le jour que porte chaque leçon : le plus proche des examens à venir qui la couvrent
 * (`DeckPace.deadline`), sinon aucun. Une leçon retirée d'un examen ne garde pas son jour.
 */
private fun syncExamDates(app: MicaboApplication, lessonIds: Collection<String>) {
    val today = startOfDay(System.currentTimeMillis())
    val exams = app.exams.exams.value
    lessonIds.toSet().forEach { lessonId ->
        val date = exams.filter { lessonId in it.lessonIds && it.date >= today }.minOfOrNull { it.date } ?: 0L
        if (app.lessons.lesson(lessonId)?.examDate != date) app.lessons.modify(lessonId) { it.copy(examDate = date) }
    }
}

/** **Un examen, à créer ou à modifier** : son nom, son jour, les leçons qu'il couvre. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExamEditScreen(id: String?) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val existing = remember(id) { app.exams.exam(id) }
    val lessons by app.lessons.lessons.collectAsState()
    val sorted = remember(lessons) { lessons.values.sortedByDescending { maxOf(it.openedAt, it.createdAt) } }
    var name by rememberSaveable { mutableStateOf(existing?.name.orEmpty()) }
    var chosen by remember { mutableStateOf(existing?.lessonIds?.toSet() ?: emptySet()) }
    var confirmDelete by remember { mutableStateOf(false) }
    val initial = remember { existing?.date ?: (System.currentTimeMillis() + 14L * 86_400_000L) }
    // Comme sur iPhone, pas de jour passé ; sauf celui d'un examen déjà enregistré.
    val selectable = remember {
        val first = localToUtcDay(System.currentTimeMillis())
        val kept = existing?.date?.let(::localToUtcDay)
        object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long): Boolean = utcTimeMillis >= first || utcTimeMillis == kept
        }
    }
    val state = rememberDatePickerState(initialSelectedDateMillis = localToUtcDay(initial), selectableDates = selectable)
    val canSave = name.isNotBlank() && state.selectedDateMillis != null

    Column(Modifier.fillMaxSize().statusBarsPadding().imePadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CloseButton(onClick = { navigator.back() })
            Spacer(Modifier.width(14.dp))
            Text(
                stringResource(if (existing == null) R.string.lesson_exam_new else R.string.lesson_exam_edit),
                style = nunito(22.sp, FontWeight.Black),
                color = colors.ink,
            )
        }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Label(stringResource(R.string.lesson_exam_name))
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(colors.surface)
                    .border(1.5.dp, colors.stroke, RoundedCornerShape(16.dp))
                    .padding(16.dp),
            ) {
                if (name.isEmpty()) Text(stringResource(R.string.lesson_exam_namePlaceholder), style = nunito(17.sp, FontWeight.SemiBold), color = colors.inkTertiary)
                BasicTextField(
                    value = name,
                    onValueChange = { name = it.take(80) },
                    singleLine = true,
                    textStyle = nunito(17.sp, FontWeight.Bold).copy(color = colors.ink),
                    cursorBrush = SolidColor(colors.accent),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            Spacer(Modifier.height(6.dp))
            Label(stringResource(R.string.lesson_exam_date))
            DatePicker(
                state = state,
                title = null,
                headline = null,
                showModeToggle = false,
                colors = DatePickerDefaults.colors(
                    containerColor = colors.canvas,
                    selectedDayContainerColor = colors.accent,
                    todayDateBorderColor = colors.accent,
                    todayContentColor = colors.accent,
                ),
            )
            Label(stringResource(R.string.lesson_exam_lessons))
            if (sorted.isEmpty()) NoLessons()
            sorted.forEach { lesson ->
                val on = lesson.id in chosen
                Pressable(onClick = { chosen = if (on) chosen - lesson.id else chosen + lesson.id }) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(18.dp))
                            .background(if (on) colors.accentWash else colors.surface)
                            .border(2.dp, if (on) colors.accent else colors.stroke, RoundedCornerShape(18.dp))
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon3D(lesson.icon, 36.dp)
                        Spacer(Modifier.width(12.dp))
                        Text(plainText(lesson.title), style = nunito(16.sp, FontWeight.Bold), color = colors.ink, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                        Box(
                            Modifier.size(24.dp).clip(RoundedCornerShape(7.dp)).background(if (on) colors.accent else colors.surfaceSunken),
                            contentAlignment = Alignment.Center,
                        ) {
                            if (on) Icon(Icons.Filled.Check, null, tint = colors.onInk, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
            if (existing != null) {
                TextButton(onClick = { confirmDelete = true }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                    Text(stringResource(R.string.lesson_exam_delete), style = nunito(16.sp, FontWeight.ExtraBold), color = colors.wrong)
                }
            }
            Spacer(Modifier.height(16.dp))
        }
        Box(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
            MicaboButton(
                stringResource(R.string.lesson_exam_save),
                enabled = canSave,
                onClick = {
                    val date = state.selectedDateMillis?.let(::utcToLocalDay) ?: return@MicaboButton
                    // Une leçon supprimée entre-temps ne reste pas cochée.
                    val covered = sorted.map { it.id }.filter { it in chosen }
                    val exam = (existing ?: Exam(name = name.trim(), date = date)).copy(name = name.trim(), date = date, lessonIds = covered)
                    app.exams.save(exam)
                    // Les leçons couvertes portent l'examen : leurs thèmes et leurs badges le lisent.
                    syncExamDates(app, exam.lessonIds + existing?.lessonIds.orEmpty())
                    navigator.back()
                },
            )
        }
    }

    if (confirmDelete && existing != null) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            containerColor = colors.surface,
            text = { Text(stringResource(R.string.lesson_exam_deleteConfirm), style = nunito(16.sp)) },
            confirmButton = {
                TextButton(onClick = {
                    app.exams.delete(existing.id)
                    syncExamDates(app, existing.lessonIds)
                    confirmDelete = false
                    navigator.back()
                }) { Text(stringResource(R.string.lesson_exam_delete), color = colors.wrong, style = nunito(16.sp, FontWeight.ExtraBold)) }
            },
            dismissButton = {
                TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold)) }
            },
        )
    }
}

@Composable
private fun Label(text: String) {
    Text(text, style = nunito(15.sp, FontWeight.ExtraBold), color = Micabo.colors.inkSecondary, modifier = Modifier.padding(top = 4.dp))
}
