package com.micabo.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.micabo.app.R

/**
 * **Les jetons de Micabo**, ceux de l'app iPhone (`MicaboAppearance.swift`) : le papier ivoire
 * le jour, l'encre la nuit, un seul bleu pour ce qui est actif, le violet des mots-clés.
 */
@Immutable
data class MicaboColors(
    val dark: Boolean,
    val canvas: Color,
    val surface: Color,
    val surfaceMuted: Color,
    val surfaceSunken: Color,
    val stroke: Color,
    val strokeStrong: Color,
    val hairline: Color,
    val ink: Color,
    val inkSecondary: Color,
    val inkTertiary: Color,
    val inkReading: Color,
    val inkBody: Color,
    val onInk: Color,
    val accent: Color,
    val accentSoft: Color,
    val accentVivid: Color,
    val accentWash: Color,
    val accentPale: Color,
    val progressTrack: Color,
    val positive: Color,
    val caution: Color,
    val cautionSoft: Color,
    val negative: Color,
    val keyword: Color,
    val correct: Color,
    val correctInk: Color,
    val correctSoft: Color,
    val wrong: Color,
    val wrongInk: Color,
    val wrongSoft: Color,
    val flame: Color,
    val tonePale: List<Color>,
    val toneVivid: List<Color>,
    val toneInk: List<Color>,
)

private val Light = MicaboColors(
    dark = false,
    canvas = Color(0xFFF6F4ED),
    surface = Color.White,
    surfaceMuted = Color(0xFFF0EDE4),
    surfaceSunken = Color(0xFFE9E5DA),
    stroke = Color(0xFFE7E2D7),
    strokeStrong = Color(0xFFDAD4C7),
    hairline = Color(0xFFECE8DE),
    ink = Color(0xFF1B1E24),
    inkSecondary = Color(0xFF63676F),
    inkTertiary = Color(0xFF9C9C96),
    inkReading = Color(0xFF2A2D33),
    inkBody = Color(0xFF464A52),
    onInk = Color.White,
    accent = Color(0xFF2563EB),
    accentSoft = Color(0xFFDBEAFE),
    accentVivid = Color(0xFF3B82F6),
    accentWash = Color(0xFFEEF4FE),
    accentPale = Color(0xFFBFD5FA),
    progressTrack = Color(0xFFE7E2D7),
    positive = Color(0xFF2F7D57),
    caution = Color(0xFF8A6410),
    cautionSoft = Color(0xFFFDF1D6),
    negative = Color(0xFFC93B2B),
    keyword = Color(0xFF7C3AED),
    correct = Color(0xFF16A34A),
    correctInk = Color(0xFF15803D),
    correctSoft = Color(0xFFDCFCE7),
    wrong = Color(0xFFDC2626),
    wrongInk = Color(0xFFB91C1C),
    wrongSoft = Color(0xFFFEE2E2),
    flame = Color(0xFFFF5440),
    tonePale = listOf(Color(0xFFFFF1B8), Color(0xFFCDEFDC), Color(0xFFD6E7FB), Color(0xFFFBD9E4), Color(0xFFE4D9FB)),
    toneVivid = listOf(Color(0xFFF2B200), Color(0xFF22B573), Color(0xFF3B82F6), Color(0xFFEC5B8F), Color(0xFF8B5CF6)),
    toneInk = listOf(Color(0xFF7A5600), Color(0xFF146C45), Color(0xFF1D4ED8), Color(0xFFA8204F), Color(0xFF5B21B6)),
)

private val Dark = MicaboColors(
    dark = true,
    canvas = Color(0xFF121317),
    surface = Color(0xFF1C1E24),
    surfaceMuted = Color(0xFF23262D),
    surfaceSunken = Color(0xFF2A2D35),
    stroke = Color(0xFF30333B),
    strokeStrong = Color(0xFF3B3F48),
    hairline = Color(0xFF2A2D34),
    ink = Color(0xFFF3F1EA),
    inkSecondary = Color(0xFFA4A7AE),
    inkTertiary = Color(0xFF6F737B),
    inkReading = Color(0xFFE7E5DF),
    inkBody = Color(0xFFC9CAC6),
    onInk = Color(0xFF121317),
    accent = Color(0xFF6B9BF2),
    accentSoft = Color(0xFF1D2A45),
    accentVivid = Color(0xFF60A5FA),
    accentWash = Color(0xFF17213A),
    accentPale = Color(0xFF2B4677),
    progressTrack = Color(0xFF30333B),
    positive = Color(0xFF4CC38A),
    caution = Color(0xFFE3B24C),
    cautionSoft = Color(0xFF33280F),
    negative = Color(0xFFF06A5A),
    keyword = Color(0xFFA78BFA),
    correct = Color(0xFF22C55E),
    correctInk = Color(0xFF4ADE80),
    correctSoft = Color(0xFF13301E),
    wrong = Color(0xFFEF4444),
    wrongInk = Color(0xFFF87171),
    wrongSoft = Color(0xFF3A1717),
    flame = Color(0xFFFF6B57),
    tonePale = listOf(Color(0xFF3B3112), Color(0xFF143326), Color(0xFF182B45), Color(0xFF3D1A29), Color(0xFF2A2148)),
    toneVivid = listOf(Color(0xFFF2B200), Color(0xFF22B573), Color(0xFF3B82F6), Color(0xFFEC5B8F), Color(0xFF8B5CF6)),
    toneInk = listOf(Color(0xFFF6CF5A), Color(0xFF5DD69B), Color(0xFF8DB8FA), Color(0xFFF49AB9), Color(0xFFB9A0FA)),
)

