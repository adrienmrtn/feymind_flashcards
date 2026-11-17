package com.micabo.app.ui.paywall

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Close
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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.PlanLoad
import com.micabo.app.data.PlanProblem
import com.micabo.app.data.PurchaseOutcome
import com.micabo.app.data.SiteConfig
import com.micabo.app.data.StorePlan
import com.micabo.app.i18n.t
import com.micabo.app.onboarding.TrialDates
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.onboarding.currentLocale
import com.micabo.app.ui.onboarding.frenchArticled
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Type
import com.micabo.app.ui.theme.display
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.text
import com.micabo.app.ui.v3.LocalStill
import com.micabo.app.ui.v3.MicaboIcons
import com.micabo.app.ui.v3.marked
import com.micabo.app.ui.v3.popIn
import com.micabo.app.ui.v3.rememberStill
import com.micabo.app.ui.v3.riseIn
import com.micabo.app.ui.v3.v3Card
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Les demandes d'offres à Google Play avant de parler d'erreur. */
private const val PLAN_ATTEMPTS = 3

/**
 * **Le paywall de fin de parcours ne montre sa croix qu'au bout de cinq secondes** (demande du
 * fondateur, comme `PaywallStyle.closeDelay` sur l'iPhone) : elle arrive en fondu, à sa place, et
 * le bouton retour attend avec elle. Derrière une porte de l'app, et sur l'offre de réduction, elle
 * est là d'emblée : l'élève y est venu lui-même.
 */
object PaywallClose {
    /** Le délai, en millisecondes. */
    const val DELAY_MILLIS = 5_000L

    /** Le fondu de son arrivée. */
    const val FADE_MILLIS = 600

    /** Le délai d'un paywall : `onboarding` (la fin du parcours) attend, une porte de l'app non. */
    fun delayMillis(onboarding: Boolean): Long = if (onboarding) DELAY_MILLIS else 0L
}

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
 * **Le paywall du lot 14/15**, en un écran comme sur l'iPhone (`PaywallScreen`) : la marque et
 * la croix ; Mika ; le titre (« Ton plan pour le Bac est prêt. ») et la promesse d'une ligne ; le
 * gratuit face à PRO en trois lignes vraies ; et, dans le pied fixe, les deux offres (le prix
 * ramené à la semaine en grand, la somme facturée lisible dessous), le bouton, la mention et les
 * liens. Les prix, produits et essais sont ceux de Google Play, jamais écrits ici.
 *
 * Refermé sans achat, il fait tomber l'offre (`GiftHost`), puis l'app s'ouvre avec sa leçon
 * offerte.
 */
