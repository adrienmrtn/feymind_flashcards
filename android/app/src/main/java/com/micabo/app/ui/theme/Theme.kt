package com.micabo.app.ui.theme

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
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import java.util.Locale

/**
 * **La direction artistique V3.3 — « marine, net, adulte »**, les valeurs de l'iPhone
 * (`V3Palette` dans `V3Color.swift`) : le marine est le thème par défaut, le clair (un fond
 * teinté, jamais de blanc pur en fond de page) une option du Profil.
 *
 * C'est le seul endroit où une couleur de la direction s'écrit en hexadécimal. Les jetons
 * d'avant (`canvas`, `ink`, `accent`…) en sont tirés champ par champ, comme `MicaboPalette` sur
 * l'iPhone : les écrans qui n'ont pas été réécrits passent au marine sans rien toucher.
 */
@Immutable
data class V3Palette(
    val bg: Long, val surface: Long, val soft: Long, val line: Long, val lip: Long,
    val ink: Long, val ink2: Long, val ink3: Long,
    val accent: Long, val accentBright: Long, val accentDeep: Long, val accentWash: Long, val accentWash2: Long, val accentInk: Long,
    val cta: Long, val ctaLip: Long, val ctaInk: Long,
    val yellow: Long, val yellowDeep: Long, val yellowWash: Long, val yellowInk: Long,
    val green: Long, val greenWash: Long, val greenInk: Long,
    val red: Long, val redWash: Long, val redInk: Long,
    val pink: Long, val pinkWash: Long, val pinkInk: Long,
    val lilac: Long, val lilacWash: Long, val lilacInk: Long,
    val orange: Long, val orangeWash: Long, val orangeInk: Long,
    val iconBlue: Long, val iconPink: Long, val iconGreen: Long, val iconYellow: Long, val iconLilac: Long, val iconOrange: Long, val iconRed: Long,
) {
    companion object {
        /** **Le marine** : le thème par défaut de l'app. */
        val night = V3Palette(
            bg = 0x0B0F1C, surface = 0x171C2C, soft = 0x20263A, line = 0x262D42, lip = 0x3A4260,
            ink = 0xF5F6FB, ink2 = 0xA9B1C6, ink3 = 0x6E7791,
            accent = 0x5C88FF, accentBright = 0x7FA2FF, accentDeep = 0x3F6BE8, accentWash = 0x18224A, accentWash2 = 0x22306A, accentInk = 0x7FA2FF,
            cta = 0xFFFFFF, ctaLip = 0xBFC6D9, ctaInk = 0x0B0F1C,
            yellow = 0xF7B41F, yellowDeep = 0xB07C08, yellowWash = 0x2B2412, yellowInk = 0xF7B41F,
            green = 0x34D399, greenWash = 0x0F2E26, greenInk = 0x34D399,
            red = 0xF87171, redWash = 0x3A1820, redInk = 0xFCA5A5,
            pink = 0xFF8FA8, pinkWash = 0x3A1A28, pinkInk = 0xFF8FA8,
            lilac = 0xA78BFA, lilacWash = 0x241D45, lilacInk = 0xC4B5FD,
            orange = 0xFB923C, orangeWash = 0x3A2210, orangeInk = 0xFDBA74,
            iconBlue = 0x60A5FA, iconPink = 0xF472B6, iconGreen = 0x34D399, iconYellow = 0xFBBF24, iconLilac = 0xA78BFA, iconOrange = 0xFB923C, iconRed = 0xF87171,
        )

        /** **Le clair** : une option du Profil, sur un fond teinté. */
        val day = V3Palette(
            bg = 0xEEF1F8, surface = 0xFFFFFF, soft = 0xF4F6FB, line = 0xDCE1EC, lip = 0xC2C9D8,
            ink = 0x0F1324, ink2 = 0x566078, ink3 = 0x97A0B4,
            accent = 0x3870FE, accentBright = 0x3870FE, accentDeep = 0x1F47B8, accentWash = 0xE4ECFF, accentWash2 = 0xD0DDFF, accentInk = 0x2452D0,
            cta = 0x0F1324, ctaLip = 0x000000, ctaInk = 0xFFFFFF,
            yellow = 0xF7B41F, yellowDeep = 0xB07C08, yellowWash = 0xFFF4D6, yellowInk = 0x8A5A00,
            green = 0x059669, greenWash = 0xDDF7EA, greenInk = 0x047857,
            red = 0xDC2626, redWash = 0xFFE7EC, redInk = 0xB91C1C,
            pink = 0xDB2777, pinkWash = 0xFFE4EF, pinkInk = 0xBE185D,
            lilac = 0x7C3AED, lilacWash = 0xEEE9FF, lilacInk = 0x6D28D9,
            orange = 0xF97316, orangeWash = 0xFFEDD5, orangeInk = 0xC2410C,
            iconBlue = 0x3870FE, iconPink = 0xDB2777, iconGreen = 0x059669, iconYellow = 0xD97706, iconLilac = 0x7C3AED, iconOrange = 0xF97316, iconRed = 0xDC2626,
        )

        /** Le texte posé sur le jaune : un brun très sombre, le même dans les deux thèmes. */
        val onYellow = Color(0xFF2A1D00)
    }
}

