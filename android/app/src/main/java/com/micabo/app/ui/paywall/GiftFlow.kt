package com.micabo.app.ui.paywall

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.GiftOffer
import com.micabo.app.data.PurchaseOutcome
import com.micabo.app.data.StorePlan
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.Navigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Le bleu de l'offre (`MicaboColor.offerSky`), le même sur le cadeau, le tarif et la languette. */
private val OfferSky = Color(0xFF12A3F2)
private val OfferSkyDeep = Color(0xFF0B8FDC)

/** **Le dégradé de l'offre** (`DiscountWash`) : le même sur le cadeau et sur le tarif. */
@Composable
private fun offerWash(): Brush {
    val colors = Micabo.colors
    val top = if (colors.dark) listOf(Color(0xFF3E2C66), Color(0xFF261C3D)) else listOf(Color(0xFFDCC9FB), Color(0xFFF4EEFE))
    return Brush.verticalGradient(top + colors.surface)
}

/**
 * **Le cadeau et le tarif réduit, posés par-dessus les onglets** (`DiscountBadgeHost` et
 * `micaboDiscountOffer`). Le cadeau tombe quand un paywall s'est refermé sans achat, une fois
 * l'écran parti : deux surfaces qui se croisent, et la seconde passe inaperçue.
 */
@Composable
fun GiftHost(navigator: Navigator) {
    val app = LocalApp.current
    val gift = app.gift
    val pending by gift.pending.collectAsState()
    val presentation by gift.presentation.collectAsState()
    val isPro by app.billing.isPro.collectAsState()
    val onPaywall = navigator.current is Screen.Paywall

    LaunchedEffect(pending, onPaywall) {
        if (!pending || onPaywall) return@LaunchedEffect
        delay(700)
        if (navigator.current is Screen.Paywall || !gift.takePending()) return@LaunchedEffect
        if (app.billing.enabled && !app.billing.isPro.value && gift.presentation.value == null) gift.presentGift()
    }
    // Un achat ailleurs (restauration, renouvellement) referme l'offre.
    LaunchedEffect(isPro) { if (isPro && gift.presentation.value != null) gift.subscribed() }

    BackHandler(enabled = presentation != null) { gift.dismiss() }

    val showsGift = presentation == GiftOffer.Presentation.GIFT
    val showsPaywall = presentation == GiftOffer.Presentation.PAYWALL
    AnimatedVisibility(showsGift || showsPaywall, enter = fadeIn(tween(250)), exit = fadeOut(tween(220))) {
        // Le voile : il garde les doigts, et sous le tarif il le referme.
        Box(
            Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.36f))
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {
                    if (gift.presentation.value == GiftOffer.Presentation.PAYWALL) gift.dismiss()
                },
        )
    }
    AnimatedVisibility(
        showsGift,
        enter = fadeIn(tween(250)) + scaleIn(tween(300), initialScale = 0.96f),
        exit = fadeOut(tween(200)),
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            GiftCard(onOpened = { gift.presentPaywall() }, onDismiss = { gift.dismiss() })
        }
    }
    AnimatedVisibility(
        showsPaywall,
        enter = slideInVertically(tween(380, easing = FastOutSlowInEasing)) { it } + fadeIn(tween(200)),
        exit = slideOutVertically(tween(300)) { it } + fadeOut(tween(250)),
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.BottomCenter) {
            DiscountSheet(onDismiss = { gift.dismiss() }, onSubscribed = { gift.subscribed() })
        }
    }
}

// MARK: - Premier temps : le cadeau

/**
 * Le cadeau, en pop-up (`DiscountGiftStage`). Chaque appui écrase la boîte, remonte le couvercle
 * d'un cran et fait vibrer ; au troisième, les rubans partent et le tarif prend la main.
 */
