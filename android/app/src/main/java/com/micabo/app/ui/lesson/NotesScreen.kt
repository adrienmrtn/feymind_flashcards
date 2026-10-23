package com.micabo.app.ui.lesson

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.runtime.mutableIntStateOf
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.runtime.remember
import com.micabo.app.data.NoteBlock
import com.micabo.app.data.Theme
import com.micabo.app.ui.components.CircleIconButton
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.theme.Tone
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.ThemeStatus
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.components.CloseButton
import com.micabo.app.ui.components.Eyebrow
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.components.Waiting
import com.micabo.app.ui.home.errorMessage
import com.micabo.app.data.ApiException
import com.micabo.app.data.NetworkException
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone

/**
 * Garde le temps passé sur un écran de leçon (« X h de révision »). Comme `LessonClock` sur
 * iPhone, l'horloge s'arrête quand l'app passe en arrière-plan : un écran laissé ouvert la nuit
 * ne compte pas des heures de révision.
 */
@Composable
fun TrackTime(lessonId: String) {
    val app = LocalApp.current
    @Suppress("DEPRECATION")
    val owner = androidx.compose.ui.platform.LocalLifecycleOwner.current
    DisposableEffect(lessonId, owner) {
        var start = 0L
        fun flush() {
            if (start > 0L) app.lessons.addTime(lessonId, (System.currentTimeMillis() - start) / 1000)
            start = 0L
        }
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && start == 0L) start = System.currentTimeMillis()
            if (event == Lifecycle.Event.ON_PAUSE) flush()
        }
        // L'observateur reçoit aussitôt ON_RESUME si l'écran est déjà au premier plan.
        owner.lifecycle.addObserver(observer)
        onDispose {
            owner.lifecycle.removeObserver(observer)
            flush()
        }
    }
}

/** Un écran des notes (`NotesPage`). */
private sealed interface NotesPage {
    /** L'icône, le titre du thème et son idée en une phrase. */
    data object Opening : NotesPage
    /** Un sous-titre et le bloc qu'il ouvre, ou un bloc seul ; un encadré reste avec ce qu'il commente. */
    data class Blocks(val from: Int, val until: Int) : NotesPage
    data object Takeaways : NotesPage
    data object Question : NotesPage
}

private fun notesPages(blocks: List<NoteBlock>, hasTakeaways: Boolean, hasQuestion: Boolean): List<NotesPage> {
    val pages = mutableListOf<NotesPage>(NotesPage.Opening)
    noteScreens(blocks).forEach { (start, end) -> pages.add(NotesPage.Blocks(start, end)) }
    if (hasTakeaways) pages.add(NotesPage.Takeaways)
    if (hasQuestion) pages.add(NotesPage.Question)
    return pages
}

/** Ce qu'un écran porte sans qu'il faille faire défiler, en mots pondérés (`noteWeight`). */
private const val SCREEN_WEIGHT = 150
/** En deçà, un bloc seul laisse l'écran à moitié vide : il accueille le suivant. */
private const val THIN_WEIGHT = 120

/**
 * **Les écrans des notes** (`NotesPage.screens` sur iPhone). Un écran qui n'a qu'un bloc (le
 * sous-titre qui l'ouvre ne compte pas) accueille le suivant, avec son sous-titre et son
 * encadré, tant que le tout tient sans défiler ; un bloc resté seul rejoint l'écran d'avant
 * s'il y tient. Un encadré en tête de thème garde son écran : il annonce ce qui suit.
 */
internal fun noteScreens(blocks: List<NoteBlock>): List<Pair<Int, Int>> {
    val screens = mutableListOf<Pair<Int, Int>>()
    var index = 0
    while (index < blocks.size) {
        var end = screenEnd(blocks, index)
        if (isThin(blocks.subList(index, end)) && end < blocks.size) {
            val next = screenEnd(blocks, end)
            if (noteWeight(blocks.subList(index, next)) <= SCREEN_WEIGHT) end = next
        }
        screens.add(index to end)
        index = end
    }
    val packed = mutableListOf<Pair<Int, Int>>()
    for (screen in screens) {
        val last = packed.lastOrNull()
        if (last != null && isThin(blocks.subList(screen.first, screen.second)) &&
            noteWeight(blocks.subList(last.first, screen.second)) <= SCREEN_WEIGHT
        ) {
            packed[packed.lastIndex] = last.first to screen.second
        } else {
            packed.add(screen)
        }
    }
    return packed
}

/** La fin d'un écran ouvert à `index` : le bloc, celui qu'ouvre un sous-titre, et l'encadré qui les commente. */
private fun screenEnd(blocks: List<NoteBlock>, index: Int): Int {
    var end = index + 1
    if (blocks[index] is NoteBlock.Subtitle && end < blocks.size) end += 1
    if (end < blocks.size && blocks[end] is NoteBlock.Callout && !blocks[end - 1].isBoxed) end += 1
    return end
}

