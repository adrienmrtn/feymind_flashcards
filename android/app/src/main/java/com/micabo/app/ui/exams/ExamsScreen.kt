package com.micabo.app.ui.exams

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.Exam
import com.micabo.app.data.ExamGrade
import com.micabo.app.data.MockResult
import com.micabo.app.data.daysUntil
import com.micabo.app.data.startOfDay
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.TAB_BAR_SPACE
import com.micabo.app.ui.components.CircleIconButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import java.text.DateFormat
import java.util.Date

/**
 * **L'onglet Examens** (`ExamsView`) : le prochain examen en grand, avec ses jours qui
 * restent ; ceux qui suivent ; l'examen blanc chronométré ; l'historique des copies.
 */
@Composable
fun ExamsScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val exams by app.exams.exams.collectAsState()
    val results by app.exams.results.collectAsState()
    val profile by app.prefs.profile.collectAsState()
    val today = remember { startOfDay(System.currentTimeMillis()) }
    val upcoming = remember(exams) { exams.filter { it.date >= today }.sortedBy { it.date } }
    val past = remember(exams) { exams.filter { it.date < today }.sortedByDescending { it.date } }
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = top + 16.dp, bottom = bottom + TAB_BAR_SPACE + 16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.lesson_tab_exams), style = nunito(34.sp, FontWeight.Black), color = colors.ink, modifier = Modifier.weight(1f))
                CircleIconButton(Icons.Filled.Add, stringResource(R.string.lesson_exam_new), onClick = { navigator.push(Screen.ExamEdit(null)) })
            }
        }
        val next = upcoming.firstOrNull()
        if (next == null) {
            item {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(26.dp))
                        .background(colors.surface)
                        .border(1.5.dp, colors.stroke, RoundedCornerShape(26.dp))
                        .padding(22.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon3D("examen", 80.dp)
                    Spacer(Modifier.height(10.dp))
                    Text(stringResource(R.string.lesson_exam_emptyTitle), style = nunito(21.sp, FontWeight.Black), color = colors.ink, textAlign = TextAlign.Center)
                    Spacer(Modifier.height(6.dp))
                    Text(stringResource(R.string.lesson_exam_emptyBody), style = nunito(15.sp, FontWeight.Medium, lineHeight = 21.sp), color = colors.inkSecondary, textAlign = TextAlign.Center)
                    Spacer(Modifier.height(16.dp))
                    MicaboButton(stringResource(R.string.lesson_exam_new), onClick = { navigator.push(Screen.ExamEdit(null)) }, icon = Icons.Filled.Add)
                }
            }
        } else {
            item { NextExam(next, results, profile.country, onEdit = { navigator.push(Screen.ExamEdit(next.id)) }, onMock = { navigator.push(Screen.Mock(next.id)) }) }
        }
        item { MockCard(onStart = { navigator.push(Screen.Mock(null)) }) }
        if (upcoming.size > 1) {
            item { Section(stringResource(R.string.lesson_exam_upcoming)) }
            items(upcoming.drop(1), key = { it.id }) { exam -> ExamRow(exam, onClick = { navigator.push(Screen.ExamEdit(exam.id)) }) }
        }
        if (results.isNotEmpty()) {
            item { Section(stringResource(R.string.lesson_exam_history)) }
            items(results, key = { it.id }) { result -> ResultRow(result, profile.country) }
        }
        if (past.isNotEmpty()) {
            item { Section(stringResource(R.string.lesson_exam_past)) }
            items(past, key = { it.id }) { exam -> ExamRow(exam, onClick = { navigator.push(Screen.ExamEdit(exam.id)) }) }
        }
    }
}

@Composable
private fun Section(title: String) {
    Text(title, style = nunito(21.sp, FontWeight.Black), color = Micabo.colors.ink, modifier = Modifier.padding(top = 10.dp))
}

private fun dayLabel(date: Long): String = DateFormat.getDateInstance(DateFormat.FULL).format(Date(date)).replaceFirstChar { it.uppercase() }

