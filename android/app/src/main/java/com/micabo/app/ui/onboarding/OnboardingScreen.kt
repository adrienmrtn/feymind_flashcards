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
import com.micabo.app.ui.components.BackButton
import com.micabo.app.ui.components.Mika
import com.micabo.app.ui.components.MikaMood
import com.micabo.app.ui.components.MicaboButton
import com.micabo.app.ui.components.Pressable
import com.micabo.app.ui.components.ProgressBar
import com.micabo.app.ui.text.RichText
import com.micabo.app.ui.theme.Micabo
import com.micabo.app.ui.theme.nunito

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

private const val STEPS = 7

/**
 * **Le parcours d'accueil**, court : Mika dit bonjour, puis la langue, le pays, la marche
 * d'études, ce qui freine, la moyenne et l'objectif. Tout est facultatif sauf les trois
 * premiers ; c'est ce qui dit au serveur pour qui écrire.
 */
@Composable
fun OnboardingScreen() {
    val app = LocalApp.current
    val context = LocalContext.current
    var step by rememberSaveable { mutableIntStateOf(0) }
    var forward by remember { mutableStateOf(true) }
    var language by rememberSaveable { mutableStateOf(AppLocale.resolved(app.prefs.profile.value.language).code) }
    var country by rememberSaveable { mutableStateOf(AppLocale.deviceCountry().takeIf { it in COUNTRIES } ?: "") }
    var tier by rememberSaveable { mutableStateOf("") }
    var worries by remember { mutableStateOf(listOf<String>()) }
    var current by rememberSaveable { mutableIntStateOf(-1) }
    var target by rememberSaveable { mutableIntStateOf(-1) }

    fun go(to: Int) {
        forward = to > step
        step = to
    }

    fun finish() {
        val before = app.prefs.profile.value.language
        app.prefs.update {
            it.copy(
                onboarded = true,
                language = language,
                country = country.ifEmpty { "other" },
                tier = tier.ifEmpty { "other" },
                worries = worries.toSet(),
                currentScore = current.takeIf { score -> score >= 0 },
                targetScore = target.takeIf { score -> score >= 0 },
            )
        }
        // La langue de l'interface change : l'activité se recompose dans la bonne langue.
        if (before != language && AppLocale.resolved(before).code != language) (context as? Activity)?.recreate()
    }

    BackHandler(enabled = step > 0) { go(step - 1) }

    Column(Modifier.fillMaxSize().background(Micabo.colors.canvas).statusBarsPadding().navigationBarsPadding().imePadding()) {
        if (step > 0) {
            Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                BackButton(onClick = { go(step - 1) })
                Spacer(Modifier.width(14.dp))
                ProgressBar(step / (STEPS - 1f), Modifier.weight(1f))
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
                0 -> Welcome(onNext = { go(1) })
                1 -> Choices(
                    title = stringResource(R.string.x_onb_language),
                    subtitle = stringResource(R.string.x_onb_language_sub),
                    options = AppLocale.entries.map { it.code },
                    selected = setOf(language),
                    label = { code -> AppLocale.of(code)?.label.orEmpty() },
                    onToggle = { language = it },
                    canContinue = true,
                    onNext = { go(2) },
                )
                2 -> Choices(
                    title = stringResource(R.string.ios_countryTitle),
                    subtitle = null,
                    options = COUNTRIES,
                    selected = setOfNotNull(country.ifEmpty { null }),
                    label = { code -> countryName(code) },
                    leading = { code -> countryFlag(code) },
                    onToggle = { country = it },
                    canContinue = country.isNotEmpty(),
                    onNext = { go(3) },
                )
                3 -> Choices(
                    title = stringResource(R.string.ios_levelTitle),
                    subtitle = null,
                    options = Tiers.all,
                    selected = setOfNotNull(tier.ifEmpty { null }),
                    label = { tierName(it) },
                    leading = { tierEmoji(it) },
                    onToggle = { tier = it },
                    canContinue = tier.isNotEmpty(),
                    onNext = { go(4) },
                )
                4 -> Choices(
                    title = stringResource(R.string.ios_onb_worries_title),
                    subtitle = stringResource(R.string.ios_onb_worries_sub),
                    options = WORRIES,
                    selected = worries.toSet(),
                    label = { worryName(it) },
                    multiple = true,
                    onToggle = { worry -> worries = if (worry in worries) worries - worry else worries + worry },
                    canContinue = true,
                    onNext = { go(5) },
                )
                5 -> Choices(
                    title = stringResource(R.string.ios_averageTitle),
                    subtitle = stringResource(R.string.ios_averageLead),
                    options = SCORE_STEPS.map { it.toString() },
                    selected = setOfNotNull(current.takeIf { it >= 0 }?.toString()),
                    label = { scoreName(it.toInt()) },
                    onToggle = { current = it.toInt() },
                    canContinue = true,
                    onNext = { go(6) },
                )
                else -> Choices(
                    title = stringResource(R.string.ios_targetTitle),
                    subtitle = stringResource(R.string.ios_targetLead),
                    options = SCORE_STEPS.map { it.toString() },
                    selected = setOfNotNull(target.takeIf { it >= 0 }?.toString()),
                    label = { scoreName(it.toInt()) },
                    onToggle = { target = it.toInt() },
                    canContinue = true,
                    onNext = { finish() },
                    cta = stringResource(R.string.x_onb_start),
                )
            }
        }
    }
}

@Composable
private fun Welcome(onNext: () -> Unit) {
    val colors = Micabo.colors
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Spacer(Modifier.weight(1f))
        Mika(MikaMood.WAVE, 190.dp)
        Spacer(Modifier.height(24.dp))
        Text(
            stringResource(R.string.ios_welcomeTitle),
            style = nunito(34.sp, FontWeight.Black, lineHeight = 38.sp),
            color = colors.ink,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(14.dp))
        RichText(
            stringResource(R.string.ios_onb_mika_mission),
            style = nunito(17.sp, FontWeight.SemiBold, lineHeight = 24.sp),
            color = colors.inkSecondary,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.weight(1.2f))
        MicaboButton(stringResource(R.string.common_continue), onClick = onNext)
    }
}

@Composable
private fun Choices(
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
