package com.micabo.app.ui.v3

import android.provider.Settings
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Type
import com.micabo.app.ui.theme.display
import com.micabo.app.ui.theme.text
import kotlinx.coroutines.delay

/** Les mesures de la direction V3.3 (`V3Metric`). */
object V3Metric {
    val margin = 20.dp
    /** La largeur de lecture : au-delà (tablette, pliable ouvert), la colonne se centre. */
    val readable = 600.dp
    val border = 1.5.dp
    val optionHeight = 58.dp
    val chipHeight = 40.dp
    val radiusTile = 14.dp
    val radiusInner = 16.dp
    val radiusBubble = 20.dp
    val radiusCard = 22.dp
    val radiusSheet = 28.dp
}

/** **Un écran court** (moins de 640 dp sous la barre) : Mika et les morceaux d'app se resserrent. */
val LocalCompact = compositionLocalOf { false }

/** **Les tests de rendu** posent l'écran fini : les arrivées animées sont jouées d'avance. */
val LocalStill = compositionLocalOf { false }

/**
 * **Rien ne s'anime** : un rendu de test, un aperçu, ou « Supprimer les animations » dans les
 * réglages du téléphone. Les arrivées animées posent alors leur état final, bouton compris.
 */
@Composable
fun rememberStill(): Boolean {
    val context = LocalContext.current
    val system = remember(context) {
        runCatching { Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f }.getOrDefault(false)
    }
    return LocalStill.current || LocalInspectionMode.current || system
}

/** **Un bloc qui surgit** à sa place (elle est gardée d'avance) : un fondu et une échelle à ressort. */
@Composable
fun Modifier.popIn(visible: Boolean, from: Float = 0.85f): Modifier {
    val scale by animateFloatAsState(if (visible) 1f else from, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMediumLow), label = "pop")
    val alpha by animateFloatAsState(if (visible) 1f else 0f, tween(220), label = "popAlpha")
    return graphicsLayer {
        scaleX = scale
        scaleY = scale
        this.alpha = alpha
    }
}

/** **Un bloc qui monte en fondu** à sa place, après un délai (les lignes en cascade). */
@Composable
fun Modifier.riseIn(visible: Boolean, delayMillis: Int = 0): Modifier {
    val shown by animateFloatAsState(if (visible) 1f else 0f, tween(320, delayMillis = delayMillis), label = "rise")
    return graphicsLayer {
        alpha = shown
        translationY = (1f - shown) * 14.dp.toPx()
    }
}

/**
 * **Le bouton du pied, révélé à la fin de l'animation de l'écran** : avant, il est invisible et
 * inerte, mais garde sa place (rien ne bouge) ; ensuite il arrive en fondu.
 */
@Composable
fun RevealedButton(visible: Boolean, text: String, onClick: () -> Unit, modifier: Modifier = Modifier, icon: ImageVector? = null) {
    val alpha by animateFloatAsState(if (visible) 1f else 0f, tween(300), label = "reveal")
    com.micabo.app.ui.components.MicaboButton(text, onClick, modifier.graphicsLayer { this.alpha = alpha }, enabled = visible, icon = icon)
}

/** Le lavis d'un ton sur la surface (`V3Color.wash(of:)`). */
@Composable
fun wash(tone: Color): Color = lerp(Micabo.colors.surface, tone, if (Micabo.colors.dark) 0.18f else 0.12f)

/** Le filet d'une surface teintée (`V3Color.edge(of:)`). */
@Composable
fun edge(tone: Color): Color = lerp(Micabo.colors.surface, tone, if (Micabo.colors.dark) 0.5f else 0.4f)

/** **Une carte** : la surface, un filet de 1,5 dp ; choisie, le lavis et le filet d'accent. */
@Composable
fun Modifier.v3Card(selected: Boolean = false, radius: Dp = V3Metric.radiusCard, fill: Color? = null): Modifier {
    val colors = Micabo.colors
    val shape = RoundedCornerShape(radius)
    return this
        .clip(shape)
        .background(fill ?: if (selected) colors.accentWash else colors.surface)
        .border(V3Metric.border, if (selected) colors.accent else colors.stroke, shape)
}

/**
 * **Une phrase et son mot-clé** : le groupe entre `**` prend la couleur du mot-clé (le bleu
 * clair, par défaut). Les `**` ne s'affichent jamais.
 */
fun marked(textWithMarks: String, keyword: Color, bold: Boolean = false): AnnotatedString = buildAnnotatedString {
    val parts = textWithMarks.split("**")
    parts.forEachIndexed { index, part ->
        if (index % 2 == 1) {
            withStyle(SpanStyle(color = keyword, fontWeight = if (bold) FontWeight.Bold else null)) { append(part) }
        } else {
            append(part)
        }
    }
}

