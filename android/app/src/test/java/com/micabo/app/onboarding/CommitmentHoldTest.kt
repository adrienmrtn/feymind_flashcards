package com.micabo.app.onboarding

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import com.micabo.app.shots.TestHost
import com.micabo.app.ui.onboarding.OnboardingFlow
import com.micabo.app.ui.theme.MicaboTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * **Le maintien pour s'engager, sur le vrai bouton** (lot 15) : un appui court ne signe jamais ;
 * un maintien de 2 s signe, puis le parcours passe à l'écran suivant. Le bouton qui porte le
 * geste n'est pas recréé pendant l'appui : le remplissage va au bout.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "fr-w412dp-h915dp-xhdpi")
class CommitmentHoldTest {

    @get:Rule
    val rule = createAndroidComposeRule<ComponentActivity>()

    private fun start(): OnboardingModel {
        val model = OnboardingModel.lina(OnboardingStep.commitment)
        rule.mainClock.autoAdvance = false
        rule.setContent { MicaboTheme { OnboardingFlow(model, TestHost) } }
        rule.mainClock.advanceTimeBy(1_000)
        return model
    }

    @Test
    fun aShortPressDoesNothing() {
        val model = start()
        val button = rule.onNodeWithTag("commitHold")
        button.performTouchInput { down(center) }
        rule.mainClock.advanceTimeBy(300)
        button.performTouchInput { up() }
        rule.mainClock.advanceTimeBy(2_000)
        assertFalse(model.hasCommitted)
        assertEquals(OnboardingStep.commitment, model.step)
    }

    @Test
    fun aMovedFingerDoesNothing() {
        val model = start()
        val button = rule.onNodeWithTag("commitHold")
        button.performTouchInput { down(center) }
        rule.mainClock.advanceTimeBy(500)
        button.performTouchInput { moveBy(androidx.compose.ui.geometry.Offset(0f, -400f)) }
        rule.mainClock.advanceTimeBy(100)
        button.performTouchInput { up() }
        rule.mainClock.advanceTimeBy(2_000)
        assertFalse(model.hasCommitted)
        assertEquals(OnboardingStep.commitment, model.step)
    }

    @Test
    fun holdingTwoSecondsCommitsAndMovesOn() {
        val model = start()
        val button = rule.onNodeWithTag("commitHold")
        button.performTouchInput { down(center) }
        // Le doigt reste posé deux secondes : l'horloge avance image par image.
        repeat(125) { rule.mainClock.advanceTimeByFrame() }
        assertTrue("le maintien de 2 s doit signer", model.hasCommitted)
        button.performTouchInput { up() }
        repeat(100) { rule.mainClock.advanceTimeByFrame() }
        assertEquals(OnboardingStep.planBuilding, model.step)
    }
}
