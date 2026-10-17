package com.micabo.app.ui.home

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.content.ContextWrapper
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import com.micabo.app.R
import com.micabo.app.data.LessonComposer
import com.micabo.app.data.PhotoImport
import com.micabo.app.data.Support
import com.micabo.app.data.SupportKind
import com.micabo.app.data.YouTubeLink
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.MicaboSecondaryButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito

private const val WORD_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

/** L'icône 3D d'un support. */
private fun SupportKind.icon(): String = when (this) {
    SupportKind.PDF -> "pdf"
    SupportKind.PHOTO -> "fiche"
    SupportKind.YOUTUBE -> "fusee"
    SupportKind.TEXT -> "texte"
}

/**
 * **La barre de l'accueil** : ce qu'on veut apprendre, les supports déposés en pastilles, et
 * « Créer la leçon » dès qu'il y a de quoi.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ComposerCard(composer: LessonComposer, onSend: () -> Unit) {
    val colors = Micabo.colors
    val canSend = composer.canSend
    Column(
        Modifier
            .padding(horizontal = 20.dp, vertical = 14.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(colors.surface)
            .border(2.dp, if (canSend) colors.accent.copy(alpha = 0.5f) else colors.stroke, RoundedCornerShape(24.dp))
            .padding(18.dp)
            .animateContentSize(),
    ) {
        if (composer.supports.isNotEmpty()) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                composer.supports.forEach { support -> SupportChip(support, onRemove = { composer.remove(support.id) }) }
            }
            composer.supports.firstOrNull { it.failure != null }?.failure?.let { failure ->
                Spacer(Modifier.height(8.dp))
                Text(stringResource(failure), style = nunito(13.sp, FontWeight.SemiBold, lineHeight = 18.sp), color = colors.wrongInk)
            }
            Spacer(Modifier.height(12.dp))
        }
        Box {
            if (composer.draft.isEmpty()) {
                Text(
                    stringResource(if (composer.supports.isEmpty()) R.string.lesson_home_placeholder else R.string.lesson_home_placeholderWithSupports),
                    style = nunito(19.sp, FontWeight.SemiBold),
                    color = colors.inkTertiary,
                )
            }
            BasicTextField(
                value = composer.draft,
                onValueChange = { composer.draft = it.take(400) },
                textStyle = nunito(19.sp, FontWeight.SemiBold).copy(color = colors.ink),
                cursorBrush = SolidColor(colors.accent),
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = { if (canSend) onSend() }),
                modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp),
            )
        }
        AnimatedVisibility(visible = canSend || composer.isReading, enter = fadeIn() + scaleIn(initialScale = 0.9f), exit = fadeOut() + scaleOut(targetScale = 0.9f)) {
            Column {
                Spacer(Modifier.height(12.dp))
                MicaboButton(
                    stringResource(R.string.lesson_home_send),
                    onClick = onSend,
                    enabled = canSend,
                    loading = composer.isReading,
                    icon = Icons.AutoMirrored.Filled.ArrowForward,
                )
            }
        }
    }
}

@Composable
private fun SupportChip(support: Support, onRemove: () -> Unit) {
    val colors = Micabo.colors
    val failed = support.failure != null
    Row(
        Modifier
            .widthIn(max = 260.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(if (failed) colors.wrongSoft else colors.accentWash)
            .border(1.5.dp, if (failed) colors.wrong.copy(alpha = 0.5f) else colors.accent.copy(alpha = 0.35f), RoundedCornerShape(14.dp))
            .padding(start = 8.dp, end = 4.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon3D(support.kind.icon(), 24.dp)
        Spacer(Modifier.width(6.dp))
        Text(
            support.title,
            style = nunito(14.sp, FontWeight.Bold),
            color = if (failed) colors.wrongInk else colors.ink,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f, fill = false),
        )
        Spacer(Modifier.width(6.dp))
        when {
            support.isReading -> CircularProgressIndicator(color = colors.accent, strokeWidth = 2.dp, modifier = Modifier.size(14.dp))
            failed -> Icon(Icons.Filled.Warning, null, tint = colors.wrong, modifier = Modifier.size(16.dp))
            else -> Icon(Icons.Filled.Check, null, tint = colors.correct, modifier = Modifier.size(16.dp))
        }
        Pressable(onClick = onRemove, modifier = Modifier.size(28.dp)) {
            Icon(
                Icons.Filled.Close,
                stringResource(R.string.lesson_home_removeSupport),
                tint = colors.inkSecondary,
                modifier = Modifier.align(Alignment.Center).size(16.dp),
            )
        }
    }
}

private data class SourceChip(val kind: SupportKind, val title: Int, val subtitle: Int)

/** L'activité sous un contexte, même enveloppé. */
private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

