package com.micabo.app.ui.onboarding

import android.content.Context
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.imePadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.clickable
import androidx.core.content.edit
import com.micabo.app.SignInEvent
import com.micabo.app.data.FirstLesson
import com.micabo.app.onboarding.OnboardingModel
import com.micabo.app.onboarding.OnboardingStep
import com.micabo.app.onboarding.OnboardingStore
import com.micabo.app.onboarding.TargetScore
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.BackButton
import com.micabo.app.ui.settings.SignInSheet
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.v3.ChapterGauge
import java.time.ZoneId

/** Les réponses du parcours, gardées dans les préférences de l'app. */
class PrefsOnboardingStore(context: Context) : OnboardingStore {
    private val prefs = context.getSharedPreferences("micabo", Context.MODE_PRIVATE)
    override fun string(key: String): String? = prefs.getString(key, null)
    override fun putString(key: String, value: String?) = prefs.edit { if (value == null) remove(key) else putString(key, value) }
    override fun strings(key: String): List<String> = prefs.getString(key, null)?.split('\u0000')?.filter { it.isNotEmpty() }.orEmpty()
    override fun putStrings(key: String, value: List<String>) = prefs.edit { putString(key, value.joinToString("\u0000")) }
}

/**
 * **Ce que l'app fournit au parcours** : de quoi le rendre sans l'app entière (les rendus des
 * tests posent le parcours sur un écran, avec les réponses de Lina).
 */
interface OnboardingHost {
    /** Les jours d'essai du catalogue (Google Play : 3 jours sur l'hebdomadaire et l'annuel). */
    val trialDays: Int
    fun track(event: String, props: Map<String, Any> = emptyMap())
    fun pickLanguage(code: String)
    fun signIn()
    fun finish(model: OnboardingModel)
}

/** **Le parcours d'accueil** dans l'app : le modèle repris là où l'élève l'avait laissé. */
@Composable
fun OnboardingScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    // **L'essai** : proposé tant que Google Play ne dit pas explicitement que ce compte n'y a
    // plus droit (`OnboardingTrial.isOffered`). Une réponse inconnue ou en retard laisse le
    // catalogue parler : l'essai de 3 jours s'affiche.
    var trialAnswer by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(Unit) {
        val load = runCatching { app.billing.loadPlans() }.getOrNull()
        if (load != null && load.plans.isNotEmpty()) trialAnswer = load.plans.maxOf { it.trialDays }
        app.analytics.track("paywall_trial_status", mapOf("status" to when (trialAnswer) { null -> "unknown"; 0 -> "ineligible"; else -> "eligible" }))
    }
    val model = remember {
        OnboardingModel(
            store = PrefsOnboardingStore(context),
            track = { event, props -> app.analytics.track(event, props) },
            trialOffered = { trialAnswer?.let { it > 0 } ?: true },
        ).also { it.resume() }
    }
    LaunchedEffect(Unit) {
        app.analytics.track("onboarding_started", mapOf("resumed" to model.isResumed))
    }
    val account by app.auth.account.collectAsState()
    model.hasAccount = account != null
    var signingIn by remember { mutableStateOf(false) }
    val signInEvent by app.signIn.collectAsState()
    LaunchedEffect(signInEvent) {
        if (signInEvent is SignInEvent.Success) {
            signingIn = false
            app.signInSeen()
            if (model.isAccountSheetPresented) model.finishAccountSheet()
        }
    }
    val host = remember {
        object : OnboardingHost {
            override val trialDays: Int get() = trialAnswer?.takeIf { it > 0 } ?: 3
            override fun track(event: String, props: Map<String, Any>) = app.analytics.track(event, props)
            override fun pickLanguage(code: String) {
                app.prefs.update { it.copy(language = code) }
                (context as? android.app.Activity)?.recreate()
            }
            override fun signIn() {
                signingIn = true
            }
            override fun finish(model: OnboardingModel) = finishOnboarding(app, navigator, model)
        }
    }
    OnboardingFlow(model, host)
    if (signingIn || model.isAccountSheetPresented) {
        SignInSheet(
            failure = (signInEvent as? SignInEvent.Failure)?.error,
            onDismiss = {
                signingIn = false
                app.signInSeen()
                if (model.isAccountSheetPresented) model.finishAccountSheet()
            },
        )
    }
}

