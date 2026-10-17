package com.micabo.app.ui.lesson

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.ApiException
import com.micabo.app.data.ChatMessage
import com.micabo.app.data.MikaChat
import com.micabo.app.data.MikaGate
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.TypingDots
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.home.errorMessage
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.text.plainText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/**
 * **Mika, sur la leçon** (`LessonMikaView`) : une conversation qui connaît les notes par cœur,
 * trois suggestions pour commencer, et une carte de révision quand la réponse en vaut une.
 */
@Composable
fun MikaScreen(id: String) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val lessons by app.lessons.lessons.collectAsState()
    val isPro by app.billing.isPro.collectAsState()
    val lesson = lessons[id]
    if (lesson == null) {
        LeaveWhenMissing()
        return
    }
    val tone = colors.tone(lesson.tone)
    var draft by rememberSaveable { mutableStateOf("") }
    var thinking by remember { mutableStateOf(false) }
    var failure by remember { mutableStateOf<Throwable?>(null) }
    var capped by remember { mutableStateOf(false) }
    val list = rememberLazyListState()
    val chat = lesson.chat

    fun answer() {
        thinking = true
        failure = null
        scope.launch {
            try {
                app.mika.answer(id, isPro)
                haptics.success()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (error: Throwable) {
                if (error is ApiException && error.opensPaywall) {
                    app.prefs.mikaFreeUsed = true
                    navigator.push(Screen.Paywall("pro_required"))
                } else if (error is ApiException && error.isDailyLimit) {
                    capped = true
                } else {
                    failure = error
                }
            } finally {
                thinking = false
            }
        }
    }

    fun send(text: String) {
        if (text.isBlank() || thinking) return
        when (app.mika.gate(isPro)) {
            MikaGate.PAYWALL -> {
                app.analytics.track("mika_blocked", mapOf("reason" to "paywall"))
                navigator.push(Screen.Paywall("pro_required"))
            }
            MikaGate.DAILY_CAP -> {
                app.analytics.track("mika_blocked", mapOf("reason" to "cap"))
                capped = true
            }
            MikaGate.ALLOWED -> {
                app.analytics.track("mika_asked", mapOf("turn" to chat.size / 2 + 1))
                app.mika.ask(id, text)
                draft = ""
                answer()
            }
        }
    }

    LaunchedEffect(chat.size, thinking) {
        val last = chat.size + (if (thinking) 1 else 0)
        if (last > 0) list.animateScrollToItem(last)
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().imePadding()) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CloseButton(onClick = { navigator.back() })
            Spacer(Modifier.width(10.dp))
            Mika(MikaMood.HAPPY, 44.dp)
            Spacer(Modifier.width(6.dp))
            Column(Modifier.weight(1f)) {
                Text("Mika", style = nunito(19.sp, FontWeight.Black), color = colors.ink)
                Text(plainText(lesson.title), style = nunito(13.sp, FontWeight.SemiBold), color = colors.inkSecondary, maxLines = 1)
            }
            if (chat.isNotEmpty()) {
                TextButton(onClick = { app.mika.reset(id); failure = null; capped = false }) {
                    Text(stringResource(R.string.lesson_mika_new), style = nunito(14.sp, FontWeight.ExtraBold), color = colors.accent)
                }
            }
        }
        LazyColumn(
            state = list,
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Bubble(fromMika = true) {
                    Text(stringResource(R.string.lesson_mika_welcome, plainText(lesson.title)), style = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp), color = colors.ink)
                }
            }
            itemsIndexed(chat) { index, message ->
                Message(message, toneInk = tone.ink, onAddCard = {
                    haptics.success()
                    app.mika.addCard(id, index)
                    app.analytics.track("mika_card_added")
                })
            }
            if (thinking) {
                item {
                    Bubble(fromMika = true) { TypingDots(tone.vivid) }
                }
            }
            failure?.let { error ->
                item {
                    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(errorMessage(error), style = nunito(14.sp, FontWeight.SemiBold), color = colors.wrongInk)
                        TextButton(onClick = ::answer) {
                            Icon(Icons.Filled.Refresh, null, tint = colors.accent, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text(stringResource(R.string.lesson_path_retry), style = nunito(15.sp, FontWeight.ExtraBold), color = colors.accent)
                        }
                    }
                }
            }
            if (capped) {
                item {
                    Text(stringResource(R.string.lesson_mika_capReached), style = nunito(14.sp, FontWeight.SemiBold), color = colors.inkSecondary, modifier = Modifier.fillMaxWidth().padding(8.dp))
                }
            }
        }
        if (chat.isEmpty() && !thinking) {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(R.string.lesson_mika_suggestExplain, R.string.lesson_mika_suggestExample, R.string.lesson_mika_suggestQuiz).forEach { suggestion ->
                    val text = stringResource(suggestion)
                    Pressable(onClick = { send(text) }) {
                        Text(
                            text,
                            style = nunito(15.sp, FontWeight.Bold),
                            color = tone.ink,
                            modifier = Modifier
                                .clip(RoundedCornerShape(16.dp))
                                .background(tone.pale)
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                        )
                    }
                }
            }
        }
        Row(
            Modifier
                .navigationBarsPadding()
                .padding(16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(24.dp))
                .padding(start = 16.dp, end = 6.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.weight(1f).padding(vertical = 10.dp)) {
                if (draft.isEmpty()) Text(stringResource(R.string.lesson_mika_placeholder), style = nunito(16.sp, FontWeight.Medium), color = colors.inkTertiary)
                BasicTextField(
                    value = draft,
                    onValueChange = { draft = it.take(MikaChat.MESSAGE_CHARACTERS) },
                    textStyle = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp).copy(color = colors.ink),
                    cursorBrush = SolidColor(colors.accent),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    maxLines = 5,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 22.dp),
                )
            }
            val canSend = draft.isNotBlank() && !thinking
            Pressable(onClick = { send(draft) }, enabled = canSend) {
                Box(
                    Modifier.size(44.dp).clip(CircleShape).background(if (canSend) colors.accent else colors.surfaceSunken),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.AutoMirrored.Filled.Send, stringResource(R.string.lesson_mika_send), tint = if (canSend) colors.onInk else colors.inkTertiary, modifier = Modifier.size(20.dp))
                }
            }
        }
    }
}

