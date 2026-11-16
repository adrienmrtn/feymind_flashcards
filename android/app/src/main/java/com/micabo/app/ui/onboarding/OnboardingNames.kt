package com.micabo.app.ui.onboarding

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.micabo.app.R
import com.micabo.app.onboarding.Countries

/** Les pays de la liste, puis « un autre pays » (`SchoolingCountry`). */
val COUNTRIES = Countries.listed + "other"

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

fun countryFlag(code: String): String = Countries.flag(code)

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

