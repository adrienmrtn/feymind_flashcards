package com.micabo.app.ui.components

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.micabo.app.ui.theme.Micabo

/**
 * **Les humeurs de Mika** (`MikaMood`, `design/mika-v3/apercu.html`) : ses douze expressions.
 * Mika est **dessiné dans le code**, trait pour trait d'après `design/mika-v3/mika.js` : net à
 * toutes les tailles, sans image.
 */
enum class MikaMood {
    IDLE, HAPPY, WAVE, WINK, CELEBRATE, THINK, WRITE, SURPRISE, SAD, SLEEP, LOOK, PROUD;
}

/**
 * **Mika**, la mascotte. Il ne saute pas et ne rebondit jamais (lot 10, « Mika ne saute
 * plus ») : il change d'humeur en fondu, sur place.
 */
@Composable
fun Mika(mood: MikaMood = MikaMood.IDLE, size: Dp = 120.dp, modifier: Modifier = Modifier) {
    val night = Micabo.colors.dark
    Crossfade(targetState = mood, animationSpec = tween(220), label = "mika", modifier = modifier.size(size).clearAndSetSemantics { }) { shown ->
        Canvas(Modifier.size(size)) { drawMika(shown, night) }
    }
}

private object MikaInk {
    val ink = Color(0xFF14182B)
    val pencil = Color(0xFFF7B41F)
    val eraser = Color(0xFFE3596C)
    val cheek = Color(0xFFFF8FA8)
    val wood = Color(0xFFF6DDB6)
    val spark = Color(0xFFF7B41F)
    val tongue = Color(0xFFFF7A8F)
    val air = Color(0xFF8FA9FF)
    val green = Color(0xFF35C28B)
}

private data class Pose(
    val eyes: String = "open",
    val px: Float = 0f,
    val py: Float = 0f,
    val mouth: String = "smile",
    val leftArm: String = "rest",
    val rightArm: String = "pencil",
    val extra: String = "",
)

private fun poseOf(mood: MikaMood) = when (mood) {
    MikaMood.IDLE -> Pose()
    MikaMood.HAPPY -> Pose(eyes = "happy", mouth = "open")
    MikaMood.WAVE -> Pose(leftArm = "wave", mouth = "open")
    MikaMood.WINK -> Pose(eyes = "wink", mouth = "smile")
    MikaMood.CELEBRATE -> Pose(eyes = "happy", mouth = "open", leftArm = "up", rightArm = "up", extra = "confetti")
    MikaMood.THINK -> Pose(px = 8f, py = -13f, mouth = "small", extra = "dots")
    MikaMood.WRITE -> Pose(px = 9f, py = -3f, mouth = "small", rightArm = "tilt", extra = "lines")
    MikaMood.SURPRISE -> Pose(eyes = "wide", mouth = "o")
    MikaMood.SAD -> Pose(py = 6f, mouth = "sad", rightArm = "rest")
    MikaMood.SLEEP -> Pose(eyes = "closed", mouth = "flat", rightArm = "rest", extra = "zzz")
    MikaMood.LOOK -> Pose(px = 10f, py = -2f, mouth = "small")
    MikaMood.PROUD -> Pose(eyes = "happy", mouth = "smile", rightArm = "up")
}

/** Un chemin SVG absolu (M, L, Q, C, Z), comme ceux de `mika.js`. */
internal fun svgPath(data: String): Path {
    val path = Path()
    val tokens = Regex("[MLQCZ]|-?\\d+(?:\\.\\d+)?").findAll(data).map { it.value }.toList()
    var i = 0
    var command = 'M'
    fun n() = tokens[i++].toFloat()
    while (i < tokens.size) {
        val token = tokens[i]
        if (token.length == 1 && token[0].isLetter()) {
            command = token[0]
            i++
            if (command == 'Z') {
                path.close()
                continue
            }
        }
        when (command) {
            'M' -> { path.moveTo(n(), n()); command = 'L' }
            'L' -> path.lineTo(n(), n())
            'Q' -> path.quadraticTo(n(), n(), n(), n())
            'C' -> path.cubicTo(n(), n(), n(), n(), n(), n())
            else -> i++
        }
    }
    return path
}

private val bodyPath by lazy { svgPath("M200 44 C282 44 326 104 326 174 C326 244 274 288 200 288 C126 288 74 244 74 174 C74 104 118 44 200 44 Z") }
private val legs by lazy { listOf(svgPath("M152 262 Q144 300 134 326"), svgPath("M248 262 Q256 300 266 326")) }
private val trunk by lazy { svgPath("M200 270 L200 332") }

