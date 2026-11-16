package com.micabo.app.ui.onboarding

import android.icu.text.ListFormatter
import android.icu.text.MeasureFormat
import android.icu.util.Measure
import android.icu.util.MeasureUnit
import android.text.format.DateFormat
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.platform.LocalConfiguration
import com.micabo.app.i18n.AppLocale
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/** **Les mots du parcours** (`OnbWords`) : les dates, les heures, les durées, les listes. */
object Words {
    private fun pattern(locale: Locale, skeleton: String) = DateFormat.getBestDateTimePattern(locale, skeleton)

    fun date(date: LocalDate, locale: Locale): String = DateTimeFormatter.ofPattern(pattern(locale, "dMMMMyyyy"), locale).format(date)

    fun day(date: LocalDate, locale: Locale): String = DateTimeFormatter.ofPattern(pattern(locale, "dMMMM"), locale).format(date)

    /** « 18 h », « 6 PM » : l'espace est insécable, l'heure ne se coupe pas en fin de ligne. */
    fun hour(hour: Int, locale: Locale): String =
        DateTimeFormatter.ofPattern(pattern(locale, "j"), locale).format(LocalTime.of(hour.coerceIn(0, 23), 0)).replace(' ', ' ')

    /** « 3 mois », « 2 semaines », « 12 jours » (`SchoolExams.remainingText`). */
    fun duration(days: Int, locale: Locale): String {
        val format = MeasureFormat.getInstance(locale, MeasureFormat.FormatWidth.WIDE)
        return when {
            days >= 61 -> format.format(Measure(Math.round(days / 30.4).toInt(), MeasureUnit.MONTH))
            days >= 15 -> format.format(Measure(Math.round(days / 7.0).toInt(), MeasureUnit.WEEK))
            else -> format.format(Measure(maxOf(1, days), MeasureUnit.DAY))
        }
    }

    /** « 12/20 → 16/20 », isolé de gauche à droite dans une phrase arabe ou hébraïque. */
    fun range(from: String, to: String, locale: Locale): String =
        if (isRtl(locale)) "‪$from → $to‬" else "$from → $to"

    fun list(items: List<String>, locale: Locale): String = ListFormatter.getInstance(locale).format(items)

    /** Les minutes, « 45 min », « 1 h 30 » (`Duration.formatted(.units(width: .abbreviated))`). */
    fun minutes(minutes: Int, locale: Locale): String {
        val format = MeasureFormat.getInstance(locale, MeasureFormat.FormatWidth.SHORT)
        val hours = minutes / 60
        val rest = minutes % 60
        return when {
            hours == 0 -> format.format(Measure(rest, MeasureUnit.MINUTE))
            rest == 0 -> format.format(Measure(hours, MeasureUnit.HOUR))
            else -> format.formatMeasures(Measure(hours, MeasureUnit.HOUR), Measure(rest, MeasureUnit.MINUTE))
        }
    }

    fun isRtl(locale: Locale) = locale.language in setOf("ar", "he", "iw")
}

/** La langue de l'interface, pour les mots du parcours. */
val currentLocale: Locale
    @Composable @ReadOnlyComposable get() = LocalConfiguration.current.locales[0] ?: Locale.getDefault()

/** Le code de la langue de l'app (« pt-PT », « es-419 »), pour le nom des matières. */
val appLanguageCode: String
    @Composable @ReadOnlyComposable get() = AppLocale.ofLocale(currentLocale).code
