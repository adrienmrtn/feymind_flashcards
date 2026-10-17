package com.micabo.app.data

import android.content.Context
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** La série : sa longueur, le record, et si aujourd'hui compte déjà. */
data class StreakStatus(val current: Int = 0, val best: Int = 0, val studiedToday: Boolean = false)

/** Un jour de la semaine affichée : étudié ou non, aujourd'hui, à venir. */
data class StreakDay(val date: Long, val studied: Boolean, val isToday: Boolean, val isFuture: Boolean)

/**
 * **La série de jours** (`StudyStreak`) : un registre des jours où l'élève a vraiment étudié —
 * une étape finie, une carte notée. La série court jusqu'à aujourd'hui, ou jusqu'à hier tant
 * qu'aujourd'hui n'est pas encore joué.
 */
class Streak(context: Context) {
    private val prefs = context.getSharedPreferences("micabo", Context.MODE_PRIVATE)
    private val format get() = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT)

    private val _status = MutableStateFlow(compute())
    val status: StateFlow<StreakStatus> = _status.asStateFlow()

    /** Vrai après le premier geste du jour, jusqu'à ce que la célébration ait été montrée. */
    private val _celebrate = MutableStateFlow(false)
    val celebrate: StateFlow<Boolean> = _celebrate.asStateFlow()

    fun celebrated() {
        _celebrate.value = false
    }

    private fun days(): Set<String> = prefs.getStringSet(DAYS, emptySet()).orEmpty()

    private fun stamp(time: Long): String = format.format(time)

    /** Allume aujourd'hui. Rend vrai si c'est le premier geste du jour. */
    fun record(now: Long = System.currentTimeMillis()): Boolean {
        val days = days()
        val today = stamp(now)
        if (today in days) return false
        // On garde un peu plus d'un an : assez pour le record, pas de quoi grossir sans fin.
        val kept = (days + today).sorted().takeLast(KEPT_DAYS).toSet()
        prefs.edit { putStringSet(DAYS, kept) }
        val next = compute(now)
        if (next.best > prefs.getInt(BEST, 0)) prefs.edit { putInt(BEST, next.best) }
        _status.value = next
        _celebrate.value = true
        return true
    }

    /** À relire au retour dans l'app : minuit a pu passer. */
    fun refresh() {
        _status.value = compute()
    }

    fun reset() {
        prefs.edit { remove(DAYS); remove(BEST) }
        _status.value = compute()
    }

    private fun compute(now: Long = System.currentTimeMillis()): StreakStatus {
        val days = days()
        val calendar = Calendar.getInstance().apply { timeInMillis = now }
        val studiedToday = stamp(now) in days
        if (!studiedToday) calendar.add(Calendar.DAY_OF_YEAR, -1)
        var length = 0
        while (stamp(calendar.timeInMillis) in days) {
            length += 1
            calendar.add(Calendar.DAY_OF_YEAR, -1)
        }
        return StreakStatus(current = length, best = maxOf(prefs.getInt(BEST, 0), length), studiedToday = studiedToday)
    }

    /** La semaine en cours, du lundi au dimanche (ou selon le premier jour du pays). */
    fun week(now: Long = System.currentTimeMillis()): List<StreakDay> {
        val days = days()
        val today = stamp(now)
        val calendar = Calendar.getInstance().apply {
            timeInMillis = startOfDay(now)
            set(Calendar.DAY_OF_WEEK, firstDayOfWeek)
            if (timeInMillis > now) add(Calendar.WEEK_OF_YEAR, -1)
        }
        return (0 until 7).map {
            val time = calendar.timeInMillis
            val day = stamp(time)
            StreakDay(time, day in days, day == today, time > now && day != today).also { calendar.add(Calendar.DAY_OF_YEAR, 1) }
        }
    }

    private companion object {
        const val DAYS = "streak.days"
        const val BEST = "streak.best"
        const val KEPT_DAYS = 400
    }
}
