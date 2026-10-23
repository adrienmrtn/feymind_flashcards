package com.micabo.app.ui.onboarding

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.micabo.app.R
import com.micabo.app.data.Tiers
import com.micabo.app.i18n.AppLocale
import com.micabo.app.ui.LocalApp
import com.micabo.app.ui.LocalNavigator
import com.micabo.app.ui.Screen
import com.micabo.app.ui.components.BackButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito
import kotlinx.coroutines.delay

/** Les pays que le serveur connaît (`learner.ts`), et « un autre pays ». */
val COUNTRIES = listOf(
    "fr", "be", "ch", "ca", "lu", "ma", "dz", "tn", "sn", "ci", "uk", "us",
    "de", "it", "es", "pt", "cz", "nl", "gr", "hu", "pl", "ro", "se", "tr", "other",
)

val WORRIES = listOf("examStress", "hardLessons", "homework", "forgetting", "noStart", "motivation")

/** Les crans de « ta moyenne » : de 0 à 100 sur l'échelle de l'app (`learner.ts`). */
val SCORE_STEPS = listOf(35, 55, 70, 85, 95)

@Composable
fun countryName(code: String): String = stringResource(
    when (code) {
        "fr" -> R.string.country_fr
        "be" -> R.string.country_be
        "ch" -> R.string.country_ch
        "ca" -> R.string.country_ca
        "lu" -> R.string.country_lu
        "ma" -> R.string.country_ma
        "dz" -> R.string.country_dz
        "tn" -> R.string.country_tn
        "sn" -> R.string.country_sn
        "ci" -> R.string.country_ci
        "uk" -> R.string.country_uk
        "us" -> R.string.country_us
        "de" -> R.string.country_de
        "it" -> R.string.country_it
        "es" -> R.string.country_es
        "pt" -> R.string.country_pt
        "cz" -> R.string.country_cz
        "nl" -> R.string.country_nl
        "gr" -> R.string.country_gr
        "hu" -> R.string.country_hu
        "pl" -> R.string.country_pl
        "ro" -> R.string.country_ro
        "se" -> R.string.country_se
        "tr" -> R.string.country_tr
        else -> R.string.country_other
    },
)

fun countryFlag(code: String): String {
    val region = when (code) {
        "uk" -> "GB"
        "other" -> return "🌍"
        else -> code.uppercase()
    }
    return region.map { Character.toChars(0x1F1E6 + (it - 'A')).concatToString() }.joinToString("")
}

@Composable
fun tierName(tier: String): String = stringResource(
    when (tier) {
        "lowerSecondary" -> R.string.ios_level_generic_middle
        "upperSecondary" -> R.string.ios_level_generic_high
        "preUniversity" -> R.string.ios_level_prepa
        "undergraduate" -> R.string.ios_level_generic_college
        "graduate" -> R.string.ios_level_master
        "health" -> R.string.ios_level_medicine
        "competitive" -> R.string.ios_level_concours
        else -> R.string.ios_level_other
    },
)

fun tierEmoji(tier: String): String = when (tier) {
    "lowerSecondary" -> "🎒"
    "upperSecondary" -> "📚"
    "preUniversity" -> "🧠"
    "undergraduate" -> "🎓"
    "graduate" -> "🔬"
    "health" -> "🩺"
    "competitive" -> "🏆"
    else -> "✨"
}

@Composable
fun worryName(worry: String): String = stringResource(
    when (worry) {
        "examStress" -> R.string.ios_onb_worry_examStress
        "hardLessons" -> R.string.ios_onb_worry_hardLessons
        "homework" -> R.string.ios_onb_worry_homework
        "forgetting" -> R.string.ios_onb_worry_forgetting
        "noStart" -> R.string.ios_onb_worry_noStart
        else -> R.string.ios_onb_worry_motivation
    },
)

@Composable
fun scoreName(score: Int): String = stringResource(
    when (score) {
        35 -> R.string.x_score_1
        55 -> R.string.x_score_2
        70 -> R.string.x_score_3
        85 -> R.string.x_score_4
        else -> R.string.x_score_5
    },
)

val GOALS = listOf("exam", "lectures", "competition", "language", "curiosity", "profession", "other")

@Composable
fun goalName(goal: String): String = stringResource(
    when (goal) {
        "exam" -> R.string.ios_goal_exam
        "lectures" -> R.string.ios_goal_lectures
        "competition" -> R.string.ios_goal_competition
        "language" -> R.string.ios_goal_language
        "curiosity" -> R.string.ios_goal_curiosity
        "profession" -> R.string.ios_goal_profession
        else -> R.string.ios_goal_other
    },
)

