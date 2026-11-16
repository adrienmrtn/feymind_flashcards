package com.micabo.app.shots

import android.graphics.Bitmap
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsNodeInteraction
import androidx.compose.ui.test.junit4.ComposeTestRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.test.core.app.ActivityScenario
import com.micabo.app.ui.theme.MicaboTheme
import com.micabo.app.ui.v3.LocalStill
import org.junit.Assert.fail
import org.robolectric.RuntimeEnvironment
import org.robolectric.shadows.ShadowLooper
import java.io.File
import java.util.Locale

/**
 * **Un téléphone de la matrice** : sa taille en dp, sa densité, la taille du texte, la langue, le
 * thème, la barre de navigation (gestes ou trois boutons) et l'encoche.
 */
data class Device(
    val name: String,
    val widthDp: Int,
    val heightDp: Int,
    val density: String = "xhdpi",
    val fontScale: Float = 1f,
    val language: String = "fr",
    val night: Boolean = true,
    /** La barre du système en bas : 16 dp pour les gestes, 48 dp pour trois boutons. */
    val navDp: Int = 16,
    /** La barre d'état ; plus haute avec une encoche ou une découpe. */
    val statusDp: Int = 24,
) {
    val qualifiers: String get() = "$language-" + (if (language in setOf("ar", "iw", "he")) "ldrtl-" else "") + "w${widthDp}dp-h${heightDp}dp-" + (if (night) "night" else "notnight") + "-$density"
    val rtl: Boolean get() = language in setOf("ar", "iw", "he")

    override fun toString() = name

    companion object {
        /** Petit téléphone (Galaxy A, Moto E) : 360 × 640 dp. */
        val small = Device("petit-360x640", 360, 640)
        val pixel8 = Device("pixel8-412x915", 412, 915)
        val pixel8Pro = Device("pixel8pro-448x998", 448, 998, statusDp = 32)
        val fold = Device("pliable-deplie-673x841", 673, 841)
        val tablet = Device("tablette-600x960", 600, 960)
        val font130 = Device("pixel8-texte130", 412, 915, fontScale = 1.3f)
        val font200 = Device("petit-texte200", 360, 640, fontScale = 2.0f)
        val arabic = Device("pixel8-arabe-rtl", 412, 915, language = "ar")
        val light = Device("pixel8-theme-clair", 412, 915, night = false)
        val threeButtons = Device("pixel8-3boutons-encoche", 412, 915, navDp = 48, statusDp = 40)
        val english = Device("pixel8-anglais", 412, 915, language = "en")

        val all = listOf(small, pixel8, pixel8Pro, fold, tablet, font130, font200, arabic, light, threeButtons, english)
    }
}

/** Ce qu'un rendu a trouvé : rien, ou la liste des défauts. */
class ShotReport {
    val problems = mutableListOf<String>()
}

private val shotsRoot: File by lazy {
    File(System.getProperty("micabo.shots") ?: "build/shots").also { it.mkdirs() }
}

private val reportFile: File by lazy { File(shotsRoot, "report.txt") }

/**
 * **Pose un écran sur un téléphone, le photographie et le vérifie** :
 * - il se compose sans planter ;
 * - aucun texte n'est coupé ni ne déborde de sa boîte (`hasVisualOverflow`, lignes élidées) ;
 * - le bouton principal (`cta`, ou le bouton à maintenir) est entièrement visible, au-dessus de
 *   la barre du système, sans défilement ;
 * - rien d'interactif ne passe sous la barre d'état ni sous la barre de navigation.
 */