private val leftArms = mapOf(
    "rest" to "M110 232 Q66 250 60 298 Q58 318 76 316",
    "wave" to "M106 214 Q58 196 50 142 Q48 124 64 122",
    "up" to "M112 200 Q70 150 74 96",
    "chin" to "M112 240 Q110 290 168 262",
)
private val rightArms = mapOf(
    "pencil" to "M290 232 Q340 240 346 192",
    "up" to "M288 200 Q330 150 326 96",
    "write" to "M290 236 Q330 268 318 300",
    "rest" to "M290 232 Q334 250 340 298 Q342 318 324 316",
    "tilt" to "M290 232 Q340 240 346 192",
)

/** **Dessine Mika** dans la boîte entière, dans le cadrage de la maquette (-10 -30 420 420). */
fun DrawScope.drawMika(mood: MikaMood, night: Boolean) {
    val pose = poseOf(mood)
    val body = if (night) Color(0xFF5C88FF) else Color(0xFF3870FE)
    val shade = if (night) Color(0xFF3F6BE8) else Color(0xFF2A5BE0)
    val scale = size.minDimension / 420f
    withTransform({
        translate(size.width / 2f - 200f * scale, size.height / 2f - 180f * scale)
        scale(scale, scale, Offset.Zero)
    }) {
        val thick = Stroke(width = 46f, cap = StrokeCap.Round, join = StrokeJoin.Round)
        legs.forEach { drawPath(it, shade, style = thick) }
        drawPath(svgPath(leftArms.getValue(pose.leftArm)), body, style = thick)
        drawPath(trunk, body, style = thick)
        drawPath(svgPath(rightArms.getValue(pose.rightArm)), body, style = thick)
        drawPath(bodyPath, body)
        rotate(-28f, Offset(144f, 94f)) {
            drawOval(Color.White.copy(alpha = 0.26f), Offset(144f - 32f, 94f - 15f), Size(64f, 30f))
        }
        pencil(pose, body)
        eyes(pose)
        drawOval(MikaInk.cheek.copy(alpha = 0.8f), Offset(116f - 18f, 212f - 11f), Size(36f, 22f))
        drawOval(MikaInk.cheek.copy(alpha = 0.8f), Offset(284f - 18f, 212f - 11f), Size(36f, 22f))
        mouth(pose)
        extra(pose)
    }
}

private fun DrawScope.pencilAt(x: Float, top: Float) {
    drawRoundRect(MikaInk.pencil, Offset(x, top), Size(22f, 84f), androidx.compose.ui.geometry.CornerRadius(5f))
    drawRoundRect(MikaInk.eraser, Offset(x, top + 72f), Size(22f, 14f), androidx.compose.ui.geometry.CornerRadius(5f))
    drawPath(svgPath("M$x ${top + 4} L${x + 11} ${top - 24} L${x + 22} ${top + 4} Z"), MikaInk.wood)
    drawPath(svgPath("M${x + 6.5f} ${top - 12} L${x + 11} ${top - 24} L${x + 15.5f} ${top - 12} Z"), MikaInk.ink)
}

private fun DrawScope.pencil(pose: Pose, body: Color) {
    when (pose.rightArm) {
        "pencil", "tilt" -> {
            val angle = if (pose.rightArm == "tilt") -24f else 14f
            val pivot = if (pose.rightArm == "tilt") Offset(346f, 192f) else Offset(346f, 150f)
            rotate(angle, pivot) { pencilAt(335f, 88f) }
            drawCircle(body, 23f, Offset(346f, 192f))
        }
        "up" -> {
            rotate(-12f, Offset(326f, 60f)) { pencilAt(315f, 10f) }
            drawCircle(body, 23f, Offset(326f, 96f))
        }
        "write" -> {
            rotate(205f, Offset(318f, 300f)) { pencilAt(307f, 230f) }
            drawCircle(body, 23f, Offset(318f, 300f))
        }
    }
    val spark = (pose.rightArm == "pencil" && pose.extra.isEmpty()) || pose.rightArm == "up"
    if (spark) {
        val at = if (pose.rightArm == "up") Offset(372f, 30f) else Offset(320f, 44f)
        translate(at.x, at.y) {
            drawPath(svgPath("M0 -20 Q4 -4 20 0 Q4 4 0 20 Q-4 4 -20 0 Q-4 -4 0 -20 Z"), MikaInk.spark)
        }
    }
}