/**
 * **La fin du parcours** : le profil part (ce qui dit au serveur pour qui écrire), la première
 * leçon choisie attend l'accueil (aucune leçon n'est écrite avant le paywall), et le paywall
 * s'ouvre. Le refermer mène à l'app, avec une leçon offerte.
 */
fun finishOnboarding(app: com.micabo.app.MicaboApplication, navigator: com.micabo.app.ui.Navigator, model: OnboardingModel) {
    if (app.prefs.profile.value.onboarded) return
    model.persist()
    val exam = model.datedExam
    app.prefs.update {
        it.copy(
            onboarded = true,
            name = model.displayName.trim(),
            country = model.country,
            region = model.customCountry?.lowercase().orEmpty(),
            tier = model.tier ?: "other",
            trackId = model.schoolTrack?.id.orEmpty(),
            yearId = model.schoolYear?.id.orEmpty(),
            stageTitle = model.stage?.title.orEmpty(),
            examId = model.examChoice?.id.orEmpty(),
            examDay = exam?.second?.toEpochDay() ?: -1L,
            subjects = model.subjects.toSet(),
            hardestSubject = model.hardestSubject.orEmpty(),
            worries = model.worries.map { w -> w.name }.toSet(),
            goals = buildSet {
                model.goal?.let { g -> add(g.name) }
                model.examChoice?.let { choice -> add(if (choice.hasDate) "exam" else "lectures") }
            },
            currentScore = model.currentScore?.takeIf { s -> s >= TargetScore.MIN }?.let(TargetScore::percent),
            targetScore = model.targetScore?.let(TargetScore::percent),
            grade = model.currentScore ?: -1,
            gradeTarget = model.targetScore ?: -1,
            dailyMinutes = model.minutesPerDay,
            studyHour = model.reminderHour,
        )
    }
    FirstLesson.save(app, model.firstLessonSubject, model.firstLessonChoice == com.micabo.app.onboarding.FirstLessonChoice.IMPORT)
    app.prefs.onboardingLessonPending = app.lessons.lessons.value.values.none { it.usesFreeLesson }
    app.analytics.track("onboarding_finished", mapOf("tier" to (model.tier ?: "other"), "worries" to model.worries.size, "daily" to model.minutesPerDay))
    if (app.billing.enabled && !app.billing.isPro.value) navigator.push(Screen.Paywall("onboarding"))
}

/**
 * **Le parcours, posé sur son modèle** : la barre du haut (retour, jauge à sept segments),
 * l'écran de l'étape, qui glisse. Les rendus le posent tel quel.
 */
@Composable
fun OnboardingFlow(model: OnboardingModel, host: OnboardingHost) {
    val colors = Micabo.colors
    val step = model.step
    BackHandler(enabled = model.canGoBack) { model.goBack() }
    LaunchedEffect(step) {
        if (step == OnboardingStep.paywall) host.finish(model)
    }
    Column(Modifier.fillMaxSize().background(colors.canvas).statusBarsPadding().imePadding()) {
        if (step.showsChrome) {
            Row(
                Modifier.fillMaxWidth().heightIn(min = 52.dp).padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (model.canGoBack) BackButton(onClick = model::goBack) else Spacer(Modifier.size(44.dp))
                Spacer(Modifier.width(14.dp))
                ChapterGauge(step.chapter, step.chapterFraction, OnboardingStep.CHAPTER_COUNT, Modifier.weight(1f))
                Spacer(Modifier.width(8.dp))
                if (step == OnboardingStep.currentAverage) {
                    androidx.compose.material3.Text(
                        com.micabo.app.i18n.t("common.skip"),
                        style = com.micabo.app.ui.theme.text(17.sp, androidx.compose.ui.text.font.FontWeight.SemiBold),
                        color = colors.inkSecondary,
                        modifier = Modifier.clickable(onClick = model::skipAverages).padding(horizontal = 6.dp, vertical = 12.dp),
                    )
                }
            }
        }
        AnimatedContent(
            targetState = step,
            transitionSpec = {
                val direction = if (model.isMovingForward) 1 else -1
                (slideInHorizontally(tween(320)) { direction * it / 3 } + fadeIn(tween(260))) togetherWith
                    (slideOutHorizontally(tween(320)) { -direction * it / 4 } + fadeOut(tween(200)))
            },
            modifier = Modifier.weight(1f).testTag("step:${step.name}"),
            label = "onboarding",
        ) { shown ->
            Box(Modifier.fillMaxSize()) { StepScreen(shown, model, host) }
        }
    }
}

