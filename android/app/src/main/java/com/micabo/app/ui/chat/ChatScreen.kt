package com.micabo.app.ui.chat

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.AddAPhoto
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.Menu
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.Text
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.data.ApiException
import com.micabo.app.data.ChatMessage
import com.micabo.app.data.ChatStore
import com.micabo.app.data.Conversation
import com.micabo.app.data.MikaGate
import com.micabo.app.data.PhotoImport
import com.micabo.app.i18n.t
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.TypingDots
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Type
import com.micabo.app.ui.theme.display
import com.micabo.app.ui.theme.text
import com.micabo.app.ui.v3.MicaboIcons
import com.micabo.app.ui.v3.wash
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/**
 * **Le chat avec Mika, autonome** (lot 12 de l'iPhone) : une question tapée, et jusqu'à six
 * photos lues sur le téléphone (aucune image ne quitte l'appareil, seul leur texte part) ; les
 * conversations se gardent, et leur historique s'ouvre dans un tiroir, à gauche.
 */
@Composable
fun ChatScreen(id: String?) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val isPro by app.billing.isPro.collectAsState()
    val all by app.chats.all.collectAsState()
    var current by remember { mutableStateOf(app.chats.get(id) ?: Conversation()) }
    var draft by remember { mutableStateOf("") }
    var thinking by remember { mutableStateOf(false) }
    var reading by remember { mutableStateOf(false) }
    var problem by remember { mutableStateOf<String?>(null) }
    val pending = remember { mutableStateListOf<Uri>() }
    val drawer = rememberDrawerState(DrawerValue.Closed)
    val photoTitle = t("ios.chat12.family.scan")
    val genericError = androidx.compose.ui.res.stringResource(com.micabo.app.R.string.x_error_generic)

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(ChatStore.MAX_PHOTOS)) { uris ->
        pending.addAll(uris.take(ChatStore.MAX_PHOTOS - pending.size))
    }

    fun send() {
        val text = draft.trim()
        if ((text.isEmpty() && pending.isEmpty()) || thinking || reading) return
        when (app.mika.gate(isPro)) {
            MikaGate.PAYWALL -> {
                navigator.push(Screen.Paywall("pro_required", trigger = "mika"))
                return
            }
            MikaGate.DAILY_CAP -> {
                problem = genericError
                return
            }
            MikaGate.ALLOWED -> Unit
        }
        val photos = pending.toList()
        pending.clear()
        draft = ""
        problem = null
        scope.launch {
            var conversation = current
            if (photos.isNotEmpty()) {
                reading = true
                val read = runCatching { PhotoImport.read(context, photos, photoTitle).text }.getOrDefault("")
                reading = false
                conversation = conversation.copy(attachment = (conversation.attachment + "\n\n" + read).trim(), photos = conversation.photos + photos.size)
            }
            val question = text.ifEmpty { photoTitle }
            conversation = conversation.copy(
                title = conversation.title.ifEmpty { question.take(60) },
                messages = conversation.messages + ChatMessage(role = "user", text = question.take(1_500)),
            )
            current = conversation
            app.chats.save(conversation)
            app.analytics.track("mika_asked", mapOf("turn" to conversation.messages.size / 2 + 1, "photos" to photos.size, "chat" to true))
            thinking = true
            try {
                val answered = app.mika.answerConversation(conversation, photoTitle, isPro)
                current = answered
                app.chats.save(answered)
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (error: Throwable) {
                if (error is ApiException && error.opensPaywall) {
                    app.prefs.mikaFreeUsed = true
                    navigator.push(Screen.Paywall("pro_required", trigger = "mika"))
                } else {
                    problem = genericError
                }
            } finally {
                thinking = false
            }
        }
    }

    ModalNavigationDrawer(
        drawerState = drawer,
        drawerContent = {
            ChatDrawer(all, current.id, onPick = { picked ->
                current = picked
                scope.launch { drawer.close() }
            }, onNew = {
                current = Conversation()
                scope.launch { drawer.close() }
            })
        },
    ) {
        ChatContent(
            conversation = current,
            draft = draft,
            onDraft = { draft = it.take(1_500) },
            photos = pending.size,
            thinking = thinking || reading,
            problem = problem,
            onRemovePhotos = { pending.clear() },
            onAddPhotos = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
            onSend = ::send,
            onMenu = { scope.launch { drawer.open() } },
            onBack = { navigator.back() },
            onNew = { current = Conversation() },
        )
    }
}

