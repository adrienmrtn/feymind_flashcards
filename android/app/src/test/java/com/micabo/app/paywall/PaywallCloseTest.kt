package com.micabo.app.paywall

import com.micabo.app.ui.paywall.PaywallClose
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** **La croix du paywall de fin de parcours n'arrive qu'au bout de cinq secondes** ; derrière une porte, d'emblée. */
class PaywallCloseTest {
    @Test
    fun endOfOnboardingWaitsFiveSeconds() {
        assertEquals(5_000L, PaywallClose.DELAY_MILLIS)
        assertEquals(5_000L, PaywallClose.delayMillis(onboarding = true))
        assertEquals(0L, PaywallClose.delayMillis(onboarding = false))
        assertTrue("La croix arrive en fondu", PaywallClose.FADE_MILLIS > 0)
    }
}
