package com.micabo.app.ui.paywall

import android.app.Activity
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.PurchaseOutcome
import com.micabo.app.data.StorePlan
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val TRIAL_DAYS = 3

/**
 * **Le paywall**, sur le modèle de l'iPhone (`PaywallPlansView`) : la couronne de Pro, ce qui
 * l'a ouvert, les deux offres (l'annuelle mise en avant, trois jours offerts), ce que Pro
 * ouvre. Les prix sont ceux de Google Play quand RevenueCat a répondu ; sans clé RevenueCat,
 * l'écran dit que les abonnements arrivent bientôt.
 */
@Composable
fun PaywallScreen(reason: String) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val isPro by app.billing.isPro.collectAsState()
    var plans by remember { mutableStateOf<List<StorePlan>?>(null) }
    var yearly by remember { mutableStateOf(true) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var showsClose by remember { mutableStateOf(false) }

    val failText = stringResource(R.string.ios_paywallBuyFail)
    val noRestoreText = stringResource(R.string.ios_paywallNoRestore)

    LaunchedEffect(Unit) {
        app.analytics.track("paywall_opened", mapOf("trigger" to reason.ifEmpty { "upgrade" }))
        plans = app.billing.plans()
        app.analytics.track("paywall_plans_seen", mapOf("available" to !plans.isNullOrEmpty()))
    }
    LaunchedEffect(Unit) {
        delay(2500)
        showsClose = true
    }
    LaunchedEffect(isPro) { if (isPro) navigator.back() }

    val available = app.billing.enabled && !plans.isNullOrEmpty()
    val selected = plans?.firstOrNull { it.yearly == yearly }
    val yearlyPrice = plans?.firstOrNull { it.yearly }
    val weeklyPrice = plans?.firstOrNull { !it.yearly }
    // Les jours offerts viennent de Google Play : un essai déjà utilisé n'est plus promis.
    val yearlyTrial = if (yearlyPrice == null) TRIAL_DAYS else yearlyPrice.trialDays
    val selectedTrial = if (selected == null) TRIAL_DAYS else selected.trialDays

    val headline = when (reason) {
        "free_limit" -> stringResource(R.string.lesson_error_freeLimit)
        "import_pro" -> stringResource(R.string.ios_paywallGenerateHeadline)
        "pro_required" -> stringResource(R.string.ios_paywallPracticeHeadline)
        else -> stringResource(R.string.ios_paywallUpgradeHeadline)
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp), horizontalArrangement = Arrangement.End) {
            AnimatedVisibility(visible = showsClose, enter = fadeIn(tween(350))) {
                CloseButton(onClick = {
                    app.analytics.track("paywall_dismissed", mapOf("trigger" to reason.ifEmpty { "upgrade" }))
                    navigator.back()
                })
            }
            if (!showsClose) Spacer(Modifier.size(44.dp))
        }
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                headline,
                style = nunito(13.sp, FontWeight.Bold),
                color = colors.accent,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(colors.accentWash)
                    .padding(horizontal = 14.dp, vertical = 7.dp),
            )
            Spacer(Modifier.height(18.dp))
            Hero(108.dp)
            Spacer(Modifier.height(18.dp))
            RichText(
                stringResource(R.string.ios_paywallPlansTitle),
                style = nunito(31.sp, FontWeight.Black, lineHeight = 34.sp),
                textAlign = TextAlign.Center,
                keywordColor = colors.accent,
            )
            Spacer(Modifier.height(20.dp))
            PlanCard(
                title = stringResource(R.string.ios_planYearly),
                price = yearlyPrice?.monthly?.let { stringResource(R.string.ios_paywallOnly, it) } ?: yearlyPrice?.price ?: "—",
                detail = yearlyPrice?.price?.let { stringResource(R.string.ios_paywallBilledPerYear, it) },
                badge = if (yearlyTrial > 0) stringResource(R.string.ios_paywall_badge_free, yearlyTrial.toString()) else null,
                selected = yearly,
                onClick = { haptics.selection(); yearly = true },
            )
            Spacer(Modifier.height(12.dp))
            PlanCard(
                title = stringResource(R.string.ios_planWeekly),
                price = weeklyPrice?.price?.let { stringResource(R.string.ios_paywallBilledPer, it, stringResource(R.string.ios_unitWeek)) } ?: "—",
                detail = null,
                badge = null,
                selected = !yearly,
                onClick = { haptics.selection(); yearly = false },
            )
            Spacer(Modifier.height(22.dp))
            Features()
            Spacer(Modifier.height(18.dp))
        }
        Column(
            Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            message?.let {
                Text(it, style = nunito(14.sp, FontWeight.Bold), color = colors.wrongInk, textAlign = TextAlign.Center, modifier = Modifier.padding(bottom = 8.dp))
            }
            if (available) {
                MicaboButton(
                    text = if (selectedTrial > 0) stringResource(R.string.ios_paywallStartTrial, selectedTrial.toString()) else stringResource(R.string.x_paywall_subscribe),
                    loading = busy,
                    onClick = {
                        val plan = selected ?: return@MicaboButton
                        val activity = context as? Activity ?: return@MicaboButton
                        busy = true
                        message = null
                        app.analytics.track("paywall_purchase_started", mapOf("plan" to if (plan.yearly) "yearly" else "weekly"))
                        scope.launch {
                            when (app.billing.purchase(activity, plan)) {
                                PurchaseOutcome.Success -> {
                                    app.analytics.track("paywall_purchased", mapOf("plan" to if (plan.yearly) "yearly" else "weekly", "trial" to plan.trialDays))
                                    haptics.success()
                                    navigator.back()
                                }
                                PurchaseOutcome.Cancelled -> app.analytics.track("paywall_purchase_cancelled")
                                PurchaseOutcome.Unavailable -> message = failText
                                is PurchaseOutcome.Failed -> {
                                    app.analytics.track("paywall_purchase_failed")
                                    message = failText
                                }
                            }
                            busy = false
                        }
                    },
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    selected?.let {
                        val unit = stringResource(if (it.yearly) R.string.ios_unitYear else R.string.ios_unitWeek)
                        if (it.trialDays > 0) {
                            stringResource(R.string.x_paywall_finePrint, it.trialDays.toString(), it.price, unit)
                        } else {
                            stringResource(R.string.x_paywall_finePrintNoTrial, it.price, unit)
                        }
                    } ?: stringResource(R.string.ios_paywallReassurance),
                    style = nunito(12.sp, FontWeight.Medium, lineHeight = 16.sp),
                    color = colors.inkTertiary,
                    textAlign = TextAlign.Center,
                )
                TextButton(onClick = {
                    scope.launch {
                        busy = true
                        val restored = app.billing.restore()
                        if (restored) app.analytics.track("paywall_restored")
                        busy = false
                        if (!restored) message = noRestoreText
                    }
                }) {
                    Text(stringResource(R.string.ios_paywallRestore), style = nunito(14.sp, FontWeight.Bold), color = colors.inkSecondary)
                }
            } else {
                MicaboButton(text = stringResource(R.string.x_paywall_soon), enabled = false, onClick = {})
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(R.string.x_paywall_soonBody),
                    style = nunito(13.sp, FontWeight.Medium, lineHeight = 18.sp),
                    color = colors.inkSecondary,
                    textAlign = TextAlign.Center,
                )
                TextButton(onClick = { navigator.back() }) {
                    Text(stringResource(R.string.lesson_finished_back), style = nunito(15.sp, FontWeight.Bold), color = colors.accent)
                }
            }
        }
    }
}