private fun hex(value: Long) = Color(0xFF000000 or value)

/**
 * **Les jetons de Micabo** : ceux d'avant la V3.3 (que lisent les écrans pas encore réécrits),
 * tirés de `V3Palette`, et les jetons V3.3 eux-mêmes (`cta`, `yellow`, `accentBright`…).
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
    // V3.3
    val accentBright: Color,
    val accentDeep: Color,
    val accentInk: Color,
    val cta: Color,
    val ctaLip: Color,
    val ctaInk: Color,
    val yellow: Color,
    val yellowDeep: Color,
    val yellowWash: Color,
    val yellowInk: Color,
    val green: Color,
    val greenWash: Color,
    val greenInk: Color,
    val red: Color,
    val redWash: Color,
    val redInk: Color,
    val pink: Color,
    val lilac: Color,
    val orange: Color,
    val iconBlue: Color,
    val iconPink: Color,
    val iconGreen: Color,
    val iconYellow: Color,
    val iconLilac: Color,
    val iconOrange: Color,
    val iconRed: Color,
) {
    /** Le texte posé sur le jaune. */
    val onYellow: Color get() = V3Palette.onYellow
}

private fun colorsOf(p: V3Palette, dark: Boolean) = MicaboColors(
    dark = dark,
    canvas = hex(p.bg),
    surface = hex(p.surface),
    surfaceMuted = hex(p.soft),
    surfaceSunken = if (dark) hex(0x0F1424) else hex(0xE2E7F1),
    stroke = hex(p.line),
    strokeStrong = hex(p.lip),
    hairline = if (dark) hex(0x20263A) else hex(0xE8ECF3),
    ink = hex(p.ink),
    inkSecondary = hex(p.ink2),
    inkTertiary = hex(p.ink3),
    inkReading = if (dark) hex(0xE9ECF5) else hex(0x1E2338),
    inkBody = if (dark) hex(0xC9CEDD) else hex(0x3D4459),
    onInk = if (dark) hex(p.bg) else Color.White,
    accent = hex(p.accent),
    accentSoft = hex(p.accentWash2),
    accentVivid = hex(p.accent),
    accentWash = hex(p.accentWash),
    accentPale = if (dark) hex(0x1E3A85) else hex(0xBBCEFF),
    progressTrack = hex(p.line),
    positive = hex(p.green),
    caution = hex(p.yellowInk),
    cautionSoft = hex(p.yellowWash),
    negative = hex(p.red),
    keyword = hex(p.accentBright),
    correct = hex(p.green),
    correctInk = hex(p.greenInk),
    correctSoft = hex(p.greenWash),
    wrong = hex(p.red),
    wrongInk = hex(p.redInk),
    wrongSoft = hex(p.redWash),
    flame = hex(p.orange),
    tonePale = listOf(hex(p.yellowWash), hex(p.greenWash), hex(p.accentWash), hex(p.pinkWash), hex(p.lilacWash)),
    toneVivid = listOf(hex(p.iconYellow), hex(p.iconGreen), hex(p.iconBlue), hex(p.iconPink), hex(p.iconLilac)),
    toneInk = listOf(hex(p.yellowInk), hex(p.greenInk), hex(p.accentInk), hex(p.pinkInk), hex(p.lilacInk)),
    accentBright = hex(p.accentBright),
    accentDeep = hex(p.accentDeep),
    accentInk = hex(p.accentInk),
    cta = hex(p.cta),
    ctaLip = hex(p.ctaLip),
    ctaInk = hex(p.ctaInk),
    yellow = hex(p.yellow),
    yellowDeep = hex(p.yellowDeep),
    yellowWash = hex(p.yellowWash),
    yellowInk = hex(p.yellowInk),
    green = hex(p.green),
    greenWash = hex(p.greenWash),
    greenInk = hex(p.greenInk),
    red = hex(p.red),
    redWash = hex(p.redWash),
    redInk = hex(p.redInk),
    pink = hex(p.pink),
    lilac = hex(p.lilac),
    orange = hex(p.orange),
    iconBlue = hex(p.iconBlue),
    iconPink = hex(p.iconPink),
    iconGreen = hex(p.iconGreen),
    iconYellow = hex(p.iconYellow),
    iconLilac = hex(p.iconLilac),
    iconOrange = hex(p.iconOrange),
    iconRed = hex(p.iconRed),
)