private fun DrawScope.eye(cx: Float, kind: String, pose: Pose) {
    val line = Stroke(width = if (kind == "closed") 8f else 9f, cap = StrokeCap.Round)
    when (kind) {
        "happy" -> drawPath(svgPath("M${cx - 22} 176 Q$cx 146 ${cx + 22} 176"), MikaInk.ink, style = line)
        "closed" -> drawPath(svgPath("M${cx - 20} 172 Q$cx 184 ${cx + 20} 172"), MikaInk.ink, style = line)
        else -> {
            val wide = kind == "wide"
            val ry = if (wide) 38f else 34f
            val rx = if (wide) 30f else 28f
            val pr = if (wide) 0.85f else 1f
            val dx = (if (cx < 200) 5f else -5f) + pose.px
            val dy = 6f + pose.py
            drawOval(Color.White, Offset(cx - rx, 166f - ry), Size(rx * 2, ry * 2))
            drawOval(MikaInk.ink, Offset(cx + dx - 15f * pr, 166f + dy - 19f * pr), Size(30f * pr, 38f * pr))
            drawCircle(Color.White, 6f, Offset(cx + dx - 6f, 166f + dy - 9f))
        }
    }
}

private fun DrawScope.eyes(pose: Pose) {
    if (pose.eyes == "wink") {
        eye(158f, "open", pose)
        eye(242f, "happy", pose)
    } else {
        eye(158f, pose.eyes, pose)
        eye(242f, pose.eyes, pose)
    }
}

private fun DrawScope.mouth(pose: Pose) {
    val line = Stroke(width = 7f, cap = StrokeCap.Round)
    when (pose.mouth) {
        "smile" -> drawPath(svgPath("M184 212 Q200 228 216 212"), MikaInk.ink, style = line)
        "open" -> {
            drawPath(svgPath("M178 208 Q200 206 222 208 Q218 240 200 240 Q182 240 178 208 Z"), MikaInk.ink)
            drawPath(svgPath("M188 229 Q200 221 212 229 Q208 240 200 240 Q192 240 188 229 Z"), MikaInk.tongue)
        }
        "o" -> drawOval(MikaInk.ink, Offset(200f - 11f, 220f - 14f), Size(22f, 28f))
        "flat" -> drawPath(svgPath("M188 218 L212 218"), MikaInk.ink, style = line)
        "sad" -> drawPath(svgPath("M186 224 Q200 210 214 224"), MikaInk.ink, style = line)
        "small" -> drawPath(svgPath("M190 214 Q200 222 210 214"), MikaInk.ink, style = line)
    }
}

private fun DrawScope.extra(pose: Pose) {
    when (pose.extra) {
        "dots" -> {
            drawCircle(MikaInk.air, 9f, Offset(318f, 20f))
            drawCircle(MikaInk.air, 11f, Offset(346f, 8f))
            drawCircle(MikaInk.air, 13f, Offset(378f, -6f))
        }
        "lines" -> {
            val line = Stroke(width = 7f, cap = StrokeCap.Round)
            listOf("M262 58 L250 40", "M286 44 L282 22", "M244 80 L226 70").forEach { drawPath(svgPath(it), MikaInk.pencil, style = line) }
        }
        "zzz" -> {
            // Deux « z » en traits, à la place du texte de la maquette.
            val line = Stroke(width = 7f, cap = StrokeCap.Round, join = StrokeJoin.Round)
            drawPath(svgPath("M302 42 L326 42 L302 70 L326 70"), MikaInk.air, style = line)
            drawPath(svgPath("M338 14 L354 14 L338 34 L354 34"), MikaInk.air, style = Stroke(width = 5f, cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
        "confetti" -> {
            fun square(x: Float, y: Float, side: Float, angle: Float, color: Color) {
                rotate(angle, Offset(x + side / 2, y + side / 2)) {
                    drawRoundRect(color, Offset(x, y), Size(side, side), androidx.compose.ui.geometry.CornerRadius(3f))
                }
            }
            square(40f, 40f, 14f, 20f, MikaInk.pencil)
            square(350f, 150f, 12f, -15f, MikaInk.eraser)
            drawCircle(MikaInk.green, 7f, Offset(60f, 150f))
            drawCircle(MikaInk.eraser, 7f, Offset(200f, 8f))
            square(120f, 0f, 12f, 30f, MikaInk.air)
            square(280f, -6f, 14f, 12f, MikaInk.green)
        }
    }
}

/** Le cadre qu'occupe Mika dans le dessin (pour les tests : rien ne sort de sa boîte). */
internal val mikaDrawingBounds = Rect(-10f, -30f, 410f, 390f)
