package com.micabo.app.ui.lesson

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.Lesson
import com.micabo.app.data.PathCircle
import com.micabo.app.data.ThemeStatus
import com.micabo.app.data.pathCircles
import com.micabo.app.data.pathGroups
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.lessons.RenameDialog
import com.micabo.app.ui.components.BackButton
import com.micabo.app.ui.components.CircleIconButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.components.TypingDots
import com.micabo.app.ui.components.Waiting
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.text.plainText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.Tone
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone
import kotlinx.coroutines.delay
import kotlin.math.sin

/** Le titre d'un cercle. */
@Composable
fun circleTitle(lesson: Lesson, circle: PathCircle): String = when (circle) {
    PathCircle.IntroCircle -> stringResource(R.string.lesson_circle_intro)
    is PathCircle.NotesCircle -> plainText(lesson.themes.getOrNull(circle.theme)?.title.orEmpty())
    is PathCircle.QuizCircle -> stringResource(R.string.lesson_circle_checkpoint)
    is PathCircle.FinalCircle -> stringResource(R.string.lesson_circle_final)
}

fun circleIcon(lesson: Lesson, circle: PathCircle): String = when (circle) {
    PathCircle.IntroCircle -> "etoile"
    is PathCircle.NotesCircle -> lesson.themes.getOrNull(circle.theme)?.icon ?: "livre-ouvert"
    is PathCircle.QuizCircle -> "quiz"
    is PathCircle.FinalCircle -> "trophee"
}

/** Ouvre un cercle : l'intro, les notes d'un thème, un quiz. */
fun openCircle(navigator: com.micabo.app.ui.Navigator, lesson: Lesson, circle: PathCircle) {
    when (circle) {
        PathCircle.IntroCircle -> navigator.push(Screen.Intro(lesson.id))
        is PathCircle.NotesCircle -> navigator.push(Screen.Notes(lesson.id, circle.theme))
        is PathCircle.QuizCircle, is PathCircle.FinalCircle -> navigator.push(Screen.Quiz(lesson.id, circle.id))
    }
}

/** Vrai quand le cercle attend encore ses thèmes (en préparation ou en échec). */
fun circleBlocked(lesson: Lesson, circle: PathCircle): String? {
    val themes = when (circle) {
        PathCircle.IntroCircle -> emptyList()
        is PathCircle.NotesCircle -> listOf(circle.theme)
        is PathCircle.QuizCircle -> circle.themes
        is PathCircle.FinalCircle -> circle.themes
    }
    val statuses = themes.mapNotNull { lesson.themes.getOrNull(it)?.status }
    return when {
        circle is PathCircle.NotesCircle && statuses.firstOrNull() == ThemeStatus.FAILED -> ThemeStatus.FAILED
        circle is PathCircle.NotesCircle && statuses.firstOrNull() == ThemeStatus.PENDING -> ThemeStatus.PENDING
        // Un quiz s'ouvre dès qu'un de ses thèmes a des questions.
        circle !is PathCircle.NotesCircle && themes.isNotEmpty() && statuses.none { it == ThemeStatus.READY } ->
            if (statuses.any { it == ThemeStatus.PENDING }) ThemeStatus.PENDING else ThemeStatus.FAILED
        else -> null
    }
}

/**
 * **Le chemin d'une leçon** : l'intro, un cercle par thème, un quiz à chaque palier, le quiz
 * final. Les cercles se remplissent pendant qu'on lit ; on avance l'un après l'autre.
 */
@Composable
fun LessonScreen(id: String) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val lessons by app.lessons.lessons.collectAsState()
    val lesson = lessons[id]

    LaunchedEffect(id) {
        app.lessons.markOpened(id)
        app.lessons.resume(id)
    }

    if (lesson == null) {
        Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
            BackButton(onClick = { navigator.back() })
            Waiting(stringResource(R.string.lesson_notes_writing), Modifier.fillMaxSize())
        }
        return
    }
    LessonPath(lesson)
}