/** Une des cinq teintes de leçon : jaune, menthe, bleu, rose, lilas. */
@Immutable
data class Tone(val pale: Color, val vivid: Color, val ink: Color)

fun MicaboColors.tone(index: Int): Tone {
    val i = ((index % 5) + 5) % 5
    return Tone(tonePale[i], toneVivid[i], toneInk[i])
}

val Nunito = FontFamily(
    Font(R.font.nunito_regular, FontWeight.Normal),
    Font(R.font.nunito_medium, FontWeight.Medium),
    Font(R.font.nunito_semibold, FontWeight.SemiBold),
    Font(R.font.nunito_bold, FontWeight.Bold),
    Font(R.font.nunito_extrabold, FontWeight.ExtraBold),
    Font(R.font.nunito_black, FontWeight.Black),
)

/** Un style Nunito : la seule famille de l'app. */
fun nunito(size: TextUnit, weight: FontWeight = FontWeight.Normal, lineHeight: TextUnit = TextUnit.Unspecified): TextStyle =
    TextStyle(fontFamily = Nunito, fontSize = size, fontWeight = weight, lineHeight = lineHeight)

val LocalMicaboColors = staticCompositionLocalOf { Light }

object Micabo {
    val colors: MicaboColors
        @Composable get() = LocalMicaboColors.current
}

@Composable
fun MicaboTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colors = if (dark) Dark else Light
    val scheme = if (dark) {
        darkColorScheme(
            primary = colors.accent,
            onPrimary = colors.onInk,
            background = colors.canvas,
            onBackground = colors.ink,
            surface = colors.surface,
            onSurface = colors.ink,
            surfaceVariant = colors.surfaceMuted,
            onSurfaceVariant = colors.inkSecondary,
            outline = colors.stroke,
            error = colors.wrong,
        )
    } else {
        lightColorScheme(
            primary = colors.accent,
            onPrimary = colors.onInk,
            background = colors.canvas,
            onBackground = colors.ink,
            surface = colors.surface,
            onSurface = colors.ink,
            surfaceVariant = colors.surfaceMuted,
            onSurfaceVariant = colors.inkSecondary,
            outline = colors.stroke,
            error = colors.wrong,
        )
    }
    val base = MaterialTheme.typography
    val typography = base.copy(
        displayLarge = base.displayLarge.copy(fontFamily = Nunito),
        displayMedium = base.displayMedium.copy(fontFamily = Nunito),
        displaySmall = base.displaySmall.copy(fontFamily = Nunito),
        headlineLarge = base.headlineLarge.copy(fontFamily = Nunito),
        headlineMedium = base.headlineMedium.copy(fontFamily = Nunito),
        headlineSmall = base.headlineSmall.copy(fontFamily = Nunito),
        titleLarge = base.titleLarge.copy(fontFamily = Nunito),
        titleMedium = base.titleMedium.copy(fontFamily = Nunito),
        titleSmall = base.titleSmall.copy(fontFamily = Nunito),
        bodyLarge = base.bodyLarge.copy(fontFamily = Nunito),
        bodyMedium = base.bodyMedium.copy(fontFamily = Nunito),
        bodySmall = base.bodySmall.copy(fontFamily = Nunito),
        labelLarge = base.labelLarge.copy(fontFamily = Nunito),
        labelMedium = base.labelMedium.copy(fontFamily = Nunito),
        labelSmall = base.labelSmall.copy(fontFamily = Nunito),
    )
    CompositionLocalProvider(LocalMicaboColors provides colors) {
        MaterialTheme(colorScheme = scheme, typography = typography, content = content)
    }
}