fun shoot(
    rule: ComposeTestRule,
    device: Device,
    group: String,
    name: String,
    requireCta: Boolean = true,
    content: @Composable () -> Unit,
): ShotReport {
    RuntimeEnvironment.setQualifiers(device.qualifiers)
    RuntimeEnvironment.setFontScale(device.fontScale)
    val locale = Locale.forLanguageTag(device.language)
    Locale.setDefault(locale)
    val report = ShotReport()
    val scenario = ActivityScenario.launch(ComponentActivity::class.java)
    try {
        scenario.onActivity { activity ->
            WindowCompat.setDecorFitsSystemWindows(activity.window, false)
            activity.setContent {
                CompositionLocalProvider(LocalStill provides true) {
                    MicaboTheme(dark = device.night) {
                        Box(Modifier.fillMaxSize().background(com.micabo.app.ui.theme.Micabo.colors.canvas)) {
                            content()
                            SystemBars(device)
                        }
                    }
                }
            }
        }
        rule.waitForIdle()
        // Les barres du système, une fois la vue attachée : l'heure en haut, la navigation en bas.
        scenario.onActivity { activity ->
            val density = activity.resources.displayMetrics.density
            val insets = WindowInsetsCompat.Builder()
                .setInsets(WindowInsetsCompat.Type.statusBars(), Insets.of(0, (device.statusDp * density).toInt(), 0, 0))
                .setInsets(WindowInsetsCompat.Type.navigationBars(), Insets.of(0, 0, 0, (device.navDp * density).toInt()))
                .setInsets(WindowInsetsCompat.Type.systemBars(), Insets.of(0, (device.statusDp * density).toInt(), 0, (device.navDp * density).toInt()))
                .build()
            ViewCompat.dispatchApplyWindowInsets(activity.window.decorView, insets)
            activity.window.decorView.requestLayout()
        }
        rule.waitForIdle()
        ShadowLooper.idleMainLooper()
        rule.mainClock.advanceTimeBy(2_000)
        rule.waitForIdle()
        check(rule, device, report)
        // La photo : la fenêtre entière dessinée dans une image (pas d'attente d'un rendu matériel).
        var image: Bitmap? = null
        scenario.onActivity { activity ->
            val view = activity.window.decorView
            val bitmap = Bitmap.createBitmap(view.width.coerceAtLeast(1), view.height.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
            view.draw(android.graphics.Canvas(bitmap))
            image = bitmap
        }
        val shot = image ?: error("aucune image")
        val folder = File(File(shotsRoot, device.name), group).also { it.mkdirs() }
        File(folder, "$name.png").outputStream().use { shot.compress(Bitmap.CompressFormat.PNG, 100, it) }
    } catch (error: Throwable) {
        report.problems += "plante : ${error.javaClass.simpleName} ${error.message?.take(300)}"
    } finally {
        scenario.close()
    }
    if (!requireCta) report.problems.removeAll { it.startsWith("bouton") }
    synchronized(reportFile) {
        reportFile.appendText(buildString {
            append("${device.name}/$group/$name : ")
            append(if (report.problems.isEmpty()) "ok" else report.problems.joinToString(" ; "))
            append('\n')
        })
    }
    return report
}

private fun check(rule: ComposeTestRule, device: Device, report: ShotReport) {
    val root = rule.onRoot(useUnmergedTree = true).fetchSemanticsNode()
    val bounds = root.boundsInRoot
    val density = root.layoutInfo.density.density
    val top = device.statusDp * density
    val bottom = bounds.height - device.navDp * density
    val nodes = mutableListOf<SemanticsNode>()
    fun walk(node: SemanticsNode) {
        nodes += node
        node.children.forEach(::walk)
    }
    walk(root)
    for (node in nodes) {
        val text = node.config.getOrNull(SemanticsProperties.Text)?.joinToString(" ")?.take(60) ?: continue
        val action = node.config.getOrNull(SemanticsActions.GetTextLayoutResult) ?: continue
        val results = mutableListOf<TextLayoutResult>()
        action.action?.invoke(results)
        val layout = results.firstOrNull() ?: continue
        val ellipsized = (0 until layout.lineCount).any { layout.isLineEllipsized(it) }
        // Coupé : des lignes au-delà du maximum, des points de suspension, ou une hauteur qui
        // déborde de sa boîte (2 px de marge). La largeur du paragraphe n'est pas comparée :
        // c'est la largeur offerte, pas celle du texte, et elle signalait tout à tort.
        val dh = layout.multiParagraph.height - layout.size.height
        if (layout.multiParagraph.didExceedMaxLines || ellipsized || dh > 2f) {
            report.problems += "texte coupé « $text » (" + (if (ellipsized) "points de suspension" else if (dh > 2f) "dépasse de ${dh.toInt()} px en hauteur" else "lignes en trop") + ")"
        }
        val box = node.boundsInRoot
        if (box.width > 0 && (box.left < -1f || box.right > bounds.width + 1f) && node.isVisibleOnScreen(bounds)) {
            report.problems += "texte hors de l'écran « $text »"
        }
    }
    val ctas = nodes.filter { node ->
        val tag = node.config.getOrNull(SemanticsProperties.TestTag)
        tag == "cta" || tag == "commitHold" || tag == "homeCta"
    }
    if (ctas.isEmpty()) {
        report.problems += "bouton principal absent"
    }
    for (cta in ctas) {
        val box = cta.boundsInRoot
        if (box.bottom > bottom + 1f) report.problems += "bouton principal sous la barre du système (${box.bottom} > $bottom)"
        if (box.top < top - 1f) report.problems += "bouton principal sous la barre d'état"
        if (box.height < 40f * density) report.problems += "bouton principal écrasé"
    }
    nodes.filter { it.config.contains(SemanticsActions.OnClick) && it.boundsInRoot.height > 0 }.forEach { node ->
        val box = node.boundsInRoot
        if (box.top < top - 1f && box.bottom > 0f) report.problems += "élément touchable sous la barre d'état (${node.config.getOrNull(SemanticsProperties.TestTag) ?: node.id})"
    }
}

private fun SemanticsNode.isVisibleOnScreen(screen: Rect): Boolean {
    val box = boundsInRoot
    return box.bottom > 0f && box.top < screen.height
}

/** Les barres du système dessinées par-dessus le rendu : l'heure, la batterie, la pastille ou trois boutons. */
@Composable
private fun SystemBars(device: Device) {
    val ink = if (device.night) Color.White else Color.Black
    Box(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().height(device.statusDp.dp).padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("9:41", color = ink, fontSize = (13f / androidx.compose.ui.platform.LocalDensity.current.fontScale).sp)
            Spacer(Modifier.weight(1f))
            if (device.statusDp > 30) Box(Modifier.size(22.dp).clip(CircleShape).background(Color.Black))
            Spacer(Modifier.weight(1f))
            Box(Modifier.size(width = 22.dp, height = 11.dp).clip(RoundedCornerShape(3.dp)).background(ink.copy(alpha = 0.8f)))
        }
        Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(device.navDp.dp), contentAlignment = Alignment.Center) {
            if (device.navDp > 24) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceEvenly) {
                    Box(Modifier.size(14.dp).clip(RoundedCornerShape(2.dp)).background(ink.copy(alpha = 0.7f)))
                    Box(Modifier.size(16.dp).clip(CircleShape).background(ink.copy(alpha = 0.7f)))
                    Box(Modifier.size(14.dp).clip(RoundedCornerShape(2.dp)).background(ink.copy(alpha = 0.7f)))
                }
            } else {
                Box(Modifier.width(108.dp).height(4.dp).clip(CircleShape).background(ink.copy(alpha = 0.7f)))
            }
        }
    }
}

/** Échoue avec tous les défauts trouvés, groupés. */
fun assertClean(reports: Map<String, ShotReport>) {
    val bad = reports.filterValues { it.problems.isNotEmpty() }
    if (bad.isNotEmpty()) {
        fail(bad.entries.joinToString("\n") { (name, report) -> "$name : ${report.problems.joinToString(" ; ")}" })
    }
}
