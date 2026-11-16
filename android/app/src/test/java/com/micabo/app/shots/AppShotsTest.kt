package com.micabo.app.shots

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ApplicationProvider
import com.micabo.app.MicaboApplication
import com.micabo.app.data.ChatMessage
import com.micabo.app.data.Conversation
import com.micabo.app.data.FirstLesson
import com.micabo.app.data.StorePlan
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Navigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.TabsScreen
import com.micabo.app.ui.chat.ChatContent
import com.micabo.app.ui.paywall.PaywallContent
import com.micabo.app.ui.paywall.PriceState
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.Instant

/**
 * **Le paywall, l'accueil et le chat sur toute la matrice de téléphones** : les mêmes
 * vérifications que le parcours (rien ne plante, rien ne se coupe, le bouton principal reste
 * visible au-dessus de la barre du système).
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(sdk = [35])
class AppShotsTest(private val device: Device) {

    @get:Rule
    val rule = createEmptyComposeRule()

    /** Des offres d'exemple, pour le rendu seulement : les vraies viennent de Google Play. */
    private val plans = listOf(
        StorePlan(yearly = false, price = "4,99 €", pkg = null, trialDays = 3, micros = 4_990_000, weekly = "4,99 €"),
        StorePlan(yearly = true, price = "49,99 €", pkg = null, trialDays = 3, micros = 49_990_000, weekly = "0,96 €"),
    )
    private val now = Instant.parse("2026-11-12T10:00:00Z").toEpochMilli()

    private fun paywall(state: PriceState, trigger: String?, exam: String?) = @androidx.compose.runtime.Composable {
        PaywallContent(
            state = state, plans = if (state == PriceState.READY) plans else emptyList(), yearlySelected = true, onSelect = {},
            name = "Lina", examName = exam, examId = if (exam != null) "fr.bac" else "", trigger = trigger, busy = false,
            message = null, failure = "Pas de connexion. Vérifie ton internet et réessaie.", onClose = {}, onRetry = {},
            onRestore = {}, onOpen = {}, onSubscribe = {}, now = now,
        )
    }

    @Test
    fun paywallAndChatAndHome() {
        val reports = linkedMapOf(
            "paywall-parcours" to shoot(rule, device, "app", "paywall-parcours", content = paywall(PriceState.READY, null, "Bac")),
            "paywall-mika" to shoot(rule, device, "app", "paywall-porte-mika", content = paywall(PriceState.READY, "mika", null)),
            "paywall-chargement" to shoot(rule, device, "app", "paywall-chargement", content = paywall(PriceState.LOADING, null, null)),
            "chat-vide" to shoot(rule, device, "app", "chat-vide") {
                ChatContent(Conversation(), "", {}, 0, false, null, {}, {}, {}, {}, {}, {})
            },
            "chat" to shoot(rule, device, "app", "chat-conversation") {
                ChatContent(
                    Conversation(
                        title = "Le second degré",
                        photos = 2,
                        messages = listOf(
                            ChatMessage("user", "Comment je calcule le discriminant de x² − 4x + 3 ?"),
                            ChatMessage("assistant", "On prend **Δ = b² − 4ac** : ici 16 − 12 = 4. Comme Δ est positif, il y a deux solutions."),
                        ),
                    ),
                    "Et ensuite ?", {}, 2, true, null, {}, {}, {}, {}, {}, {},
                )
            },
        )
        val app = ApplicationProvider.getApplicationContext<MicaboApplication>()
        FirstLesson.save(app, "Le second degré", import = false)
        reports["accueil-premiere-lecon"] = shoot(rule, device, "app", "accueil-premiere-lecon") {
            val navigator = androidx.compose.runtime.remember { Navigator(Screen.Home) }
            CompositionLocalProvider(LocalApp provides app, LocalNavigator provides navigator) { TabsScreen(navigator) }
        }
        FirstLesson.clear(app)
        reports["accueil"] = shoot(rule, device, "app", "accueil") {
            val navigator = androidx.compose.runtime.remember { Navigator(Screen.Home) }
            CompositionLocalProvider(LocalApp provides app, LocalNavigator provides navigator) { TabsScreen(navigator) }
        }
        assertClean(reports)
    }

    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun devices(): List<Array<Any>> = Device.all.map { arrayOf<Any>(it) }
    }
}