@Composable
private fun GiftCard(onOpened: () -> Unit, onDismiss: () -> Unit) {
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    var taps by remember { mutableIntStateOf(0) }
    var bursting by remember { mutableStateOf(false) }
    val squash = remember { Animatable(1f) }
    val wobble = remember { Animatable(0f) }
    val remaining = (GiftOffer.TAPS - taps).coerceAtLeast(0)

    fun tap() {
        if (taps >= GiftOffer.TAPS) return
        taps += 1
        haptics.tap()
        scope.launch {
            squash.animateTo(0.9f, tween(110))
            squash.animateTo(1f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMediumLow))
        }
        // L'inclinaison alterne : une boîte qui penche toujours du même côté a l'air de tomber.
        scope.launch {
            wobble.animateTo(if (taps % 2 == 0) -5f else 5f, tween(110))
            wobble.animateTo(0f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMediumLow))
        }
        if (taps < GiftOffer.TAPS) return
        bursting = true
        haptics.success()
        // Le temps que les rubans partent.
        scope.launch {
            delay(500)
            onOpened()
        }
    }

    Column(
        Modifier
            .padding(horizontal = 28.dp)
            .widthIn(max = 400.dp)
            .fillMaxWidth()
            .shadow(24.dp, RoundedCornerShape(30.dp))
            .clip(RoundedCornerShape(30.dp))
            .background(offerWash())
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
            .padding(start = 18.dp, end = 18.dp, top = 8.dp, bottom = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { OfferClose(onDismiss) }
        Text(
            stringResource(R.string.ios_giftTitle),
            style = nunito(26.sp, FontWeight.Black, lineHeight = 30.sp),
            color = colors.ink,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 12.dp),
        )
        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.ios_giftBody),
            style = nunito(15.sp, FontWeight.Medium, lineHeight = 20.sp),
            color = colors.inkSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 12.dp),
        )
        Spacer(Modifier.height(16.dp))
        Box(
            Modifier
                .size(176.dp)
                .graphicsLayer {
                    scaleX = squash.value
                    scaleY = squash.value
                    rotationZ = wobble.value
                }
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { tap() },
            contentAlignment = Alignment.Center,
        ) {
            GiftBox(taps, bursting)
        }
        Spacer(Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            repeat(GiftOffer.TAPS) { index ->
                val done = index < taps
                val width by animateDpAsState(if (done) 26.dp else 9.dp, spring(dampingRatio = 0.6f), label = "dot")
                Box(
                    Modifier
                        .size(width, 9.dp)
                        .clip(RoundedCornerShape(50))
                        .background(if (done) OfferSky else OfferSky.copy(alpha = 0.25f)),
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        Text(
            if (remaining == 0) stringResource(R.string.ios_giftOpening) else stringResource(R.string.ios_giftTapsLeft, remaining.toString()),
            style = nunito(14.sp, FontWeight.Bold),
            color = colors.inkSecondary,
        )
    }
}

/** La boîte (`DiscountGiftBox`) : un corps, un couvercle qui remonte, un nœud, des rubans. */
@Composable
private fun GiftBox(taps: Int, bursting: Boolean) {
    val lift by animateFloatAsState(-taps * 7f, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMediumLow), label = "lid")
    val tilt by animateFloatAsState(if (bursting) -12f else 0f, spring(dampingRatio = 0.62f), label = "tilt")
    val bow by animateFloatAsState(if (bursting) 0f else 1f, tween(250), label = "bow")
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        if (bursting) Ribbons()
        // Le corps.
        Box(
            Modifier
                .offset(y = 30.dp)
                .size(132.dp, 96.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(OfferSky),
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.fillMaxHeight().width(18.dp).background(Color.White.copy(alpha = 0.45f)))
        }
        // Le couvercle.
        Box(
            Modifier
                .offset(y = (-24f + lift).dp)
                .graphicsLayer {
                    rotationZ = tilt
                    transformOrigin = TransformOrigin(0f, 1f)
                }
                .size(150.dp, 34.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(OfferSkyDeep),
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.fillMaxHeight().width(18.dp).background(Color.White.copy(alpha = 0.45f)))
        }
        // Le nœud.
        Canvas(
            Modifier
                .offset(y = (-50f + lift).dp)
                .size(78.dp, 34.dp)
                .alpha(bow),
        ) {
            val mid = size.width / 2
            val bottom = size.height
            val w = size.width
            val h = size.height
            val path = Path().apply {
                moveTo(mid, bottom)
                cubicTo(mid - w * 0.18f, bottom - h * 0.9f, 0f, 0f, 0f, h * 0.25f)
                cubicTo(0f, bottom, mid - w * 0.24f, bottom, mid, bottom)
                moveTo(mid, bottom)
                cubicTo(mid + w * 0.18f, bottom - h * 0.9f, w, 0f, w, h * 0.25f)
                cubicTo(w, bottom, mid + w * 0.24f, bottom, mid, bottom)
            }
            drawPath(path, OfferSkyDeep)
        }
    }
}