/** **Le chat, sans l'app** : de quoi le poser dans les rendus. */
@Composable
fun ChatContent(
    conversation: Conversation,
    draft: String,
    onDraft: (String) -> Unit,
    photos: Int,
    thinking: Boolean,
    problem: String?,
    onRemovePhotos: () -> Unit,
    onAddPhotos: () -> Unit,
    onSend: () -> Unit,
    onMenu: () -> Unit,
    onBack: () -> Unit,
    onNew: () -> Unit,
) {
    val colors = Micabo.colors
    val list = rememberLazyListState()
    LaunchedEffect(conversation.messages.size, thinking) {
        val last = conversation.messages.size + (if (thinking) 1 else 0) - 1
        if (last >= 0) list.animateScrollToItem(last)
    }
    Column(Modifier.fillMaxSize().background(colors.canvas).statusBarsPadding().imePadding()) {
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            RoundIcon(Icons.AutoMirrored.Rounded.ArrowBack, t("app.common.back"), onBack)
            RoundIcon(Icons.Rounded.Menu, t("ios.chat12.menu"), onMenu, Modifier.testTag("chatMenu"))
            Text(conversation.title.ifEmpty { t("ios.chat12.new") }, style = display(22.sp), color = colors.ink, maxLines = 2, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis, modifier = Modifier.weight(1f).padding(horizontal = 6.dp))
            RoundIcon(Icons.Rounded.Edit, t("ios.chat12.new"), onNew)
        }
        if (conversation.messages.isEmpty() && !thinking) {
            androidx.compose.foundation.layout.BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            Column(Modifier.fillMaxWidth().verticalScroll(androidx.compose.foundation.rememberScrollState()).heightIn(min = maxHeight).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                Mika(MikaMood.WAVE, if (androidx.compose.ui.platform.LocalDensity.current.fontScale >= 1.5f) 88.dp else 140.dp)
                Text(t("ios.chat12.empty.title"), style = display(28.sp), color = colors.ink, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 12.dp))
                Text(t("ios.chat12.empty.body"), style = Type.body, color = colors.ink, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 8.dp))
            }
            }
        } else {
            LazyColumn(Modifier.weight(1f).fillMaxWidth(), state = list, contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                items(conversation.messages) { message -> Bubble(message) }
                if (thinking) item { Row(verticalAlignment = Alignment.Bottom) { Mika(MikaMood.THINK, 40.dp); Spacer(Modifier.width(8.dp)); TypingDots(colors.inkSecondary, Modifier.padding(bottom = 14.dp)) } }
            }
        }
        problem?.let { Text(it, style = Type.mention, color = colors.redInk, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp)) }
        Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(start = 12.dp, end = 12.dp, top = 6.dp, bottom = 10.dp)) {
            if (photos > 0) {
                Row(
                    Modifier.padding(bottom = 8.dp).clip(CircleShape).background(wash(colors.iconBlue)).padding(start = 12.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(MicaboIcons.photo, null, tint = colors.iconBlue, modifier = Modifier.size(18.dp))
                    Text(" × $photos", style = text(15.sp, FontWeight.SemiBold), color = colors.ink)
                    RoundIcon(Icons.Rounded.Close, t("app.a11y.close"), onRemovePhotos)
                }
            }
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(26.dp)).background(colors.surface).border(1.5.dp, colors.stroke, RoundedCornerShape(26.dp)).padding(start = 4.dp, end = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                RoundIcon(Icons.Rounded.AddAPhoto, t("ios.chat12.family.scan"), onAddPhotos, Modifier.testTag("chatPhotos"))
                Box(Modifier.weight(1f).padding(vertical = 12.dp)) {
                    if (draft.isEmpty()) Text(t("ios.core13.bar.ask"), style = text(17.sp), color = colors.inkTertiary)
                    BasicTextField(draft, onDraft, textStyle = text(17.sp).copy(color = colors.ink), cursorBrush = SolidColor(colors.accent), maxLines = 5, modifier = Modifier.fillMaxWidth().testTag("chatField"))
                }
                Box(
                    Modifier.size(44.dp).clip(CircleShape).background(if (draft.isNotBlank() || photos > 0) colors.accent else colors.surfaceMuted).clickable(onClick = onSend).testTag("cta"),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.AutoMirrored.Rounded.Send, t("app.feedback.send"), tint = Color.White, modifier = Modifier.size(20.dp))
                }
            }
        }
    }
}

