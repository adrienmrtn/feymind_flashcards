package com.micabo.app.ui.lesson

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.Question
import com.micabo.app.ui.components.Eyebrow
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.text.plainText
import com.micabo.app.ui.text.richText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Tone
import com.micabo.app.ui.theme.nunito
import kotlinx.coroutines.delay
import kotlin.random.Random

data class QuizAnswer(val right: Boolean, val picked: Int? = null)

const val GAP = "…"

/**
 * **Une question**, sous ses cinq formes (`QuestionCard.swift`) : QCM, vrai ou faux, phrase à
 * trou, remise en ordre, association. Le retour suit la réponse : Mika, juste ou faux, et
 * pourquoi.
 */
@Composable
fun QuestionCard(
    question: Question,
    tone: Tone,
    seed: Long,
    answered: QuizAnswer?,
    onAnswer: (QuizAnswer) -> Unit,
    modifier: Modifier = Modifier,
    /** Faux pendant un examen blanc : ni retour ni vibration qui trahirait la réponse. */
    reveal: Boolean = true,
) {
    val haptics = rememberHaptics()
    val answer: (QuizAnswer) -> Unit = {
        if (!reveal) haptics.tap() else if (it.right) haptics.success() else haptics.error()
        onAnswer(it)
    }
    Column(modifier.animateContentSize(spring()), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Eyebrow(stringResource(kindLabel(question.kind)), tone.ink)
        when (question.kind) {
            "gap" -> {
                GapSentence(question, tone, answered)
                ChoiceList(question, tone, answered, compact = true, onAnswer = answer)
            }
            "truefalse" -> {
                Prompt(question.prompt)
                TrueFalse(question, answered, answer)
            }
            "order" -> {
                Prompt(question.prompt)
                OrderBuilder(question, tone, seed, answered, answer)
            }
            "match" -> {
                Prompt(question.prompt)
                MatchBoard(question, tone, seed, answered, answer)
            }
            else -> {
                Prompt(question.prompt)
                ChoiceList(question, tone, answered, compact = false, onAnswer = answer)
            }
        }
        AnimatedVisibility(visible = reveal && answered != null, enter = fadeIn(tween(250)) + slideInVertically { it / 3 }) {
            Feedback(question, answered?.right == true)
        }
    }
}

fun kindLabel(kind: String): Int = when (kind) {
    "truefalse" -> R.string.lesson_question_kind_truefalse
    "gap" -> R.string.lesson_question_kind_gap
    "order" -> R.string.lesson_question_kind_order
    "match" -> R.string.lesson_question_kind_match
    else -> R.string.lesson_question_kind_choice
}

@Composable
private fun Prompt(text: String) {
    RichText(text, style = nunito(22.sp, FontWeight.ExtraBold, lineHeight = 28.sp))
}

@Composable
fun Feedback(question: Question, right: Boolean) {
    val colors = Micabo.colors
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(if (right) colors.correctSoft else colors.wrongSoft)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Mika(if (right) MikaMood.HAPPY else MikaMood.SAD, 64.dp)
        Spacer(Modifier.width(12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                stringResource(if (right) R.string.lesson_question_right else R.string.lesson_question_wrong),
                style = nunito(18.sp, FontWeight.ExtraBold),
                color = if (right) colors.correctInk else colors.wrongInk,
            )
            if (!right && (question.kind == "order" || question.kind == "match")) {
                RichText(question.answerText, style = nunito(15.sp, FontWeight.Bold, lineHeight = 20.sp), tintsKeywords = false)
            }
            if (question.why.isNotBlank()) {
                RichText(question.why, style = nunito(15.sp, FontWeight.Medium, lineHeight = 21.sp))
            }
        }
    }
}