/** Les rubans du troisième appui : huit traits qui partent du centre. */
@Composable
private fun Ribbons() {
    val out = remember { Animatable(0f) }
    LaunchedEffect(Unit) { out.animateTo(1f, tween(550, easing = FastOutSlowInEasing)) }
    Canvas(Modifier.fillMaxSize()) {
        val distance = (34f + (104f - 34f) * out.value) * density
        val ribbon = Size(6.dp.toPx(), 22.dp.toPx())
        repeat(8) { index ->
            rotate(index * 45f, pivot = center) {
                drawRoundRect(
                    color = OfferSky.copy(alpha = 0.9f * (1f - out.value)),
                    topLeft = Offset(center.x - ribbon.width / 2, center.y - distance - ribbon.height / 2),
                    size = ribbon,
                    cornerRadius = CornerRadius(ribbon.width / 2),
                )
            }
        }
    }
}

/** La croix de l'offre, en haut à droite, dans le bleu de l'offre. */
@Composable
private fun OfferClose(onClick: () -> Unit) {
    Pressable(onClick = onClick, modifier = Modifier.size(44.dp)) {
        Icon(
            Icons.Filled.Close,
            contentDescription = stringResource(R.string.app_a11y_close),
            tint = OfferSky,
            modifier = Modifier.align(Alignment.CenterEnd).size(24.dp),
        )
    }
}

// MARK: - Second temps : le tarif réduit

/**
 * **Le paywall du cadeau** (`DiscountPaywallStage`), en feuille qui monte du bas : le taux, un
 * prix, un bouton. Le mois en grand, et dessous ce qui est réellement prélevé, à côté du tarif
 * barré d'où l'on vient.
 */
