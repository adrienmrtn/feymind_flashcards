package com.micabo.app.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.Lesson
import com.micabo.app.data.XpRules
import com.micabo.app.data.XpStatus
import com.micabo.app.data.currentCircle
import com.micabo.app.data.pathCircles
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.lesson.circleTitle
import com.micabo.app.ui.text.plainText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone
import com.micabo.app.ui.xp.ProgressRing
import com.micabo.app.ui.xp.XpGold
import com.micabo.app.ui.xp.xpInk

/**
 * **« Aujourd'hui »** : l'anneau de l'objectif du jour, les cartes à réviser, la leçon à
 * continuer (l'ancienne carte « Reprendre », fondue ici) ; sans leçon, l'invitation à créer la
 * première.
 */
@Composable
internal fun TodayCard(
    status: XpStatus,
    hasLessons: Boolean,
    dueCards: Int,
    resume: Lesson?,
    onReview: () -> Unit,
    onContinue: (Lesson) -> Unit,
    onCreate: () -> Unit,
) {
    val colors = Micabo.colors
    Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 26.dp)) {
        Text(stringResource(R.string.kx_today_title), style = nunito(22.sp, FontWeight.Black), color = colors.ink)
        Spacer(Modifier.height(12.dp))
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(colors.surface)
                .border(1.5.dp, if (status.goalReached) XpGold.copy(alpha = 0.6f) else colors.stroke, RoundedCornerShape(24.dp)),
        ) {
            Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                ProgressRing(status.goalProgress, 64.dp, 8.dp, XpGold) {
                    Text(if (status.goalReached) "🎉" else "⚡", style = nunito(22.sp))
                }
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        stringResource(if (status.goalReached) R.string.kx_today_goalDone else R.string.kx_today_goal),
                        style = nunito(18.sp, FontWeight.ExtraBold),
                        color = colors.ink,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        stringResource(R.string.kx_today_goalProgress, minOf(status.today, XpRules.DAILY_GOAL).toString(), XpRules.DAILY_GOAL.toString()),
                        style = nunito(15.sp, FontWeight.Bold),
                        color = xpInk(),
                    )
                }
            }
            if (!hasLessons) {
                Line()
                TodayRow(icon = "fusee", title = stringResource(R.string.kx_today_first), subtitle = stringResource(R.string.kx_today_firstSub), onClick = onCreate)
            } else {
                if (dueCards > 0) {
                    Line()
                    TodayRow(icon = "cartes", title = pluralStringResource(R.plurals.kx_today_due, dueCards, dueCards), subtitle = null, onClick = onReview)
                }
                resume?.let { lesson ->
                    Line()
                    ContinueRow(lesson, onClick = { onContinue(lesson) })
                }
            }
        }
    }
}

@Composable
private fun Line() = HorizontalDivider(color = Micabo.colors.hairline, modifier = Modifier.padding(horizontal = 16.dp))

@Composable
private fun TodayRow(icon: String, title: String, subtitle: String?, onClick: () -> Unit) {
    val colors = Micabo.colors
    Pressable(onClick = onClick) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon3D(icon, 40.dp)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(title, style = nunito(16.sp, FontWeight.ExtraBold, lineHeight = 21.sp), color = colors.ink)
                if (subtitle != null) {
                    Text(subtitle, style = nunito(14.sp, FontWeight.SemiBold, lineHeight = 19.sp), color = colors.inkSecondary)
                }
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary)
        }
    }
}

/** « Continuer {leçon} » : le cercle où elle attend, et sa jauge. */
@Composable
private fun ContinueRow(lesson: Lesson, onClick: () -> Unit) {
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    val circles = remember(lesson) { lesson.pathCircles() }
    val done = circles.count { it.id in lesson.progress.done }
    val current = remember(lesson) { lesson.currentCircle() }
    val percent = if (circles.isEmpty()) 0f else done / circles.size.toFloat()
    Pressable(onClick = onClick) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(48.dp).clip(RoundedCornerShape(14.dp)).background(tone.pale), contentAlignment = Alignment.Center) {
                Icon3D(lesson.icon, 36.dp)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.kx_today_continue, plainText(lesson.title)),
                    style = nunito(16.sp, FontWeight.ExtraBold, lineHeight = 21.sp),
                    color = colors.ink,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
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
                Spacer(Modifier.height(8.dp))
                ProgressBar(percent, height = 7.dp, color = tone.vivid)
            }
            Spacer(Modifier.width(6.dp))
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = colors.inkTertiary)
        }
    }
}

/** Un outil de l'accueil : son icône sur sa teinte, son nom, une ligne. */
internal data class Tool(val icon: String, val tone: Int, val title: String, val subtitle: String, val onClick: () -> Unit)

/** **« Outils »**, une grille de deux sur deux. */
@Composable
internal fun ToolsGrid(tools: List<Tool>) {
    val colors = Micabo.colors
    Column(Modifier.padding(start = 20.dp, end = 20.dp, top = 26.dp)) {
        Text(stringResource(R.string.kx_tools_title), style = nunito(22.sp, FontWeight.Black), color = colors.ink)
        Spacer(Modifier.height(12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            tools.chunked(2).forEach { pair ->
                Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    pair.forEach { tool -> ToolTile(tool, Modifier.weight(1f).fillMaxHeight()) }
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun ToolTile(tool: Tool, modifier: Modifier) {
    val colors = Micabo.colors
    val tone = colors.tone(tool.tone)
    Pressable(onClick = tool.onClick, modifier = modifier) {
        Column(
            Modifier
                .fillMaxWidth()
                .fillMaxHeight()
                .clip(RoundedCornerShape(22.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp))
                .padding(14.dp),
        ) {
            Box(
                Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(tone.pale)
                    .border(1.5.dp, tone.vivid.copy(alpha = 0.35f), RoundedCornerShape(18.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon3D(tool.icon, 40.dp)
            }
            Spacer(Modifier.height(12.dp))
            Text(tool.title, style = nunito(16.sp, FontWeight.ExtraBold, lineHeight = 20.sp), color = colors.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(2.dp))
            Text(
                tool.subtitle,
                style = nunito(13.sp, FontWeight.SemiBold, lineHeight = 17.sp),
                color = colors.inkSecondary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
