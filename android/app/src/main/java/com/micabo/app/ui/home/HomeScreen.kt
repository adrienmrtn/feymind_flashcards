package com.micabo.app.ui.home

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import com.micabo.app.data.MikaGate
import com.micabo.app.data.XpRules
import com.micabo.app.data.dueCards
import com.micabo.app.ui.lesson.QUICK_QUIZ
import com.micabo.app.ui.xp.ProPill
import com.micabo.app.ui.xp.XpPill
import kotlinx.coroutines.launch
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.micabo.app.R
import com.micabo.app.data.Lesson
import com.micabo.app.data.LessonComposer
import com.micabo.app.data.currentCircle
import com.micabo.app.data.learnedCards
import com.micabo.app.ui.TAB_BAR_SPACE
import com.micabo.app.ui.lesson.circleTitle
import com.micabo.app.ui.streak.StreakPill
import com.micabo.app.ui.streak.StreakSheet
import com.micabo.app.data.pathCircles
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.CircleIconButton
import com.micabo.app.ui.components.Icon3D
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.components.TypingDots
import com.micabo.app.ui.components.rememberHaptics
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.text.plainText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import com.micabo.app.ui.theme.tone
import kotlinx.coroutines.delay

/**
 * **L'accueil** (`HomeView`) : la série en haut, la grande question, la barre et ses supports,
 * les trois chiffres de l'élève et « Reprendre » sur la dernière leçon ouverte.
 */