/** La secousse d'une mauvaise réponse. */
@Composable
private fun rememberShake(trigger: Boolean): Float {
    val offset = remember { Animatable(0f) }
    LaunchedEffect(trigger) {
        if (trigger) {
            for (x in listOf(10f, -10f, 7f, -7f, 3f, 0f)) offset.animateTo(x, tween(45))
        }
    }
    return offset.value
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChoiceList(question: Question, tone: Tone, answered: QuizAnswer?, compact: Boolean, onAnswer: (QuizAnswer) -> Unit) {
    val items: @Composable (Int) -> Unit = { index ->
        ChoiceButton(
            text = question.choices[index],
            state = when {
                answered == null -> ChoiceState.IDLE
                index == question.answer -> ChoiceState.RIGHT
                answered.picked == index -> ChoiceState.WRONG
                else -> ChoiceState.DIM
            },
            compact = compact,
            shake = answered != null && answered.picked == index && !answered.right,
            onClick = { if (answered == null) onAnswer(QuizAnswer(index == question.answer, index)) },
        )
    }
    if (compact) {
        FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            question.choices.indices.forEach { items(it) }
        }
    } else {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            question.choices.indices.forEach { items(it) }
        }
    }
}

private enum class ChoiceState { IDLE, RIGHT, WRONG, DIM }