@Composable
private fun Bubble(fromMika: Boolean, content: @Composable () -> Unit) {
    val colors = Micabo.colors
    Row(Modifier.fillMaxWidth(), horizontalArrangement = if (fromMika) Arrangement.Start else Arrangement.End) {
        Box(
            Modifier
                .widthIn(max = 320.dp)
                .clip(
                    RoundedCornerShape(
                        topStart = if (fromMika) 6.dp else 20.dp,
                        topEnd = if (fromMika) 20.dp else 6.dp,
                        bottomStart = 20.dp,
                        bottomEnd = 20.dp,
                    ),
                )
                .background(if (fromMika) colors.surface else colors.accent)
                .let { if (fromMika) it.border(1.5.dp, colors.stroke, RoundedCornerShape(topStart = 6.dp, topEnd = 20.dp, bottomStart = 20.dp, bottomEnd = 20.dp)) else it }
                .padding(horizontal = 14.dp, vertical = 11.dp),
        ) { content() }
    }
}

@Composable
private fun Message(message: ChatMessage, toneInk: androidx.compose.ui.graphics.Color, onAddCard: () -> Unit) {
    val colors = Micabo.colors
    val fromMika = message.role != "user"
    Column(Modifier.fillMaxWidth()) {
        Bubble(fromMika) {
            if (fromMika) {
                RichText(message.text, style = nunito(16.sp, FontWeight.Medium, lineHeight = 23.sp), color = colors.ink)
            } else {
                Text(message.text, style = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp), color = colors.onInk)
            }
        }
        message.card?.let { card ->
            Spacer(Modifier.height(6.dp))
            Column(
                Modifier
                    .widthIn(max = 320.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(colors.accentWash)
                    .border(1.5.dp, colors.accent.copy(alpha = 0.35f), RoundedCornerShape(18.dp))
                    .padding(14.dp),
            ) {
                RichText(card.front, style = nunito(15.sp, FontWeight.ExtraBold, lineHeight = 20.sp), color = toneInk)
                Spacer(Modifier.height(4.dp))
                RichText(card.back, style = nunito(14.sp, FontWeight.Medium, lineHeight = 19.sp), color = colors.inkSecondary)
                Spacer(Modifier.height(10.dp))
                run {
                    if (message.cardAdded) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.Check, null, tint = colors.correct, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text(stringResource(R.string.lesson_mika_cardAdded), style = nunito(14.sp, FontWeight.ExtraBold), color = colors.correctInk)
                        }
                    } else {
                        Pressable(onClick = onAddCard) {
                            Text(
                                stringResource(R.string.lesson_mika_addCard),
                                style = nunito(14.sp, FontWeight.ExtraBold),
                                color = colors.onInk,
                                modifier = Modifier.clip(RoundedCornerShape(50)).background(colors.accent).padding(horizontal = 14.dp, vertical = 8.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}
