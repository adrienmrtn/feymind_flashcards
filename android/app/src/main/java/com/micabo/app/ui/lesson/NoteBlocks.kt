package com.micabo.app.ui.lesson

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.NoteBlock
import com.micabo.app.data.ThemeNotes
import com.micabo.app.ui.components.Eyebrow
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.text.FormulaRenderer
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Tone
import com.micabo.app.ui.theme.nunito

private val NOTES = nunito(17.sp, FontWeight.Normal, lineHeight = 26.sp)

/**
 * **Les notes d'un thème**, comme sur iPhone (`ThemeNotesView`) : l'idée en une phrase dans un
 * encadré de la teinte de la leçon, les blocs, puis « À retenir ».
 */
@Composable
fun ThemeNotesView(notes: ThemeNotes, tone: Tone) {
    val colors = Micabo.colors
    val blocks = remember(notes) { notes.blocks.flatMap { NoteBlock.parseAll(it) } }
    Column {
        if (notes.oneLiner.isNotBlank()) {
            ToneBox(stringResource(R.string.lesson_notes_oneLiner), tone) {
                RichText(notes.oneLiner, style = nunito(18.sp, FontWeight.Bold, lineHeight = 25.sp))
            }
            Spacer(Modifier.height(18.dp))
        }
        blocks.forEachIndexed { index, block ->
            val previous = blocks.getOrNull(index - 1)
            val gap = when {
                previous == null -> 0.dp
                previous is NoteBlock.Subtitle -> 10.dp
                block is NoteBlock.Subtitle -> 28.dp
                else -> 18.dp
            }
            Spacer(Modifier.height(gap))
            NoteBlockView(block, tone)
        }
        if (notes.takeaways.isNotEmpty()) {
            Spacer(Modifier.height(22.dp))
            ToneBox(stringResource(R.string.lesson_notes_takeaways), tone) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    notes.takeaways.forEach { line ->
                        Row {
                            Icon(Icons.Filled.Check, null, tint = tone.ink, modifier = Modifier.padding(top = 4.dp).size(16.dp))
                            Spacer(Modifier.width(10.dp))
                            RichText(line, style = NOTES, color = colors.ink)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ToneBox(label: String, tone: Tone, content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(tone.pale)
            .padding(18.dp),
    ) {
        Eyebrow(label, tone.ink)
        Spacer(Modifier.height(8.dp))
        content()
    }
}

@Composable
fun NoteBlockView(block: NoteBlock, tone: Tone) {
    val colors = Micabo.colors
    when (block) {
        is NoteBlock.Subtitle -> Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.width(4.dp).height(22.dp).clip(CircleShape).background(tone.vivid))
            Spacer(Modifier.width(10.dp))
            RichText(block.text, style = nunito(21.sp, FontWeight.ExtraBold, lineHeight = 26.sp), tintsKeywords = false)
        }

        is NoteBlock.Paragraph -> RichText(block.text, style = NOTES, color = colors.ink)

        is NoteBlock.Bullets -> Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            block.items.forEach { item ->
                Row {
                    Box(Modifier.padding(top = 10.dp).size(7.dp).clip(CircleShape).background(tone.vivid))
                    Spacer(Modifier.width(12.dp))
                    RichText(item, style = NOTES, color = colors.ink)
                }
            }
        }

        is NoteBlock.Definition -> Definition(block, colors.keyword)

        is NoteBlock.Dates -> Row(Modifier.horizontalScroll(rememberScrollState()).padding(vertical = 4.dp)) {
            block.items.forEachIndexed { index, (date, text) ->
                Column(Modifier.width(150.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(14.dp).clip(CircleShape).background(tone.vivid))
                        Box(
                            Modifier
                                .weight(1f)
                                .height(3.dp)
                                .background(if (index == block.items.lastIndex) Color.Transparent else tone.vivid.copy(alpha = 0.5f)),
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    RichText(date, style = nunito(17.sp, FontWeight.ExtraBold), color = tone.ink, tintsKeywords = false)
                    Spacer(Modifier.height(2.dp))
                    RichText(text, style = nunito(15.sp, FontWeight.Medium, lineHeight = 20.sp), modifier = Modifier.padding(end = 18.dp))
                }
            }
        }

        is NoteBlock.Formula -> Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(20.dp))
                .padding(18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                FormulaRenderer.plain(block.latex),
                style = nunito(22.sp).copy(fontFamily = FontFamily.Serif, fontStyle = FontStyle.Italic),
                color = colors.ink,
                textAlign = TextAlign.Center,
            )
            block.caption?.let {
                Spacer(Modifier.height(8.dp))
                RichText(it, style = nunito(15.sp, FontWeight.Medium, lineHeight = 20.sp), color = colors.inkSecondary, textAlign = TextAlign.Center)
            }
        }

        is NoteBlock.Example -> Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(colors.surfaceMuted)
                .padding(16.dp),
        ) {
            Eyebrow(stringResource(R.string.lesson_notes_example), colors.inkSecondary)
            Spacer(Modifier.height(6.dp))
            RichText(block.text, style = NOTES)
        }

        is NoteBlock.Steps -> Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(18.dp))
                .padding(16.dp),
        ) {
            block.items.forEachIndexed { index, item ->
                val last = index == block.items.lastIndex
                Row(Modifier.height(IntrinsicSize.Min)) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Box(Modifier.size(30.dp).clip(CircleShape).background(tone.vivid), contentAlignment = Alignment.Center) {
                            Text("${index + 1}", style = nunito(15.sp, FontWeight.Black), color = Color.White)
                        }
                        if (!last) Box(Modifier.width(2.dp).weight(1f).background(tone.vivid.copy(alpha = 0.35f)))
                    }
                    Spacer(Modifier.width(14.dp))
                    RichText(item, style = NOTES, modifier = Modifier.padding(top = 3.dp, bottom = if (last) 0.dp else 16.dp))
                }
            }
        }

        is NoteBlock.Table -> NoteTable(block, tone)

        is NoteBlock.Quote -> Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
            Box(Modifier.width(4.dp).fillMaxHeight().clip(CircleShape).background(tone.vivid))
            Spacer(Modifier.width(14.dp))
            Column {
                Text("“", style = nunito(40.sp, FontWeight.Black, lineHeight = 30.sp), color = tone.vivid)
                RichText(block.text, style = nunito(19.sp, FontWeight.SemiBold, lineHeight = 27.sp).copy(fontStyle = FontStyle.Italic))
                block.author?.let {
                    Spacer(Modifier.height(6.dp))
                    Text("— $it", style = nunito(15.sp, FontWeight.Bold), color = colors.inkSecondary)
                }
            }
        }

        is NoteBlock.Callout -> Callout(block, tone)
    }
}

