package com.micabo.app.ui.streak

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.micabo.app.R
import com.micabo.app.data.StreakDay
import com.micabo.app.data.StreakStatus
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import java.text.SimpleDateFormat
import java.util.Locale

/** **La pastille de la série** (`StreakPill`) : la flamme et le nombre de jours, en haut de l'accueil. */
@Composable
fun StreakPill(onClick: () -> Unit) {
    val app = LocalApp.current
    val colors = Micabo.colors
    val status by app.streak.status.collectAsState()
    val lit = status.studiedToday
    Pressable(onClick = onClick) {
        Row(
            Modifier
                .clip(RoundedCornerShape(50))
                .background(if (lit) colors.cautionSoft else colors.surface)
                .border(1.5.dp, if (lit) colors.flame.copy(alpha = 0.45f) else colors.stroke, RoundedCornerShape(50))
                .padding(start = 8.dp, end = 14.dp, top = 5.dp, bottom = 5.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon3D("flamme", 28.dp, Modifier.graphicsLayer { alpha = if (lit) 1f else 0.45f })
            Spacer(Modifier.width(4.dp))
            Text(status.current.toString(), style = nunito(18.sp, FontWeight.Black), color = if (lit) colors.flame else colors.inkSecondary)
        }
    }
}

/** La semaine, jour par jour : une pastille cochée pour chaque jour joué. */
@Composable
fun StreakWeek(days: List<StreakDay>) {
    val colors = Micabo.colors
    val letter = remember { SimpleDateFormat("EEEEE", Locale.getDefault()) }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        days.forEach { day ->
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    letter.format(day.date).uppercase(),
                    style = nunito(13.sp, FontWeight.ExtraBold),
                    color = if (day.isToday) colors.flame else colors.inkTertiary,
                )
                Spacer(Modifier.height(6.dp))
                Box(
                    Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .background(
                            when {
                                day.studied -> colors.flame
                                day.isToday -> colors.cautionSoft
                                else -> colors.surfaceSunken
                            },
                        )
                        .border(2.dp, if (day.isToday && !day.studied) colors.flame.copy(alpha = 0.5f) else androidx.compose.ui.graphics.Color.Transparent, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    if (day.studied) Icon(Icons.Filled.Check, null, tint = colors.onInk, modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}

/** « 3 jours de suite », ou « Pas encore de série ». */
@Composable
private fun StreakHeadline(status: StreakStatus) {
    val colors = Micabo.colors
    if (status.current == 0) {
        Text(stringResource(R.string.ios_streak_zeroTitle), style = nunito(26.sp, FontWeight.Black), color = colors.ink, textAlign = TextAlign.Center)
    } else {
        Text(status.current.toString(), style = nunito(64.sp, FontWeight.Black, lineHeight = 66.sp), color = colors.flame)
        Text(pluralStringResource(R.plurals.ios_streak_unit, status.current, status.current), style = nunito(20.sp, FontWeight.ExtraBold), color = colors.ink)
    }
}

/** La phrase du jour : déjà fait, ou à faire pour garder (ou allumer) la flamme. */
@Composable
private fun todayLine(status: StreakStatus): String = stringResource(
    when {
        status.studiedToday -> R.string.ios_streak_todayDone
        status.current > 0 -> R.string.ios_streak_todayPending
        else -> R.string.ios_streak_startPending
    },
)

/** **La fenêtre de la série** (`StreakSheet`) : la flamme, la semaine, le record. */
@Composable
fun StreakSheet(onDismiss: () -> Unit, onStudy: () -> Unit) {
    val app = LocalApp.current
    val colors = Micabo.colors
    val status by app.streak.status.collectAsState()
    val week = remember(status) { app.streak.week() }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier
                .padding(16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(colors.canvas)
                .padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(stringResource(R.string.ios_streak_title), style = nunito(15.sp, FontWeight.ExtraBold), color = colors.inkSecondary)
            Spacer(Modifier.height(10.dp))
            Icon3D("flamme", 84.dp, Modifier.graphicsLayer { alpha = if (status.studiedToday) 1f else 0.5f })
            StreakHeadline(status)
            Spacer(Modifier.height(8.dp))
            Text(todayLine(status), style = nunito(15.sp, FontWeight.SemiBold, lineHeight = 21.sp), color = colors.inkSecondary, textAlign = TextAlign.Center)
            Spacer(Modifier.height(18.dp))
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(22.dp))
                    .background(colors.surface)
                    .border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp))
                    .padding(16.dp),
            ) {
                Text(stringResource(R.string.ios_streak_week), style = nunito(15.sp, FontWeight.ExtraBold), color = colors.ink)
                Spacer(Modifier.height(12.dp))
                StreakWeek(week)
                Spacer(Modifier.height(14.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon3D("trophee", 26.dp)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.ios_streak_bestLabel), style = nunito(15.sp, FontWeight.Bold), color = colors.inkSecondary, modifier = Modifier.weight(1f))
                    Text(pluralStringResource(R.plurals.ios_streak_bestValue, status.best, status.best), style = nunito(15.sp, FontWeight.ExtraBold), color = colors.ink)
                }
            }
            Spacer(Modifier.height(18.dp))
            if (status.studiedToday) {
                MicaboButton(stringResource(R.string.ios_streak_continue), onClick = onDismiss, color = colors.flame)
            } else {
                MicaboButton(stringResource(R.string.ios_streak_study), onClick = onStudy, color = colors.flame)
                TextButton(onClick = onDismiss) {
                    Text(stringResource(R.string.ios_streak_close), style = nunito(15.sp, FontWeight.Bold), color = colors.inkSecondary)
                }
            }
        }
    }
}