/** Le texte sans ses marques. */
fun plain(textWithMarks: String) = textWithMarks.replace("**", "")

/** Un blanc qui sépare deux mots ; l'espace insécable (« Salut ! ») garde le signe avec son mot. */
private fun Char.splitsWords() = isWhitespace() && this != '\u00A0' && this != '\u202F'

/** Le dernier caractère de chaque mot d'une phrase : leur nombre, et où reprendre son souffle. */
private fun wordEnds(sentence: String): List<Char> = buildList {
    var end: Char? = null
    for (char in sentence) {
        if (char.splitsWords()) {
            end?.let { add(it) }
            end = null
        } else {
            end = char
        }
    }
    end?.let { add(it) }
}

/**
 * **Une phrase dite mot à mot** : la phrase entière est posée dès le départ (rien ne bouge),
 * les mots pas encore dits sont transparents ; le mot-clé entre `**` garde sa couleur.
 */
fun markedWords(textWithMarks: String, keyword: Color, shown: Int): AnnotatedString = buildAnnotatedString {
    var word = 0
    var between = true
    textWithMarks.split("**").forEachIndexed { index, part ->
        val tone = if (index % 2 == 1) keyword else Color.Unspecified
        // Les caractères de même visibilité partent ensemble, dans un seul style.
        var piece = ""
        var hidden = false
        for (char in part) {
            if (char.splitsWords()) {
                between = true
            } else if (between) {
                between = false
                word += 1
            }
            if ((word > shown) != hidden) {
                if (piece.isNotEmpty()) withStyle(SpanStyle(color = if (hidden) Color.Transparent else tone)) { append(piece) }
                piece = ""
                hidden = word > shown
            }
            piece += char
        }
        if (piece.isNotEmpty()) withStyle(SpanStyle(color = if (hidden) Color.Transparent else tone)) { append(piece) }
    }
}

/** Où en est une phrase dite mot à mot ; `finish` la termine d'un coup (un toucher sur l'écran). */
class WordReveal(val total: Int, start: Int) {
    var shown by mutableIntStateOf(start)
        private set
    val done: Boolean get() = shown >= total

    fun next() {
        if (!done) shown += 1
    }

    fun finish() {
        shown = total
    }
}

/**
 * **Le rythme d'une phrase dite mot à mot** : un mot toutes les 70 ms, un souffle après une
 * ponctuation. `instant` pose la phrase entière (retour en arrière, rendus, animations coupées).
 */
@Composable
fun rememberWordReveal(textWithMarks: String, instant: Boolean): WordReveal {
    val ends = remember(textWithMarks) { wordEnds(plain(textWithMarks)) }
    val reveal = remember(textWithMarks) { WordReveal(ends.size, if (instant) ends.size else 0) }
    LaunchedEffect(reveal) {
        // L'écran finit d'abord de glisser.
        if (!reveal.done) delay(280)
        while (!reveal.done) {
            val last = ends.getOrNull(reveal.shown - 1)
            delay(if (last != null && last in ".!?:,…") 240L else 70L)
            reveal.next()
        }
    }
    return reveal
}

/**
 * **Le titre d'un écran** (`OnbTitle`) : Sofia Black 34 (30 sur un écran court), en haut à
 * gauche, son mot-clé en bleu clair. Il passe à la ligne ; il ne se coupe jamais.
 */
@Composable
fun V3Title(
    text: String,
    modifier: Modifier = Modifier,
    size: Int = 34,
    keyword: Color = Micabo.colors.accentBright,
    align: TextAlign = TextAlign.Start,
) {
    val compact = LocalCompact.current
    val shown = if (compact && size >= 34) size - 4 else size
    Text(
        text = marked(text, keyword),
        style = display(shown.sp),
        color = Micabo.colors.ink,
        textAlign = align,
        modifier = modifier.fillMaxWidth().semantics { heading() },
    )
}

/** Une icône sur son lavis : la pastille des lignes et des listes. */
@Composable
fun IconTile(icon: ImageVector, tone: Color, size: Dp = 44.dp, iconSize: Dp = 24.dp, radius: Dp = V3Metric.radiusTile, fill: Color? = null) {
    Box(
        Modifier.size(size).clip(RoundedCornerShape(radius)).background(fill ?: wash(tone)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = tone, modifier = Modifier.size(iconSize))
    }
}