@Composable
private fun Definition(block: NoteBlock.Definition, keyword: Color) {
    val colors = Micabo.colors
    var open by remember { mutableStateOf(true) }
    val rotation by animateFloatAsState(if (open) 180f else 0f, label = "chevron")
    Pressable(onClick = { open = !open }) {
        Column(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(colors.surface)
                .border(1.5.dp, keyword.copy(alpha = 0.35f), RoundedCornerShape(18.dp))
                .padding(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Eyebrow(stringResource(R.string.lesson_notes_definition), colors.inkSecondary, Modifier.weight(1f))
                Icon(Icons.Filled.KeyboardArrowDown, null, tint = keyword, modifier = Modifier.rotate(rotation))
            }
            Spacer(Modifier.height(4.dp))
            RichText(block.term, style = nunito(19.sp, FontWeight.ExtraBold), color = keyword, tintsKeywords = false)
            AnimatedVisibility(open, enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically()) {
                RichText(block.text, style = NOTES, modifier = Modifier.padding(top = 8.dp))
            }
        }
    }
}

@Composable
private fun Callout(block: NoteBlock.Callout, tone: Tone) {
    val colors = Micabo.colors
    val (ink, wash, emoji, label) = when (block.kind) {
        "why" -> Quad(colors.accent, colors.accentWash, "💡", R.string.lesson_notes_callout_why)
        "mistake" -> Quad(colors.wrongInk, colors.wrongSoft, "⚠️", R.string.lesson_notes_callout_mistake)
        "remember" -> Quad(colors.caution, colors.cautionSoft, "📌", R.string.lesson_notes_callout_remember)
        else -> Quad(tone.ink, tone.pale, "✨", R.string.lesson_notes_callout_tip)
    }
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(wash)
            .padding(16.dp),
    ) {
        Text(emoji, style = nunito(20.sp))
        Spacer(Modifier.width(12.dp))
        Column {
            Text(block.title ?: stringResource(label), style = nunito(15.sp, FontWeight.ExtraBold), color = ink)
            Spacer(Modifier.height(4.dp))
            RichText(block.text, style = NOTES)
        }
    }
}

private data class Quad(val ink: Color, val wash: Color, val emoji: String, val label: Int)

@Composable
private fun NoteTable(block: NoteBlock.Table, tone: Tone) {
    val colors = Micabo.colors
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val fits = block.columns.size * 96 <= maxWidth.value
        val cell: Dp? = if (fits) null else 150.dp
        val content: @Composable () -> Unit = {
            Column(
                Modifier
                    .clip(RoundedCornerShape(18.dp))
                    .border(1.5.dp, colors.stroke, RoundedCornerShape(18.dp)),
            ) {
                TableRow(block.columns, header = true, background = tone.pale, cell = cell, ink = tone.ink)
                block.rows.forEachIndexed { index, row ->
                    TableRow(row, header = false, background = if (index % 2 == 1) colors.surfaceMuted else colors.surface, cell = cell, ink = colors.ink)
                }
            }
        }
        if (fits) content() else Box(Modifier.horizontalScroll(rememberScrollState())) { content() }
    }
}

@Composable
private fun TableRow(cells: List<String>, header: Boolean, background: Color, cell: Dp?, ink: Color) {
    Row(Modifier.background(background).height(IntrinsicSize.Min)) {
        cells.forEach { text ->
            val modifier = if (cell == null) Modifier.weight(1f) else Modifier.width(cell)
            RichText(
                text,
                style = nunito(if (header) 14.sp else 15.sp, if (header) FontWeight.ExtraBold else FontWeight.Medium, lineHeight = 20.sp),
                color = ink,
                tintsKeywords = !header,
                modifier = modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            )
        }
    }
}
