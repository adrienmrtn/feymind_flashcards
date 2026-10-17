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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
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
import com.micabo.app.data.CardEntry
import com.micabo.app.data.Flashcard
import com.micabo.app.data.Lesson
import com.micabo.app.data.Mastery
import com.micabo.app.data.Rating
import com.micabo.app.data.cardEntries
import com.micabo.app.data.mastery
import com.micabo.app.data.studyQueue
import com.micabo.app.ui.text.plainText
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

private val Mastery.titleRes: Int
    get() = when (this) {
        Mastery.NEW -> R.string.lesson_cards_mastery_new
        Mastery.LEARNING -> R.string.lesson_cards_mastery_learning
        Mastery.MASTERED -> R.string.lesson_cards_mastery_mastered
    }

/**
 * Un texte à trou qui a bien son trou (`Flashcard.format`) ; sans lui, la carte se lit en recto
 * verso, sinon son verso ne s'afficherait jamais.
 */
private val Flashcard.isCloze: Boolean get() = kind == "cloze" && GAP in front

@Composable
private fun Mastery.color(tone: Tone): Color = when (this) {
    Mastery.NEW -> Micabo.colors.accent
    Mastery.LEARNING -> Micabo.colors.toneVivid[1]
    Mastery.MASTERED -> Micabo.colors.correct
}