/**
 * **Les imports sous la barre** : PDF ou Word, photos ou scan, YouTube, texte collé. Ils
 * s'ajoutent à la barre. Sans Pro, toucher un import verrouillé ouvre le paywall tout de suite,
 * comme sur iPhone (`HomeView.tapImport`) : pas de PDF lu pour rien avant le refus à l'envoi.
 */
@Composable
fun SourceRow(composer: LessonComposer, isPro: Boolean, onFull: () -> Unit, onLocked: () -> Unit) {
    val colors = Micabo.colors
    val context = LocalContext.current
    var dialog by rememberSaveable { mutableStateOf<String?>(null) }

    val files = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) composer.addFile(uri)
    }
    val photos = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(PhotoImport.MAX_PAGES)) { uris ->
        composer.addPhotos(uris)
    }
    val scanner = rememberLauncherForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val pages = GmsDocumentScanningResult.fromActivityResultIntent(result.data)?.pages.orEmpty().map { it.imageUri }
            composer.addPhotos(pages)
        }
    }

    fun pickPhotos() = photos.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))

    fun scan() {
        val activity = context.findActivity() ?: return pickPhotos()
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(PhotoImport.MAX_PAGES)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        val client: GmsDocumentScanner = GmsDocumentScanning.getClient(options)
        // Sans les services Google Play à jour, le scanner ne s'ouvre pas : la galerie prend le relais.
        client.getStartScanIntent(activity)
            .addOnSuccessListener { sender -> scanner.launch(IntentSenderRequest.Builder(sender).build()) }
            .addOnFailureListener { pickPhotos() }
    }

    val chips = listOf(
        SourceChip(SupportKind.PDF, R.string.lesson_import_pdf, R.string.lesson_import_pdfSub),
        SourceChip(SupportKind.PHOTO, R.string.lesson_import_photo, R.string.lesson_import_photoSub),
        SourceChip(SupportKind.YOUTUBE, R.string.lesson_import_youtube, R.string.lesson_import_youtubeSub),
        SourceChip(SupportKind.TEXT, R.string.lesson_import_text, R.string.lesson_import_textSub),
    )
    LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        items(chips) { chip ->
            val locked = !isPro && chip.kind != SupportKind.TEXT
            Pressable(onClick = {
                if (locked) return@Pressable onLocked()
                if (!composer.hasRoom) return@Pressable onFull()
                when (chip.kind) {
                    SupportKind.PDF -> files.launch(arrayOf("application/pdf", WORD_TYPE))
                    SupportKind.PHOTO -> dialog = "photo"
                    SupportKind.YOUTUBE -> dialog = "youtube"
                    SupportKind.TEXT -> dialog = "text"
                }
            }) {
                Column(
                    Modifier
                        .width(138.dp)
                        .clip(RoundedCornerShape(20.dp))
                        .background(colors.surface)
                        .border(1.5.dp, colors.stroke, RoundedCornerShape(20.dp))
                        .padding(14.dp),
                ) {
                    Row(verticalAlignment = Alignment.Top) {
                        Icon3D(chip.kind.icon(), 40.dp)
                        Spacer(Modifier.weight(1f))
                        if (locked) {
                            Box(Modifier.clip(CircleShape).background(colors.cautionSoft).padding(5.dp)) {
                                Icon(Icons.Filled.Lock, null, tint = colors.caution, modifier = Modifier.size(13.dp))
                            }
                        }
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(stringResource(chip.title), style = nunito(16.sp, FontWeight.ExtraBold), color = colors.ink)
                    Text(
                        stringResource(chip.subtitle),
                        style = nunito(13.sp, FontWeight.Medium, lineHeight = 17.sp),
                        color = colors.inkSecondary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }

    when (dialog) {
        "photo" -> PhotoChoice(
            onDismiss = { dialog = null },
            onScan = { dialog = null; scan() },
            onLibrary = { dialog = null; pickPhotos() },
        )
        "youtube" -> YouTubeDialog(
            onDismiss = { dialog = null },
            onSubmit = { link -> dialog = null; composer.addYouTube(link) },
        )
        "text" -> PasteDialog(
            onDismiss = { dialog = null },
            onSubmit = { text -> dialog = null; composer.addText(text) },
        )
    }
}

/** Une feuille simple, au bas de l'écran ; toucher au-dessus la ferme. */
@Composable
private fun Sheet(onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val colors = Micabo.colors
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(
            Modifier.fillMaxSize().pointerInput(Unit) { detectTapGestures(onTap = { onDismiss() }) }.padding(16.dp),
            contentAlignment = Alignment.BottomCenter,
        ) {
            Column(
                Modifier
                    .fillMaxWidth()
                    // La feuille garde ses touchers : seul le vide au-dessus ferme.
                    .pointerInput(Unit) { detectTapGestures() }
                    .clip(RoundedCornerShape(28.dp))
                    .background(colors.canvas)
                    .padding(20.dp),
            ) { content() }
        }
    }
}

@Composable
private fun PhotoChoice(onDismiss: () -> Unit, onScan: () -> Unit, onLibrary: () -> Unit) {
    val colors = Micabo.colors
    Sheet(onDismiss) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon3D("fiche", 40.dp)
            Spacer(Modifier.width(10.dp))
            Text(stringResource(R.string.lesson_import_photo), style = nunito(21.sp, FontWeight.Black), color = colors.ink)
        }
        Spacer(Modifier.height(16.dp))
        MicaboButton(stringResource(R.string.lesson_import_scan), onClick = onScan)
        Spacer(Modifier.height(10.dp))
        MicaboSecondaryButton(stringResource(R.string.lesson_import_library), onClick = onLibrary)
        TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterHorizontally)) {
            Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold), color = colors.inkSecondary)
        }
    }
}