@Composable
private fun RoundIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.size(48.dp).clip(CircleShape).clickable(onClick = onClick), contentAlignment = Alignment.Center) {
        Icon(icon, label, tint = Micabo.colors.ink, modifier = Modifier.size(22.dp))
    }
}

@Composable
private fun Bubble(message: ChatMessage) {
    val colors = Micabo.colors
    if (message.role == "user") {
        Box(Modifier.fillMaxWidth().padding(start = 48.dp), contentAlignment = Alignment.CenterEnd) {
            Text(message.text, style = Type.body, color = colors.ink, modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(colors.accentWash).padding(horizontal = 14.dp, vertical = 11.dp))
        }
    } else {
        Row(Modifier.fillMaxWidth().padding(end = 24.dp), verticalAlignment = Alignment.Bottom) {
            Mika(MikaMood.HAPPY, 36.dp)
            Spacer(Modifier.width(8.dp))
            Text(
                com.micabo.app.ui.v3.marked(message.text, colors.accentBright),
                style = Type.body,
                color = colors.ink,
                modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(colors.surface).padding(horizontal = 14.dp, vertical = 11.dp),
            )
        }
    }
}

/** **Le tiroir des conversations**, à gauche : la plus récente d'abord, « Nouveau chat » en tête. */
@Composable
fun ChatDrawer(all: List<Conversation>, currentId: String, onPick: (Conversation) -> Unit, onNew: () -> Unit) {
    val colors = Micabo.colors
    ModalDrawerSheet(drawerContainerColor = colors.canvas, modifier = Modifier.widthIn(max = 320.dp)) {
        Column(Modifier.fillMaxHeight().padding(16.dp)) {
            Text(t("ios.chat12.menu"), style = display(28.sp), color = colors.ink)
            Text(t("ios.chat12.drawer.subtitle"), style = Type.mention, color = colors.inkSecondary)
            Row(
                Modifier.padding(top = 14.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(colors.surface).clickable(onClick = onNew).padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Rounded.Edit, null, tint = colors.accentBright)
                Spacer(Modifier.width(10.dp))
                Text(t("ios.chat12.new"), style = text(17.sp, FontWeight.SemiBold), color = colors.ink)
            }
            if (all.isEmpty()) {
                Text(t("ios.chat12.empty.body"), style = Type.mention, color = colors.inkSecondary, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 40.dp))
            }
            LazyColumn(Modifier.padding(top = 10.dp)) {
                items(all, key = { it.id }) { conversation ->
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(if (conversation.id == currentId) colors.accentWash else Color.Transparent).clickable { onPick(conversation) }.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(if (conversation.photos > 0) MicaboIcons.photo else MicaboIcons.mika, null, tint = colors.iconLilac, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(10.dp))
                        Text(conversation.title.ifEmpty { t("ios.chat12.family.chat") }, style = text(16.sp, FontWeight.Medium), color = colors.ink, maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
                    }
                }
            }
        }
    }
}