@Composable
private fun DiscountSheet(onDismiss: () -> Unit, onSubscribed: () -> Unit) {
    val app = LocalApp.current
    val colors = Micabo.colors
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val percent by app.gift.savingsPercent.collectAsState()
    var discount by remember { mutableStateOf<StorePlan?>(null) }
    var reference by remember { mutableStateOf<StorePlan?>(null) }
    var loading by remember { mutableStateOf(true) }
    var attempt by remember { mutableIntStateOf(0) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val failText = stringResource(R.string.ios_paywallBuyFail)
    val noRestoreText = stringResource(R.string.ios_paywallNoRestore)

    LaunchedEffect(Unit) { app.analytics.track("paywall_opened", mapOf("trigger" to "gift")) }
    LaunchedEffect(attempt) {
        loading = true
        discount = app.billing.discountPlan()
        reference = app.billing.plans().firstOrNull { it.yearly }
        val plan = discount
        val full = reference
        if (plan != null && full != null) GiftOffer.savings(plan.micros, full.micros)?.let(app.gift::rememberSavings)
        loading = false
    }

    Column(
        Modifier
            .fillMaxWidth()
            .widthIn(max = 560.dp)
            .clip(RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp))
            .background(offerWash())
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {}
            .navigationBarsPadding()
            .padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 12.dp)
            .animateContentSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier
                .padding(top = 2.dp)
                .size(38.dp, 5.dp)
                .clip(RoundedCornerShape(50))
                .background(colors.inkTertiary.copy(alpha = 0.4f)),
        )
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { OfferClose(onDismiss) }
        DiscountHeadline(percent)
        Spacer(Modifier.height(22.dp))
        PriceCard(percent, discount, reference)
        Spacer(Modifier.height(16.dp))
        message?.let {
            Text(it, style = nunito(14.sp, FontWeight.Bold), color = colors.wrongInk, textAlign = TextAlign.Center, modifier = Modifier.padding(bottom = 8.dp))
        }
        val plan = discount
        when {
            plan != null -> MicaboButton(
                text = stringResource(R.string.ios_startCheaper, percent.toString()),
                loading = busy,
                color = OfferSky,
                onClick = {
                    val activity = context as? Activity ?: return@MicaboButton
                    busy = true
                    message = null
                    app.analytics.track("paywall_purchase_started", mapOf("plan" to "yearly_discount"))
                    scope.launch {
                        when (app.billing.purchase(activity, plan)) {
                            PurchaseOutcome.Success -> {
                                app.analytics.track("paywall_purchased", mapOf("plan" to "yearly_discount", "trial" to 0))
                                haptics.success()
                                onSubscribed()
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
            loading -> MicaboButton(text = "", loading = true, color = OfferSky, onClick = {})
            else -> {
                Text(
                    stringResource(R.string.x_error_network),
                    style = nunito(14.sp, FontWeight.Bold),
                    color = colors.inkSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(bottom = 8.dp),
                )
                MicaboButton(text = stringResource(R.string.lesson_path_retry), color = OfferSky, onClick = { attempt += 1 })
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.x_paywall_billedYearlyPlay),
            style = nunito(12.sp, FontWeight.Medium, lineHeight = 16.sp),
            color = colors.inkTertiary,
            textAlign = TextAlign.Center,
        )
        LegalFooter(
            restoreEnabled = !busy,
            onRestore = {
                scope.launch {
                    busy = true
                    message = null
                    val restored = app.billing.restore()
                    if (restored) app.analytics.track("paywall_restored")
                    busy = false
                    if (restored) onSubscribed() else message = noRestoreText
                }
            },
            onOpen = { url -> runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) } },
        )
    }
}

/**
 * Le taux en bleu, la promesse dans l'encre (`DiscountHeadline`). Le gabarit traduit dit où est
 * le taux : le turc pose le signe devant (« %30 »), le français derrière (« 30 % »).
 */
@Composable
private fun DiscountHeadline(percent: Int) {
    val colors = Micabo.colors
    val marker = "￼"
    val probed = stringResource(R.string.app_paywall_discountTitle, marker)
    val subtitle = stringResource(R.string.app_paywall_discountSubtitle)
    val parts = probed.split(marker)
    val (rate, rest) = if (parts.size != 2) {
        "" to probed.replace(marker, percent.toString())
    } else {
        var before = parts[0]
        val after = parts[1]
        val trailing = after.trimStart(' ', ' ')
        when {
            trailing.startsWith("%") -> "$percent %" to before + trailing.drop(1)
            before.endsWith("%") -> {
                before = before.dropLast(1)
                "%$percent" to before + after
            }
            else -> percent.toString() to before + after
        }
    }
    Text(
        buildAnnotatedString {
            withStyle(SpanStyle(color = OfferSky)) { append(rate) }
            withStyle(SpanStyle(color = colors.ink)) { append(rest + "\n" + subtitle) }
        },
        style = nunito(29.sp, FontWeight.Black, lineHeight = 33.sp),
        textAlign = TextAlign.Center,
    )
}

@Composable
private fun PriceCard(percent: Int, discount: StorePlan?, reference: StorePlan?) {
    val colors = Micabo.colors
    Row(
        Modifier
            .fillMaxWidth()
            .shadow(10.dp, RoundedCornerShape(24.dp), ambientColor = colors.ink.copy(alpha = 0.1f), spotColor = colors.ink.copy(alpha = 0.1f))
            .clip(RoundedCornerShape(24.dp))
            .background(colors.surface)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        DiscountSeal(percent, 68.dp)
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.ios_planYearly), style = nunito(14.5.sp, FontWeight.Bold), color = OfferSky)
            Row(verticalAlignment = Alignment.Bottom) {
                Text(discount?.monthly ?: discount?.price ?: "—", style = nunito(26.sp, FontWeight.Black), color = colors.ink)
                if (discount?.monthly != null) {
                    Spacer(Modifier.width(6.dp))
                    Text(
                        stringResource(R.string.app_paywall_perMonthSlash),
                        style = nunito(15.sp, FontWeight.SemiBold),
                        color = colors.inkSecondary,
                        modifier = Modifier.padding(bottom = 4.dp),
                    )
                }
            }
            // Ce qui part du compte, et le tarif d'où l'on vient, sur une ligne.
            if (discount != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        stringResource(R.string.ios_billedYearly, discount.price),
                        style = nunito(14.sp, FontWeight.SemiBold),
                        color = colors.inkSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    reference?.let {
                        Spacer(Modifier.width(7.dp))
                        Text(
                            it.price,
                            style = nunito(14.sp, FontWeight.SemiBold).copy(textDecoration = TextDecoration.LineThrough),
                            color = colors.inkTertiary,
                            maxLines = 1,
                        )
                    }
                }
            }
        }
    }
}