private val Night = colorsOf(V3Palette.night, dark = true)
private val Day = colorsOf(V3Palette.day, dark = false)

/** Les couleurs d'une apparence, hors composition (les tests, l'écran de lancement). */
fun micaboColors(dark: Boolean): MicaboColors = if (dark) Night else Day

/** Une des cinq teintes de leçon : jaune, menthe, bleu, rose, lilas. */
@Immutable
data class Tone(val pale: Color, val vivid: Color, val ink: Color)

fun MicaboColors.tone(index: Int): Tone {
    val i = ((index % 5) + 5) % 5
    return Tone(tonePale[i], toneVivid[i], toneInk[i])
}

/**
 * **La police d'affichage : Sofia Sans Condensed**, en Black (ExtraBold pour ce qui est plus
 * léger), embarquée comme sur l'iPhone. Elle écrit le latin étendu, le cyrillique et le grec ;
 * l'arabe retombe glyphe par glyphe sur la police du système.
 */
val SofiaCondensed = FontFamily(
    Font(R.font.sofia_condensed_extrabold, FontWeight.SemiBold),
    Font(R.font.sofia_condensed_extrabold, FontWeight.Bold),
    Font(R.font.sofia_condensed_extrabold, FontWeight.ExtraBold),
    Font(R.font.sofia_condensed_black, FontWeight.Black),
)

/** L'ancien nom : les écrans d'avant la V3.3 l'importent encore. */
val Nunito: FontFamily = FontFamily.Default

/**
 * **Les titres d'une langue que la police d'affichage n'écrit pas** (`V3Typeface.SystemDisplay`) :
 * l'hébreu, le japonais et le coréen passent entiers en police système grasse, un peu plus
 * petits (un idéogramme occupe tout son cadratin), sans l'interligne serré en japonais et en
 * coréen.
 */
data class SystemDisplay(val scale: Float, val tightLeading: Boolean)

fun systemDisplay(language: String = Locale.getDefault().language): SystemDisplay? = when (language) {
    "ja", "ko" -> SystemDisplay(0.84f, tightLeading = false)
    "he", "iw" -> SystemDisplay(0.95f, tightLeading = true)
    else -> null
}

/** À partir de cette taille, un texte en gras est un titre : il prend la police d'affichage. */
const val TITLE_THRESHOLD_SP = 19f

/**
 * **Un titre en Sofia Sans Condensed** (`V3Font.heading`) : Black par défaut, interligne serré
 * (1,05). Suit la taille du texte du téléphone (des `sp`).
 */
fun display(size: TextUnit, weight: FontWeight = FontWeight.Black, lineHeight: Float = 1.05f): TextStyle {
    val system = systemDisplay()
    if (system != null) {
        val scaled = (size.value * system.scale).sp
        return TextStyle(
            fontFamily = FontFamily.Default,
            fontSize = scaled,
            fontWeight = if (weight == FontWeight.Black) FontWeight.ExtraBold else FontWeight.Bold,
            lineHeight = if (system.tightLeading) (lineHeight + 0.05f).em else TextUnit.Unspecified,
        )
    }
    return TextStyle(
        fontFamily = SofiaCondensed,
        fontSize = size,
        fontWeight = weight,
        lineHeight = lineHeight.em,
        lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None),
    )
}

