package com.micabo.app.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import com.micabo.app.MicaboApplication
import com.micabo.app.data.LessonRequest
import com.micabo.app.ui.exams.ExamEditScreen
import com.micabo.app.ui.exams.MockExamScreen
import com.micabo.app.ui.home.CreatingScreen
import com.micabo.app.ui.lesson.FlashcardsScreen
import com.micabo.app.ui.lesson.MikaScreen
import com.micabo.app.ui.lesson.IntroScreen
import com.micabo.app.ui.lesson.LessonScreen
import com.micabo.app.ui.lesson.NotesScreen
import com.micabo.app.ui.lesson.QuizScreen
import com.micabo.app.ui.onboarding.OnboardingScreen
import com.micabo.app.ui.paywall.PaywallScreen
import com.micabo.app.ui.streak.StreakCelebration
import com.micabo.app.ui.theme.Micabo

/** Les écrans de l'app. */
sealed interface Screen {
    /** Les onglets : Accueil, Leçons, Examens, Profil. */
    data object Home : Screen
    data class Creating(val request: LessonRequest) : Screen
    data class LessonPath(val id: String) : Screen
    data class Intro(val id: String) : Screen
    data class Notes(val id: String, val theme: Int) : Screen
    /** Un quiz : celui d'un palier, le final, ou « tout le quiz » (`circle` vide). */
    data class Quiz(val id: String, val circle: String) : Screen
    data class Flashcards(val id: String) : Screen
    data class Mika(val id: String) : Screen
    /** Un examen à créer (`id` nul) ou à modifier. */
    data class ExamEdit(val id: String?) : Screen
    /** Un examen blanc, sur un examen déclaré ou non. */
    data class Mock(val examId: String?) : Screen
    /** `reason` : le code du refus (`free_limit`, `import_pro`…), vide depuis les réglages. */
    data class Paywall(val reason: String) : Screen

    /** Les écrans qui montent du bas, comme une feuille. */
    val isModal: Boolean get() = this is Paywall || this is Creating
}

/** Les onglets du bas (`RootTab`). */
enum class Tab { HOME, LESSONS, EXAMS, PROFILE }

/** La place que prend la barre d'onglets, à garder libre en bas des onglets. */
val TAB_BAR_SPACE = 84.dp

/** La pile d'écrans : pousser, revenir, remplacer ; et l'onglet ouvert sous la pile. */
class Navigator(initial: Screen) {
    val stack = mutableStateListOf(initial)
    var tab by mutableStateOf(Tab.HOME)
    val current: Screen get() = stack.last()
    var forward = true
        private set

    fun push(screen: Screen) {
        forward = true
        stack.add(screen)
    }

    fun replace(screen: Screen) {
        forward = true
        stack[stack.lastIndex] = screen
    }

    fun back(): Boolean {
        if (stack.size <= 1) return false
        forward = false
        stack.removeAt(stack.lastIndex)
        return true
    }

    /** Revient à l'accueil : la pile se vide, l'onglet Accueil s'ouvre. */
    fun home() {
        forward = false
        while (stack.size > 1) stack.removeAt(stack.lastIndex)
        tab = Tab.HOME
    }
}

val LocalApp = staticCompositionLocalOf<MicaboApplication> { error("Pas d'app") }
val LocalNavigator = staticCompositionLocalOf<Navigator> { error("Pas de navigation") }

@Composable
fun MicaboRoot(app: MicaboApplication) {
    val profile by app.prefs.profile.collectAsState()
    val navigator = remember { Navigator(Screen.Home) }

    CompositionLocalProvider(LocalApp provides app, LocalNavigator provides navigator) {
        Box(Modifier.fillMaxSize().background(Micabo.colors.canvas)) {
            if (!profile.onboarded) {
                OnboardingScreen()
            } else {
                MainScreens(navigator)
                StreakCelebrationHost(navigator)
            }
        }
    }
}

@Composable
private fun MainScreens(navigator: Navigator) {
            // Le retour du système : la pile d'abord, puis l'onglet Accueil, puis quitter l'app.
            BackHandler(enabled = navigator.stack.size > 1 || navigator.tab != Tab.HOME) {
                if (!navigator.back()) navigator.tab = Tab.HOME
            }
            AnimatedContent(
                targetState = navigator.current,
                transitionSpec = {
                    val modal = targetState.isModal || initialState.isModal
                    if (modal) {
                        if (navigator.forward) {
                            (slideInVertically(tween(380)) { it / 3 } + fadeIn(tween(300))) togetherWith fadeOut(tween(200))
                        } else {
                            fadeIn(tween(250)) togetherWith (slideOutVertically(tween(320)) { it / 3 } + fadeOut(tween(260)))
                        }
                    } else if (navigator.forward) {
                        (slideInHorizontally(tween(340)) { it / 4 } + fadeIn(tween(300))) togetherWith
                            (slideOutHorizontally(tween(340)) { -it / 8 } + fadeOut(tween(220)))
                    } else {
                        (slideInHorizontally(tween(340)) { -it / 8 } + fadeIn(tween(300))) togetherWith
                            (slideOutHorizontally(tween(340)) { it / 4 } + fadeOut(tween(220)))
                    }
                },
                label = "screens",
            ) { screen ->
                Box(Modifier.fillMaxSize().background(Micabo.colors.canvas)) {
                    when (screen) {
                        Screen.Home -> TabsScreen(navigator)
                        is Screen.Creating -> CreatingScreen(screen.request)
                        is Screen.LessonPath -> LessonScreen(screen.id)
                        is Screen.Intro -> IntroScreen(screen.id)
                        is Screen.Notes -> NotesScreen(screen.id, screen.theme)
                        is Screen.Quiz -> QuizScreen(screen.id, screen.circle)
                        is Screen.Flashcards -> FlashcardsScreen(screen.id)
                        is Screen.Mika -> MikaScreen(screen.id)
                        is Screen.ExamEdit -> ExamEditScreen(screen.id)
                        is Screen.Mock -> MockExamScreen(screen.examId)
                        is Screen.Paywall -> PaywallScreen(screen.reason)
                    }
                }
            }
}

/**
 * La flamme du jour, célébrée une fois, au retour sur le chemin ou les onglets : jamais au
 * milieu d'une étape.
 */
@Composable
private fun StreakCelebrationHost(navigator: Navigator) {
    val app = LocalApp.current
    val pending by app.streak.celebrate.collectAsState()
    val status by app.streak.status.collectAsState()
    val calm = navigator.current is Screen.Home || navigator.current is Screen.LessonPath
    if (pending && calm && status.current > 0) {
        StreakCelebration(status, onDismiss = { app.streak.celebrated() })
    }
}