/** La coche ronde d'une ligne choisie (`V3Check`). */
@Composable
fun V3Check(isOn: Boolean, multiple: Boolean = false) {
    val colors = Micabo.colors
    val shape = if (multiple) RoundedCornerShape(7.dp) else CircleShape
    Box(
        Modifier
            .size(24.dp)
            .clip(shape)
            .background(if (isOn) colors.accent else Color.Transparent)
            .border(if (isOn) 0.dp else 2.dp, if (isOn) Color.Transparent else colors.strokeStrong, shape),
        contentAlignment = Alignment.Center,
    ) {
        if (isOn) Icon(Icons.Rounded.Check, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
    }
}

/**
 * **Une ligne de réponse** (`V3OptionRow`) : 58 dp au moins, une icône ou un emoji, le titre en
 * 17 gras, le détail dessous, la coche. Le titre passe à la ligne.
 */
@Composable
fun V3OptionRow(
    title: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    icon: ImageVector? = null,
    iconTone: Color? = null,
    emoji: String? = null,
    multiple: Boolean = false,
) {
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = V3Metric.optionHeight)
            .v3Card(selected = selected, radius = V3Metric.radiusInner)
            .clickable(role = if (multiple) Role.Checkbox else Role.RadioButton) {
                haptics.selection()
                onClick()
            }
            .semantics { this.selected = selected }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        when {
            icon != null -> Icon(icon, contentDescription = null, tint = iconTone ?: colors.accentBright, modifier = Modifier.size(26.dp))
            emoji != null -> Text(emoji, style = text(22.sp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = Type.option, color = colors.ink)
            if (subtitle != null) Text(subtitle, style = text(15.sp, lineHeight = 20.sp), color = colors.inkSecondary)
        }
        V3Check(selected, multiple)
    }
}

/** **Une puce** (`V3Chip`) : une pilule, une icône et un libellé. */
@Composable
fun V3Chip(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    iconTone: Color? = null,
    selected: Boolean = false,
) {
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    Row(
        modifier = modifier
            .heightIn(min = V3Metric.chipHeight)
            .clip(CircleShape)
            .background(if (selected) colors.accentWash else colors.surface)
            .border(V3Metric.border, if (selected) colors.accent else colors.stroke, CircleShape)
            .clickable(role = Role.Button) {
                haptics.selection()
                onClick()
            }
            .semantics { this.selected = selected }
            .padding(start = if (icon != null) 10.dp else 14.dp, end = 14.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (icon != null) Icon(icon, contentDescription = null, tint = iconTone ?: colors.accentBright, modifier = Modifier.size(18.dp))
        Text(label, style = text(15.sp, FontWeight.SemiBold), color = colors.ink)
    }
}

/** La puce « + Autres matières ». */
@Composable
fun V3AddChip(label: String, onClick: () -> Unit) = V3Chip(label, onClick, icon = Icons.Rounded.Add)

/**
 * **La jauge en chapitres** (`V3ActProgress`) : un segment par chapitre ; le chapitre en
 * cours se remplit à mesure de ses écrans.
 */
@Composable
fun ChapterGauge(chapter: Int, fraction: Float, count: Int, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    Row(modifier.fillMaxWidth().height(8.dp), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        repeat(count) { index ->
            val fill = when {
                index < chapter -> 1f
                index == chapter -> fraction.coerceIn(0.08f, 1f)
                else -> 0f
            }
            Box(Modifier.weight(1f).fillMaxSize().clip(CircleShape).background(colors.progressTrack)) {
                if (fill > 0f) Box(Modifier.fillMaxWidth(fill).fillMaxSize().clip(CircleShape).background(colors.accent))
            }
        }
    }
}

/**
 * **La bulle de Mika qui parle en grand** (`OnbSpeech`) : centrée, sa pointe vers lui. Avec
 * `shownWords`, la phrase est en gras et seuls ses premiers mots sont visibles.
 */
@Composable
fun SpeechBubble(text: String, modifier: Modifier = Modifier, shownWords: Int? = null) {
    val colors = Micabo.colors
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = if (shownWords == null) marked(text, colors.accentBright) else markedWords(text, colors.accentBright, shownWords),
            style = if (shownWords == null) Type.body else Type.body.copy(fontWeight = FontWeight.Bold),
            color = colors.ink,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .clip(RoundedCornerShape(V3Metric.radiusBubble))
                .background(colors.surface)
                .padding(horizontal = 18.dp, vertical = 15.dp),
        )
        androidx.compose.foundation.Canvas(Modifier.size(width = 24.dp, height = 12.dp)) {
            val path = androidx.compose.ui.graphics.Path().apply {
                moveTo(0f, 0f)
                lineTo(size.width, 0f)
                lineTo(size.width / 2f, size.height)
                close()
            }
            drawPath(path, colors.surface)
        }
    }
}