@Composable
private fun LessonPath(lesson: Lesson) {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val haptics = rememberHaptics()
    val tone = colors.tone(lesson.tone)
    // Un plan dont deux paliers partagent un thème donnerait deux fois le même cercle (et la
    // même clé, qui fait planter la liste) : chaque cercle ne compte qu'une fois.
    val circles = remember(lesson) { lesson.pathCircles().distinctBy { it.id } }
    val groups = remember(lesson) { lesson.pathGroups() }
    val rows = remember(circles, groups) { pathRows(circles, groups) }
    val current = circles.firstOrNull { it.id !in lesson.progress.done }
    val done = circles.count { it.id in lesson.progress.done }
    var banner by remember { mutableStateOf<String?>(null) }
    var menu by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf<String?>(null) }
    val listState = rememberLazyListState()
    var placedOnCurrent by remember { mutableStateOf(false) }

    val writingText = stringResource(R.string.lesson_path_writing)
    val finishFirstTemplate = stringResource(R.string.lesson_path_finishFirst, "%s")
    val currentTitle = current?.let { circleTitle(lesson, it) }.orEmpty()

    // Le chemin se cale sur l'étape en cours : d'un coup à l'ouverture, en glissant ensuite.
    val leading = if (lesson.shortened) 2 else 1
    LaunchedEffect(current?.id) {
        val row = rows.indexOfFirst { it is PathRow.Node && it.circle.id == current?.id }
        if (row > 1) {
            if (placedOnCurrent) listState.animateScrollToItem(leading + row - 1) else listState.scrollToItem(leading + row - 1)
        }
        placedOnCurrent = true
    }

    LaunchedEffect(banner) {
        if (banner != null) {
            delay(2600)
            banner = null
        }
    }

    fun tap(circle: PathCircle, title: String) {
        val state = when {
            circle.id in lesson.progress.done -> 0
            circle == current -> 1
            else -> 2
        }
        val blocked = circleBlocked(lesson, circle)
        // Comme sur iPhone, une étape à venir dit d'abord de finir l'étape en cours ; seul un
        // échec se relance d'ici, le titre « Réessayer » n'étant pas un bouton à part.
        when {
            blocked == ThemeStatus.FAILED -> {
                haptics.tap()
                app.lessons.resume(lesson.id, retryFailed = true)
            }
            state == 2 -> {
                haptics.error()
                banner = finishFirstTemplate.replace("%s", currentTitle)
            }
            blocked == ThemeStatus.PENDING -> {
                haptics.error()
                banner = writingText
            }
            else -> openCircle(navigator, lesson, circle)
        }
    }

    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = bottomInset + 190.dp),
        ) {
            item {
                Header(lesson, tone, done, circles.size, onMenu = { menu = true })
            }
            if (lesson.shortened) {
                item {
                    Text(
                        stringResource(R.string.lesson_path_shortened),
                        style = nunito(14.sp, FontWeight.SemiBold),
                        color = colors.caution,
                        modifier = Modifier
                            .padding(horizontal = 20.dp, vertical = 4.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(colors.cautionSoft)
                            .padding(12.dp),
                    )
                }
            }
            items(rows, key = { it.key }) { row ->
                when (row) {
                    is PathRow.Header -> GroupHeader(row.group + 1, row.name, tone)
                    is PathRow.Node -> CircleNode(lesson, row.circle, row.position, tone, state(lesson, row.circle, current), onTap = { tap(row.circle, it) })
                }
            }
        }

        // L'action du bas : continuer, et les deux raccourcis.
        Column(
            Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .background(
                    androidx.compose.ui.graphics.Brush.verticalGradient(
                        listOf(Color.Transparent, colors.canvas.copy(alpha = 0.95f), colors.canvas),
                    ),
                )
                .navigationBarsPadding()
                .padding(start = 20.dp, end = 20.dp, top = 28.dp, bottom = 12.dp),
        ) {
            AnimatedVisibility(visible = banner != null, enter = fadeIn() + slideInVertically { it / 2 }, exit = fadeOut() + slideOutVertically { it / 2 }) {
                Text(
                    banner.orEmpty(),
                    style = nunito(15.sp, FontWeight.Bold),
                    color = colors.onInk,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .padding(bottom = 10.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(colors.ink)
                        .padding(12.dp),
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(bottom = 10.dp)) {
                Shortcut("quiz", stringResource(R.string.lesson_nav_quiz), Modifier.weight(1f)) {
                    if (lesson.readyThemes == 0) banner = writingText else navigator.push(Screen.Quiz(lesson.id, ""))
                }
                Shortcut("cartes", stringResource(R.string.lesson_nav_flashcards), Modifier.weight(1f)) {
                    if (lesson.flashcards.isEmpty()) banner = writingText else navigator.push(Screen.Flashcards(lesson.id))
                }
            }
            val title = current?.let { circleTitle(lesson, it) }
            MicaboButton(
                text = if (current == null) stringResource(R.string.lesson_finished_cards)
                else if (done == 0) stringResource(R.string.lesson_path_start)
                else stringResource(R.string.lesson_path_continue),
                color = tone.vivid.takeIf { colors.dark } ?: colors.accent,
                onClick = {
                    if (current == null) {
                        if (lesson.flashcards.isNotEmpty()) navigator.push(Screen.Flashcards(lesson.id))
                    } else {
                        tap(current, title.orEmpty())
                    }
                },
            )
        }
    }

    if (menu) {
        Box(Modifier.statusBarsPadding().padding(top = 56.dp).fillMaxWidth().padding(end = 20.dp), contentAlignment = Alignment.TopEnd) {
            DropdownMenu(expanded = true, onDismissRequest = { menu = false }, containerColor = colors.surface) {
                DropdownMenuItem(text = { Text(stringResource(R.string.lesson_menu_rename), style = nunito(16.sp, FontWeight.Bold)) }, onClick = {
                    menu = false
                    confirm = "rename"
                })
                DropdownMenuItem(text = { Text(stringResource(R.string.lesson_menu_reset), style = nunito(16.sp, FontWeight.Bold)) }, onClick = {
                    menu = false
                    confirm = "reset"
                })
                DropdownMenuItem(text = { Text(stringResource(R.string.lesson_menu_delete), style = nunito(16.sp, FontWeight.Bold), color = colors.wrong) }, onClick = {
                    menu = false
                    confirm = "delete"
                })
            }
        }
    }
    if (confirm == "rename") {
        RenameDialog(lesson.title, onDismiss = { confirm = null }, onSave = { title ->
            app.lessons.rename(lesson.id, title)
            confirm = null
        })
    }
    confirm?.takeIf { it != "rename" }?.let { action ->
        AlertDialog(
            onDismissRequest = { confirm = null },
            containerColor = colors.surface,
            title = {
                Text(
                    stringResource(if (action == "delete") R.string.lesson_menu_deleteTitle else R.string.lesson_menu_resetTitle),
                    style = nunito(20.sp, FontWeight.ExtraBold),
                )
            },
            text = {
                Text(
                    stringResource(if (action == "delete") R.string.lesson_menu_deleteMessage else R.string.lesson_menu_resetMessage),
                    style = nunito(16.sp),
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    confirm = null
                    if (action == "delete") {
                        app.lessons.delete(lesson.id)
                        app.exams.forgetLesson(lesson.id)
                        navigator.back()
                    } else {
                        app.lessons.restart(lesson.id)
                    }
                }) {
                    Text(
                        stringResource(if (action == "delete") R.string.lesson_menu_delete else R.string.lesson_menu_reset),
                        color = if (action == "delete") colors.wrong else colors.accent,
                        style = nunito(16.sp, FontWeight.ExtraBold),
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { confirm = null }) { Text(stringResource(R.string.lesson_menu_cancel), style = nunito(16.sp, FontWeight.Bold)) }
            },
        )
    }
}

private enum class NodeState { DONE, CURRENT, UPCOMING }

/** Une ligne du chemin : l'en-tête d'un palier, ou un cercle à sa place sur la sinusoïde. */
private sealed interface PathRow {
    val key: String

    data class Header(val group: Int, val name: String) : PathRow {
        override val key = "group:$group"
    }

    data class Node(val circle: PathCircle, val position: Int) : PathRow {
        override val key = circle.id
    }
}

/** L'intro, puis chaque palier (ses thèmes et son quiz), puis le quiz final. */
private fun pathRows(circles: List<PathCircle>, groups: List<com.micabo.app.data.Group>): List<PathRow> = buildList {
    val placed = mutableSetOf<String>()
    var position = 0
    fun node(circle: PathCircle) {
        if (placed.add(circle.id)) add(PathRow.Node(circle, position++))
    }
    circles.firstOrNull()?.let(::node)
    groups.forEachIndexed { groupIndex, group ->
        add(PathRow.Header(groupIndex, group.name))
        circles.filter { circle ->
            (circle is PathCircle.NotesCircle && circle.theme in group.themes) ||
                (circle is PathCircle.QuizCircle && circle.group == groupIndex)
        }.forEach(::node)
    }
    circles.lastOrNull()?.takeIf { it is PathCircle.FinalCircle }?.let(::node)
}

private fun state(lesson: Lesson, circle: PathCircle, current: PathCircle?): NodeState = when {
    circle.id in lesson.progress.done -> NodeState.DONE
    circle == current -> NodeState.CURRENT
    else -> NodeState.UPCOMING
}

@Composable
private fun Header(lesson: Lesson, tone: Tone, done: Int, total: Int, onMenu: () -> Unit) {
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    Column(
        Modifier
            .fillMaxWidth()
            .background(tone.pale)
            .statusBarsPadding()
            .padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 22.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            BackButton(onClick = { navigator.back() })
            Spacer(Modifier.weight(1f))
            // Mika, qui connaît la leçon par cœur (`LessonMikaView`).
            Pressable(onClick = { navigator.push(Screen.Mika(lesson.id)) }) {
                Row(
                    Modifier
                        .clip(RoundedCornerShape(50))
                        .background(colors.surface)
                        .border(1.5.dp, colors.stroke, RoundedCornerShape(50))
                        .padding(start = 4.dp, end = 14.dp, top = 2.dp, bottom = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Mika(MikaMood.WAVE, 38.dp)
                    Text(stringResource(R.string.lesson_mika_open), style = nunito(14.sp, FontWeight.ExtraBold), color = colors.ink)
                }
            }
            Spacer(Modifier.width(10.dp))
            CircleIconButton(Icons.Filled.MoreVert, stringResource(R.string.lesson_menu_more), onClick = onMenu)
        }
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                if (lesson.subject.isNotBlank()) {
                    Text(lesson.subject.uppercase(), style = nunito(12.sp, FontWeight.ExtraBold).copy(letterSpacing = 1.2.sp), color = tone.ink)
                    Spacer(Modifier.height(4.dp))
                }
                Text(
                    plainText(lesson.title),
                    style = nunito(26.sp, FontWeight.Black, lineHeight = 30.sp),
                    color = colors.ink,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.width(10.dp))
            Icon3D(lesson.icon, 84.dp)
        }
        Spacer(Modifier.height(14.dp))
        Text(
            stringResource(R.string.lesson_path_stepsDone, done.toString(), total.toString()),
            style = nunito(14.sp, FontWeight.Bold),
            color = tone.ink,
        )
        Spacer(Modifier.height(6.dp))
        ProgressBar(if (total == 0) 0f else done / total.toFloat(), color = tone.vivid)
    }
}

