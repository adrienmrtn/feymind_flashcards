package com.micabo.app.ui.lesson

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.toMutableStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.Flashcard
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Eyebrow
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.components.Waiting
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Tone
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone
import kotlinx.coroutines.launch
import kotlin.math.abs

/**
 * **Les flashcards de la leçon** : on retourne la carte, puis « À revoir » la remet au bout du
 * paquet, « Je sais » la range. Un glissé fait la même chose.
 */
@Composable
fun FlashcardsScreen(id: String) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val lessons by app.lessons.lessons.collectAsState()
    val lesson = lessons[id]
    if (lesson == null) {
        LeaveWhenMissing()
        return
    }
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    val haptics = rememberHaptics()
    val cards = remember(id) { lesson.flashcards }
    val queue = remember(id) { cards.indices.toList().toMutableStateList() }
    var learned by rememberSaveable { mutableIntStateOf(0) }
    var flipped by remember { mutableStateOf(false) }
    var round by remember { mutableIntStateOf(0) }
    TrackTime(id)

    fun next(knew: Boolean) {
        if (queue.isEmpty()) return
        val card = queue.removeAt(0)
        if (knew) {
            haptics.success()
            learned += 1
        } else {
            haptics.tap()
            queue.add(card)
        }
        flipped = false
        round += 1
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CloseButton(onClick = { navigator.back() })
            Spacer(Modifier.width(14.dp))
            ProgressBar(if (cards.isEmpty()) 0f else learned / cards.size.toFloat(), Modifier.weight(1f), color = tone.vivid)
            Spacer(Modifier.width(10.dp))
            Text("$learned/${cards.size}", style = nunito(15.sp, FontWeight.ExtraBold), color = colors.inkSecondary)
        }
        when {
            cards.isEmpty() -> Waiting(stringResource(R.string.lesson_cards_empty), Modifier.fillMaxSize())
            queue.isEmpty() -> Column(
                Modifier.fillMaxSize().navigationBarsPadding().padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.weight(1f))
                Mika(MikaMood.CELEBRATE, 180.dp)
                Spacer(Modifier.height(14.dp))
                Text(stringResource(R.string.lesson_cards_done), style = nunito(28.sp, FontWeight.Black), color = colors.ink, textAlign = TextAlign.Center)
                Spacer(Modifier.height(6.dp))
                Text(
                    stringResource(R.string.lesson_cards_total, cards.size.toString(), learned.toString()),
                    style = nunito(16.sp, FontWeight.SemiBold),
                    color = colors.inkSecondary,
                )
                Spacer(Modifier.weight(1f))
                MicaboButton(stringResource(R.string.lesson_quiz_finish), onClick = { navigator.back() })
            }
            else -> Column(Modifier.fillMaxSize().navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
                AnimatedContent(
                    targetState = round,
                    transitionSpec = { (scaleIn(initialScale = 0.92f) + fadeIn(tween(220))) togetherWith fadeOut(tween(150)) },
                    modifier = Modifier.weight(1f),
                    label = "card",
                ) { _ ->
                    val card = cards[queue.firstOrNull() ?: 0]
                    CardView(card, tone, flipped, onFlip = { haptics.selection(); flipped = !flipped }, onSwipe = { next(it) })
                }
                Spacer(Modifier.height(16.dp))
                if (flipped) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Box(Modifier.weight(1f)) {
                            MicaboButton(stringResource(R.string.lesson_cards_again), onClick = { next(false) }, color = colors.wrong)
                        }
                        Box(Modifier.weight(1f)) {
                            MicaboButton(stringResource(R.string.lesson_cards_good), onClick = { next(true) }, color = colors.correct)
                        }
                    }
                } else {
                    MicaboButton(stringResource(R.string.lesson_cards_flip), onClick = { haptics.selection(); flipped = true }, color = tone.vivid)
                }
            }
        }
    }
}

@Composable
private fun CardView(card: Flashcard, tone: Tone, flipped: Boolean, onFlip: () -> Unit, onSwipe: (Boolean) -> Unit) {
    val colors = Micabo.colors
    val rotation by animateFloatAsState(if (flipped) 180f else 0f, spring(dampingRatio = 0.75f, stiffness = Spring.StiffnessLow), label = "flip")
    val drag = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    Box(
        Modifier
            .fillMaxSize()
            .pointerInput(flipped) {
                detectHorizontalDragGestures(
                    onDragEnd = {
                        val value = drag.value
                        scope.launch {
                            if (flipped && abs(value) > 220f) onSwipe(value > 0) else drag.animateTo(0f, spring())
                        }
                    },
                    onDragCancel = { scope.launch { drag.animateTo(0f) } },
                    onHorizontalDrag = { change, amount ->
                        change.consume()
                        scope.launch { drag.snapTo(drag.value + amount) }
                    },
                )
            }
            .graphicsLayer {
                translationX = drag.value
                rotationZ = drag.value / 40f
            },
    ) {
        Pressable(onClick = onFlip, haptic = false, modifier = Modifier.fillMaxSize()) {
            Box(
                Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        rotationY = rotation
                        cameraDistance = 14f * density
                    }
                    .clip(RoundedCornerShape(28.dp))
                    .background(if (rotation <= 90f) colors.surface else tone.pale)
                    .border(2.dp, if (rotation <= 90f) colors.stroke else tone.vivid.copy(alpha = 0.5f), RoundedCornerShape(28.dp))
                    .padding(24.dp),
                contentAlignment = Alignment.Center,
            ) {
                val back = rotation > 90f
                Column(
                    Modifier.graphicsLayer { rotationY = if (back) 180f else 0f },
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Eyebrow(stringResource(if (back) R.string.lesson_cards_answer else R.string.lesson_cards_question), tone.ink)
                    Spacer(Modifier.height(16.dp))
                    val text = if (back) {
                        if (card.kind == "cloze") card.front.replace(GAP, "**${card.back}**") else card.back
                    } else {
                        if (card.kind == "cloze") card.front.replace(GAP, "_____") else card.front
                    }
                    RichText(
                        text,
                        style = nunito(if (back) 22.sp else 24.sp, FontWeight.ExtraBold, lineHeight = 31.sp),
                        textAlign = TextAlign.Center,
                    )
                    if (!back) {
                        Spacer(Modifier.height(24.dp))
                        Text(stringResource(R.string.ios_onb_train_reveal), style = nunito(14.sp, FontWeight.SemiBold), color = colors.inkTertiary, textAlign = TextAlign.Center)
                    }
                }
            }
        }
    }
}