@Composable
private fun ChoiceButton(text: String, state: ChoiceState, compact: Boolean, shake: Boolean, onClick: () -> Unit) {
    val colors = Micabo.colors
    val background by animateColorAsState(
        when (state) {
            ChoiceState.RIGHT -> colors.correct
            ChoiceState.WRONG -> colors.wrong
            else -> colors.surface
        },
        label = "choice",
    )
    val ink = when (state) {
        ChoiceState.RIGHT, ChoiceState.WRONG -> Color.White
        ChoiceState.DIM -> colors.inkTertiary
        ChoiceState.IDLE -> colors.ink
    }
    val offset = rememberShake(shake)
    Pressable(onClick = onClick, enabled = state == ChoiceState.IDLE, haptic = false, modifier = Modifier.graphicsLayer { translationX = offset }) {
        Box(
            Modifier
                .then(if (compact) Modifier else Modifier.fillMaxWidth())
                .clip(RoundedCornerShape(16.dp))
                .background(if (state == ChoiceState.IDLE) colors.stroke else Color.Transparent)
                .padding(bottom = if (state == ChoiceState.IDLE) 3.dp else 0.dp),
        ) {
            Row(
                Modifier
                    .then(if (compact) Modifier else Modifier.fillMaxWidth())
                    .clip(RoundedCornerShape(16.dp))
                    .background(background)
                    .border(2.dp, if (state == ChoiceState.IDLE) colors.stroke else Color.Transparent, RoundedCornerShape(16.dp))
                    .padding(horizontal = 16.dp, vertical = if (compact) 12.dp else 15.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                RichText(
                    text,
                    style = nunito(if (compact) 18.sp else 17.sp, FontWeight.Bold, lineHeight = 22.sp),
                    color = ink,
                    tintsKeywords = false,
                    modifier = if (compact) Modifier else Modifier.weight(1f),
                )
                if (state == ChoiceState.RIGHT || state == ChoiceState.WRONG) {
                    Spacer(Modifier.width(8.dp))
                    Icon(if (state == ChoiceState.RIGHT) Icons.Filled.Check else Icons.Filled.Close, null, tint = Color.White, modifier = Modifier.size(20.dp))
                }
            }
        }
    }
}

@Composable
private fun GapSentence(question: Question, tone: Tone, answered: QuizAnswer?) {
    val colors = Micabo.colors
    val parts = question.prompt.split(GAP)
    val word = plainText(question.choices.getOrNull(question.answer).orEmpty())
    val text = buildAnnotatedString {
        append(richText(parts.first(), colors.keyword))
        withStyle(
            SpanStyle(
                color = if (answered != null) colors.correctInk else tone.ink,
                background = if (answered != null) colors.correctSoft else tone.pale,
            ),
        ) { append(if (answered != null) " $word " else " ________ ") }
        if (parts.size > 1) append(richText(parts.drop(1).joinToString(GAP), colors.keyword))
    }
    Text(text, style = nunito(22.sp, FontWeight.ExtraBold, lineHeight = 30.sp), color = colors.ink)
}

@Composable
private fun TrueFalse(question: Question, answered: QuizAnswer?, onAnswer: (QuizAnswer) -> Unit) {
    val colors = Micabo.colors
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        question.choices.take(2).forEachIndexed { index, label ->
            val background by animateColorAsState(
                when {
                    answered == null -> colors.surface
                    index == question.answer -> colors.correct
                    answered.picked == index -> colors.wrong
                    else -> colors.surface
                },
                label = "tf",
            )
            val ink = when {
                answered == null -> if (index == 0) colors.correctInk else colors.wrongInk
                index == question.answer || answered.picked == index -> Color.White
                else -> colors.inkTertiary
            }
            val offset = rememberShake(answered != null && answered.picked == index && !answered.right)
            Pressable(
                onClick = { if (answered == null) onAnswer(QuizAnswer(index == question.answer, index)) },
                enabled = answered == null,
                haptic = false,
                modifier = Modifier.weight(1f).graphicsLayer { translationX = offset },
            ) {
                Column(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(22.dp))
                        .background(background)
                        .border(2.dp, if (answered == null) colors.stroke else Color.Transparent, RoundedCornerShape(22.dp))
                        .padding(vertical = 26.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Box(Modifier.size(40.dp).clip(CircleShape).background(ink.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                        Icon(if (index == 0) Icons.Filled.Check else Icons.Filled.Close, null, tint = ink, modifier = Modifier.size(26.dp))
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(label, style = nunito(19.sp, FontWeight.ExtraBold), color = ink)
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun OrderBuilder(question: Question, tone: Tone, seed: Long, answered: QuizAnswer?, onAnswer: (QuizAnswer) -> Unit) {
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    val pool = remember(question, seed) {
        val order = question.choices.indices.shuffled(Random(seed)).toMutableList()
        if (order == question.choices.indices.toList() && order.size > 1) {
            val first = order[0]; order[0] = order[1]; order[1] = first
        }
        order
    }
    val placed = remember(question) { mutableStateListOf<Int>() }
    LaunchedEffect(answered) {
        if (answered != null && placed.size != question.choices.size) {
            placed.clear()
            placed.addAll(question.choices.indices)
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            placed.forEachIndexed { position, item ->
                val verdict = answered?.let { item == position }
                Pressable(onClick = { if (answered == null) placed.remove(item) }, enabled = answered == null) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(colors.surface)
                            .border(2.dp, when (verdict) { null -> colors.stroke; true -> colors.correct; false -> colors.wrong }, RoundedCornerShape(16.dp))
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            Modifier.size(30.dp).clip(CircleShape).background(when (verdict) { null -> tone.vivid; true -> colors.correct; false -> colors.wrong }),
                            contentAlignment = Alignment.Center,
                        ) { Text("${position + 1}", style = nunito(16.sp, FontWeight.Black), color = Color.White) }
                        Spacer(Modifier.width(12.dp))
                        RichText(question.choices[item], style = nunito(17.sp, FontWeight.Bold, lineHeight = 22.sp), tintsKeywords = false, modifier = Modifier.weight(1f))
                    }
                }
            }
            for (slot in placed.size until question.choices.size) {
                val dash = colors.stroke
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(54.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .drawDashedBorder(dash),
                    contentAlignment = Alignment.CenterStart,
                ) {
                    Text("${slot + 1}", style = nunito(17.sp, FontWeight.Black), color = colors.inkTertiary, modifier = Modifier.padding(start = 22.dp))
                }
            }
        }
        if (answered == null) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                pool.filter { it !in placed }.forEach { item ->
                    Pressable(onClick = { haptics.selection(); placed.add(item) }, haptic = false) {
                        RichText(
                            question.choices[item],
                            style = nunito(16.sp, FontWeight.Bold),
                            tintsKeywords = false,
                            modifier = Modifier
                                .clip(RoundedCornerShape(14.dp))
                                .background(colors.surface)
                                .border(2.dp, colors.stroke, RoundedCornerShape(14.dp))
                                .padding(horizontal = 14.dp, vertical = 11.dp),
                        )
                    }
                }
            }
            MicaboButton(
                stringResource(R.string.lesson_question_check),
                enabled = placed.size == question.choices.size,
                color = tone.vivid,
                onClick = { onAnswer(QuizAnswer(placed.toList() == question.choices.indices.toList())) },
            )
        }
    }
}

private fun Modifier.drawDashedBorder(color: Color): Modifier = this.drawBehind {
        drawRoundRect(
            color = color,
            style = Stroke(width = 2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(14f, 10f))),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(16.dp.toPx()),
        )
    }

@Composable
private fun MatchBoard(question: Question, tone: Tone, seed: Long, answered: QuizAnswer?, onAnswer: (QuizAnswer) -> Unit) {
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    val rightOrder = remember(question, seed) {
        val order = question.matches.indices.shuffled(Random(seed + 3)).toMutableList()
        if (order == question.matches.indices.toList() && order.size > 1) {
            val first = order[0]; order[0] = order[1]; order[1] = first
        }
        order
    }
    val pairs = remember(question) { mutableStateMapOf<Int, Int>() }
    var selected by remember(question) { mutableStateOf<Int?>(null) }
    val palette = colors.toneVivid
    var submitted by remember(question) { mutableStateOf(false) }
    LaunchedEffect(answered) {
        if (answered != null && pairs.size != question.choices.size) {
            pairs.clear()
            question.choices.indices.forEach { pairs[it] = it }
        }
    }
    LaunchedEffect(pairs.size) {
        if (!submitted && answered == null && pairs.size == question.choices.size && question.choices.isNotEmpty()) {
            submitted = true
            delay(250)
            onAnswer(QuizAnswer(pairs.all { it.key == it.value }))
        }
    }

    @Composable
    fun Tile(text: String, color: Color?, isSelected: Boolean, verdict: Boolean?, modifier: Modifier, onClick: () -> Unit) {
        val fill = when (verdict) {
            true -> colors.correctSoft
            false -> colors.wrongSoft
            null -> color?.copy(alpha = 0.16f) ?: colors.surface
        }
        val stroke = when (verdict) {
            true -> colors.correct
            false -> colors.wrong
            null -> color ?: colors.stroke
        }
        Pressable(onClick = onClick, enabled = answered == null, haptic = false, modifier = modifier) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 52.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(fill)
                    .border(if (isSelected) 3.dp else 2.dp, stroke, RoundedCornerShape(14.dp))
                    .padding(horizontal = 10.dp, vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                RichText(text, style = nunito(15.sp, FontWeight.Bold, lineHeight = 19.sp), tintsKeywords = false, textAlign = TextAlign.Center)
            }
        }
    }

    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            question.choices.indices.forEach { left ->
                val color = if (pairs.containsKey(left) || selected == left) palette[left % palette.size] else null
                val verdict = if (answered != null) pairs[left]?.let { it == left } else null
                Tile(question.choices[left], color, selected == left, verdict, Modifier.fillMaxWidth()) {
                    haptics.selection()
                    pairs.remove(left)
                    selected = if (selected == left) null else left
                }
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            rightOrder.forEach { right ->
                val owner = pairs.entries.firstOrNull { it.value == right }?.key
                val color = owner?.let { palette[it % palette.size] }
                val verdict = if (answered != null) owner?.let { it == right } else null
                Tile(question.matches[right], color, false, verdict, Modifier.fillMaxWidth()) {
                    val left = selected ?: return@Tile
                    haptics.selection()
                    if (owner != null) pairs.remove(owner)
                    pairs[left] = right
                    selected = null
                }
            }
        }
    }
}