/** **Le panneau du profil** : la série, la semaine et ce qu'il reste pour battre le record. */
@Composable
fun StreakPanel() {
    val app = LocalApp.current
    val colors = Micabo.colors
    val status by app.streak.status.collectAsState()
    val week = remember(status) { app.streak.week() }
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(24.dp))
            .padding(18.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon3D("flamme", 52.dp, Modifier.graphicsLayer { alpha = if (status.studiedToday) 1f else 0.5f })
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    pluralStringResource(R.plurals.ios_profile_streakDays, status.current, status.current),
                    style = nunito(21.sp, FontWeight.Black),
                    color = colors.ink,
                )
                Text(
                    when {
                        status.current == 0 -> stringResource(R.string.ios_profile_streakStart)
                        status.current >= status.best -> stringResource(R.string.ios_profile_streakBest)
                        else -> stringResource(R.string.ios_profile_streakToBeat, status.best.toString(), (status.best - status.current + 1).toString())
                    },
                    style = nunito(14.sp, FontWeight.SemiBold, lineHeight = 19.sp),
                    color = colors.inkSecondary,
                )
            }
        }
        Spacer(Modifier.height(16.dp))
        StreakWeek(week)
    }
}

/**
 * **La célébration** (`StreakCelebrationView`) : la première étape du jour allume la flamme.
 * Elle s'affiche une fois par jour, au retour sur le chemin ou l'accueil.
 */
@Composable
fun StreakCelebration(status: StreakStatus, onDismiss: () -> Unit) {
    val colors = Micabo.colors
    val pop = remember { Animatable(0.3f) }
    LaunchedEffect(Unit) { pop.animateTo(1f, spring(dampingRatio = 0.45f, stiffness = 220f)) }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier
                .padding(20.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(30.dp))
                .background(colors.canvas)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon3D("flamme", 120.dp, Modifier.graphicsLayer { scaleX = pop.value; scaleY = pop.value })
            }
            Text(status.current.toString(), style = nunito(72.sp, FontWeight.Black, lineHeight = 74.sp), color = colors.flame)
            Text(pluralStringResource(R.plurals.ios_streak_unit, status.current, status.current), style = nunito(21.sp, FontWeight.ExtraBold), color = colors.ink)
            Spacer(Modifier.height(10.dp))
            Text(
                stringResource(
                    when {
                        status.current <= 1 -> R.string.ios_streak_celebrate_first
                        status.current >= status.best -> R.string.ios_streak_celebrate_record
                        else -> R.string.ios_streak_celebrate_line
                    },
                ),
                style = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp),
                color = colors.inkSecondary,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(14.dp))
            Mika(MikaMood.CELEBRATE, 90.dp)
            Spacer(Modifier.height(14.dp))
            MicaboButton(stringResource(R.string.ios_streak_continue), onClick = onDismiss, color = colors.flame)
        }
    }
}
