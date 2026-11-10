package com.micabo.app.ui.exercise

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.micabo.app.R
import com.micabo.app.data.ApiException
import com.micabo.app.data.MikaGate
import com.micabo.app.data.PhotoImport
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboSecondaryButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MikaSays
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.TypingDots
import com.micabo.app.ui.components.Waiting
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.home.errorMessage
import com.micabo.app.ui.lesson.Bubble
import com.micabo.app.ui.lesson.Message
import com.micabo.app.ui.lesson.MikaInput
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import kotlinx.coroutines.launch
import kotlin.coroutines.cancellation.CancellationException

/** Moins de signes que ça : l'OCR n'a rien lu d'utile sur la photo. */
private const val MIN_TEXT = 12

/** L'activité sous un contexte, même enveloppé. */
private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

/**
 * **Scanner un exo** (« Mika · Exercice ») : une page, prise au scanner de documents ou choisie
 * dans la galerie, lue sur le téléphone par l'OCR des imports ; puis Mika l'explique pas à pas,
 * dans une conversation hors leçon. La porte est celle de Mika : une question offerte, puis Pro.
 */
@Composable
fun ExerciseScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val context = LocalContext.current
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val session = app.mika.exercise
    val isPro by app.billing.isPro.collectAsState()
    var reading by remember { mutableStateOf(false) }
    var unreadable by rememberSaveable { mutableStateOf(false) }
    var thinking by remember { mutableStateOf(false) }
    var failure by remember { mutableStateOf<Throwable?>(null) }
    var capped by remember { mutableStateOf(false) }
    var draft by rememberSaveable { mutableStateOf("") }
    val title = stringResource(R.string.kx_exercise_attachment)
    val firstMessage = stringResource(R.string.kx_exercise_firstMessage)
    val list = rememberLazyListState()

    fun answer() {
        thinking = true
        failure = null
        scope.launch {
            try {
                app.mika.answerExercise(session, isPro)
                haptics.success()
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (error: Throwable) {
                if (error is ApiException && error.opensPaywall) {
                    app.prefs.mikaFreeUsed = true
                    navigator.push(Screen.Paywall("pro_required", trigger = "mika"))
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

    /** Envoie une question à Mika, si sa porte l'accepte ; rend vrai si elle est partie. */
    fun send(text: String): Boolean {
        if (text.isBlank() || thinking || session.isEmpty) return false
        return when (app.mika.gate(isPro)) {
            MikaGate.PAYWALL -> {
                app.analytics.track("mika_blocked", mapOf("reason" to "paywall", "exercise" to true))
                navigator.push(Screen.Paywall("pro_required", trigger = "mika"))
                false
            }
            MikaGate.DAILY_CAP -> {
                app.analytics.track("mika_blocked", mapOf("reason" to "cap", "exercise" to true))
                capped = true
                false
            }
            MikaGate.ALLOWED -> {
                app.analytics.track("mika_asked", mapOf("turn" to session.messages.size / 2 + 1, "exercise" to true))
                session.ask(text)
                answer()
                true
            }
        }
    }

    fun read(uri: Uri?) {
        if (uri == null) return
        reading = true
        unreadable = false
        failure = null
        capped = false
        scope.launch {
            val text = try {
                PhotoImport.read(context, listOf(uri), title).text
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (error: Exception) {
                ""
            }
            reading = false
            if (text.trim().length < MIN_TEXT) {
                unreadable = true
                haptics.error()
                app.analytics.track("exercise_unreadable")
                return@launch
            }
            session.start(title, text)
            app.analytics.track("exercise_scanned", mapOf("chars" to text.length))
            send(firstMessage)
        }
    }

    val scanner = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            read(GmsDocumentScanningResult.fromActivityResultIntent(result.data)?.pages?.firstOrNull()?.imageUri)
        }
    }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri -> read(uri) }

    fun pick() = picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))

    fun scan() {
        val activity = context.findActivity() ?: return pick()
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(1)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        // Sans les services Google Play à jour, le scanner ne s'ouvre pas : la galerie prend le relais.
        GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
            .addOnSuccessListener { sender -> scanner.launch(IntentSenderRequest.Builder(sender).build()) }
            .addOnFailureListener { pick() }
    }

    LaunchedEffect(session.messages.size, thinking) {
        val last = session.messages.size + (if (thinking) 1 else 0)
        if (!session.isEmpty && last > 0) list.animateScrollToItem(last)
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().imePadding()) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CloseButton(onClick = { navigator.back() })
            Spacer(Modifier.width(10.dp))
            Mika(MikaMood.HAPPY, 44.dp)
            Spacer(Modifier.width(6.dp))
            Text(stringResource(R.string.kx_exercise_title), style = nunito(19.sp, FontWeight.Black), color = colors.ink, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (!session.isEmpty) {
                TextButton(onClick = { session.clear(); failure = null; capped = false; unreadable = false }, enabled = !thinking) {
                    Text(stringResource(R.string.kx_exercise_new), style = nunito(14.sp, FontWeight.ExtraBold), color = colors.accent)
                }
            }
        }
        when {
            reading -> Waiting(stringResource(R.string.kx_exercise_reading), Modifier.fillMaxSize())
            session.isEmpty -> Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .navigationBarsPadding()
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.height(24.dp))
                Icon3D(if (unreadable) "loupe" else "fiche", 120.dp)
                Spacer(Modifier.height(24.dp))
                MikaSays(
                    stringResource(if (unreadable) R.string.kx_exercise_unreadable else R.string.kx_exercise_intro),
                    mood = if (unreadable) MikaMood.SAD else MikaMood.WAVE,
                    size = 72.dp,
                )
                Spacer(Modifier.height(28.dp))
                MicaboButton(stringResource(if (unreadable) R.string.kx_exercise_retake else R.string.kx_exercise_camera), onClick = ::scan)
                Spacer(Modifier.height(10.dp))
                MicaboSecondaryButton(stringResource(R.string.kx_exercise_library), onClick = ::pick)
            }
            else -> {
                LazyColumn(
                    state = list,
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    item { Attachment(session.title, session.text) }
                    itemsIndexed(session.messages) { _, message ->
                        Message(message, toneInk = colors.accent, onAddCard = {})
                    }
                    if (thinking) {
                        item { Bubble(fromMika = true) { TypingDots(colors.accentVivid) } }
                    }
                    failure?.let { error ->
                        item {
                            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(errorMessage(error), style = nunito(14.sp, FontWeight.SemiBold), color = colors.wrongInk, textAlign = TextAlign.Center)
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
                    // Revenu du paywall avant la première explication : la question attend d'un toucher.
                    if (session.messages.isEmpty() && !thinking) {
                        item {
                            Pressable(onClick = { send(firstMessage) }) {
                                Text(
                                    firstMessage,
                                    style = nunito(15.sp, FontWeight.Bold),
                                    color = colors.accent,
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(16.dp))
                                        .background(colors.accentWash)
                                        .padding(horizontal = 14.dp, vertical = 10.dp),
                                )
                            }
                        }
                    }
                }
                MikaInput(
                    draft = draft,
                    placeholder = stringResource(R.string.kx_exercise_placeholder),
                    enabled = !thinking,
                    onDraft = { draft = it },
                    onSend = { if (send(draft)) draft = "" },
                )
            }
        }
    }
}

/** **La pièce jointe** : l'exercice tel que l'OCR l'a lu ; un toucher le déplie. */
@Composable
private fun Attachment(title: String, text: String) {
    val colors = Micabo.colors
    var open by rememberSaveable { mutableStateOf(false) }
    Pressable(onClick = { open = !open }, haptic = false) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(20.dp))
                .padding(14.dp)
                .animateContentSize(),
        ) {
            Icon3D("fiche", 40.dp)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(title, style = nunito(15.sp, FontWeight.ExtraBold), color = colors.ink)
                Spacer(Modifier.height(4.dp))
                Text(
                    text.trim(),
                    style = nunito(14.sp, FontWeight.Medium, lineHeight = 19.sp),
                    color = colors.inkSecondary,
                    maxLines = if (open) Int.MAX_VALUE else 3,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}
