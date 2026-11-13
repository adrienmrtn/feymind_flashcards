package com.micabo.app.ui.xp

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.micabo.app.R
import com.micabo.app.data.XpRules
import com.micabo.app.data.XpStatus
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MikaSays
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito

/** L'or de l'XP : le même, le jour et la nuit, lisible sur son fond pâle. */
val XpGold = Color(0xFFF2B200)
private val XpGoldInkLight = Color(0xFF7A5600)
private val XpGoldInkDark = Color(0xFFF6CF5A)

/** L'encre de l'XP, sur la teinte pâle du jaune. */
@Composable
fun xpInk(): Color = if (Micabo.colors.dark) XpGoldInkDark else XpGoldInkLight

/** Le nom de la ligue, dans la langue de l'app. */
@Composable
fun leagueName(id: String): String = stringResource(
    when (id) {
        "silver" -> R.string.kx_league_silver
        "gold" -> R.string.kx_league_gold
        "sapphire" -> R.string.kx_league_sapphire
        "diamond" -> R.string.kx_league_diamond
        else -> R.string.kx_league_bronze
    },
)

/** L'emblème de la ligue, en un caractère. */
fun leagueEmoji(id: String): String = when (id) {
    "silver" -> "🥈"
    "gold" -> "🥇"
    "sapphire" -> "🔷"
    "diamond" -> "💎"
    else -> "🥉"
}

/** La couleur de la ligue, pour son anneau et sa jauge. */
fun leagueColor(id: String): Color = when (id) {
    "silver" -> Color(0xFF94A3B8)
    "gold" -> XpGold
    "sapphire" -> Color(0xFF3B82F6)
    "diamond" -> Color(0xFF8B5CF6)
    else -> Color(0xFFC2773A)
}