/** **Le sceau de la remise** (`DiscountSeal`) : un disque à douze festons. */
@Composable
private fun DiscountSeal(percent: Int, size: Dp) {
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            val scallops = 12
            val bump = 0.17f
            val radius = this.size.minDimension / 2 / (1 + bump)
            val step = (Math.PI * 2 / scallops).toFloat()
            fun point(angle: Float, distance: Float) = Offset(center.x + distance * kotlin.math.cos(angle), center.y + distance * kotlin.math.sin(angle))
            val path = Path()
            for (index in 0 until scallops) {
                val from = point(index * step, radius)
                val to = point((index + 1) * step, radius)
                val crest = point((index + 0.5f) * step, radius * (1 + bump))
                // Le sommet d'une quadratique est en (p0 + 2c + p1) / 4 : le contrôle se déduit de la crête.
                val control = Offset(2 * crest.x - (from.x + to.x) / 2, 2 * crest.y - (from.y + to.y) / 2)
                if (index == 0) path.moveTo(from.x, from.y)
                path.quadraticTo(control.x, control.y, to.x, to.y)
            }
            path.close()
            drawPath(path, Brush.verticalGradient(listOf(OfferSky, OfferSkyDeep)))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(stringResource(R.string.ios_discount), style = nunito(9.5.sp, FontWeight.Bold), color = Color.White, maxLines = 1)
            Row {
                Text("$percent", style = nunito(20.sp, FontWeight.Black, lineHeight = 22.sp), color = Color.White)
                Text("%", style = nunito(10.sp, FontWeight.Black), color = Color.White, modifier = Modifier.padding(top = 2.dp))
            }
        }
    }
}

// MARK: - La languette et la rangée du Profil

/** Le décompte de la fenêtre, relu chaque seconde tant qu'elle court. */
@Composable
private fun rememberWindowLeft(startedAt: Long, ticking: Boolean): Long {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(startedAt, ticking) {
        while (ticking) {
            now = System.currentTimeMillis()
            delay(1000)
        }
        now = System.currentTimeMillis()
    }
    return if (startedAt > 0) GiftOffer.windowRemaining(startedAt, now) else 0L
}

/**
 * **La languette de l'offre** (`DiscountBadge`), collée au bord droit des onglets, avec le
 * décompte des vingt-quatre heures. Un appui rouvre le tarif, pas le cadeau.
 */
