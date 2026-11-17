package com.micabo.app.data

import org.junit.Assert.assertTrue
import org.junit.Test

/** **Une machine de test n'envoie aucune statistique** : la CI remplissait la vraie table (`build = 'debug'`). */
class AnalyticsSilenceTest {
    @Test
    fun testRunsSendNothing() {
        assertTrue(Analytics.isTestRun)
    }
}