/** **La pastille « +10 XP »**, dans un retour de quiz ou qui monte après un gain. */
@Composable
fun XpBadge(amount: Int, modifier: Modifier = Modifier) {
    Text(
        "⚡ +$amount XP",
        style = nunito(14.sp, FontWeight.Black),
        color = xpInk(),
        maxLines = 1,
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(Micabo.colors.tonePale[0])
            .border(1.5.dp, XpGold.copy(alpha = 0.55f), RoundedCornerShape(50))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

/** **La pastille XP de l'accueil** : l'XP de la semaine et l'emblème de la ligue ; elle ouvre la ligue. */
@Composable
fun XpPill(onClick: () -> Unit) {
    val app = LocalApp.current
    val colors = Micabo.colors
    val status by app.xp.status.collectAsState()
    val league = status.league
    val description = stringResource(R.string.kx_home_xpA11y, status.week.toString(), leagueName(league.id))
    Pressable(onClick = onClick, modifier = Modifier.semantics { contentDescription = description }) {
        Row(
            Modifier
                .clip(RoundedCornerShape(50))
                .background(colors.surface)
                .border(1.5.dp, XpGold.copy(alpha = 0.5f), RoundedCornerShape(50))
                .padding(start = 10.dp, end = 12.dp, top = 7.dp, bottom = 7.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("⚡", style = nunito(16.sp, FontWeight.Black))
            Spacer(Modifier.width(3.dp))
            Text(status.week.toString(), style = nunito(17.sp, FontWeight.Black), color = xpInk())
            Spacer(Modifier.width(5.dp))
            Text(leagueEmoji(league.id), style = nunito(16.sp))
        }
    }
}

/** **La pilule « ✦ Pro »**, en dégradé de l'app : elle ouvre le paywall. */
@Composable
fun ProPill(onClick: () -> Unit) {
    val colors = Micabo.colors
    val description = stringResource(R.string.kx_home_proA11y)
    Pressable(onClick = onClick, modifier = Modifier.semantics { contentDescription = description }) {
        Text(
            "✦ Pro",
            style = nunito(16.sp, FontWeight.Black),
            color = Color.White,
            modifier = Modifier
                .clip(RoundedCornerShape(50))
                .background(Brush.linearGradient(listOf(colors.accent, colors.toneVivid[4])))
                .padding(horizontal = 14.dp, vertical = 8.dp),
        )
    }
}

/** **Un anneau** qui se remplit de 0 à 1, et ce qu'on veut en son centre. */
@Composable
fun ProgressRing(
    progress: Float,
    size: Dp,
    stroke: Dp,
    color: Color,
    modifier: Modifier = Modifier,
    track: Color = Micabo.colors.progressTrack,
    content: @Composable BoxScope.() -> Unit = {},
) {
    val animated by animateFloatAsState(progress.coerceIn(0f, 1f), tween(600, easing = FastOutSlowInEasing), label = "ring")
    Box(modifier.size(size), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val width = stroke.toPx()
            val inset = width / 2
            val arc = Size(this.size.width - width, this.size.height - width)
            drawArc(track, startAngle = -90f, sweepAngle = 360f, useCenter = false, topLeft = Offset(inset, inset), size = arc, style = Stroke(width))
            if (animated > 0f) {
                drawArc(color, startAngle = -90f, sweepAngle = 360f * animated, useCenter = false, topLeft = Offset(inset, inset), size = arc, style = Stroke(width, cap = StrokeCap.Round))
            }
        }
        content()
    }
}

/**
 * **Le petit « +10 XP » qui monte et s'efface** à chaque gain, par-dessus tous les écrans, avec
 * une haptique légère. Un gain que l'écran montre déjà (le retour d'un quiz) ne s'y affiche pas.
 */
@Composable
fun XpToastHost(modifier: Modifier = Modifier) {
    val app = LocalApp.current
    val haptics = rememberHaptics()
    val toasts = remember { mutableStateListOf<Pair<Long, Int>>() }
    LaunchedEffect(Unit) {
        var next = 0L
        app.xp.gains.collect { gain ->
            if (!gain.toast) return@collect
            haptics.selection()
            toasts.add(next++ to gain.amount)
            // Une rafale (une révision rapide) ne couvre pas l'écran : trois au plus.
            while (toasts.size > 3) toasts.removeAt(0)
        }
    }
    Box(modifier.fillMaxWidth().statusBarsPadding().padding(top = 60.dp), contentAlignment = Alignment.TopCenter) {
        toasts.forEach { (id, amount) ->
            key(id) {
                val progress = remember { Animatable(0f) }
                LaunchedEffect(Unit) {
                    progress.animateTo(1f, tween(1400, easing = LinearOutSlowInEasing))
                    toasts.removeAll { it.first == id }
                }
                XpBadge(
                    amount,
                    Modifier.graphicsLayer {
                        val p = progress.value
                        translationY = -p * 56.dp.toPx()
                        alpha = when {
                            p < 0.12f -> p / 0.12f
                            p > 0.65f -> (1f - (p - 0.65f) / 0.35f).coerceAtLeast(0f)
                            else -> 1f
                        }
                        val pop = if (p < 0.15f) 0.85f + p else 1f
                        scaleX = pop
                        scaleY = pop
                    },
                )
            }
        }
    }
}

/**
 * **La fête de l'objectif du jour**, une fois par jour : Mika dans sa bulle, l'anneau plein, l'XP
 * du jour.
 */
@Composable
fun XpGoalCelebration(status: XpStatus, onDismiss: () -> Unit) {
    val colors = Micabo.colors
    val pop = remember { Animatable(0.4f) }
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
            ProgressRing(1f, 132.dp, 14.dp, XpGold, Modifier.graphicsLayer { scaleX = pop.value; scaleY = pop.value }) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(status.today.toString(), style = nunito(36.sp, FontWeight.Black), color = xpInk())
                    Text("XP", style = nunito(14.sp, FontWeight.ExtraBold), color = colors.inkSecondary)
                }
            }
            Spacer(Modifier.height(16.dp))
            Text(
                stringResource(R.string.kx_goal_title),
                style = nunito(24.sp, FontWeight.Black, lineHeight = 28.sp),
                color = colors.ink,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(14.dp))
            MikaSays(stringResource(R.string.kx_goal_body, XpRules.DAILY_GOAL.toString()), mood = MikaMood.CELEBRATE, size = 72.dp)
            Spacer(Modifier.height(18.dp))
            MicaboButton(stringResource(R.string.ios_streak_continue), onClick = onDismiss)
        }
    }
}
