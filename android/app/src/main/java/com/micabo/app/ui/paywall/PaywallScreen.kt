package com.micabo.app.ui.paywall

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.micabo.app.data.PlanLoad
import com.micabo.app.data.PlanProblem
import com.micabo.app.data.PurchaseOutcome
import com.micabo.app.data.SiteConfig
import com.micabo.app.data.StorePlan
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
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

/** Les deux temps du paywall, comme sur iPhone (`PaywallFlowView.Stage`). */
private enum class PaywallStage { OFFER, PLANS }

/** Les demandes d'offres à Google Play avant de parler d'erreur. */
private const val PLAN_ATTEMPTS = 3

/**
 * **La porte du paywall dans les événements**, dans le vocabulaire de l'iPhone (`PaywallTrigger`) :
 * les deux apps se lisent dans les mêmes colonnes. `trigger` la donne quand l'écran la connaît
 * (Mika, l'examen blanc, l'entraînement) ; sinon elle se déduit du refus du serveur.
 */
internal fun paywallTrigger(reason: String, trigger: String = ""): String = trigger.ifEmpty {
    when (reason) {
        "" -> "upgrade"
        // Le parcours d'accueil : l'iPhone ouvre ce paywall sans porte, et l'écrit « inconnu ».
        "onboarding" -> "inconnu"
        "free_limit" -> "secondCourse"
        "import_pro" -> "generateCourse"
        "pro_required" -> "practice"
        else -> reason
    }
}

/**
 * **Le paywall, en deux temps**, comme sur iPhone (`PaywallFlowView`) : d'abord l'offre, une seule
 * (l'annuelle, ses jours offerts, la somme prélevée), dont la croix n'arrive qu'après quatre
 * secondes ; cette croix, comme le retour du système, n'annule pas : elle ouvre les formules,
 * l'annuelle et l'hebdomadaire côte à côte. C'est la croix (ou le retour) des formules qui
 * referme. Avant, un seul écran se refermait d'un retour, sans que l'élève voie la comparaison.
 *
 * Les prix sont ceux de Google Play quand RevenueCat a répondu ; sans clé RevenueCat, l'écran dit
 * que les abonnements arrivent bientôt.
 */