@Composable
fun HomeScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val colors = Micabo.colors
    val lessons by app.lessons.lessons.collectAsState()
    val composer = app.composer
    val isPro by app.billing.isPro.collectAsState()
    var full by remember { mutableStateOf(false) }
    var streakSheet by remember { mutableStateOf(false) }
    val focus = LocalFocusManager.current
    val focusSeconds by app.focus.seconds.collectAsState()
    val xpStatus by app.xp.status.collectAsState()
    // Le temps du minuteur compte dans le temps de révision, comme celui passé dans les leçons.
    val stats = remember(lessons, focusSeconds) { HomeStats.of(lessons.values).let { it.copy(seconds = it.seconds + focusSeconds) } }
    val resume = remember(lessons) { lessons.values.filter { it.openedAt > 0 }.maxByOrNull { it.openedAt } }
    // Les cartes dues de toutes les leçons ; « Réviser » ouvre la leçon qui en a le plus.
    val due = remember(lessons) { lessons.values.map { it to it.dueCards() }.filter { it.second > 0 } }
    val dueTotal = due.sumOf { it.second }
    val list = rememberLazyListState()
    val composerFocus = remember { FocusRequester() }
    val keyboard = LocalSoftwareKeyboardController.current
    val scope = rememberCoroutineScope()

    // La leçon du parcours d'accueil (`LessonCreation.onboarding`) : la première après l'accueil,
    // tant qu'aucune leçon ne compte. Comme sur l'iPhone et le site, elle peut partir d'un PDF ou
    // de photos sans abonnement : le serveur l'accorde une fois (`begin_lesson`, `p_onboarding`).
    val onboardingLesson = app.prefs.onboardingLessonPending && lessons.values.none { it.usesFreeLesson }
    // **La leçon offerte peut venir d'un import** (`docs/refonte-knowunity.md` § 7) : tant qu'elle
    // n'a pas servi, un élève sans Pro la crée depuis un PDF, des photos ou YouTube, et la
    // génération part avec `onboarding: true`. Ensuite, les imports rouvrent le paywall.
    val freeLessonLeft = !isPro && lessons.values.none { it.usesFreeLesson }

    // La porte du gratuit, côté app (`LessonAllowance.gate`) : la leçon offerte ne se crée qu'une
    // fois. Le serveur tient la même porte ; celle-ci évite un appel refusé. Un paquet ou un cours
    // d'exemple venu de l'iPhone ne la ferme pas (`Lesson.usesFreeLesson`).
    fun send() {
        // Un double toucher n'empile pas deux écrans (création ou paywall) l'un sur l'autre.
        if (!composer.canSend || navigator.current != Screen.Home) return
        focus.clearFocus()
        when {
            !isPro && composer.needsPro && !freeLessonLeft -> navigator.push(Screen.Paywall("import_pro"))
            !isPro && !freeLessonLeft -> navigator.push(Screen.Paywall("free_limit"))
            else -> navigator.push(
                Screen.Creating(composer.request(examDate = null).copy(onboarding = onboardingLesson || (freeLessonLeft && composer.needsPro))),
            )
        }
    }

    /** Un écran de l'accueil ; un double toucher n'en empile pas deux. */
    fun open(screen: Screen) {
        if (navigator.current == Screen.Home) navigator.push(screen)
    }

    /** Le curseur dans la barre, la barre en vue : pour écrire sa première leçon. */
    fun focusComposer() {
        scope.launch {
            list.animateScrollToItem(0)
            runCatching { composerFocus.requestFocus() }
            keyboard?.show()
        }
    }

    // **Les notifications** (Android 13 et plus) : demandées ici, et seulement ici. Plus juste
    // avant le paywall (l'étape du rappel de l'accueil), où la fenêtre du système coupait l'élan
    // vers l'essai. Pas tant que le cadeau du paywall attend ou s'affiche, ni avant la première
    // leçon : le rappel du jour n'a rien à rappeler sans elle. Une fois, jamais en boucle.
    val context = LocalContext.current
    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { app.rescheduleReminders() }
    val onHome = navigator.current == Screen.Home
    val giftPending by app.gift.pending.collectAsState()
    val giftShown by app.gift.presentation.collectAsState()
    val hasLesson = lessons.isNotEmpty()
    LaunchedEffect(onHome, giftPending, giftShown, hasLesson) {
        if (!onHome || giftPending || giftShown != null || !hasLesson) return@LaunchedEffect
        if (Build.VERSION.SDK_INT < 33 || app.prefs.notificationsAsked) return@LaunchedEffect
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return@LaunchedEffect
        // Le paywall refermé pose le cadeau un instant après l'arrivée sur l'accueil (`GiftHost`) :
        // on lui laisse le temps de tomber, puis on revérifie.
        delay(1_500)
        if (navigator.current != Screen.Home || app.gift.pending.value || app.gift.presentation.value != null) return@LaunchedEffect
        app.prefs.notificationsAsked = true
        notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    // Un support refusé parce qu'il faut Pro (une vidéo ou un enregistrement, 402 `import_pro`) :
    // le paywall s'ouvre une fois, au lieu d'une pastille « illisible » sans issue.
    val refused = composer.supports.firstOrNull { it.paywall != null }
    LaunchedEffect(refused?.id, onHome) {
        val support = refused ?: return@LaunchedEffect
        val code = support.paywall ?: return@LaunchedEffect
        if (!onHome) return@LaunchedEffect
        composer.paywallShown(support.id)
        navigator.push(Screen.Paywall(code))
    }

    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    LazyColumn(
        Modifier.fillMaxSize(),
        state = list,
        contentPadding = PaddingValues(top = top + 8.dp, bottom = bottom + TAB_BAR_SPACE + 16.dp),
    ) {
        item {
            // La rangée du haut : « ✦ Pro » pour qui ne l'est pas, puis l'XP de la semaine et la série.
            Row(Modifier.padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                Image(
                    painterResource(R.mipmap.ic_launcher_foreground_art),
                    contentDescription = null,
                    modifier = Modifier.size(34.dp).clip(RoundedCornerShape(10.dp)),
                )
                Spacer(Modifier.width(8.dp))
                if (isPro) {
                    Text(stringResource(R.string.app_name), style = nunito(22.sp, FontWeight.Black), color = colors.ink, maxLines = 1)
                } else {
                    ProPill(onClick = { open(Screen.Paywall("")) })
                }
                Spacer(Modifier.weight(1f))
                XpPill(onClick = { open(Screen.League) })
                Spacer(Modifier.width(8.dp))
                StreakPill(onClick = { streakSheet = true })
            }
        }
        item {
            Row(Modifier.padding(start = 20.dp, end = 20.dp, top = 22.dp), verticalAlignment = Alignment.Bottom) {
                RichText(
                    stringResource(R.string.lesson_home_title),
                    style = nunito(30.sp, FontWeight.Black, lineHeight = 34.sp),
                    color = colors.ink,
                    modifier = Modifier.weight(1f),
                )
                Mika(MikaMood.IDLE, 84.dp)
            }
        }
        item {
            ComposerCard(composer, onSend = ::send, focusRequester = composerFocus)
        }
        item {
            // Plus de cadenas sur les imports tant que la leçon offerte reste.
            SourceRow(
                composer,
                isPro = isPro || onboardingLesson || freeLessonLeft,
                onFull = { full = true },
                onLocked = {
                    focus.clearFocus()
                    if (navigator.current == Screen.Home) navigator.push(Screen.Paywall("import_pro"))
                },
            )
        }
        item {
            TodayCard(
                status = xpStatus,
                hasLessons = lessons.isNotEmpty(),
                dueCards = dueTotal,
                resume = resume,
                onReview = { due.maxByOrNull { it.second }?.first?.let { open(Screen.Flashcards(it.id)) } },
                onContinue = { open(Screen.LessonPath(it.id)) },
                onCreate = ::focusComposer,
            )
        }
        item {
            // Le quiz éclair part de la dernière leçon ouverte (sinon de la plus récente).
            val quizLesson = resume ?: lessons.values.maxByOrNull { it.createdAt }
            ToolsGrid(
                listOf(
                    Tool("loupe", 2, stringResource(R.string.kx_tool_scan), stringResource(R.string.kx_tool_scanSub)) {
                        // La porte de Mika d'abord : pas de photo prise pour rien avant le paywall.
                        if (app.mika.gate(isPro) == MikaGate.PAYWALL) open(Screen.Paywall("pro_required", trigger = "mika")) else open(Screen.Exercise)
                    },
                    Tool(
                        "quiz", 4, stringResource(R.string.kx_tool_quiz),
                        if (quizLesson == null) stringResource(R.string.kx_tool_quizEmpty) else stringResource(R.string.kx_tool_quizSub),
                    ) {
                        if (quizLesson == null) focusComposer() else open(Screen.Quiz(quizLesson.id, QUICK_QUIZ))
                    },
                    Tool("reveil", 1, stringResource(R.string.kx_tool_focus), stringResource(R.string.kx_tool_focusSub, XpRules.FOCUS_MINUTES.toString())) {
                        open(Screen.Focus)
                    },
                    Tool("trophee", 0, stringResource(R.string.kx_tool_league), stringResource(R.string.kx_tool_leagueSub)) {
                        open(Screen.League)
                    },
                ),
            )
        }
        if (lessons.isNotEmpty()) {
            item { StatsCard(stats) }
        }
    }

    if (full) {
        AlertDialog(
            onDismissRequest = { full = false },
            text = { Text(stringResource(R.string.lesson_home_supportsFull, LessonComposer.MAX_SUPPORTS.toString()), style = nunito(16.sp)) },
            confirmButton = { TextButton(onClick = { full = false }) { Text(stringResource(R.string.ios_ok), style = nunito(16.sp, FontWeight.ExtraBold)) } },
            containerColor = colors.surface,
        )
    }
    if (streakSheet) {
        StreakSheet(
            onDismiss = { streakSheet = false },
            onStudy = {
                streakSheet = false
                resume?.let { navigator.push(Screen.LessonPath(it.id)) }
            },
        )
    }
}