@Composable
private fun NextExam(exam: Exam, results: List<MockResult>, country: String, onEdit: () -> Unit, onMock: () -> Unit) {
    val colors = Micabo.colors
    val days = daysUntil(exam.date)
    val best = results.filter { it.examId == exam.id }.maxByOrNull { it.fraction }
    Pressable(onClick = onEdit) {
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(colors.tonePale[3])
                .border(1.5.dp, colors.toneVivid[3].copy(alpha = 0.35f), RoundedCornerShape(28.dp))
                .padding(22.dp),
        ) {
            Text(stringResource(R.string.lesson_exam_upNext).uppercase(), style = nunito(12.sp, FontWeight.ExtraBold).copy(letterSpacing = 1.2.sp), color = colors.toneInk[3])
            Spacer(Modifier.height(6.dp))
            Text(exam.name, style = nunito(24.sp, FontWeight.Black, lineHeight = 28.sp), color = colors.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(dayLabel(exam.date), style = nunito(14.sp, FontWeight.SemiBold), color = colors.inkSecondary)
            Spacer(Modifier.height(14.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                if (days <= 0) {
                    // Le jour même : « Aujourd'hui », pas « 0 jours restants » (`ExamHero`).
                    Text(
                        stringResource(R.string.app_exams_countdown_today).replaceFirstChar { it.uppercase() },
                        style = nunito(44.sp, FontWeight.Black, lineHeight = 48.sp),
                        color = colors.toneInk[3],
                        modifier = Modifier.weight(1f, fill = false),
                    )
                } else {
                    Text(days.toString(), style = nunito(64.sp, FontWeight.Black, lineHeight = 64.sp), color = colors.toneInk[3])
                    Spacer(Modifier.width(8.dp))
                    Text(
                        stringResource(if (days == 1) R.string.lesson_exam_dayLeft else R.string.lesson_exam_daysLeft),
                        style = nunito(18.sp, FontWeight.ExtraBold),
                        color = colors.ink,
                        modifier = Modifier.padding(bottom = 10.dp),
                    )
                }
                Spacer(Modifier.weight(1f))
                if (best != null) {
                    Column(horizontalAlignment = Alignment.End, modifier = Modifier.padding(bottom = 8.dp)) {
                        Text(ExamGrade.label(best.fraction, country), style = nunito(24.sp, FontWeight.Black), color = colors.correctInk)
                        Text(stringResource(R.string.lesson_exam_best), style = nunito(12.sp, FontWeight.Bold), color = colors.inkSecondary)
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            MicaboButton(stringResource(R.string.lesson_exam_startMock), onClick = onMock, color = colors.toneVivid[3])
        }
    }
}

@Composable
private fun MockCard(onStart: () -> Unit) {
    val colors = Micabo.colors
    Pressable(onClick = onStart) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(24.dp))
                .padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon3D("sablier", 52.dp)
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.lesson_exam_mockTitle), style = nunito(18.sp, FontWeight.ExtraBold), color = colors.ink)
                Text(stringResource(R.string.lesson_exam_mockBody), style = nunito(14.sp, FontWeight.Medium, lineHeight = 19.sp), color = colors.inkSecondary)
            }
        }
    }
}

@Composable
private fun ExamRow(exam: Exam, onClick: () -> Unit) {
    val colors = Micabo.colors
    val days = daysUntil(exam.date)
    Pressable(onClick = onClick) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(20.dp))
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.size(52.dp).clip(RoundedCornerShape(16.dp)).background(colors.cautionSoft), contentAlignment = Alignment.Center) {
                Text(if (days >= 0) days.toString() else "✓", style = nunito(20.sp, FontWeight.Black), color = colors.caution)
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(exam.name, style = nunito(17.sp, FontWeight.ExtraBold), color = colors.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(dayLabel(exam.date), style = nunito(13.sp, FontWeight.SemiBold), color = colors.inkSecondary, maxLines = 1)
            }
        }
    }
}

@Composable
private fun ResultRow(result: MockResult, country: String) {
    val colors = Micabo.colors
    val passed = ExamGrade.passes(result.fraction)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(20.dp))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(result.title, style = nunito(16.sp, FontWeight.ExtraBold), color = colors.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                "${DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(result.date))} · ${result.correct}/${result.total}",
                style = nunito(13.sp, FontWeight.SemiBold),
                color = colors.inkSecondary,
            )
        }
        Text(
            ExamGrade.label(result.fraction, country),
            style = nunito(20.sp, FontWeight.Black),
            color = if (passed) colors.correctInk else colors.wrongInk,
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .background(if (passed) colors.correctSoft else colors.wrongSoft)
                .padding(horizontal = 12.dp, vertical = 6.dp),
        )
    }
}

/** Mika, quand il n'y a pas encore de leçon à mettre dans un examen. */
@Composable
fun NoLessons() {
    val colors = Micabo.colors
    Column(Modifier.fillMaxWidth().padding(vertical = 20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Mika(MikaMood.SLEEP, 100.dp)
        Spacer(Modifier.height(8.dp))
        Text(stringResource(R.string.lesson_exam_noLessons), style = nunito(15.sp, FontWeight.SemiBold), color = colors.inkSecondary, textAlign = TextAlign.Center)
    }
}
