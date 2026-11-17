package com.micabo.app.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.data.LessonComposer
import com.micabo.app.i18n.t
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Type
import com.micabo.app.ui.theme.display
import com.micabo.app.ui.theme.text
import com.micabo.app.ui.v3.LocalCompact
import com.micabo.app.ui.v3.V3Chip
import com.micabo.app.ui.v3.V3Title

/**
 * **La scène de l'accueil** (`HomeStage`, lot 13 : la leçon au centre) : Mika, une phrase en
 * grand, une seule action. La première leçon choisie au parcours d'accueil l'attend ici
 * (« Écris ta première leçon : **Le second degré** », « Écrire ma leçon ») ; sinon, la puce
 * « + Nouvelle leçon » ouvre la feuille de création.
 */
@Composable
fun HomeStage(
    firstTopic: String?,
    firstImport: Boolean,
    freeLessonLeft: Boolean,
    onWriteFirst: (String) -> Unit,
    onNewLesson: () -> Unit,
) {
    val colors = Micabo.colors
    val compact = LocalCompact.current
    Column(
        Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Mika(if (firstTopic != null || firstImport) MikaMood.WRITE else MikaMood.WAVE, if (compact) 110.dp else 150.dp)
        when {
            firstTopic != null -> {
                V3Title(t("ios.home13.ask.firstTopic", "topic" to firstTopic), size = 32, align = TextAlign.Center)
                if (freeLessonLeft) Text(t("ios.home13.firstFree"), style = Type.mention, color = colors.green, textAlign = TextAlign.Center)
                MicaboButton(
                    t("ios.home13.cta.firstTopic"),
                    onClick = { onWriteFirst(firstTopic) },
                    icon = Icons.Rounded.Edit,
                    modifier = Modifier.widthIn(max = 340.dp).testTag("homeCta"),
                )
                V3Chip(t("lesson.lessons.new"), onClick = onNewLesson, icon = Icons.Rounded.Add)
            }
            else -> {
                V3Title(if (firstImport) t("ios.core13.home.promise") else t("lesson.home.title"), size = 32, align = TextAlign.Center)
                if (freeLessonLeft) Text(t("ios.home13.firstFree"), style = Type.mention, color = colors.green, textAlign = TextAlign.Center)
                MicaboButton(
                    t("lesson.lessons.new"),
                    onClick = onNewLesson,
                    icon = Icons.Rounded.Add,
                    modifier = Modifier.widthIn(max = 340.dp).testTag("homeCta"),
                )
            }
        }
    }
}

/**
 * **La feuille « Nouvelle leçon »** (lot 13) : la promesse, un sujet à apprendre, ou son cours
 * (photo, PDF, enregistrement…), puis « Écrire ma leçon ».
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NewLessonSheet(
    composer: LessonComposer,
    canImport: Boolean,
    onSend: () -> Unit,
    onFull: () -> Unit,
    onLocked: () -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = Micabo.colors
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = colors.canvas,
    ) {
        NewLessonContent(composer, canImport, onSend, onFull, onLocked)
    }
}

/** Le contenu de la feuille, seul : la feuille l'enveloppe, les rendus de test le posent tel quel. */
@Composable
fun NewLessonContent(
    composer: LessonComposer,
    canImport: Boolean,
    onSend: () -> Unit,
    onFull: () -> Unit,
    onLocked: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = Micabo.colors
    // Le contenu défile ; « Écrire ma leçon » reste en bas, toujours visible.
    Column(modifier.fillMaxWidth().navigationBarsPadding().padding(bottom = 12.dp)) {
        Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState())) {
            Text(t("lesson.lessons.new"), style = display(30.sp), color = colors.ink, modifier = Modifier.padding(horizontal = 20.dp))
            Text(t("ios.core13.new.promise"), style = Type.body, color = colors.ink, modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 6.dp))
            Text(t("ios.core13.new.topicLabel"), style = text(15.sp, FontWeight.SemiBold), color = colors.inkSecondary, modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 18.dp))
            ComposerCard(composer, onSend = onSend)
            Text(t("ios.core13.new.orSupport"), style = text(15.sp, FontWeight.SemiBold), color = colors.inkSecondary, modifier = Modifier.padding(horizontal = 20.dp))
            SourceRow(composer, isPro = canImport, onFull = onFull, onLocked = onLocked)
        }
        MicaboButton(
            t("ios.core13.cta.write"),
            onClick = onSend,
            enabled = composer.canSend,
            icon = Icons.Rounded.Edit,
            modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 16.dp).testTag("cta"),
        )
    }
}