/**
 * **Mika qui réagit, sous le titre** (`OnbMikaRow`) : sa bulle (19–20 sp, texte principal),
 * Mika du côté de fin. La rangée garde la hauteur de Mika : une réplique qui change ne
 * déplace rien.
 */
@Composable
fun MikaRow(say: String, mood: MikaMood, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    // Texte très agrandi : la bulle prend toute la largeur, Mika (décoratif) laisse sa place.
    val roomy = androidx.compose.ui.platform.LocalDensity.current.fontScale < 1.5f
    val size = if (!roomy) 0.dp else if (LocalCompact.current) 76.dp else 96.dp
    Row(modifier.fillMaxWidth().heightIn(min = size), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            text = marked(say, colors.accentBright),
            style = Type.body,
            color = colors.ink,
            modifier = Modifier
                .weight(1f)
                .padding(bottom = size * 0.2f)
                .clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp, bottomStart = 20.dp, bottomEnd = 6.dp))
                .background(colors.surface)
                .padding(horizontal = 14.dp, vertical = 11.dp)
                .testTag("mikaSays"),
        )
        if (roomy) Mika(mood, size)
    }
}

/** **Une ligne rassurante** au-dessus du bouton (« Rien à payer aujourd'hui »), en vert. */
@Composable
fun Reassurance(text: String, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Rounded.CheckCircle, contentDescription = null, tint = colors.green, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(6.dp))
        Text(text, style = Type.mention.copy(fontWeight = FontWeight.SemiBold), color = colors.greenInk, textAlign = TextAlign.Center)
    }
}

/**
 * **L'écran d'une étape** (`OnbScreen`) : la tête (le titre, Mika qui réagit), le corps (les
 * réponses, ou le bloc d'une page au centre optique), et le pied fixe, au-dessus de la barre du
 * système. Le contenu défile s'il dépasse ; le bouton du pied reste toujours visible.
 */
@Composable
fun OnbScreen(
    modifier: Modifier = Modifier,
    centered: Boolean = false,
    header: @Composable ColumnScope.() -> Unit,
    body: @Composable ColumnScope.() -> Unit = {},
    footer: (@Composable ColumnScope.() -> Unit)? = null,
) {
    val colors = Micabo.colors
    BoxWithConstraints(modifier.fillMaxSize().background(colors.canvas)) {
        val compact = maxHeight < 640.dp
        androidx.compose.runtime.CompositionLocalProvider(LocalCompact provides compact) {
            // Sur une tablette ou un pliable ouvert, la colonne garde une largeur de lecture.
            Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
                BoxWithConstraints(Modifier.weight(1f).widthIn(max = V3Metric.readable).fillMaxWidth()) {
                    val viewport = maxHeight
                    Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                        CenteredColumn(
                            minHeight = viewport,
                            centered = centered,
                            modifier = Modifier.fillMaxWidth().padding(horizontal = V3Metric.margin),
                            header = { Column(Modifier.fillMaxWidth(), content = header) },
                            body = { Column(Modifier.fillMaxWidth().padding(bottom = 16.dp), content = body) },
                        )
                    }
                }
                if (footer != null) {
                    Column(
                        Modifier
                            .widthIn(max = V3Metric.readable)
                            .fillMaxWidth()
                            .navigationBarsPadding()
                            .padding(start = V3Metric.margin, end = V3Metric.margin, top = 8.dp, bottom = 16.dp)
                            .testTag("footer"),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        content = footer,
                    )
                } else {
                    Spacer(Modifier.navigationBarsPadding())
                }
            }
        }
    }
}

/**
 * La tête en haut, le corps dessous ; une page centrée pose son corps au centre optique de la
 * place qui reste (un peu plus d'air dessous que dessus). La colonne fait au moins la hauteur
 * de la fenêtre, et défile au-delà.
 */
@Composable
private fun CenteredColumn(minHeight: Dp, centered: Boolean, modifier: Modifier, header: @Composable () -> Unit, body: @Composable () -> Unit) {
    Layout(contents = listOf(header, body), modifier = modifier) { (headerMeasurables, bodyMeasurables), constraints ->
        val loose = constraints.copy(minHeight = 0, maxHeight = androidx.compose.ui.unit.Constraints.Infinity)
        val headers = headerMeasurables.map { it.measure(loose) }
        val bodies = bodyMeasurables.map { it.measure(loose) }
        val headerHeight = headers.sumOf { it.height }
        val bodyHeight = bodies.sumOf { it.height }
        val min = minHeight.roundToPx()
        val height = maxOf(min, headerHeight + bodyHeight)
        val spare = height - headerHeight - bodyHeight
        val bodyTop = if (centered && spare > 0) headerHeight + maxOf(0, spare / 2 - 12.dp.roundToPx()) else headerHeight
        layout(constraints.maxWidth, height) {
            var y = 0
            headers.forEach { it.placeRelative(0, y); y += it.height }
            y = bodyTop
            bodies.forEach { it.placeRelative(0, y); y += it.height }
        }
    }
}

