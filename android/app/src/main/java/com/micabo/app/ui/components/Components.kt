package com.micabo.app.ui.components

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.annotation.DrawableRes
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito

// MARK: - Le toucher

/** Les retours haptiques de l'app (`Haptics.swift`), par la vue Android. */
class Haptics(private val view: View) {
    fun tap() = view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
    fun selection() = view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
    fun success() = view.performHapticFeedback(
        if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.VIRTUAL_KEY,
    )
    fun error() = view.performHapticFeedback(
        if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.REJECT else HapticFeedbackConstants.LONG_PRESS,
    )
}

@Composable
fun rememberHaptics(): Haptics {
    val view = LocalView.current
    return remember(view) { Haptics(view) }
}

// MARK: - Les boutons

/**
 * **Le bouton plein**, en relief comme sur iPhone : une tranche plus sombre sous la face, qui
 * s'enfonce quand on appuie.
 */
@Composable
fun MicaboButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    color: Color = Micabo.colors.accent,
    contentColor: Color = Color.White,
    icon: ImageVector? = null,
) {
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val face = if (enabled) color else colors.surfaceSunken
    val edge = if (enabled) color.darken(0.22f) else colors.stroke
    val depth by animateFloatAsState(if (pressed && enabled) 0f else 4f, spring(stiffness = Spring.StiffnessHigh), label = "depth")
    Box(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 58.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(edge)
            .clickable(interactionSource = interaction, indication = null, enabled = enabled && !loading) {
                haptics.tap()
                onClick()
            },
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 54.dp)
                .offset(y = (4 - depth).dp)
                .clip(RoundedCornerShape(16.dp))
                .background(face)
                .padding(horizontal = 20.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (loading) {
                CircularProgressIndicator(color = contentColor, strokeWidth = 2.5.dp, modifier = Modifier.size(22.dp))
            } else {
                if (icon != null) {
                    Icon(icon, contentDescription = null, tint = if (enabled) contentColor else colors.inkTertiary, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(8.dp))
                }
                Text(
                    text = text,
                    style = nunito(17.sp, FontWeight.ExtraBold),
                    color = if (enabled) contentColor else colors.inkTertiary,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

/** Le bouton secondaire : une carte blanche bordée, en relief elle aussi. */
@Composable
fun MicaboSecondaryButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, color: Color = Micabo.colors.accent) {
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.97f else 1f, label = "scale")
    Box(
        modifier = modifier
            .fillMaxWidth()
            .scale(scale)
            .heightIn(min = 54.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(colors.surface)
            .border(2.dp, colors.stroke, RoundedCornerShape(16.dp))
            .clickable(interactionSource = interaction, indication = null) {
                haptics.tap()
                onClick()
            }
            .padding(horizontal = 20.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = nunito(16.sp, FontWeight.ExtraBold), color = color, textAlign = TextAlign.Center)
    }
}

/** Un élément qui se presse : il se tasse un peu sous le doigt. */
@Composable
fun Pressable(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    haptic: Boolean = true,
    content: @Composable BoxScope.() -> Unit,
) {
    val haptics = rememberHaptics()
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed && enabled) 0.96f else 1f, spring(dampingRatio = 0.6f), label = "press")
    Box(
        modifier = modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .clickable(interactionSource = interaction, indication = null, enabled = enabled) {
                if (haptic) haptics.selection()
                onClick()
            },
        content = content,
    )
}

@Composable
fun CircleIconButton(icon: ImageVector, contentDescription: String?, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    Pressable(onClick = onClick, modifier = modifier.size(44.dp).clip(CircleShape).background(colors.surface).border(1.5.dp, colors.stroke, CircleShape)) {
        Icon(icon, contentDescription = contentDescription, tint = colors.ink, modifier = Modifier.align(Alignment.Center).size(22.dp))
    }
}

@Composable
fun BackButton(onClick: () -> Unit, modifier: Modifier = Modifier) =
    CircleIconButton(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.app_common_back), onClick, modifier)

@Composable
fun CloseButton(onClick: () -> Unit, modifier: Modifier = Modifier) =
    CircleIconButton(Icons.Filled.Close, stringResource(R.string.app_a11y_close), onClick, modifier)

// MARK: - La jauge

@Composable
fun ProgressBar(progress: Float, modifier: Modifier = Modifier, color: Color = Micabo.colors.accentVivid, height: Dp = 12.dp) {
    val colors = Micabo.colors
    val animated by animateFloatAsState(progress.coerceIn(0f, 1f), tween(450, easing = FastOutSlowInEasing), label = "progress")
    Box(modifier.fillMaxWidth().height(height).clip(RoundedCornerShape(height / 2)).background(colors.progressTrack)) {
        Box(
            Modifier
                .fillMaxWidth(animated)
                .height(height)
                .clip(RoundedCornerShape(height / 2))
                .background(color),
        ) {
            // Le reflet, comme une barre de jeu.
            Box(
                Modifier
                    .padding(horizontal = 6.dp, vertical = 3.dp)
                    .fillMaxWidth()
                    .height(height / 4)
                    .clip(RoundedCornerShape(height))
                    .background(Color.White.copy(alpha = 0.3f)),
            )
        }
    }
}