@Composable
fun PaywallScreen(reason: String, trigger: String = "") {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val isPro by app.billing.isPro.collectAsState()
    val door = remember(reason, trigger) { paywallTrigger(reason, trigger) }
    var stage by remember { mutableStateOf(PaywallStage.OFFER) }
    val openedAt = remember { System.currentTimeMillis() }
    var load by remember { mutableStateOf<PlanLoad?>(null) }
    var yearly by remember { mutableStateOf(true) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var showsClose by remember { mutableStateOf(false) }
    var attempt by remember { mutableIntStateOf(0) }
    // Un achat confirmé, ou en attente d'une validation (un parent, par Family Link) : ni l'un ni
    // l'autre n'est une fermeture, et le cadeau ne tombe pas derrière eux (`countsAsDismissal`).
    var subscribed by remember { mutableStateOf(false) }
    var awaitingApproval by remember { mutableStateOf(false) }
    var showsPending by remember { mutableStateOf(false) }

    val failText = stringResource(R.string.ios_paywallBuyFail)
    val noRestoreText = stringResource(R.string.ios_paywallNoRestore)

    LaunchedEffect(Unit) { app.analytics.track("paywall_opened", mapOf("trigger" to door, "reason" to reason)) }
    // Les offres de Google Play, redemandées deux fois (le service Play qui se connecte, le réseau
    // qui revient) avant de parler d'erreur ; « réessayer » relance le tout.
    LaunchedEffect(attempt) {
        load = null
        var result = app.billing.loadPlans()
        var tries = 1
        while (result.plans.isEmpty() && app.billing.enabled && tries < PLAN_ATTEMPTS) {
            delay(1_500L * tries)
            tries += 1
            result = app.billing.loadPlans()
        }
        load = result
        // Les prix chargés (ou non, et pourquoi) : `paywall_plans_seen` est la seconde page, comme sur iPhone.
        app.analytics.track(
            "paywall_prices_loaded",
            mapOf("trigger" to door, "available" to result.plans.isNotEmpty(), "attempts" to tries, "error" to result.code),
        )
        if (result.plans.isNotEmpty()) {
            // L'essai, offre par offre (`paywall_trial_status` de l'iPhone). Google Play ne rend que
            // les offres auxquelles ce compte a droit : sans essai, on ne sait pas s'il a servi ou
            // s'il n'existe pas dans ce pays.
            val statuses = mutableMapOf<String, Any?>()
            result.plans.forEach { plan ->
                statuses[plan.analyticsId.substringAfterLast('.')] = if (plan.trialDays > 0) "eligible" else "deja_utilise_ou_aucun"
            }
            statuses["storefront"] = app.billing.storefront() ?: "inconnu"
            app.analytics.track("paywall_trial_status", statuses)
        }
    }
    // La croix de l'offre attend quatre secondes, le temps de lire ce qu'on quitte ; celle des
    // formules deux (`PaywallOfferView.closeDelay`, `PaywallPlansView.closeDelay`). Le retour du
    // système, lui, répond toujours.
    LaunchedEffect(stage) {
        showsClose = false
        delay(if (stage == PaywallStage.OFFER) 4_000L else 2_000L)
        showsClose = true
    }
    val closeAlpha by animateFloatAsState(if (showsClose) 1f else 0f, tween(350), label = "close")
    // Une seule sortie : l'achat et la restauration allument Pro, qui referme l'écran. Sans
    // garde, l'achat refermait deux fois, et l'écran d'en dessous partait avec le paywall.
    LaunchedEffect(isPro) { if (isPro && navigator.current is Screen.Paywall) navigator.back() }
    // **Toute sortie se compte** (la croix, le retour, l'accueil qui revient), avec la page et le
    // temps passé, comme sur iPhone (`onDisappear`). **Refermé sans achat, le paywall fait tomber
    // le cadeau** (`DiscountOffer.paywallClosed`) : les onglets le posent une fois l'écran parti
    // (`GiftHost`). Pas derrière un achat en attente : il est déjà acheté, à une validation près.
    DisposableEffect(Unit) {
        onDispose {
            val pro = app.billing.isPro.value
            if (!subscribed && !pro && !awaitingApproval) {
                app.analytics.track(
                    "paywall_dismissed",
                    mapOf(
                        "trigger" to door,
                        "stage" to if (stage == PaywallStage.PLANS) "plans" else "offre",
                        "seconds" to (System.currentTimeMillis() - openedAt) / 100 / 10.0,
                    ),
                )
            }
            if (app.billing.enabled && !awaitingApproval) app.gift.paywallClosed(pro)
        }
    }

    fun showPlans() {
        if (stage == PaywallStage.PLANS) return
        stage = PaywallStage.PLANS
        app.analytics.track("paywall_plans_seen", mapOf("trigger" to door))
    }

    fun close() {
        if (navigator.current is Screen.Paywall) navigator.back()
    }

    // Le retour du système suit la croix : sur l'offre, il ouvre les formules ; sur les formules,
    // il referme. Désactivé dès que l'écran s'en va, pour ne pas refermer celui d'en dessous.
    BackHandler(enabled = navigator.current is Screen.Paywall) {
        if (stage == PaywallStage.OFFER) showPlans() else close()
    }

    val loaded = load?.plans
    val available = app.billing.enabled && !loaded.isNullOrEmpty()
    val yearlyPrice = loaded?.firstOrNull { it.yearly }
    val weeklyPrice = loaded?.firstOrNull { !it.yearly }
    // L'offre ne montre que l'annuelle ; les formules, le choix de l'élève. L'offre absente de la
    // boutique ne se choisit pas : le bouton ne ferait rien.
    val selected = if (stage == PaywallStage.OFFER) {
        yearlyPrice ?: loaded?.firstOrNull()
    } else {
        loaded?.firstOrNull { it.yearly == yearly } ?: loaded?.firstOrNull()
    }
    val choosesYearly = selected?.yearly ?: yearly
    // Les jours offerts viennent de Google Play seul : un essai déjà utilisé n'est plus promis.
    val yearlyTrial = yearlyPrice?.trialDays ?: 0
    val selectedTrial = selected?.trialDays ?: 0

    val headline = when (reason) {
        "free_limit" -> stringResource(R.string.lesson_error_freeLimit)
        "import_pro" -> stringResource(R.string.ios_paywallGenerateHeadline)
        "pro_required" -> stringResource(R.string.ios_paywallPracticeHeadline)
        else -> stringResource(R.string.ios_paywallUpgradeHeadline)
    }
    // « Essaie **3 jours gratuitement** » quand Google Play accorde l'essai ; sinon, la promesse de Pro.
    val offerTitle = if (yearlyTrial > 0) {
        val lead = stringResource(R.string.ios_paywallTry_lead).trim()
        val free = stringResource(R.string.ios_paywallTry_free, yearlyTrial.toString()).trim()
        listOf(lead, "**$free**").filter { it.isNotEmpty() }.joinToString(" ")
    } else {
        stringResource(R.string.ios_paywallUpgradeHeadline)
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp), horizontalArrangement = Arrangement.End) {
            CloseButton(
                onClick = {
                    if (!showsClose) return@CloseButton
                    if (stage == PaywallStage.OFFER) showPlans() else close()
                },
                modifier = Modifier.graphicsLayer { alpha = closeAlpha },
            )
        }
        AnimatedContent(
            targetState = stage,
            transitionSpec = {
                // Un fondu et une légère montée : on déplie le même écran, on n'en change pas.
                (fadeIn(tween(300)) + slideInVertically(tween(300)) { 18 }) togetherWith fadeOut(tween(180))
            },
            modifier = Modifier.weight(1f),
            label = "paywall",
        ) { shown ->
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                when (shown) {
                    PaywallStage.OFFER -> {
                        // Ce qui a ouvert l'écran ; rien à la sortie du parcours d'accueil, où l'on arrive.
                        if (reason != "onboarding") {
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
                        }
                        Hero(108.dp)
                        Spacer(Modifier.height(18.dp))
                        RichText(
                            offerTitle,
                            style = nunito(31.sp, FontWeight.Black, lineHeight = 34.sp),
                            textAlign = TextAlign.Center,
                            keywordColor = colors.accent,
                        )
                        Spacer(Modifier.height(20.dp))
                        // Une offre, un prix : l'annuelle seule, la somme prélevée en premier.
                        if (loaded.isNullOrEmpty() || yearlyPrice != null) {
                            YearlyCard(yearlyPrice, selected = true, onClick = {})
                        } else {
                            WeeklyCard(weeklyPrice, selected = true, onClick = {})
                        }
                        Spacer(Modifier.height(22.dp))
                        Features()
                        Spacer(Modifier.height(6.dp))
                        TextButton(onClick = { showPlans() }) {
                            Text(stringResource(R.string.ios_paywallSeeAll), style = nunito(16.sp, FontWeight.Bold), color = colors.accent)
                        }
                        Spacer(Modifier.height(10.dp))
                    }
                    PaywallStage.PLANS -> {
                        Hero(104.dp)
                        Spacer(Modifier.height(18.dp))
                        RichText(
                            stringResource(R.string.ios_paywallPlansTitle),
                            style = nunito(31.sp, FontWeight.Black, lineHeight = 34.sp),
                            textAlign = TextAlign.Center,
                            keywordColor = colors.accent,
                        )
                        Spacer(Modifier.height(20.dp))
                        // Google Play : la somme prélevée est le prix le plus visible, l'équivalent mensuel
                        // vient dessous.
                        if (loaded.isNullOrEmpty() || yearlyPrice != null) {
                            YearlyCard(yearlyPrice, selected = choosesYearly, onClick = { haptics.selection(); yearly = true })
                            Spacer(Modifier.height(12.dp))
                        }
                        if (loaded.isNullOrEmpty() || weeklyPrice != null) {
                            WeeklyCard(weeklyPrice, selected = !choosesYearly, onClick = { haptics.selection(); yearly = false })
                        }
                        Spacer(Modifier.height(22.dp))
                        Features()
                        Spacer(Modifier.height(18.dp))
                    }
                }
            }
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
                        val props: Map<String, Any?> = mapOf(
                            "trigger" to door,
                            "plan" to plan.analyticsId,
                            "stage" to if (stage == PaywallStage.PLANS) "plans" else "offre",
                        )
                        app.analytics.track("paywall_purchase_started", props)
                        scope.launch {
                            when (val outcome = app.billing.purchase(activity, plan)) {
                                PurchaseOutcome.Success -> {
                                    subscribed = true
                                    app.analytics.track("paywall_purchased", props + ("trial" to plan.trialDays))
                                    haptics.success()
                                    if (navigator.current is Screen.Paywall) navigator.back()
                                }
                                PurchaseOutcome.Cancelled -> app.analytics.track("paywall_purchase_cancelled", props)
                                // Ni échec ni achat : la validation viendra d'ailleurs, et Pro s'ouvrira
                                // seul. On le dit, sans parler d'échec ni faire tomber le cadeau.
                                PurchaseOutcome.Pending -> {
                                    awaitingApproval = true
                                    app.analytics.track("paywall_purchase_pending", props)
                                    showsPending = true
                                }
                                PurchaseOutcome.Unavailable -> {
                                    app.analytics.track("paywall_purchase_failed", props + ("reason" to "boutique_fermee"))
                                    message = failText
                                }
                                is PurchaseOutcome.Failed -> {
                                    app.analytics.track("paywall_purchase_failed", props + ("reason" to outcome.code.ifEmpty { "refus" }))
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
            } else if (app.billing.enabled && load == null) {
                // Google Play répond : pas de « bientôt disponible » le temps qu'il réponde.
                MicaboButton(text = "", loading = true, onClick = {})
            } else if (app.billing.enabled) {
                // Abonnements configurés, mais la boutique n'a pas répondu, même après trois
                // demandes : le réseau, ou Google Play lui-même (service absent, compte Google
                // manquant). « Pas de connexion » n'est dit que quand c'est vrai.
                Text(
                    stringResource(
                        when (load?.problem) {
                            PlanProblem.NETWORK -> R.string.x_error_network
                            PlanProblem.STORE -> R.string.x_paywall_playUnavailable
                            else -> R.string.x_error_generic
                        },
                    ),
                    style = nunito(14.sp, FontWeight.Bold),
                    color = colors.inkSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(bottom = 8.dp),
                )
                MicaboButton(text = stringResource(R.string.lesson_path_retry), onClick = { attempt += 1 })
            } else {
                MicaboButton(text = stringResource(R.string.x_paywall_soon), enabled = false, onClick = {})
                Spacer(Modifier.height(8.dp))
                Text(
                    stringResource(R.string.x_paywall_soonBody),
                    style = nunito(13.sp, FontWeight.Medium, lineHeight = 18.sp),
                    color = colors.inkSecondary,
                    textAlign = TextAlign.Center,
                )
                TextButton(onClick = { close() }) {
                    Text(stringResource(R.string.lesson_finished_back), style = nunito(15.sp, FontWeight.Bold), color = colors.accent)
                }
            }
            if (app.billing.enabled) {
                LegalFooter(
                    restoreEnabled = !busy,
                    onRestore = {
                        scope.launch {
                            busy = true
                            message = null
                            val restored = app.billing.restore()
                            if (restored) {
                                subscribed = true
                                app.analytics.track("paywall_restored", mapOf("trigger" to door))
                            }
                            busy = false
                            if (!restored) message = noRestoreText
                        }
                    },
                    onOpen = { url -> runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) } },
                )
            }
        }
    }

    if (showsPending) {
        PendingPurchaseDialog(onDismiss = { showsPending = false })
    }
}