/**
 * **Le texte courant, en police système** (Roboto), comme l'iPhone écrit le sien en SF Pro :
 * c'est ce qui le fait suivre la taille du texte du téléphone et écrire toutes les langues.
 */
fun text(size: TextUnit, weight: FontWeight = FontWeight.Normal, lineHeight: TextUnit = TextUnit.Unspecified): TextStyle =
    TextStyle(fontFamily = FontFamily.Default, fontSize = size, fontWeight = weight, lineHeight = lineHeight)

/**
 * **Le style d'un texte d'avant la V3.3**, ramené à la règle de l'iPhone (`V3Typeface`) : à
 * partir de 19 sp, un texte demi-gras ou plus est un titre (Sofia Sans Condensed) ; le reste
 * est en police système. Le nom est resté : il est lu partout.
 */
fun nunito(size: TextUnit, weight: FontWeight = FontWeight.Normal, lineHeight: TextUnit = TextUnit.Unspecified): TextStyle {
    val strong = weight.weight >= FontWeight.SemiBold.weight
    if (strong && size.isSp && size.value >= TITLE_THRESHOLD_SP) {
        val style = display(size, if (weight.weight >= FontWeight.ExtraBold.weight) FontWeight.Black else FontWeight.ExtraBold, 1.1f)
        return if (lineHeight != TextUnit.Unspecified) style.copy(lineHeight = lineHeight) else style
    }
    return text(size, weight, lineHeight)
}

/**
 * **L'échelle typographique du lot 15** (« le texte doit être principal ») : le corps à 20 sp
 * dans la couleur principale, le détail d'une ligne à 17, les mentions à 15, le légal à 13.
 */
object Type {
    /** Le titre d'un écran du parcours : Sofia Black 34, interligne 1,05, deux lignes au plus. */
    val screenTitle: TextStyle get() = display(34.sp)
    /** La bulle de Mika : 19 Medium, couleur principale, interligne 1,3. */
    val bubble: TextStyle get() = text(19.sp, FontWeight.Medium, 25.sp)
    /** Le corps : lignes de liste, contenu de démo, promesses. */
    val body: TextStyle get() = text(20.sp, FontWeight.Medium, 26.sp)
    /** Le détail d'une ligne. */
    val detail: TextStyle get() = text(17.sp, FontWeight.Normal, 23.sp)
    /** Une ligne de réponse. */
    val option: TextStyle get() = text(17.sp, FontWeight.Bold, 22.sp)
    /** Une mention : une source, « en accéléré », la mention d'un prix. */
    val mention: TextStyle get() = text(15.sp, FontWeight.Normal, 20.sp)
    /** Le minuscule obligatoire : Restaurer · Conditions · Confidentialité. */
    val legal: TextStyle get() = text(13.sp, FontWeight.Medium, 17.sp)
    /** Le libellé du bouton principal : Sofia 21. */
    val button: TextStyle get() = display(21.sp, FontWeight.Black, 1.1f)
}

val LocalMicaboColors = staticCompositionLocalOf { Night }

object Micabo {
    val colors: MicaboColors
        @Composable get() = LocalMicaboColors.current
}

/**
 * **Le thème de l'app.** `dark` vrai pour le marine (par défaut), faux pour le clair. Le choix
 * du thème est fait par `MainActivity` (`ThemeChoice`).
 */
@Composable
fun MicaboTheme(dark: Boolean = true, content: @Composable () -> Unit) {
    val colors = micaboColors(dark)
    val scheme = if (dark) {
        darkColorScheme(
            primary = colors.accent,
            onPrimary = Color.White,
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
            onPrimary = Color.White,
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
    CompositionLocalProvider(LocalMicaboColors provides colors) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

/**
 * **Le thème choisi** (`MicaboAppearance`) : le marine pour tout élève qui n'a rien choisi ;
 * « Jour » et « Comme le téléphone » restent au choix dans le Profil. L'ancienne valeur
 * « system », écrite par défaut avant la V3.3, n'est pas un choix : seul `themeChosen` en est un.
 */
fun isNight(theme: String, chosen: Boolean, systemDark: Boolean): Boolean {
    if (!chosen) return true
    return when (theme) {
        "light" -> false
        "dark" -> true
        else -> systemDark
    }
}