@Composable
private fun GroupHeader(number: Int, name: String, tone: Tone) {
    val colors = Micabo.colors
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.weight(1f).height(2.dp).background(colors.stroke))
        Text(
            if (name.isBlank()) stringResource(R.string.lesson_path_palier, number.toString())
            else stringResource(R.string.lesson_path_palierNamed, number.toString(), plainText(name)),
            style = nunito(14.sp, FontWeight.ExtraBold),
            color = tone.ink,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .padding(horizontal = 10.dp)
                .widthIn(max = 260.dp)
                .clip(CircleShape)
                .background(tone.pale)
                .padding(horizontal = 14.dp, vertical = 6.dp),
        )
        Box(Modifier.weight(1f).height(2.dp).background(colors.stroke))
    }
}

@Composable
private fun CircleNode(lesson: Lesson, circle: PathCircle, position: Int, tone: Tone, state: NodeState, onTap: (String) -> Unit) {
    val colors = Micabo.colors
    val title = circleTitle(lesson, circle)
    val blocked = circleBlocked(lesson, circle)
    // Le chemin serpente : chaque cercle se décale sur une sinusoïde.
    val offset = (sin(position * 0.9) * 70).dp
    val milestone = circle is PathCircle.QuizCircle || circle is PathCircle.FinalCircle
    val size = if (milestone) 88.dp else 78.dp
    // Seule l'étape en cours respire : une animation sans fin par cercle redessinerait tout le chemin.
    val scale = if (state == NodeState.CURRENT) {
        val pulse = rememberInfiniteTransition(label = "pulse")
        pulse.animateFloat(1f, 1.06f, infiniteRepeatable(tween(900, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "scale").value
    } else {
        1f
    }
    val stateLabel = stringResource(
        when (state) {
            NodeState.DONE -> R.string.lesson_path_a11y_done
            NodeState.CURRENT -> R.string.lesson_path_a11y_current
            NodeState.UPCOMING -> R.string.lesson_path_a11y_locked
        },
    )
    val ring = when (state) {
        NodeState.DONE -> colors.correct
        NodeState.CURRENT -> tone.vivid
        NodeState.UPCOMING -> colors.stroke
    }
    Column(
        Modifier.fillMaxWidth().padding(vertical = 8.dp).offset(x = offset),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (state == NodeState.CURRENT && blocked == null) {
            Text(
                stringResource(if (lesson.progress.done.isEmpty()) R.string.lesson_path_start else R.string.lesson_path_continue).uppercase(),
                style = nunito(13.sp, FontWeight.Black).copy(letterSpacing = 1.sp),
                color = tone.ink,
                modifier = Modifier
                    .padding(bottom = 8.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(colors.surface)
                    .border(2.dp, tone.vivid, RoundedCornerShape(12.dp))
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            )
        }
        Pressable(
            onClick = { onTap(title) },
            modifier = Modifier.scale(scale).semantics(mergeDescendants = true) { contentDescription = "$title, $stateLabel" },
        ) {
            Box(contentAlignment = Alignment.Center) {
                Box(
                    Modifier
                        .size(size + 12.dp)
                        .clip(CircleShape)
                        .background(ring.copy(alpha = if (state == NodeState.UPCOMING) 1f else 0.9f)),
                )
                Box(
                    Modifier
                        .size(size)
                        .clip(CircleShape)
                        .background(if (state == NodeState.UPCOMING) colors.surfaceMuted else tone.pale),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon3D(circleIcon(lesson, circle), size * 0.68f, Modifier.alpha(if (state == NodeState.UPCOMING || blocked != null) 0.45f else 1f))
                }
                when {
                    blocked == ThemeStatus.PENDING -> Badge(colors.surface, Modifier.align(Alignment.BottomEnd)) { TypingDots(tone.vivid) }
                    blocked == ThemeStatus.FAILED -> Badge(colors.wrong, Modifier.align(Alignment.BottomEnd)) {
                        Icon(Icons.Filled.Refresh, null, tint = Color.White, modifier = Modifier.size(16.dp))
                    }
                    state == NodeState.DONE -> Badge(colors.correct, Modifier.align(Alignment.BottomEnd)) {
                        Icon(Icons.Filled.Check, null, tint = Color.White, modifier = Modifier.size(16.dp))
                    }
                    state == NodeState.UPCOMING -> Badge(colors.surface, Modifier.align(Alignment.BottomEnd)) {
                        Icon(Icons.Filled.Lock, null, tint = colors.inkTertiary, modifier = Modifier.size(14.dp))
                    }
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        Text(
            title,
            style = nunito(15.sp, if (state == NodeState.CURRENT) FontWeight.ExtraBold else FontWeight.Bold, lineHeight = 19.sp),
            color = if (state == NodeState.UPCOMING) colors.inkSecondary else colors.ink,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.widthIn(max = 200.dp),
        )
        if (blocked == ThemeStatus.FAILED) {
            Text(stringResource(R.string.lesson_path_retry), style = nunito(13.sp, FontWeight.ExtraBold), color = colors.wrongInk)
        } else if (circle is PathCircle.QuizCircle && circle.name.isNotBlank()) {
            Text(plainText(circle.name), style = nunito(13.sp, FontWeight.SemiBold), color = colors.inkSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 200.dp))
        }
    }
}

@Composable
private fun Badge(color: Color, modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val colors = Micabo.colors
    Box(
        modifier
            .size(30.dp)
            .clip(CircleShape)
            .background(color)
            .border(2.dp, colors.canvas, CircleShape),
        contentAlignment = Alignment.Center,
    ) { content() }
}

@Composable
private fun Shortcut(icon: String, label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val colors = Micabo.colors
    Pressable(onClick = onClick, modifier = modifier) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(colors.surface)
                .border(1.5.dp, colors.stroke, RoundedCornerShape(16.dp))
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Icon3D(icon, 28.dp)
            Spacer(Modifier.width(8.dp))
            Text(label, style = nunito(15.sp, FontWeight.ExtraBold), color = colors.ink)
        }
    }
}