// MARK: - Mika et les icônes

enum class MikaMood(@DrawableRes val drawable: Int) {
    IDLE(R.drawable.mika_idle),
    HAPPY(R.drawable.mika_happy),
    SAD(R.drawable.mika_sad),
    THINK(R.drawable.mika_think),
    CELEBRATE(R.drawable.mika_celebrate),
    WAVE(R.drawable.mika_wave),
    SLEEP(R.drawable.mika_sleep),
    SURPRISE(R.drawable.mika_surprise),
}

/** **Mika**, la mascotte : il respire doucement ; heureux, il saute. */
@Composable
fun Mika(mood: MikaMood = MikaMood.IDLE, size: Dp = 120.dp, modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "mika")
    val bounce = mood == MikaMood.HAPPY || mood == MikaMood.CELEBRATE
    val breathe by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(if (bounce) 520 else 1800, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "breathe",
    )
    val entrance = remember(mood) { Animatable(0.85f) }
    LaunchedEffect(mood) { entrance.animateTo(1f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMediumLow)) }
    Image(
        painter = painterResource(mood.drawable),
        contentDescription = null,
        modifier = modifier
            .size(size)
            .graphicsLayer {
                val lift = if (bounce) breathe * 0.08f else breathe * 0.02f
                translationY = -size.toPx() * lift
                scaleX = entrance.value * (1f + breathe * 0.015f)
                scaleY = entrance.value * (1f - breathe * 0.01f + breathe * 0.03f)
            },
    )
}

/** L'icône 3D d'une leçon ou d'un thème, depuis son identifiant (`MicaboIcon.lessonCatalog`). */
@DrawableRes
fun icon3d(id: String): Int = when (id) {
    "livre-ouvert" -> R.drawable.icon3d_livre_ouvert
    "globe" -> R.drawable.icon3d_globe
    "fiole" -> R.drawable.icon3d_fiole
    "parchemin" -> R.drawable.icon3d_parchemin
    "calculatrice" -> R.drawable.icon3d_calculatrice
    "atome" -> R.drawable.icon3d_atome
    "ampoule" -> R.drawable.icon3d_ampoule
    "loupe" -> R.drawable.icon3d_loupe
    "puzzle" -> R.drawable.icon3d_puzzle
    "cerveau" -> R.drawable.icon3d_cerveau
    "reveil" -> R.drawable.icon3d_reveil
    "sablier" -> R.drawable.icon3d_sablier
    "plume" -> R.drawable.icon3d_plume
    "palette" -> R.drawable.icon3d_palette
    "fusee" -> R.drawable.icon3d_fusee
    "drapeau" -> R.drawable.icon3d_drapeau
    "diplome" -> R.drawable.icon3d_diplome
    "epingle" -> R.drawable.icon3d_epingle
    "coche" -> R.drawable.icon3d_coche
    "cadenas" -> R.drawable.icon3d_cadenas
    "etoile" -> R.drawable.icon3d_etoile
    "trophee" -> R.drawable.icon3d_trophee
    "couronne" -> R.drawable.icon3d_couronne
    "flamme" -> R.drawable.icon3d_flamme
    "examen" -> R.drawable.icon3d_examen
    "quiz" -> R.drawable.icon3d_quiz
    "cartes" -> R.drawable.icon3d_cartes
    "pdf" -> R.drawable.icon3d_pdf
    "texte" -> R.drawable.icon3d_texte
    "fiche" -> R.drawable.icon3d_fiche
    else -> R.drawable.icon3d_livre_ouvert
}

@Composable
fun Icon3D(id: String, size: Dp, modifier: Modifier = Modifier) {
    Image(painter = painterResource(icon3d(id)), contentDescription = null, modifier = modifier.size(size))
}

/** Une petite étiquette en capitales, au-dessus d'un encadré. */
@Composable
fun Eyebrow(text: String, color: Color, modifier: Modifier = Modifier) {
    Text(text.uppercase(), style = nunito(12.sp, FontWeight.ExtraBold).copy(letterSpacing = 1.2.sp), color = color, modifier = modifier)
}

/** Un écran d'attente : Mika qui réfléchit, une phrase. */
@Composable
fun Waiting(text: String, modifier: Modifier = Modifier) {
    Column(modifier.padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Mika(MikaMood.THINK, 120.dp)
        Spacer(Modifier.height(16.dp))
        Text(text, style = nunito(17.sp, FontWeight.Bold), color = Micabo.colors.inkSecondary, textAlign = TextAlign.Center)
    }
}

/** Trois points qui s'allument l'un après l'autre. */
@Composable
fun TypingDots(color: Color, modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "dots")
    val phase by transition.animateFloat(0f, 3f, infiniteRepeatable(tween(1200, easing = LinearEasing)), label = "phase")
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        repeat(3) { index ->
            val on = phase.toInt() == index
            Box(Modifier.size(7.dp).clip(CircleShape).background(color.copy(alpha = if (on) 1f else 0.3f)))
        }
    }
}

fun Color.darken(fraction: Float): Color =
    Color(red * (1 - fraction), green * (1 - fraction), blue * (1 - fraction), alpha)

@Composable
fun RowScope.Grow() = Spacer(Modifier.weight(1f))