@Composable
fun StepScreen(step: OnboardingStep, model: OnboardingModel, host: OnboardingHost) {
    when (step) {
        OnboardingStep.hookLogo -> StoriesStep(model, host)
        OnboardingStep.welcome -> WelcomeStep(model)
        OnboardingStep.name -> NameStep(model)
        OnboardingStep.country -> CountryStep(model)
        OnboardingStep.level -> LevelStep(model)
        OnboardingStep.schoolType -> SchoolTypeStep(model)
        OnboardingStep.year -> SchoolYearStep(model)
        OnboardingStep.exam -> ExamStep(model)
        OnboardingStep.subjects -> SubjectsStep(model)
        OnboardingStep.studyIntro, OnboardingStep.helpIntro, OnboardingStep.goalIntro,
        OnboardingStep.organizeIntro, OnboardingStep.storyIntro -> ChapterOpenerStep(step, model)
        OnboardingStep.hardestSubject -> HardestSubjectStep(model)
        OnboardingStep.goal -> GoalStep(model)
        OnboardingStep.worries -> WorriesStep(model)
        OnboardingStep.studyHours -> StudyHoursStep(model)
        OnboardingStep.studyMethod -> StudyMethodStep(model)
        OnboardingStep.solutionMap -> SolutionMapStep(model)
        OnboardingStep.origin -> OriginStep(model)
        OnboardingStep.lessonDemo -> LessonDemoStep(model)
        OnboardingStep.scanDemo -> ScanDemoStep(model)
        OnboardingStep.research -> ResearchStep(model)
        OnboardingStep.currentAverage -> CurrentAverageStep(model)
        OnboardingStep.targetAverage -> TargetAverageStep(model)
        OnboardingStep.startingPoint -> StartingPointStep(model)
        OnboardingStep.dailyTime -> DailyTimeStep(model)
        OnboardingStep.planDemo -> PlanDemoStep(model)
        OnboardingStep.focusDemo -> FocusDemoStep(model)
        OnboardingStep.notifications -> NotificationsStep(model, host)
        OnboardingStep.commitment -> CommitmentStep(model)
        OnboardingStep.planBuilding -> PlanBuildingStep(model)
        OnboardingStep.profileSummary -> ProfileSummaryStep(model)
        OnboardingStep.storyCreate -> StoryCreateStep(model)
        OnboardingStep.storyPath -> StoryPathStep(model)
        OnboardingStep.storyPractice -> StoryPracticeStep(model)
        OnboardingStep.storyAsk -> StoryAskStep(model)
        OnboardingStep.storyClose -> StoryCloseStep(model)
        OnboardingStep.firstLesson -> FirstLessonStep(model)
        OnboardingStep.freeTrialIntro -> FreeTrialIntroStep(model)
        OnboardingStep.trialOffer -> TrialOfferStep(model, host)
        OnboardingStep.paywall -> Box(Modifier.fillMaxSize().background(Micabo.colors.canvas))
    }
}

/** Le sens de lecture : les visuels de démo (formules, chemins) restent de gauche à droite. */
@Composable
fun LeftToRight(content: @Composable () -> Unit) {
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr, content = content)
}

/** Le fuseau de l'appareil, pour les dates affichées. */
val deviceZone: ZoneId get() = ZoneId.systemDefault()