/** **Les trois chiffres de l'accueil** (`HomeStats`) : tout est mesuré, rien n'est estimé. */
data class HomeStats(val seconds: Long, val learnedLessons: Int, val learnedCards: Int) {
    companion object {
        fun of(lessons: Collection<Lesson>): HomeStats = HomeStats(
            seconds = lessons.sumOf { it.progress.seconds },
            learnedLessons = lessons.count { it.progress.finishedAt > 0 },
            learnedCards = lessons.sumOf { it.learnedCards() },
        )
    }
}

/** « 12 min » sous l'heure, « 1,5 h » sous dix heures, « 14 h » au-delà. */
@Composable
private fun formattedTime(seconds: Long): String {
    val minutes = Math.round(seconds / 60.0).toInt()
    if (minutes < 60) return stringResource(R.string.lesson_home_minutes, minutes.toString())
    val hours = seconds / 3600.0
    val value = if (hours < 10) {
        java.text.NumberFormat.getNumberInstance().apply { maximumFractionDigits = 1; minimumFractionDigits = 0 }.format(Math.round(hours * 10) / 10.0)
    } else {
        Math.round(hours).toString()
    }
    return stringResource(R.string.lesson_home_hours, value)
}

@Composable
private fun StatsCard(stats: HomeStats) {
    val colors = Micabo.colors
    Row(
        Modifier
            .padding(start = 20.dp, end = 20.dp, top = 26.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(colors.surface)
            .border(1.5.dp, colors.stroke, RoundedCornerShape(24.dp))
            .padding(vertical = 18.dp, horizontal = 8.dp),
    ) {
        Stat("sablier", formattedTime(stats.seconds), stringResource(R.string.lesson_home_statTime), Modifier.weight(1f))
        Stat("diplome", stats.learnedLessons.toString(), stringResource(R.string.lesson_home_statLessons), Modifier.weight(1f))
        Stat("cartes", stats.learnedCards.toString(), stringResource(R.string.lesson_home_statCards), Modifier.weight(1f))
    }
}

@Composable
private fun Stat(icon: String, value: String, label: String, modifier: Modifier) {
    val colors = Micabo.colors
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        Icon3D(icon, 34.dp)
        Spacer(Modifier.height(6.dp))
        Text(value, style = nunito(22.sp, FontWeight.Black), color = colors.ink, maxLines = 1)
        Text(
            label,
            style = nunito(13.sp, FontWeight.SemiBold, lineHeight = 16.sp),
            color = colors.inkSecondary,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            maxLines = 2,
        )
    }
}

