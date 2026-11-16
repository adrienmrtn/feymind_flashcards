package com.micabo.app.shots

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import com.micabo.app.data.CreationStage
import com.micabo.app.data.LessonRequest
import com.micabo.app.ui.home.Generating
import com.micabo.app.ui.home.NewLessonContent
import com.micabo.app.ui.theme.Micabo
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

    private fun paywall(state: PriceState, trigger: String?, exam: String?, offers: List<StorePlan> = plans, yearly: Boolean = true) = @androidx.compose.runtime.Composable {
        PaywallContent(
            state = state, plans = if (state == PriceState.READY) offers else emptyList(), yearlySelected = yearly, onSelect = {},
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
            // Lot 17 : la formule hebdomadaire cochée (la mention suit), et un compte sans essai.
            "paywall-hebdo" to shoot(rule, device, "app", "paywall-parcours-hebdo", content = paywall(PriceState.READY, null, "Bac", yearly = false)),
            "paywall-sans-essai" to shoot(rule, device, "app", "paywall-sans-essai", content = paywall(PriceState.READY, null, "Bac", offers = plans.map { it.copy(trialDays = 0) })),
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
        // Créer une leçon : la feuille « Nouvelle leçon », puis l'écran qui l'écrit (« Étape 3 sur 4 »).
        app.composer.draft = "La photosynthèse"
        reports["nouvelle-lecon"] = shoot(rule, device, "app", "nouvelle-lecon") {
            CompositionLocalProvider(LocalApp provides app) {
                Box(Modifier.fillMaxSize().background(Micabo.colors.canvas).statusBarsPadding()) {
                    NewLessonContent(app.composer, canImport = false, onSend = {}, onFull = {}, onLocked = {})
                }
            }
        }
        app.composer.draft = ""
        reports["leçon-en-cours"] = shoot(rule, device, "app", "lecon-en-ecriture", requireCta = false) {
            Generating(LessonRequest(topic = "La photosynthèse", text = ""), CreationStage.WRITING, null, onClose = {}, onRetry = {})
        }
        // L'offre −40 % à la fermeture : la phrase de Mika dans sa bulle (les prix ne viennent pas
        // de la boutique sous les tests : l'écran montre son état sans réseau).
        reports["offre-40"] = shoot(rule, device, "app", "offre-40", requireCta = false) {
            CompositionLocalProvider(LocalApp provides app) {
                Box(Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.BottomCenter) {
                    com.micabo.app.ui.paywall.DiscountSheet(onDismiss = {}, onSubscribed = {})
                }
            }
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