/**
 * **L'ouverture d'un chapitre** (`OnbChapterOpener`) : le titre, un grand Mika et sa bulle. Mika
 * dit sa phrase mot à mot ; le bouton n'arrive qu'à la fin. Toucher l'écran termine la phrase ;
 * `instant` la pose entière (l'écran retrouvé par un retour).
 */
@Composable
fun ChapterOpener(title: String, say: String, mood: MikaMood, cta: String, instant: Boolean = false, onContinue: () -> Unit) {
    val still = rememberStill()
    val reveal = rememberWordReveal(say, instant || still)
    OnbScreen(
        modifier = Modifier.pointerInput(reveal) { detectTapGestures(onTap = { reveal.finish() }) },
        centered = true,
        header = { V3Title(title, Modifier.padding(top = 16.dp)) },
        body = {
            val size = if (LocalCompact.current) 150.dp else 210.dp
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                SpeechBubble(say, shownWords = reveal.shown)
                Mika(mood, size)
            }
        },
        footer = { RevealedButton(reveal.done, cta, onContinue, Modifier.testTag("cta")) },
    )
}

/** Un panneau d'app dans une démo (`OnbPanel`) : une carte, ses lignes espacées. */
@Composable
fun Panel(modifier: Modifier = Modifier, padding: Dp = 18.dp, spacing: Dp = 14.dp, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier.fillMaxWidth().v3Card().padding(padding), verticalArrangement = Arrangement.spacedBy(spacing), content = content)
}

/** La pastille « +10 XP ». */
@Composable
fun XpPill(points: Int) {
    val colors = Micabo.colors
    Text(
        "+$points XP",
        style = display(18.sp, FontWeight.Black),
        color = colors.onYellow,
        modifier = Modifier.clip(CircleShape).background(colors.yellow).padding(horizontal = 12.dp, vertical = 5.dp),
    )
}

/** Un libellé discret, au-dessus d'un groupe (« Les principales »). */
@Composable
fun GroupHeader(text: String) {
    Text(text, style = Type.mention.copy(fontWeight = FontWeight.SemiBold), color = Micabo.colors.inkSecondary, modifier = Modifier.semantics { heading() })
}

/** Une forme de feuille modale. */
val SheetShape: Shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)

/** Un texte qu'on annonce sans le lire deux fois (les visuels de démo). */
fun Modifier.described(text: String) = semantics { contentDescription = text }

/**
 * **Un grand chiffre qui rapetisse plutôt que de se couper** (`minimumScaleFactor` de
 * l'iPhone) : une formule, un prix, une note sur une ligne, même à 200 % de texte.
 */
@Composable
fun FitText(
    text: String,
    style: TextStyle,
    color: Color,
    modifier: Modifier = Modifier,
    align: TextAlign = TextAlign.Start,
    minSize: Int = 12,
) {
    androidx.compose.foundation.text.BasicText(
        text = text,
        style = style.copy(color = color, textAlign = align),
        maxLines = 1,
        autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = minSize.sp, maxFontSize = style.fontSize, stepSize = 1.sp),
        modifier = modifier,
    )
}

/**
 * **Une taille de texte plafonnée**, pour les pastilles et barres de taille fixe (onglets,
 * compteurs) : elles suivent le réglage du téléphone jusqu'à [max], puis s'arrêtent, au lieu
 * de casser leurs mots lettre par lettre. Le contenu, lui, grandit sans plafond.
 */
@Composable
fun CappedFontScale(max: Float = 1.3f, content: @Composable () -> Unit) {
    val density = androidx.compose.ui.platform.LocalDensity.current
    if (density.fontScale <= max) {
        content()
    } else {
        androidx.compose.runtime.CompositionLocalProvider(
            androidx.compose.ui.platform.LocalDensity provides androidx.compose.ui.unit.Density(density.density, max),
            content = content,
        )
    }
}

/** Le style d'un grand chiffre de démo (Sofia 28–44). */
fun figure(size: Int): TextStyle = display(size.sp, FontWeight.Black, 1.0f)