@Composable
fun PaywallScreen(reason: String, trigger: String = "") {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val isPro by app.billing.isPro.collectAsState()
    val profile by app.prefs.profile.collectAsState()
    val door = remember(reason, trigger) { paywallTrigger(reason, trigger) }
    val openedAt = remember { System.currentTimeMillis() }
    var load by remember { mutableStateOf<PlanLoad?>(null) }
    var yearly by remember { mutableStateOf(true) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var attempt by remember { mutableIntStateOf(0) }
    var subscribed by remember { mutableStateOf(false) }
    var awaitingApproval by remember { mutableStateOf(false) }
    var showsPending by remember { mutableStateOf(false) }
    val failText = t("ios.paywallBuyFail")
    val noRestoreText = stringResource(R.string.ios_paywallNoRestore)
    val onboarding = reason == "onboarding"
    // La croix de la fin du parcours arrive au bout de cinq secondes (`PaywallClose`).
    var closeReady by remember { mutableStateOf(PaywallClose.delayMillis(onboarding) <= 0L) }
    LaunchedEffect(onboarding) {
        if (closeReady) return@LaunchedEffect
        delay(PaywallClose.delayMillis(onboarding))
        closeReady = true
    }

    LaunchedEffect(Unit) { app.analytics.track("paywall_opened", mapOf("trigger" to door, "reason" to reason)) }
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
        app.analytics.track(
            "paywall_prices_loaded",
            mapOf("trigger" to door, "available" to result.plans.isNotEmpty(), "attempts" to tries, "error" to result.code),
        )
        if (result.plans.isNotEmpty()) {
            val statuses = mutableMapOf<String, Any?>()
            result.plans.forEach { plan ->
                statuses[plan.analyticsId.substringAfterLast('.')] = if (plan.trialDays > 0) "eligible" else "deja_utilise_ou_aucun"
            }
            statuses["storefront"] = app.billing.storefront() ?: "inconnu"
            app.analytics.track("paywall_trial_status", statuses)
        }
    }
    LaunchedEffect(isPro) { if (isPro && navigator.current is Screen.Paywall) navigator.back() }
    DisposableEffect(Unit) {
        onDispose {
            val pro = app.billing.isPro.value
            if (!subscribed && !pro && !awaitingApproval) {
                app.analytics.track(
                    "paywall_dismissed",
                    mapOf("trigger" to door, "stage" to "paywall", "seconds" to (System.currentTimeMillis() - openedAt) / 100 / 10.0),
                )
            }
            if (app.billing.enabled && !awaitingApproval) app.gift.paywallClosed(pro)
        }
    }

    fun close() {
        if (navigator.current is Screen.Paywall) navigator.back()
    }
    // Le retour fait comme la croix : avant qu'elle arrive, il ne ferme rien (et ne quitte pas l'app).
    BackHandler(enabled = navigator.current is Screen.Paywall) { if (closeReady) close() }

    val plans = load?.plans
    val state = when {
        !app.billing.enabled -> PriceState.UNAVAILABLE
        load == null -> PriceState.LOADING
        plans.isNullOrEmpty() -> PriceState.FAILED
        else -> PriceState.READY
    }
    val failure = when (load?.problem) {
        PlanProblem.NETWORK -> stringResource(R.string.x_error_network)
        PlanProblem.STORE -> stringResource(R.string.x_paywall_playUnavailable)
        else -> stringResource(R.string.x_error_generic)
    }
    val examId = profile.examId
    val examName = (com.micabo.app.onboarding.SchoolExams.choice(examId) as? com.micabo.app.onboarding.ExamChoice.Named)?.exam?.title
        ?.takeIf { profile.examDay < 0 || profile.examDay >= java.time.LocalDate.now().toEpochDay() }
    PaywallContent(
        state = state,
        plans = plans.orEmpty(),
        yearlySelected = yearly,
        onSelect = { haptics.selection(); yearly = it },
        name = profile.name.trim().split(' ').firstOrNull()?.takeIf { it.isNotEmpty() },
        examName = examName,
        examId = examId,
        trigger = if (onboarding || reason.isEmpty()) null else door,
        onboarding = onboarding,
        showsClose = closeReady,
        busy = busy,
        message = message,
        failure = failure,
        onClose = ::close,
        onRetry = { attempt += 1 },
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
        onSubscribe = { plan ->
            val activity = context as? Activity ?: return@PaywallContent
            busy = true
            message = null
            val props: Map<String, Any?> = mapOf("trigger" to door, "plan" to plan.analyticsId, "stage" to "paywall")
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
    if (showsPending) PendingPurchaseDialog(onDismiss = { showsPending = false })
}

/** L'état des prix : prêts, en route, introuvables, ou pas d'abonnements sur cette version. */
enum class PriceState { READY, LOADING, FAILED, UNAVAILABLE }

/** Les trois lignes du gratuit face à PRO (`PaywallFeature.shown`) : la porte d'abord. */
private enum class Feature(val titleKey: String, val free: String?) {
    lessons("ios.pay11.row.lessons", "1"),
    mika("ios.pay11.row.mika", "1"),
    exams("ios.pay11.row.exams", "1"),
    practice("ios.pay11.row.practice", "1"),
    pdf("ios.pay11.row.pdf", null);

    companion object {
        fun shown(trigger: String?): List<Feature> {
            val lead = when (trigger) {
                "mika" -> mika
                "mockExam" -> exams
                "practice" -> practice
                "generateCourse" -> pdf
                "secondCourse" -> lessons
                else -> null
            }
            return (listOfNotNull(lead) + entries.filter { it != lead }).take(3)
        }
    }
}

/** L'examen dans la phrase : « pour le Bac » en français (`PaywallProfile.examPhrase`). */
fun examPhrase(examName: String?, examId: String, locale: java.util.Locale): String? {
    examName ?: return null
    if (examName.length > 18) return null
    if (locale.language != "fr") return examName
    val french = listOf("fr.", "be.", "lu.", "ca.", "ma.", "dz.", "tn.", "sn.", "ci.", "ch.maturite", "ch.ef")
    if (french.none { examId.startsWith(it) }) return null
    return frenchArticled(examName)
}

/**
 * **Le paywall, sans l'app** : de quoi le poser dans les rendus et le vérifier. `onboarding` : le
 * paywall de la fin du parcours, qui arrive en douceur (Mika, puis le titre, puis les bénéfices)
 * et dont le bouton sans essai dit « Continuer ».
 */
@Composable
fun PaywallContent(
    state: PriceState,
    plans: List<StorePlan>,
    yearlySelected: Boolean,
    onSelect: (Boolean) -> Unit,
    name: String?,
    examName: String?,
    examId: String,
    trigger: String?,
    busy: Boolean,
    message: String?,
    failure: String,
    onClose: () -> Unit,
    onRetry: () -> Unit,
    onRestore: () -> Unit,
    onOpen: (String) -> Unit,
    onSubscribe: (StorePlan) -> Unit,
    now: Long = System.currentTimeMillis(),
    onboarding: Boolean = false,
    showsClose: Boolean = true,
) {
    val colors = Micabo.colors
    val locale = currentLocale
    // L'arrivée depuis le parcours : 1 Mika, 2 le titre et la promesse, 3 les bénéfices.
    val still = rememberStill()
    var arrival by remember { mutableIntStateOf(if (onboarding && !still) 0 else 3) }
    LaunchedEffect(Unit) {
        if (arrival >= 3) return@LaunchedEffect
        delay(120)
        arrival = 1
        delay(220)
        arrival = 2
        delay(120)
        arrival = 3
    }
    val yearlyPlan = plans.firstOrNull { it.yearly }
    val weeklyPlan = plans.firstOrNull { !it.yearly }
    val selected = plans.firstOrNull { it.yearly == yearlySelected } ?: plans.firstOrNull()
    val trialDays = selected?.trialDays ?: 0
    val exam = examPhrase(examName, examId, locale)
    val title = if (exam != null) t("ios.pay10.title.planExam", "exam" to exam) else t("ios.pay10.title.plan")
    val promise = if (trialDays > 0) t("ios.pay10.title.trial", "n" to trialDays) else t("ios.pay10.title.noTrial")
    BoxWithConstraints(Modifier.fillMaxSize().background(colors.canvas)) {
        val short = maxHeight < 820.dp
        // Texte très agrandi : les deux offres l'une sous l'autre, dans la partie qui défile,
        // pour que le bouton reste en bas sans écraser les prix lettre par lettre.
        val big = LocalDensity.current.fontScale >= 1.5f
        // Mika ne s'affiche que s'il reste la place : sur un petit téléphone, le reste passe avant.
        val hero = maxHeight >= 720.dp && !big
        // Lot 17 (variante A) : à la fin du parcours, le paywall ne fait plus que faire choisir —
        // trois bénéfices d'une ligne, les formules l'une sous l'autre, « Rien à payer
        // aujourd'hui » collé au bouton. Derrière une porte de l'app, le tableau reste.
        val endOfOnboarding = trigger == null
        val plansInBody = big && state == PriceState.READY
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0f to colors.accent.copy(alpha = 0.16f), 0.55f to Color.Transparent)))
        Column(Modifier.fillMaxSize().statusBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(Modifier.widthIn(max = 560.dp).fillMaxWidth().heightIn(min = 52.dp).padding(start = 20.dp, end = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("Micabo", style = display(20.sp), color = colors.ink)
                        Text("PRO", style = text(13.sp, FontWeight.Black), color = colors.onYellow, modifier = Modifier.clip(CircleShape).background(colors.yellow).padding(horizontal = 8.dp, vertical = 2.dp))
                    }
                    if (name != null) Text(t("ios.pay10.brand.for", "name" to name), style = text(13.sp, FontWeight.SemiBold), color = colors.inkSecondary, maxLines = 1)
                }
                // Un rendu pose l'écran fini : la croix y est.
                IconButtonClose(enabled = !busy, visible = showsClose || LocalStill.current || LocalInspectionMode.current, onClick = onClose)
            }
            Column(
                Modifier.weight(1f).widthIn(max = 560.dp).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Spacer(Modifier.height(8.dp))
                if (hero) {
                    Box(Modifier.popIn(arrival >= 1, from = 0.6f), contentAlignment = Alignment.Center) {
                        val size = if (endOfOnboarding) 72.dp else if (short) 96.dp else 128.dp
                        Box(Modifier.size(size * 1.35f).background(Brush.radialGradient(listOf(colors.accent.copy(alpha = 0.40f), Color.Transparent)), CircleShape))
                        Mika(if (trigger == null) MikaMood.CELEBRATE else MikaMood.WINK, size)
                    }
                }
                Text(marked(title, colors.accentBright), style = display(if (short) 30.sp else 34.sp), color = colors.ink, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 10.dp).riseIn(arrival >= 2))
                Text(promise, style = text(17.sp, FontWeight.SemiBold, 22.sp), color = colors.accentBright, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp).riseIn(arrival >= 2, delayMillis = 60))
                if (plansInBody) PlanRows(yearlyPlan, weeklyPlan, selected, locale, onSelect, Modifier.padding(top = 14.dp))
                if (endOfOnboarding) {
                    PaywallChecks(Modifier.padding(top = if (short) 16.dp else 24.dp), visible = arrival >= 3)
                } else if (big) {
                    com.micabo.app.ui.v3.CappedFontScale(1.5f) { FeatureTable(Feature.shown(trigger), Modifier.padding(top = 14.dp)) }
                } else {
                    FeatureTable(Feature.shown(trigger), Modifier.padding(top = if (short) 14.dp else 22.dp))
                }
                if (trigger != null && trialDays > 0 && state == PriceState.READY) {
                    val reminder = TrialDates.reminder(now, trialDays)
                    val line = t("ios.pay10.nothingToday") + (reminder?.let { " · " + t("ios.pay12.remindOn", "date" to TrialDates.dayText(it, locale)) } ?: "")
                    Text(line, style = text(15.sp, FontWeight.SemiBold, 20.sp), color = colors.green, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 12.dp))
                }
                // Texte très agrandi : « Restaurer · Conditions · Confidentialité » passent dans la
                // partie qui défile, pour laisser au bouton et à la mention légale la place du bas.
                if (big) LegalFooter(restoreEnabled = !busy, onRestore = onRestore, onOpen = onOpen)
                Spacer(Modifier.height(12.dp))
            }
            Column(
                Modifier.widthIn(max = 560.dp).fillMaxWidth().navigationBarsPadding().padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                when (state) {
                    PriceState.READY -> if (!plansInBody) PlanRows(yearlyPlan, weeklyPlan, selected, locale, onSelect)
                    PriceState.LOADING -> Text(t("ios.pay10.loading"), style = Type.mention, color = colors.inkSecondary, modifier = Modifier.fillMaxWidth().v3Card(radius = 16.dp).padding(vertical = 30.dp), textAlign = TextAlign.Center)
                    PriceState.FAILED -> Text(failure, style = Type.mention, color = colors.inkSecondary, modifier = Modifier.fillMaxWidth().v3Card(radius = 16.dp).padding(16.dp), textAlign = TextAlign.Center)
                    PriceState.UNAVAILABLE -> Text(stringResource(R.string.x_paywall_soonBody), style = Type.mention, color = colors.inkSecondary, textAlign = TextAlign.Center)
                }
                message?.let { Text(it, style = text(15.sp, FontWeight.SemiBold), color = colors.redInk, textAlign = TextAlign.Center) }
                // « ✓ Rien à payer aujourd'hui », collé au bouton, seulement si l'essai est accordé.
                if (endOfOnboarding && trialDays > 0 && state == PriceState.READY) {
                    com.micabo.app.ui.v3.Reassurance(t("ios.pay10.nothingToday"))
                }
                when (state) {
                    PriceState.READY -> MicaboButton(
                        // Sans essai, à la fin du parcours : « Continuer » ; derrière une porte de l'app, « S'abonner ».
                        if (trialDays > 0) t("ios.pay11.cta.trial", "n" to trialDays) else t(if (onboarding) "common.continue" else "ios.pay12.cta.subscribe"),
                        onClick = { selected?.let(onSubscribe) },
                        loading = busy,
                        modifier = Modifier.testTag("cta"),
                    )
                    PriceState.LOADING -> MicaboButton("", onClick = {}, loading = true, modifier = Modifier.testTag("cta"))
                    PriceState.FAILED -> MicaboButton(t("ios.retry"), onClick = onRetry, modifier = Modifier.testTag("cta"))
                    PriceState.UNAVAILABLE -> MicaboButton(stringResource(R.string.lesson_finished_back), onClick = onClose, modifier = Modifier.testTag("cta"))
                }
                if (state == PriceState.READY && selected != null) {
                    Text(legalLine(selected, now, locale), style = Type.mention, color = colors.inkSecondary, textAlign = TextAlign.Center)
                }
                if (!big) LegalFooter(restoreEnabled = !busy, onRestore = onRestore, onOpen = onOpen)
            }
        }
    }
}