/** La couronne de Pro, sur son halo, et trois des choses qu'elle ouvre qui flottent autour. */
@Composable
private fun Hero(size: Dp) {
    val colors = Micabo.colors
    val transition = rememberInfiniteTransition(label = "hero")
    val float by transition.animateFloat(0f, 1f, infiniteRepeatable(tween(2200, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "float")
    val entrance = remember { Animatable(0.4f) }
    LaunchedEffect(Unit) { entrance.animateTo(1f, spring(dampingRatio = 0.5f, stiffness = 200f)) }
    Box(Modifier.size(size * 2.2f, size * 1.3f), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .size(size * 1.25f)
                .graphicsLayer { scaleX = entrance.value; scaleY = entrance.value }
                .clip(CircleShape)
                .background(Brush.radialGradient(listOf(colors.cautionSoft, colors.accentWash, colors.canvas))),
        )
        Icon3D(
            "couronne",
            size * 0.8f,
            Modifier.graphicsLayer {
                scaleX = entrance.value
                scaleY = entrance.value
                translationY = -float * 10f
                rotationZ = (float - 0.5f) * 6f
            },
        )
        listOf(Triple("pdf", -0.78f to 0.12f, 0.0f), Triple("quiz", 0.8f to -0.18f, 0.3f), Triple("examen", 0.56f to 0.36f, 0.6f)).forEach { (icon, place, phase) ->
            Icon3D(
                icon,
                size * 0.36f,
                Modifier
                    .offset(x = size * place.first, y = size * place.second)
                    .graphicsLayer {
                        val wave = ((float + phase) % 1f)
                        translationY = (wave - 0.5f) * 14f
                        alpha = entrance.value.coerceIn(0f, 1f)
                    },
            )
        }
    }
}

@Composable
private fun PlanCard(title: String, price: String, detail: String?, badge: String?, selected: Boolean, onClick: () -> Unit) {
    val colors = Micabo.colors
    val border by animateColorAsState(if (selected) colors.accent else colors.stroke, label = "border")
    Pressable(onClick = onClick, haptic = false, modifier = Modifier.fillMaxWidth()) {
        Box {
            Row(
                Modifier
                    .padding(top = if (badge != null) 10.dp else 0.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(22.dp))
                    .background(if (selected) colors.accentWash else colors.surface)
                    .border(if (selected) 2.5.dp else 1.5.dp, border, RoundedCornerShape(22.dp))
                    .padding(18.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    Modifier
                        .size(26.dp)
                        .clip(CircleShape)
                        .background(if (selected) colors.accent else colors.surface)
                        .border(2.dp, if (selected) colors.accent else colors.strokeStrong, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    if (selected) Icon(Icons.Filled.Check, null, tint = colors.onInk, modifier = Modifier.size(16.dp))
                }
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f)) {
                    Text(title, style = nunito(18.sp, FontWeight.Black), color = colors.ink)
                    Text(price, style = nunito(15.sp, FontWeight.Bold), color = colors.inkSecondary)
                    if (detail != null) Text(detail, style = nunito(13.sp, FontWeight.Medium), color = colors.inkTertiary)
                }
            }
            if (badge != null) {
                Text(
                    badge,
                    style = nunito(12.sp, FontWeight.Black),
                    color = colors.onInk,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(end = 18.dp)
                        .clip(RoundedCornerShape(50))
                        .background(colors.accent)
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun Features() {
    val colors = Micabo.colors
    val features = listOf(
        "livre-ouvert" to R.string.ios_paywallFeat1,
        "pdf" to R.string.ios_paywallFeat2,
        "quiz" to R.string.ios_paywallFeat3,
        "examen" to R.string.ios_paywallFeat4,
        "cerveau" to R.string.ios_paywallFeat5,
    )
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp))
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(stringResource(R.string.ios_paywallIncluded), style = nunito(17.sp, FontWeight.Black), color = colors.ink)
        features.forEach { (icon, label) ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon3D(icon, 32.dp)
                Spacer(Modifier.width(12.dp))
                Text(stringResource(label), style = nunito(16.sp, FontWeight.Bold, lineHeight = 21.sp), color = colors.ink, modifier = Modifier.weight(1f))
                Icon(Icons.Filled.Check, null, tint = colors.correct, modifier = Modifier.size(20.dp))
            }
        }
    }
}
