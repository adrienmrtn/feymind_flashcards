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
                    "sh", "bs" -> SR
                    else -> entries.firstOrNull { it.code == language }
                }
                if (match != null) return match
            }
            return EN
        }

        fun resolved(stored: String): AppLocale = of(stored) ?: fromDevice()

        /** Le pays de scolarisation le plus probable, d'après le téléphone. */
        fun deviceCountry(): String {
            val region = Locale.getDefault().country.lowercase()
            return when (region) {
                "gb" -> "uk"
                else -> region
            }
        }

        /** Le contexte de l'activité, dans la langue choisie : textes et sens de lecture. */
        fun wrap(base: Context, stored: String): Context {
            val chosen = of(stored) ?: return base
            val locale = chosen.locale
            Locale.setDefault(locale)
            val config = Configuration(base.resources.configuration)
            config.setLocales(LocaleList(locale))
            config.setLayoutDirection(locale)
            return base.createConfigurationContext(config)
        }
    }
}