@Composable
fun OfferTab(modifier: Modifier = Modifier) {
    val app = LocalApp.current
    val isPro by app.billing.isPro.collectAsState()
    val seen by app.gift.seen.collectAsState()
    val startedAt by app.gift.startedAt.collectAsState()
    val eligible = app.billing.enabled && !isPro && seen && startedAt > 0
    val left = rememberWindowLeft(startedAt, eligible)
    val locale = LocalContext.current.resources.configuration.locales[0]
    AnimatedVisibility(
        eligible && left > 0,
        modifier = modifier,
        enter = fadeIn(tween(300)) + slideInHorizontally(tween(300)) { it / 3 },
        exit = fadeOut(tween(250)),
    ) {
        Pressable(onClick = { app.gift.presentPaywall() }) {
            val shape = RoundedCornerShape(topStart = 16.dp, bottomStart = 16.dp)
            Column(
                Modifier
                    .shadow(10.dp, shape)
                    .clip(shape)
                    .background(OfferSky)
                    .widthIn(min = 56.dp)
                    .padding(start = 10.dp, end = 8.dp, top = 14.dp, bottom = 13.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                GiftGlyph(18.dp, Color.White)
                Text(
                    stringResource(R.string.ios_offerBadge).uppercase(locale),
                    style = nunito(9.sp, FontWeight.Black).copy(letterSpacing = 0.6.sp),
                    color = Color.White.copy(alpha = 0.82f),
                    maxLines = 1,
                )
                Text(GiftOffer.countdown(left), style = nunito(11.sp, FontWeight.Black), color = Color.White, maxLines = 1)
            }
        }
    }
}

/**
 * **La rangée de l'offre, dans le Profil** : elle reste tant qu'on n'est pas abonné, et rouvre
 * le tarif (une fenêtre finie en relance une). « −40 % sur l'année », et le temps qui reste
 * quand la fenêtre court.
 */
@Composable
fun OfferRow() {
    val app = LocalApp.current
    val colors = Micabo.colors
    val percent by app.gift.savingsPercent.collectAsState()
    val startedAt by app.gift.startedAt.collectAsState()
    val left = rememberWindowLeft(startedAt, startedAt > 0 && GiftOffer.isLive(startedAt))
    val help = stringResource(R.string.ios_pro_offerHelp, percent.toString())
    Pressable(onClick = { app.gift.presentPaywall() }) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(22.dp))
                .background(colors.surface)
                .padding(horizontal = 18.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .size(42.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(OfferSky.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center,
            ) { GiftGlyph(22.dp, OfferSky) }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.ios_pro_offer), style = nunito(16.sp, FontWeight.Bold), color = colors.ink)
                Text(
                    if (left > 0) "$help · ${GiftOffer.countdown(left)}" else help,
                    style = nunito(14.sp, FontWeight.SemiBold),
                    color = OfferSky,
                )
            }
        }
    }
}

/** Un petit cadeau dessiné : le corps, le couvercle, le ruban. */
@Composable
private fun GiftGlyph(size: Dp, color: Color) {
    Canvas(Modifier.size(size)) {
        val w = this.size.width
        val h = this.size.height
        drawRoundRect(color, topLeft = Offset(w * 0.12f, h * 0.42f), size = Size(w * 0.76f, h * 0.52f), cornerRadius = CornerRadius(w * 0.08f))
        drawRoundRect(color, topLeft = Offset(w * 0.04f, h * 0.26f), size = Size(w * 0.92f, h * 0.2f), cornerRadius = CornerRadius(w * 0.06f))
        val path = Path().apply {
            moveTo(w * 0.5f, h * 0.26f)
            cubicTo(w * 0.42f, h * 0.02f, w * 0.18f, h * 0.06f, w * 0.26f, h * 0.22f)
            close()
            moveTo(w * 0.5f, h * 0.26f)
            cubicTo(w * 0.58f, h * 0.02f, w * 0.82f, h * 0.06f, w * 0.74f, h * 0.22f)
            close()
        }
        drawPath(path, color)
    }
}
