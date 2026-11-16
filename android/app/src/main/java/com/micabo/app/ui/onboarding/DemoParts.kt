package com.micabo.app.ui.onboarding

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.i18n.t
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.text
import com.micabo.app.ui.v3.MicaboIcons
import com.micabo.app.ui.v3.wash
import java.time.LocalDate
import java.time.format.TextStyle

/** **Les cinq façons d'apporter un cours** (`OnbSource`) : PDF, cours enregistré, photo, YouTube, texte. */
enum class OnbSource(val titleKey: String) {
    PDF("ios.sup.source.pdf"),
    LECTURE("ios.sup.source.lecture"),
    PHOTO("ios.sup.source.photo"),
    YOUTUBE("ios.sup.source.youtube"),
    TEXT("ios.sup.source.text");

    val icon: ImageVector
        get() = when (this) {
            PDF -> MicaboIcons.pdf
            LECTURE -> MicaboIcons.audio
            PHOTO -> MicaboIcons.photo
            YOUTUBE -> MicaboIcons.youtube
            TEXT -> MicaboIcons.text
        }

    @Composable
    fun tone(): Color {
        val colors = Micabo.colors
        return when (this) {
            PDF -> colors.iconOrange
            LECTURE -> colors.iconPink
            PHOTO -> colors.iconBlue
            YOUTUBE -> colors.iconYellow
            TEXT -> colors.iconGreen
        }
    }
}

/** **Le bandeau des sources** : cinq tuiles, leur nom dessous (deux lignes au plus). */
@Composable
fun SourceStrip(highlighted: OnbSource? = null, tile: Int = 46, modifier: Modifier = Modifier) {
    val colors = Micabo.colors
    LeftToRight {
        Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Top) {
            OnbSource.entries.forEach { source ->
                val tone = source.tone()
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(
                        Modifier
                            .size(tile.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(wash(tone))
                            .border(if (source == highlighted) 2.dp else 0.dp, if (source == highlighted) tone else Color.Transparent, RoundedCornerShape(14.dp)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(source.icon, null, tint = tone, modifier = Modifier.size((tile * 0.55f).dp))
                    }
                    androidx.compose.foundation.text.BasicText(
                        t(source.titleKey),
                        style = text(13.sp, FontWeight.SemiBold, 16.sp).copy(
                            color = if (source == highlighted || highlighted == null) colors.ink else colors.inkSecondary,
                            textAlign = TextAlign.Center,
                        ),
                        maxLines = 2,
                        autoSize = androidx.compose.foundation.text.TextAutoSize.StepBased(minFontSize = 8.sp, maxFontSize = 13.sp, stepSize = 0.5.sp),
                    )
                }
            }
        }
    }
}

/** **Une page de cahier** photographiée : des lignes, un titre, une formule, sans texte lisible. */
@Composable
fun NotebookPhoto(modifier: Modifier = Modifier) {
    val paper = Color(0xFFFBF8EF)
    val rule = Color(0xFFB9C7E8)
    val ink = Color(0xFF2A3A6B)
    Box(modifier.clip(RoundedCornerShape(12.dp)).background(paper)) {
        Canvas(Modifier.matchParentSize()) {
            val gap = size.height / 9f
            for (index in 1..8) {
                val y = gap * index
                drawLine(rule, Offset(0f, y), Offset(size.width, y), strokeWidth = 1.5f)
            }
            drawLine(Color(0xFFE79AA6), Offset(size.width * 0.12f, 0f), Offset(size.width * 0.12f, size.height), strokeWidth = 2f)
            val line = Stroke(width = 3f, cap = StrokeCap.Round)
            listOf(0.55f to 0.7f, 0.42f to 0.5f, 0.6f to 0.62f, 0.3f to 0.45f).forEachIndexed { row, (start, length) ->
                val y = gap * (row * 2 + 1) - gap * 0.25f
                val path = Path().apply {
                    moveTo(size.width * 0.16f, y)
                    var x = size.width * 0.16f
                    val end = size.width * (0.16f + length * 0.8f)
                    var up = true
                    while (x < end) {
                        x += 9f
                        lineTo(x, y + if (up) -4f else 3f)
                        up = !up
                    }
                }
                drawPath(path, ink.copy(alpha = if (row == 0) 0.9f else 0.6f), style = line)
                if (start > 1f) drawCircle(ink, 2f)
            }
        }
    }
}

/** **Le cadre de visée** d'un appareil photo : quatre coins arrondis. */
@Composable
fun Viewfinder(color: Color, modifier: Modifier = Modifier, arm: Float = 28f, radius: Float = 12f) {
    Canvas(modifier) {
        val stroke = Stroke(width = 4.dp.toPx(), cap = StrokeCap.Round)
        val a = arm.dp.toPx()
        val r = radius.dp.toPx()
        val corners = listOf(Triple(0f, 0f, 1f to 1f), Triple(size.width, 0f, -1f to 1f), Triple(size.width, size.height, -1f to -1f), Triple(0f, size.height, 1f to -1f))
        corners.forEach { (x, y, signs) ->
            val (h, v) = signs
            val path = Path().apply {
                moveTo(x, y + v * a)
                lineTo(x, y + v * r)
                quadraticTo(x, y, x + h * r, y)
                lineTo(x + h * a, y)
            }
            drawPath(path, color, style = stroke)
        }
    }
}

/** **Une semaine du calendrier** (`V3WeekStrip`) : l'initiale du jour, son chiffre, un point. */
@Composable
fun WeekStrip(start: LocalDate, selected: Int, modifier: Modifier = Modifier, done: Int = 0, event: Int? = null, onPick: ((Int) -> Unit)? = null) {
    val colors = Micabo.colors
    val locale = currentLocale
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        (0 until 7).forEach { offset ->
            val day = start.plusDays(offset.toLong())
            val isSelected = offset == selected
            Column(
                Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(day.dayOfWeek.getDisplayName(TextStyle.NARROW, locale), style = text(15.sp), color = if (isSelected) colors.accentBright else colors.inkSecondary)
                Box(
                    Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(
                            when {
                                isSelected -> colors.accent
                                offset < done -> wash(colors.green)
                                else -> colors.surfaceMuted
                            },
                        )
                        .then(if (onPick != null) Modifier.clickable { onPick(offset) } else Modifier),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("${day.dayOfMonth}", style = text(19.sp, FontWeight.Bold), color = if (isSelected) Color.White else colors.ink)
                }
                Box(Modifier.size(6.dp).clip(CircleShape).background(if (offset == event) colors.yellow else if (offset < done) colors.green else Color.Transparent))
            }
        }
    }
}