/**
 * **La croix**, 48 dp touchables. `visible` faux (les cinq premières secondes de la fin du
 * parcours) : sa place est gardée, mais rien ne s'y voit, ne s'y touche, ni ne s'y lit avec
 * TalkBack ; elle arrive ensuite en fondu.
 */
@Composable
private fun IconButtonClose(enabled: Boolean, visible: Boolean, onClick: () -> Unit) {
    val colors = Micabo.colors
    val alpha by animateFloatAsState(if (visible) 1f else 0f, tween(PaywallClose.FADE_MILLIS), label = "closeFade")
    val touch = if (visible) Modifier.clip(CircleShape).clickable(enabled = enabled, onClick = onClick) else Modifier
    Box(
        Modifier.size(48.dp).then(touch).alpha(alpha).testTag("close"),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.Rounded.Close,
            contentDescription = if (visible) t("app.a11y.close") else null,
            tint = colors.inkSecondary.copy(alpha = if (enabled) 1f else 0.35f),
            modifier = Modifier.size(22.dp),
        )
    }
}

/** « −40 % » sur l'annuelle, d'après les deux prix de Google Play (rien d'écrit en dur). */
private fun savings(yearly: StorePlan?, weekly: StorePlan?, locale: java.util.Locale): String? {
    if (yearly == null || weekly == null || yearly.micros <= 0 || weekly.micros <= 0) return null
    val percent = Math.round((1 - yearly.micros / (weekly.micros * 52.0)) * 100).toInt()
    if (percent <= 0) return null
    return java.text.NumberFormat.getPercentInstance(locale).format(-percent / 100.0).replace("-", "−")
}