/**
 * **L'achat attend une validation** (`ios.paywallPending`) : un parent par Family Link, le plus
 * souvent. Ni un échec ni un achat ; Pro s'ouvrira seul quand Google Play confirmera.
 */
@Composable
internal fun PendingPurchaseDialog(onDismiss: () -> Unit) {
    val colors = Micabo.colors
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = colors.surface,
        title = { Text(stringResource(R.string.ios_paywallPendingTitle), style = nunito(20.sp, FontWeight.ExtraBold)) },
        text = { Text(stringResource(R.string.ios_paywallPending), style = nunito(16.sp)) },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.ios_ok), style = nunito(16.sp, FontWeight.ExtraBold), color = colors.accent)
            }
        },
    )
}

/** L'annuelle : la somme prélevée par an d'abord, l'équivalent mensuel dessous, l'essai en pastille. */
@Composable
private fun YearlyCard(plan: StorePlan?, selected: Boolean, onClick: () -> Unit) {
    val trial = plan?.trialDays ?: 0
    PlanCard(
        title = stringResource(R.string.ios_planYearly),
        price = plan?.price?.let { stringResource(R.string.ios_paywallBilledPerYear, it) } ?: "—",
        detail = plan?.monthly?.let { stringResource(R.string.ios_paywallOnly, it) },
        badge = if (trial > 0) stringResource(R.string.ios_paywall_badge_free, trial.toString()) else null,
        selected = selected,
        onClick = onClick,
    )
}

