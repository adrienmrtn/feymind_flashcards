package com.micabo.app.i18n

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import java.util.Locale

/**
 * **Les 26 langues de Micabo**, les mêmes que l'app iPhone (`UiLocale`). Le code est celui de
 * l'app ; `content` est celui qui part au serveur (`ContentLanguage`) : le portugais du Portugal
 * s'y écrit `pt`.
 */
enum class AppLocale(val code: String, val label: String, val content: String) {
    EN("en", "English", "en"),
    FR("fr", "Français", "fr"),
    DE("de", "Deutsch", "de"),
    ES("es", "Español (España)", "es"),
    ES419("es-419", "Español (Latinoamérica)", "es-419"),
    IT("it", "Italiano", "it"),
    PT("pt-PT", "Português (Portugal)", "pt"),
    PTBR("pt-BR", "Português (Brasil)", "pt-BR"),
    NL("nl", "Nederlands", "nl"),
    PL("pl", "Polski", "pl"),
    RO("ro", "Română", "ro"),
    SV("sv", "Svenska", "sv"),
    DA("da", "Dansk", "da"),
    FI("fi", "Suomi", "fi"),
    ET("et", "Eesti", "et"),
    CS("cs", "Čeština", "cs"),
    SK("sk", "Slovenčina", "sk"),
    HU("hu", "Magyar", "hu"),
    HR("hr", "Hrvatski", "hr"),
    SL("sl", "Slovenščina", "sl"),
    SR("sr", "Srpski", "sr"),
    BG("bg", "Български", "bg"),
    EL("el", "Ελληνικά", "el"),
    RU("ru", "Русский", "ru"),
    TR("tr", "Türkçe", "tr"),
    AR("ar", "العربية", "ar");

    val locale: Locale get() = Locale.forLanguageTag(code)

    companion object {
        fun of(code: String): AppLocale? = entries.firstOrNull { it.code.equals(code, ignoreCase = true) }

        /** La langue du téléphone, ramenée à celles de l'app ; l'anglais sinon. */
        fun fromDevice(): AppLocale {
            val device = LocaleList.getDefault()
            for (index in 0 until device.size()) {
                val locale = device[index]
                val language = locale.language
                val region = locale.country
                val match = when (language) {
                    "es" -> if (region.isEmpty() || region == "ES") ES else ES419
                    "pt" -> if (region == "BR") PTBR else PT
                    "nb", "no", "nn" -> DA
                    // Comme l'iPhone (`UiLocale.fromPreferredLanguages`) : le bosnien et le
                    // monténégrin s'écrivent en ijékavien, comme le croate.
                    "sh", "bs", "cnr" -> HR
                    else -> entries.firstOrNull { it.code == language }
                }
                if (match != null) return match
            }
            return EN
        }

        fun resolved(stored: String): AppLocale = of(stored) ?: fromDevice()

        /**
         * **Le pays de scolarisation le plus probable** (`SchoolingCountry.guessed` sur iPhone).
         * La langue décide avant la région : un téléphone en « fr-US » (français, région des
         * États-Unis, comme à l'étranger) cochait les États-Unis. La région ne compte que quand
         * son pays parle la langue (« fr-BE », « fr-CA »), ou quand cette langue n'a pas de pays
         * à elle dans la liste (« ar-MA »). La langue choisie dans l'app passe avant le téléphone.
         */
        fun deviceCountry(chosen: String = ""): String {
            val device = LocaleList.getDefault()
            val tags = (0 until device.size()).map { device[it].language.lowercase() to device[it].country.lowercase() }
            val language = chosen.lowercase().substringBefore('-').takeIf { it.isNotEmpty() }
            if (language != null) {
                val ordered = tags.filter { it.first == language } + (language to "")
                firstMatch(ordered)?.let { return it }
            }
            return firstMatch(tags) ?: "other"
        }

        /** Le pays de la première langue qui en désigne un : sa région quand ce pays la parle, sinon le pays de la langue. */
        private fun firstMatch(tags: List<Pair<String, String>>): String? {
            for ((language, rawRegion) in tags) {
                val region = if (rawRegion == "gb") "uk" else rawRegion
                val speaks = COUNTRY_LANGUAGE[region] ?: continue
                if (BY_LANGUAGE[language] == null || speaks == language) return region
            }
            return tags.firstNotNullOfOrNull { BY_LANGUAGE[it.first] }
        }

        /** La langue des cours de chaque pays de la liste (`SchoolingCountry.language`). */
        private val COUNTRY_LANGUAGE = mapOf(
            "fr" to "fr", "be" to "fr", "ch" to "fr", "ca" to "fr", "lu" to "fr", "ma" to "fr", "dz" to "fr",
            "tn" to "fr", "sn" to "fr", "ci" to "fr", "uk" to "en", "us" to "en", "de" to "de", "it" to "it",
            "es" to "es", "pt" to "pt", "cz" to "cs", "nl" to "nl", "gr" to "el", "hu" to "hu", "pl" to "pl",
            "ro" to "ro", "se" to "sv", "tr" to "tr",
        )

        /** Le pays qui parle chaque langue de la liste : l'anglais sans région est américain. */
        private val BY_LANGUAGE = mapOf(
            "fr" to "fr", "en" to "us", "de" to "de", "it" to "it", "es" to "es", "pt" to "pt", "cs" to "cz",
            "nl" to "nl", "el" to "gr", "hu" to "hu", "pl" to "pl", "ro" to "ro", "sv" to "se", "tr" to "tr",
        )

        /**
         * Le contexte de l'activité, dans la langue choisie : textes et sens de lecture.
         *
         * **Avant tout choix, la langue du téléphone ramenée à celles de l'app** (`fromDevice`),
         * celle que l'écran de la langue présélectionne : sans elle, un téléphone en norvégien ou
         * en bosnien lisait le parcours d'accueil en anglais, et un téléphone en serbe latin
         * (`sr-Latn`, qu'Android ne sert pas avec `values-sr`) aussi.
         */
        fun wrap(base: Context, stored: String): Context {
            val chosen = of(stored) ?: fromDevice()
            val locale = chosen.locale
            Locale.setDefault(locale)
            val config = Configuration(base.resources.configuration)
            config.setLocales(LocaleList(locale))
            config.setLayoutDirection(locale)
            return base.createConfigurationContext(config)
        }
    }
}