/** La mention sous le bouton : la somme et sa date (`PaywallCopy.legal`). */
@Composable
private fun legalLine(plan: StorePlan, now: Long, locale: java.util.Locale): String {
    if (plan.trialDays > 0) {
        val end = TrialDates.dayText(TrialDates.end(now, plan.trialDays), locale)
        return t(if (plan.yearly) "ios.pay11.legal.trialYear" else "ios.pay11.legal.trialWeek", "date" to end, "price" to plan.price)
    }
    return t(if (plan.yearly) "ios.pay11.legal.year" else "ios.pay11.legal.week", "price" to plan.price)
}

/** Les deux formules, **l'une sous l'autre** (lot 17) : l'annuelle d'abord, avec sa remise. */
@Composable
private fun PlanRows(yearly: StorePlan?, weekly: StorePlan?, selected: StorePlan?, locale: java.util.Locale, onSelect: (Boolean) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        yearly?.let { PlanRow(it, selected = selected == it, savings = savings(yearly, weekly, locale), onClick = { onSelect(true) }) }
        weekly?.let { PlanRow(it, selected = selected == it, savings = null, onClick = { onSelect(false) }) }
    }
}

/**
 * **Une offre, en ligne pleine largeur** (lot 17) : le rond coché, son nom (et la remise),
 * dessous **la somme réellement facturée**, au corps de lecture et en couleur principale ; à
 * droite, le prix ramené à la semaine, en grand. Le prix ne se coupe jamais : il rapetisse.
 */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun PlanRow(plan: StorePlan, selected: Boolean, savings: String?, onClick: () -> Unit) {
    val colors = Micabo.colors
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 66.dp)
            .v3Card(selected = selected, radius = 16.dp)
            .clickable(role = Role.RadioButton, onClick = onClick)
            .semantics { this.selected = selected }
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(if (selected) colors.accent else Color.Transparent)
                .border(2.dp, if (selected) colors.accent else colors.inkTertiary, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (selected) Box(Modifier.size(9.dp).clip(CircleShape).background(Color.White))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(t(if (plan.yearly) "ios.planYearly" else "ios.planWeekly"), style = text(17.sp, FontWeight.Bold), color = colors.ink)
                if (savings != null) {
                    Text(
                        savings,
                        style = text(13.sp, FontWeight.Black),
                        color = colors.onYellow,
                        modifier = Modifier.align(Alignment.CenterVertically).clip(CircleShape).background(colors.yellow).padding(horizontal = 8.dp, vertical = 2.dp),
                    )
                }
            }
            // La somme facturée se lit : couleur principale, jamais plus petite que la mention.
            Text(
                if (plan.yearly) t("ios.billedYearly", "price" to plan.price) else t("ios.billedEach", "unit" to t("ios.unitWeek")),
                style = text(16.sp, FontWeight.Medium, 21.sp),
                color = colors.ink,
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            com.micabo.app.ui.v3.FitText(plan.weekly ?: plan.price, display(28.sp), colors.ink, Modifier.widthIn(max = 120.dp), TextAlign.End, minSize = 16)
            Text(t("app.paywall.perWeekSlash"), style = text(14.sp, FontWeight.Medium), color = colors.inkSecondary, textAlign = TextAlign.End)
        }
    }
}