/**
 * **Les flashcards de la leçon** (`LessonCardsHub`) : où en est chaque carte (nouvelle, en
 * cours, maîtrisée), puis une séance — les cartes à revoir d'abord, quinze nouvelles au plus.
 * Chaque note (« À revoir », « Bien », « Facile ») fixe le prochain rappel, par SM-2.
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
    var running by remember { mutableStateOf<List<CardEntry>?>(null) }
    TrackTime(id)
    AnimatedContent(targetState = running, transitionSpec = { fadeIn(tween(220)) togetherWith fadeOut(tween(160)) }, label = "cards") { cards ->
        if (cards == null) {
            CardsHub(lesson, onClose = { navigator.back() }, onStart = { running = it })
        } else {
            CardsRun(lesson, cards, onClose = { running = null })
        }
    }
}

@Composable
private fun CardsHub(lesson: Lesson, onClose: () -> Unit, onStart: (List<CardEntry>) -> Unit) {
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    val entries = remember(lesson) { lesson.cardEntries() }
    val queue = remember(lesson) { lesson.studyQueue() }
    val counts = remember(entries) { entries.groupingBy { it.review.mastery }.eachCount() }
    val shown = remember { Animatable(0f) }
    LaunchedEffect(Unit) { shown.animateTo(1f, tween(900, delayMillis = 150)) }
    LazyColumn(
        Modifier.fillMaxSize().statusBarsPadding(),
        contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 32.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item { CloseButton(onClick = onClose) }
        item {
            Text(stringResource(R.string.lesson_nav_flashcards), style = nunito(36.sp, FontWeight.Black), color = colors.ink, modifier = Modifier.padding(top = 4.dp))
        }
        item {
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(26.dp))
                    .background(colors.surface)
                    .border(1.5.dp, colors.stroke, RoundedCornerShape(26.dp))
                    .padding(20.dp),
            ) {
                Text(stringResource(R.string.lesson_cards_progress), style = nunito(21.sp, FontWeight.ExtraBold), color = colors.ink)
                Spacer(Modifier.height(16.dp))
                Row(
                    Modifier
                        .fillMaxWidth()
                        .height(14.dp)
                        .clip(RoundedCornerShape(50))
                        .background(colors.progressTrack),
                ) {
                    // Les trois parts grandissent ensemble à l'ouverture ; le reste de la barre reste vide.
                    Mastery.entries.forEach { mastery ->
                        val count = counts[mastery] ?: 0
                        if (count > 0) {
                            Box(Modifier.weight((count * shown.value).coerceAtLeast(0.0001f)).fillMaxHeight().background(mastery.color(tone)))
                        }
                    }
                    val rest = entries.size * (1f - shown.value)
                    if (rest > 0.001f || entries.isEmpty()) Spacer(Modifier.weight(rest.coerceAtLeast(0.0001f)))
                }
                Spacer(Modifier.height(14.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                    Mastery.entries.forEach { mastery ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(10.dp).clip(CircleShape).background(mastery.color(tone)))
                            Spacer(Modifier.width(6.dp))
                            Text("${counts[mastery] ?: 0} ${stringResource(mastery.titleRes)}", style = nunito(14.sp, FontWeight.SemiBold), color = colors.ink, maxLines = 1)
                        }
                    }
                }
                Spacer(Modifier.height(18.dp))
                MicaboButton(
                    if (queue.isEmpty()) stringResource(R.string.lesson_cards_reviewAnyway) else stringResource(R.string.lesson_cards_start, queue.size.toString()),
                    enabled = entries.isNotEmpty(),
                    color = tone.vivid,
                    onClick = { onStart(if (queue.isEmpty()) entries.shuffled().take(20) else queue) },
                )
                if (entries.isEmpty()) {
                    Spacer(Modifier.height(10.dp))
                    Text(stringResource(R.string.lesson_cards_empty), style = nunito(15.sp, FontWeight.Medium), color = colors.inkSecondary)
                }
            }
        }
        if (entries.isNotEmpty()) {
            item {
                Text(
                    stringResource(R.string.lesson_cards_all, entries.size.toString()),
                    style = nunito(22.sp, FontWeight.ExtraBold),
                    color = colors.ink,
                    modifier = Modifier.padding(top = 10.dp),
                )
            }
            items(entries, key = { it.key }) { entry ->
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(22.dp))
                        .background(colors.surface)
                        .border(1.5.dp, colors.stroke, RoundedCornerShape(22.dp))
                        .padding(18.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            plainText(if (entry.card.isCloze) entry.card.front.replace(GAP, "____") else entry.card.front),
                            style = nunito(17.sp, FontWeight.ExtraBold, lineHeight = 22.sp),
                            color = tone.ink,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Spacer(Modifier.height(6.dp))
                        Text(
                            plainText(entry.card.back),
                            style = nunito(15.sp, FontWeight.Medium, lineHeight = 20.sp),
                            color = colors.inkSecondary,
                            maxLines = 3,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                    Spacer(Modifier.width(12.dp))
                    Box(Modifier.size(14.dp).clip(CircleShape).background(entry.review.mastery.color(tone)))
                }
            }
        }
    }
}

@Composable
private fun CardsRun(lesson: Lesson, cards: List<CardEntry>, onClose: () -> Unit) {
    val app = LocalApp.current
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    val haptics = rememberHaptics()
    var index by rememberSaveable { mutableIntStateOf(0) }
    var flipped by remember { mutableStateOf(false) }
    val finished = index >= cards.size
    LaunchedEffect(Unit) { app.analytics.track("review_started", mapOf("cards" to cards.size, "lesson" to true)) }
    LaunchedEffect(finished) { if (finished) app.analytics.track("review_finished", mapOf("cards" to cards.size, "lesson" to true)) }

    fun rate(rating: Rating) {
        if (finished) return
        if (rating == Rating.AGAIN) haptics.tap() else haptics.success()
        app.lessons.review(lesson.id, cards[index].key, rating)
        flipped = false
        index += 1
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CloseButton(onClick = onClose)
            Spacer(Modifier.width(14.dp))
            ProgressBar(if (cards.isEmpty()) 0f else index / cards.size.toFloat(), Modifier.weight(1f), color = tone.vivid)
            if (!finished) {
                Spacer(Modifier.width(10.dp))
                Text("${index + 1} / ${cards.size}", style = nunito(15.sp, FontWeight.ExtraBold), color = colors.inkSecondary)
            }
        }
        if (finished) {
            Column(
                Modifier.fillMaxSize().navigationBarsPadding().padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.weight(1f))
                Mika(MikaMood.CELEBRATE, 180.dp)
                Spacer(Modifier.height(14.dp))
                Text("${cards.size} / ${cards.size}", style = nunito(52.sp, FontWeight.Black), color = tone.ink)
                Text(stringResource(R.string.lesson_cards_done), style = nunito(24.sp, FontWeight.Black), color = colors.ink, textAlign = TextAlign.Center)
                Spacer(Modifier.weight(1f))
                MicaboButton(stringResource(R.string.lesson_quiz_finish), onClick = onClose)
            }
        } else {
            Column(Modifier.fillMaxSize().navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp)) {
                AnimatedContent(
                    targetState = index,
                    transitionSpec = { (scaleIn(initialScale = 0.92f) + fadeIn(tween(220))) togetherWith fadeOut(tween(150)) },
                    modifier = Modifier.weight(1f),
                    label = "card",
                ) { shownIndex ->
                    val card = cards[shownIndex.coerceAtMost(cards.lastIndex)].card
                    CardView(card, tone, flipped, onFlip = { haptics.selection(); flipped = !flipped }, onSwipe = { knew -> rate(if (knew) Rating.GOOD else Rating.AGAIN) })
                }
                Spacer(Modifier.height(16.dp))
                if (flipped) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Box(Modifier.weight(1f)) {
                            MicaboButton(stringResource(R.string.lesson_cards_again), onClick = { rate(Rating.AGAIN) }, color = colors.wrong)
                        }
                        Box(Modifier.weight(1f)) {
                            MicaboButton(stringResource(R.string.lesson_cards_good), onClick = { rate(Rating.GOOD) }, color = tone.vivid)
                        }
                        Box(Modifier.weight(1f)) {
                            MicaboButton(stringResource(R.string.lesson_cards_easy), onClick = { rate(Rating.EASY) }, color = colors.correct)
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
                        if (card.isCloze) card.front.replace(GAP, "**${card.back}**") else card.back
                    } else {
                        if (card.isCloze) card.front.replace(GAP, "_____") else card.front
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
