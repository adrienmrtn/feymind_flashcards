package com.micabo.app.shots

import androidx.compose.ui.test.junit4.createEmptyComposeRule
import com.micabo.app.onboarding.OnboardingModel
import com.micabo.app.onboarding.OnboardingStep
import com.micabo.app.ui.onboarding.OnboardingFlow
import com.micabo.app.ui.onboarding.OnboardingHost
import com.micabo.app.ui.onboarding.CommitmentStep
import com.micabo.app.ui.onboarding.LessonDemoStep
import com.micabo.app.ui.onboarding.ScanDemoStep
import com.micabo.app.ui.onboarding.StoriesStep
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate

/** Un hôte de test : l'essai du catalogue (3 jours), rien ne part, rien ne se termine. */
object TestHost : OnboardingHost {
    override val trialDays = 3
    override fun track(event: String, props: Map<String, Any>) = Unit
    override fun pickLanguage(code: String) = Unit
    override fun signIn() = Unit
    override fun finish(model: OnboardingModel) = Unit
}

/** Les réponses de Lina, posées sur un écran ; le niveau large se montre avec un pays non décrit. */
fun linaOn(step: OnboardingStep): OnboardingModel {
    val model = OnboardingModel.lina(step, today = LocalDate.now())
    if (step == OnboardingStep.level) model.selectWorld("JP")
    if (step == OnboardingStep.firstLesson) model.firstLessonTopic = ""
    return model
}

/**
 * **Le parcours d'accueil, écran par écran, sur toute la matrice de téléphones.** Chaque écran
 * est photographié (`build/shots/<téléphone>/onboarding/<écran>.png`) et vérifié : rien ne
 * plante, aucun texte n'est coupé, le bouton principal reste visible au-dessus de la barre du
 * système. Les téléphones les plus durs (le petit, le texte à 200 %, l'arabe) passent tous les
 * écrans ; les autres passent les écrans les plus chargés.
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(sdk = [35])
class OnboardingShotsTest(private val device: Device) {

    @get:Rule
    val rule = createEmptyComposeRule()

    private val every = OnboardingStep.entries.filter { it != OnboardingStep.paywall }

    /** Les écrans les plus chargés : ceux que tous les téléphones passent. */
    private val busiest = listOf(
        OnboardingStep.hookLogo, OnboardingStep.welcome, OnboardingStep.yourName, OnboardingStep.subjects,
        OnboardingStep.solutionMap, OnboardingStep.origin, OnboardingStep.scanDemo, OnboardingStep.research,
        OnboardingStep.currentAverage, OnboardingStep.dailyTime, OnboardingStep.planDemo, OnboardingStep.notifications,
        OnboardingStep.commitment, OnboardingStep.profileSummary, OnboardingStep.storyPath, OnboardingStep.storyPractice,
        OnboardingStep.firstLesson, OnboardingStep.freeTrialIntro, OnboardingStep.trialOffer,
    )

    @Test
    fun everyScreen() {
        val full = device in listOf(Device.small, Device.pixel8, Device.font200, Device.arabic)
        val steps = if (full) every else busiest
        val reports = steps.associate { step ->
            val model = linaOn(step)
            step.analyticsName to shoot(rule, device, "onboarding", "%02d-%s".format(java.util.Locale.ROOT, step.ordinal, step.analyticsName), requireCta = step != OnboardingStep.planBuilding && !step.advancesOnChoice) {
                OnboardingFlow(model, TestHost)
            }
        }.toMutableMap()
        // Les démos jouées et le maintien à mi-course : ce que l'élève voit après avoir touché.
        reports["lessonDemo-jouee"] = shoot(rule, device, "onboarding-etats", "lessonDemo-jouee") {
            LessonDemoStep(linaOn(OnboardingStep.lessonDemo), previewPlayed = true)
        }
        reports["scanDemo-resolu"] = shoot(rule, device, "onboarding-etats", "scanDemo-resolu") {
            ScanDemoStep(linaOn(OnboardingStep.scanDemo), previewStage = 3)
        }
        reports["commitment-maintien"] = shoot(rule, device, "onboarding-etats", "commitment-maintien") {
            CommitmentStep(linaOn(OnboardingStep.commitment), previewHold = 0.6f)
        }
        for (page in 1..4) {
            reports["histoire-$page"] = shoot(rule, device, "onboarding-etats", "hookLogo-histoire-$page") {
                StoriesStep(linaOn(OnboardingStep.hookLogo), TestHost, page = page)
            }
        }
        assertClean(reports)
    }

    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun devices(): List<Array<Any>> = Device.all.map { arrayOf<Any>(it) }
    }
}