/**
 * **Trois bénéfices, une ligne chacun** (lot 17) : une coche jaune, le corps de lecture. Sans
 * « illimité ». Ils montent en cascade (120 ms d'écart) quand le paywall arrive du parcours.
 */
@Composable
private fun PaywallChecks(modifier: Modifier = Modifier, visible: Boolean = true) {
    val colors = Micabo.colors
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        listOf("ios.onb17.pay.lessons", "ios.onb17.pay.mika", "ios.onb17.pay.exams").forEachIndexed { index, key ->
            Row(Modifier.riseIn(visible, delayMillis = index * 120), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(Icons.Rounded.CheckCircle, null, tint = colors.yellow, modifier = Modifier.size(24.dp))
                Text(t(key), style = Type.body, color = colors.ink, modifier = Modifier.weight(1f))
            }
        }
    }
}

/** **Le gratuit face à PRO**, trois lignes vraies (lot 14) : la limite gratuite, la coche de PRO. */
@Composable
private fun FeatureTable(features: List<Feature>, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    // Les colonnes « Gratuit » et « PRO » s'élargissent avec le texte du téléphone (jusqu'à 150 %).
    val grow = LocalDensity.current.fontScale.coerceIn(1f, 1.5f)
    Column(modifier.fillMaxWidth().v3Card().padding(horizontal = 6.dp).padding(bottom = 6.dp)) {
        Row(Modifier.fillMaxWidth().heightIn(min = 28.dp), verticalAlignment = Alignment.CenterVertically) {
            Spacer(Modifier.weight(1f))
            com.micabo.app.ui.v3.FitText(t("ios.pay11.table.free"), text(13.sp, FontWeight.Bold), colors.inkTertiary, Modifier.width(62.dp * grow), TextAlign.Center, minSize = 9)
            Box(Modifier.width(52.dp * grow), contentAlignment = Alignment.Center) {
                Text("PRO", style = text(13.sp, FontWeight.Black), color = colors.onYellow, modifier = Modifier.clip(CircleShape).background(colors.yellow).padding(horizontal = 7.dp, vertical = 1.dp))
            }
        }
        features.forEach { feature ->
            Row(Modifier.fillMaxWidth().heightIn(min = 40.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    when (feature) {
                        Feature.lessons -> MicaboIcons.book
                        Feature.mika -> MicaboIcons.mika
                        Feature.exams -> MicaboIcons.quiz
                        Feature.practice -> MicaboIcons.cards
                        Feature.pdf -> MicaboIcons.pdf
                    },
                    null,
                    tint = when (feature) {
                        Feature.lessons -> colors.iconBlue
                        Feature.mika -> colors.iconLilac
                        Feature.exams -> colors.iconPink
                        Feature.practice -> colors.iconGreen
                        Feature.pdf -> colors.iconOrange
                    },
                    modifier = Modifier.padding(start = 6.dp).size(20.dp),
                )
                Text(t(feature.titleKey), style = text(16.sp, FontWeight.SemiBold, 21.sp), color = colors.ink, modifier = Modifier.weight(1f).padding(start = 10.dp, end = 4.dp, top = 6.dp, bottom = 6.dp))
                Text(feature.free ?: "—", style = text(16.sp, FontWeight.Bold), color = if (feature.free == null) colors.inkTertiary else colors.inkSecondary, textAlign = TextAlign.Center, modifier = Modifier.width(62.dp * grow))
                Box(Modifier.width(52.dp * grow).heightIn(min = 40.dp).background(colors.yellowWash), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.CheckCircle, null, tint = colors.yellow, modifier = Modifier.size(20.dp))
                }
            }
        }
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

/** Restaurer · Conditions · Confidentialité : le minuscule obligatoire, à 13 sp (lot 15). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun LegalFooter(restoreEnabled: Boolean, onRestore: () -> Unit, onOpen: (String) -> Unit) {
    val colors = Micabo.colors
    FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalArrangement = Arrangement.Center) {
        TextButton(onClick = onRestore, enabled = restoreEnabled) {
            Text(t("ios.paywallRestore"), style = Type.legal, color = colors.inkSecondary)
        }
        TextButton(onClick = { onOpen("${SiteConfig.URL}/conditions") }) {
            Text(t("ios.pay10.terms"), style = Type.legal, color = colors.inkSecondary)
        }
        TextButton(onClick = { onOpen("${SiteConfig.URL}/confidentialite") }) {
            Text(t("ios.pay10.privacy"), style = Type.legal, color = colors.inkSecondary)
        }
    }
}