private fun clipboardText(context: Context): String =
    (context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager)
        ?.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(context)?.toString().orEmpty()

@Composable
private fun YouTubeDialog(onDismiss: () -> Unit, onSubmit: (String) -> Unit) {
    val colors = Micabo.colors
    val context = LocalContext.current
    var link by rememberSaveable { mutableStateOf("") }
    val valid = YouTubeLink.videoId(link) != null
    Sheet(onDismiss) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon3D("fusee", 40.dp)
            Spacer(Modifier.width(10.dp))
            Text(stringResource(R.string.lesson_import_youtubeTitle), style = nunito(21.sp, FontWeight.Black), color = colors.ink)
        }
        Spacer(Modifier.height(14.dp))
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(colors.surface)
                .border(1.5.dp, if (valid) colors.accent.copy(alpha = 0.5f) else colors.stroke, RoundedCornerShape(18.dp))
                .padding(start = 14.dp, end = 6.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.weight(1f).padding(vertical = 10.dp)) {
                if (link.isEmpty()) {
                    Text(stringResource(R.string.lesson_import_youtubePlaceholder), style = nunito(16.sp, FontWeight.Medium), color = colors.inkTertiary)
                }
                BasicTextField(
                    value = link,
                    onValueChange = { link = it.take(300) },
                    singleLine = true,
                    textStyle = nunito(16.sp, FontWeight.SemiBold).copy(color = colors.ink),
                    cursorBrush = SolidColor(colors.accent),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { if (valid) onSubmit(link) }),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            TextButton(onClick = { link = clipboardText(context).trim().take(300) }) {
                Text(stringResource(R.string.lesson_import_paste), style = nunito(15.sp, FontWeight.ExtraBold), color = colors.accent)
            }
        }
        if (link.isNotBlank() && !valid) {
            Spacer(Modifier.height(8.dp))
            Text(stringResource(R.string.ios_yt_invalidLink), style = nunito(13.sp, FontWeight.SemiBold), color = colors.wrongInk)
        }
        Spacer(Modifier.height(14.dp))
        MicaboButton(stringResource(R.string.lesson_import_add), onClick = { onSubmit(link) }, enabled = valid)
        TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterHorizontally)) {
            Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold), color = colors.inkSecondary)
        }
    }
}

@Composable
fun PasteDialog(onDismiss: () -> Unit, onSubmit: (String) -> Unit) {
    val colors = Micabo.colors
    var text by rememberSaveable { mutableStateOf("") }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier
                .padding(16.dp)
                .fillMaxWidth()
                .clip(RoundedCornerShape(28.dp))
                .background(colors.canvas)
                .padding(20.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon3D("texte", 40.dp)
                Spacer(Modifier.width(10.dp))
                Text(stringResource(R.string.lesson_import_textTitle), style = nunito(21.sp, FontWeight.Black), color = colors.ink)
            }
            Spacer(Modifier.height(14.dp))
            Box(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 180.dp, max = 320.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(colors.surface)
                    .border(1.5.dp, colors.stroke, RoundedCornerShape(18.dp))
                    .padding(14.dp),
            ) {
                if (text.isEmpty()) {
                    Text(stringResource(R.string.lesson_import_textPlaceholder), style = nunito(16.sp, FontWeight.Medium), color = colors.inkTertiary)
                }
                BasicTextField(
                    value = text,
                    onValueChange = { text = it.take(60_000) },
                    textStyle = nunito(16.sp, FontWeight.Medium, lineHeight = 22.sp).copy(color = colors.ink),
                    cursorBrush = SolidColor(colors.accent),
                    modifier = Modifier.fillMaxSize(),
                )
            }
            Spacer(Modifier.height(8.dp))
            Text(
                if (text.trim().length < 40) stringResource(R.string.x_paste_tooShort) else "${text.length} / 60 000",
                style = nunito(13.sp, FontWeight.SemiBold),
                color = colors.inkTertiary,
            )
            Spacer(Modifier.height(14.dp))
            MicaboButton(stringResource(R.string.lesson_import_add), onClick = { onSubmit(text.trim()) }, enabled = text.trim().length >= 40)
            TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold), color = colors.inkSecondary)
            }
        }
    }
}