/** Les étapes du parcours d'accueil, dans l'ordre de l'iPhone (`OnboardingStep`). */
private enum class Step(val asks: Boolean = false) {
    HOOK,
    NAME(true),
    WELCOME,
    LANGUAGE(true),
    COUNTRY(true),
    LEVEL(true),
    WORRIES(true),
    PROOF,
    GOAL(true),
    CURRENT(true),
    TARGET(true),
    DAILY(true),
    BUILDING,
    SOURCES,
    PATHS,
    TUTOR,
    SOCIAL,
    TRIAL,
    REMINDER,
}

/**
 * **Le parcours d'accueil** (`OnboardingFlowView`) : l'accroche, le prénom, la langue, le pays,
 * la marche d'études, ce qui freine, les buts, la moyenne et l'objectif, le temps par jour ;
 * Mika prépare le plan, montre ce qu'il sait faire, puis l'essai gratuit et le paywall. Ce
 * qui est répondu dit au serveur pour qui écrire.
 */
@Composable
fun OnboardingScreen() {
    val app = LocalApp.current
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    var index by rememberSaveable { mutableIntStateOf(0) }
    var forward by remember { mutableStateOf(true) }
    var name by rememberSaveable { mutableStateOf(app.prefs.profile.value.name) }
    var language by rememberSaveable { mutableStateOf(AppLocale.resolved(app.prefs.profile.value.language).code) }
    var country by rememberSaveable { mutableStateOf(AppLocale.deviceCountry().takeIf { it in COUNTRIES } ?: "") }
    var tier by rememberSaveable { mutableStateOf("") }
    var worries by rememberSaveable { mutableStateOf(listOf<String>()) }
    var goals by rememberSaveable { mutableStateOf(listOf<String>()) }
    var current by rememberSaveable { mutableIntStateOf(-1) }
    var target by rememberSaveable { mutableIntStateOf(-1) }
    var daily by rememberSaveable { mutableIntStateOf(-1) }
    // Les jours d'essai que Google Play accordera à ce compte : null tant qu'il n'a pas répondu.
    var trialDays by rememberSaveable { mutableStateOf<Int?>(null) }
    LaunchedEffect(Unit) {
        // RevenueCat se configure après la session invitée : on redemande quelques fois.
        repeat(5) {
            val plans = app.billing.plans()
            if (plans.isNotEmpty()) {
                trialDays = (plans.firstOrNull { it.yearly } ?: plans.first()).trialDays
                return@LaunchedEffect
            }
            delay(3_000)
        }
    }
    // Pas d'abonnement, ou un essai déjà consommé sur ce compte Google : on ne promet ni
    // l'essai gratuit ni son rappel.
    val offersTrial = app.billing.enabled && trialDays != 0
    val steps = Step.entries.filter { offersTrial || (it != Step.TRIAL && it != Step.REMINDER) }
    val step = steps[index.coerceAtMost(steps.lastIndex)]
    val asking = steps.filter { it.asks }

    fun go(to: Int) {
        forward = to > index
        index = to.coerceIn(0, steps.lastIndex)
    }

    /** Le retour enjambe le chargement du plan, qui sinon repartait aussitôt en avant. */
    fun back() {
        var to = index.coerceAtMost(steps.lastIndex) - 1
        if (to > 0 && steps[to] == Step.BUILDING) to -= 1
        go(to)
    }

    /** La langue choisie vaut tout de suite : les écrans suivants la parlent. */
    fun pickLanguage(code: String) {
        language = code
        if (AppLocale.resolved(app.prefs.profile.value.language).code != code) {
            app.prefs.update { it.copy(language = code) }
            (context as? Activity)?.recreate()
        }
    }

    fun finish() {
        // Un double appui (ou la réponse à la permission, puis l'appui) ne pousse qu'un paywall.
        if (app.prefs.profile.value.onboarded) return
        app.prefs.update {
            it.copy(
                onboarded = true,
                name = name.trim(),
                language = language,
                country = country.ifEmpty { "other" },
                tier = tier.ifEmpty { "other" },
                worries = worries.toSet(),
                goals = goals.toSet(),
                currentScore = current.takeIf { score -> score >= 0 },
                targetScore = target.takeIf { score -> score >= 0 },
                dailyMinutes = daily.coerceAtLeast(0),
            )
        }
        app.analytics.track("onboarding_finished", mapOf("tier" to tier, "worries" to worries.size, "daily" to daily))
        // Le parcours se termine sur le paywall de l'essai ; le refermer ouvre l'accueil. Sans
        // abonnements à vendre (ou déjà Pro), on va droit à l'accueil.
        if (app.billing.enabled && !app.billing.isPro.value) navigator.push(Screen.Paywall("onboarding"))
    }

    /** La suite, ou la fin du parcours après le dernier écran. */
    fun next() = if (index >= steps.lastIndex) finish() else go(index + 1)

    // Pendant le chargement, le retour ne fait rien : il ne doit pas fermer l'app en plein parcours.
    BackHandler(enabled = index > 0) { if (step != Step.BUILDING) back() }

    // Le parcours a commencé : dit une fois, sur le premier écran réellement affiché. Avant,
    // seul l'index 0 de l'accroche le disait, et un parcours repris plus loin (rotation,
    // app relancée) ne comptait jamais son début : 17 appareils à l'accroche contre 60 au pays.
    var started by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(step) {
        if (!started) {
            started = true
            app.analytics.track("onboarding_started", mapOf("resumed" to (step != Step.HOOK || index != 0)))
        }
        app.analytics.track("onboarding_step", mapOf("step" to step.name.lowercase(), "index" to index))
    }

    Column(Modifier.fillMaxSize().background(Micabo.colors.canvas).statusBarsPadding().navigationBarsPadding().imePadding()) {
        if (step.asks || (index > 0 && step != Step.BUILDING)) {
            Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                BackButton(onClick = ::back)
                Spacer(Modifier.width(14.dp))
                if (step.asks) {
                    ProgressBar((asking.indexOf(step) + 1) / asking.size.toFloat(), Modifier.weight(1f))
                }
            }
        }
        AnimatedContent(
            targetState = step,
            transitionSpec = {
                val sign = if (forward) 1 else -1
                (slideInHorizontally(tween(320)) { sign * it / 3 } + fadeIn(tween(280))) togetherWith
                    (slideOutHorizontally(tween(320)) { -sign * it / 4 } + fadeOut(tween(200)))
            },
            modifier = Modifier.weight(1f),
            label = "onboarding",
        ) { shown ->
            when (shown) {
                Step.HOOK -> Hook(onNext = ::next)
                Step.NAME -> NameStep(name, onName = { name = it.take(40) }, onNext = ::next)
                Step.WELCOME -> Welcome(name.trim(), onNext = ::next)
                Step.LANGUAGE -> Choices(
                    title = stringResource(R.string.x_onb_language),
                    subtitle = stringResource(R.string.x_onb_language_sub),
                    options = AppLocale.entries.map { it.code },
                    selected = setOf(language),
                    label = { code -> AppLocale.of(code)?.label.orEmpty() },
                    onToggle = ::pickLanguage,
                    canContinue = true,
                    onNext = ::next,
                )
                Step.COUNTRY -> Choices(
                    title = stringResource(R.string.ios_countryTitle),
                    subtitle = null,
                    options = COUNTRIES,
                    selected = setOfNotNull(country.ifEmpty { null }),
                    label = { code -> countryName(code) },
                    leading = { code -> countryFlag(code) },
                    onToggle = { country = it },
                    canContinue = country.isNotEmpty(),
                    onNext = ::next,
                )
                Step.LEVEL -> Choices(
                    title = stringResource(R.string.ios_levelTitle),
                    subtitle = null,
                    options = Tiers.all,
                    selected = setOfNotNull(tier.ifEmpty { null }),
                    label = { tierName(it) },
                    leading = { tierEmoji(it) },
                    onToggle = { tier = it },
                    canContinue = tier.isNotEmpty(),
                    onNext = ::next,
                )
                Step.WORRIES -> Choices(
                    title = stringResource(R.string.ios_onb_worries_title),
                    subtitle = stringResource(R.string.ios_onb_worries_sub),
                    options = WORRIES,
                    selected = worries.toSet(),
                    label = { worryName(it) },
                    multiple = true,
                    onToggle = { worry -> worries = if (worry in worries) worries - worry else worries + worry },
                    canContinue = true,
                    onNext = ::next,
                )
                Step.PROOF -> Proof(worries.firstOrNull(), onNext = ::next)
                Step.GOAL -> Choices(
                    title = stringResource(R.string.ios_goalTitle),
                    subtitle = stringResource(R.string.ios_goalSub),
                    options = GOALS,
                    selected = goals.toSet(),
                    label = { goalName(it) },
                    multiple = true,
                    onToggle = { goal -> goals = if (goal in goals) goals - goal else goals + goal },
                    canContinue = true,
                    onNext = ::next,
                )
                Step.CURRENT -> Choices(
                    title = stringResource(R.string.ios_averageTitle),
                    subtitle = stringResource(R.string.ios_averageLead),
                    options = SCORE_STEPS.map { it.toString() },
                    selected = setOfNotNull(current.takeIf { it >= 0 }?.toString()),
                    label = { scoreName(it.toInt()) },
                    onToggle = { current = it.toInt() },
                    canContinue = true,
                    onNext = ::next,
                )
                Step.TARGET -> Choices(
                    title = stringResource(R.string.ios_targetTitle),
                    subtitle = stringResource(R.string.ios_targetLead),
                    options = SCORE_STEPS.filter { current < 0 || it >= current }.map { it.toString() },
                    selected = setOfNotNull(target.takeIf { it >= 0 }?.toString()),
                    label = { scoreName(it.toInt()) },
                    onToggle = { target = it.toInt() },
                    canContinue = true,
                    onNext = ::next,
                )
                Step.DAILY -> DailyTime(daily, onPick = { daily = it }, onNext = ::next)
                Step.BUILDING -> Building(onDone = ::next)
                Step.SOURCES -> MikaSources(onNext = ::next)
                Step.PATHS -> MikaPaths(onNext = ::next)
                Step.TUTOR -> MikaTutor(onNext = ::next)
                Step.SOCIAL -> SocialProof(onNext = ::next)
                Step.TRIAL -> TrialOffer(onNext = ::next)
                Step.REMINDER -> TrialReminderStep(days = trialDays ?: 3, onNext = ::next)
            }
        }
    }
}