/** Un seul bloc à lire, et assez court pour laisser de la place. */
private fun isThin(screen: List<NoteBlock>): Boolean {
    val content = screen.filter { it !is NoteBlock.Subtitle }
    val block = content.singleOrNull() ?: return false
    if (block is NoteBlock.Callout) return false
    return noteWeight(listOf(block)) < THIN_WEIGHT
}

/** La place qu'un écran demande : ses mots, et le cadre de ce qui se dessine en encadré. */
private fun noteWeight(blocks: List<NoteBlock>): Int = blocks.sumOf { block ->
    val frame = when (block) {
        is NoteBlock.Subtitle -> 6
        is NoteBlock.Paragraph -> 0
        is NoteBlock.Bullets -> 4 * block.items.size
        is NoteBlock.Steps -> 4 * block.items.size
        is NoteBlock.Table -> 18 + 6 * block.rows.size
        is NoteBlock.Dates -> 18 + 4 * block.items.size
        else -> 18
    }
    block.wordCount + frame
}

/**
 * **Un cercle Notes, en écrans courts** (`NotesCircleView`) : l'idée du thème, un écran par
 * bloc, « À retenir », puis la question de fin. Les segments du haut se remplissent à mesure ;
 * on avance avec « Continuer », on revient avec la flèche. Le cercle se coche quand la
 * question a sa réponse, bonne ou non.
 */
@Composable
fun NotesScreen(id: String, theme: Int) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val lessons by app.lessons.lessons.collectAsState()
    val lesson = lessons[id]
    val item = lesson?.themes?.getOrNull(theme)
    if (lesson == null || item == null) {
        LeaveWhenMissing()
        return
    }
    val colors = Micabo.colors
    val tone = colors.tone(lesson.tone)
    val haptics = rememberHaptics()
    var answeredRight by rememberSaveable(id, theme) { mutableStateOf<Boolean?>(null) }
    var picked by rememberSaveable(id, theme) { mutableStateOf(-1) }
    var page by rememberSaveable(id, theme) { mutableIntStateOf(0) }
    var forward by remember { mutableStateOf(true) }
    val answered = answeredRight?.let { QuizAnswer(it, picked.takeIf { index -> index >= 0 }) }
    // Une question de fin mal formée (sans propositions) bloquerait « Terminer » : on s'en passe.
    val final = item.questions.firstOrNull()?.takeIf { it.isValid }
    val notes = item.notes
    val blocks = remember(notes) { notes?.blocks.orEmpty().flatMap { NoteBlock.parseAll(it) } }
    val pages = remember(blocks, notes, final) { notesPages(blocks, notes?.takeaways.orEmpty().isNotEmpty(), final != null) }
    TrackTime(id)

    fun finish() {
        app.lessons.complete(id, "notes:$theme")
        navigator.back()
    }

    if (item.status != ThemeStatus.READY || notes == null) {
        Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)) {
            Row(Modifier.padding(vertical = 8.dp)) { CloseButton(onClick = { navigator.back() }) }
            Opening(item, theme, tone, oneLiner = null)
            Spacer(Modifier.height(20.dp))
            if (item.status == ThemeStatus.PENDING) {
                Waiting(stringResource(R.string.lesson_notes_writing), Modifier.fillMaxWidth())
            } else {
                FailedTheme(item.error) { app.lessons.resume(id, retryFailed = true) }
            }
        }
        return
    }

    val current = pages.getOrElse(page) { NotesPage.Question }
    val isLast = page >= pages.lastIndex
    val waiting = current == NotesPage.Question && answered == null

    BackHandler(enabled = page > 0) {
        forward = false
        page -= 1
    }

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            CloseButton(onClick = { navigator.back() })
            Spacer(Modifier.width(12.dp))
            // Un segment par écran : ceux qu'on a passés sont pleins.
            Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                pages.indices.forEach { index ->
                    val fill by animateFloatAsState(if (index <= page) 1f else 0f, tween(380), label = "segment")
                    Box(Modifier.weight(1f).height(6.dp).clip(RoundedCornerShape(50)).background(colors.progressTrack)) {
                        Box(Modifier.fillMaxWidth(fill).fillMaxHeight().clip(RoundedCornerShape(50)).background(tone.vivid))
                    }
                }
            }
            if (page > 0) {
                Spacer(Modifier.width(10.dp))
                CircleIconButton(Icons.AutoMirrored.Filled.ArrowBack, null, onClick = { haptics.selection(); forward = false; page -= 1 })
            }
        }
        AnimatedContent(
            targetState = page,
            transitionSpec = {
                val sign = if (forward) 1 else -1
                (slideInHorizontally(tween(340)) { sign * it / 3 } + fadeIn(tween(280))) togetherWith
                    (slideOutHorizontally(tween(340)) { -sign * it / 4 } + fadeOut(tween(200)))
            },
            modifier = Modifier.weight(1f).fillMaxWidth(),
            label = "notesPage",
        ) { shown ->
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 14.dp),
            ) {
                when (val content = pages.getOrElse(shown) { NotesPage.Question }) {
                    NotesPage.Opening -> Opening(item, theme, tone, notes.oneLiner)
                    is NotesPage.Blocks -> blocks.subList(content.from, content.until).forEachIndexed { offset, block ->
                        if (offset > 0) Spacer(Modifier.height(if (blocks[content.from + offset - 1] is NoteBlock.Subtitle) 10.dp else 18.dp))
                        NoteBlockView(block, tone)
                    }
                    NotesPage.Takeaways -> ToneBox(stringResource(R.string.lesson_notes_takeaways), tone) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            notes.takeaways.forEach { line ->
                                Row {
                                    Icon(Icons.Filled.Check, null, tint = tone.ink, modifier = Modifier.padding(top = 4.dp).size(16.dp))
                                    Spacer(Modifier.width(10.dp))
                                    RichText(line, style = nunito(17.sp, FontWeight.Normal, lineHeight = 26.sp), color = colors.ink)
                                }
                            }
                        }
                    }
                    NotesPage.Question -> if (final != null) {
                        Text(stringResource(R.string.lesson_notes_question), style = nunito(22.sp, FontWeight.Black), color = colors.ink)
                        Spacer(Modifier.height(14.dp))
                        QuestionCard(
                            question = final,
                            tone = tone,
                            seed = (id.hashCode() + theme).toLong(),
                            answered = answered,
                            onAnswer = {
                                picked = it.picked ?: -1
                                answeredRight = it.right
                                if (it.right) haptics.success() else {
                                    haptics.error()
                                    app.lessons.missed(id, theme)
                                }
                            },
                        )
                    }
                }
                Spacer(Modifier.height(24.dp))
            }
        }
        Column(Modifier.navigationBarsPadding().padding(horizontal = 20.dp, vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            if (waiting) {
                Text(stringResource(R.string.lesson_notes_answerToFinish), style = nunito(14.sp, FontWeight.Bold), color = colors.inkSecondary, textAlign = TextAlign.Center)
                Spacer(Modifier.height(8.dp))
            }
            MicaboButton(
                text = if (isLast) stringResource(R.string.lesson_notes_finishStep) else stringResource(R.string.lesson_quiz_continue),
                enabled = !waiting,
                color = if (isLast && answered?.right == true) colors.correct else colors.accent,
                onClick = {
                    if (isLast) finish() else {
                        forward = true
                        page += 1
                    }
                },
            )
        }
    }
}