@Composable
private fun WeeklyCard(plan: StorePlan?, selected: Boolean, onClick: () -> Unit) {
    PlanCard(
        title = stringResource(R.string.ios_planWeekly),
        price = plan?.price?.let { stringResource(R.string.ios_paywallBilledPer, it, stringResource(R.string.ios_unitWeek)) } ?: "—",
        detail = null,
        badge = null,
        selected = selected,
        onClick = onClick,
    )
}


/** Restauration et mentions légales, en pied de page, comme sur iPhone (`PaywallLegalFooter`). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun LegalFooter(restoreEnabled: Boolean, onRestore: () -> Unit, onOpen: (String) -> Unit) {
    val colors = Micabo.colors
    FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalArrangement = Arrangement.Center) {
        TextButton(onClick = onRestore, enabled = restoreEnabled) {
            Text(stringResource(R.string.ios_paywallRestore), style = nunito(13.sp, FontWeight.Bold), color = colors.inkSecondary)
        }
        TextButton(onClick = { onOpen("${SiteConfig.URL}/conditions") }) {
            Text(stringResource(R.string.ios_paywallTerms), style = nunito(13.sp, FontWeight.Bold), color = colors.inkSecondary)
        }
        TextButton(onClick = { onOpen("${SiteConfig.URL}/confidentialite") }) {
            Text(stringResource(R.string.common_privacy), style = nunito(13.sp, FontWeight.Bold), color = colors.inkSecondary)
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