@Composable
internal fun Choices(
    title: String,
    subtitle: String?,
    options: List<String>,
    selected: Set<String>,
    label: @Composable (String) -> String,
    onToggle: (String) -> Unit,
    canContinue: Boolean,
    onNext: () -> Unit,
    leading: ((String) -> String)? = null,
    multiple: Boolean = false,
    cta: String = stringResource(R.string.common_continue),
) {
    val colors = Micabo.colors
    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
        ) {
            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.Top) {
                Mika(MikaMood.IDLE, 64.dp)
                Spacer(Modifier.width(10.dp))
                Box(
                    Modifier
                        .padding(top = 6.dp)
                        .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 18.dp, bottomEnd = 18.dp, bottomStart = 18.dp))
                        .background(colors.surface)
                        .border(1.5.dp, colors.stroke, RoundedCornerShape(topStart = 4.dp, topEnd = 18.dp, bottomEnd = 18.dp, bottomStart = 18.dp))
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                ) {
                    Text(title.replace("\n", " "), style = nunito(20.sp, FontWeight.ExtraBold, lineHeight = 25.sp), color = colors.ink)
                }
            }
            if (subtitle != null) {
                Spacer(Modifier.height(10.dp))
                Text(subtitle, style = nunito(15.sp, FontWeight.Medium, lineHeight = 21.sp), color = colors.inkSecondary)
            }
            Spacer(Modifier.height(18.dp))
            options.forEach { option ->
                val isOn = option in selected
                Pressable(
                    onClick = { onToggle(option) },
                    modifier = Modifier.padding(bottom = 10.dp).fillMaxWidth(),
                ) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(18.dp))
                            .background(if (isOn) colors.accentWash else colors.surface)
                            .border(2.dp, if (isOn) colors.accent else colors.stroke, RoundedCornerShape(18.dp))
                            .padding(horizontal = 16.dp, vertical = 15.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        if (leading != null) {
                            Text(leading(option), style = nunito(22.sp))
                            Spacer(Modifier.width(12.dp))
                        }
                        Text(
                            label(option),
                            style = nunito(17.sp, FontWeight.Bold),
                            color = if (isOn) colors.accent else colors.ink,
                            modifier = Modifier.weight(1f),
                        )
                        Box(
                            Modifier
                                .size(24.dp)
                                .clip(if (multiple) RoundedCornerShape(7.dp) else CircleShape)
                                .background(if (isOn) colors.accent else colors.surface)
                                .border(2.dp, if (isOn) colors.accent else colors.strokeStrong, if (multiple) RoundedCornerShape(7.dp) else CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            if (isOn) Icon(Icons.Filled.Check, null, tint = colors.onInk, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
        }
        Column(Modifier.padding(horizontal = 20.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            MicaboButton(cta, onClick = onNext, enabled = canContinue)
        }
    }
}