/** L'ouverture d'un thème : son numéro, son titre, son icône, et son idée en une phrase. */
@Composable
private fun Opening(item: Theme, theme: Int, tone: Tone, oneLiner: String?) {
    Column {
        Spacer(Modifier.height(10.dp))
        Icon3D(item.icon, 96.dp)
        Spacer(Modifier.height(12.dp))
        Eyebrow(stringResource(R.string.lesson_notes_themeNumber, (theme + 1).toString()), tone.ink)
        Spacer(Modifier.height(6.dp))
        RichText(item.title, style = nunito(30.sp, FontWeight.Black, lineHeight = 34.sp), tintsKeywords = false)
        if (!oneLiner.isNullOrBlank()) {
            Spacer(Modifier.height(22.dp))
            ToneBox(stringResource(R.string.lesson_notes_oneLiner), tone) {
                RichText(oneLiner, style = nunito(19.sp, FontWeight.Bold, lineHeight = 27.sp))
            }
        }
    }
}

/**
 * Une leçon supprimée pendant qu'on la lit : on revient au chemin. Après une mort du processus,
 * l'écran revient avant les leçons : on attend qu'elles soient lues, puis deux images, le
 * temps qu'une leçon arrivée remplace cet écran (et annule ce retour).
 */
@Composable
fun LeaveWhenMissing() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    androidx.compose.runtime.LaunchedEffect(Unit) {
        app.lessons.ready()
        androidx.compose.runtime.withFrameNanos {}
        androidx.compose.runtime.withFrameNanos {}
        navigator.back()
    }
}

@Composable
fun FailedTheme(code: String, onRetry: () -> Unit) {
    val colors = Micabo.colors
    val error = when (code) {
        "network" -> NetworkException(Exception())
        "generic", "", "invalid" -> Exception()
        else -> ApiException(if (code == "daily_limit") 429 else 402, code, "")
    }
    Column(Modifier.fillMaxWidth().padding(vertical = 24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Mika(MikaMood.SAD, 120.dp)
        Text(errorMessage(error), style = nunito(16.sp, FontWeight.SemiBold, lineHeight = 22.sp), color = colors.inkSecondary, textAlign = TextAlign.Center)
        AnimatedVisibility(visible = true, enter = fadeIn() + slideInVertically()) {
            MicaboButton(stringResource(R.string.lesson_path_retry), onClick = onRetry)
        }
    }
}
