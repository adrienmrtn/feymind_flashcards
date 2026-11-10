package com.micabo.app.data

import android.content.Context
import androidx.core.content.edit
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.LocalDate

/** Une ligue (`LeagueId` du site) et l'XP de la semaine qui y fait entrer : son plancher. */
data class XpLeague(val id: String, val floor: Int)

/**
 * **Les nombres de l'XP** (`web/packages/core/src/xp.ts`, `XPRules.swift` sur l'iPhone) : ce que
 * rapporte chaque geste, l'objectif du jour, le plafond, la durée du minuteur et les ligues.
 * `xp-parity.test.ts` relit ce bloc : un chiffre qui diverge fait tomber le test.
 */
object XpRules {
    const val CORRECT_ANSWER = 10
    const val WRONG_ANSWER = 2
    const val CARD_REVIEWED = 3
    const val CIRCLE_COMPLETED = 25
    const val LESSON_CREATED = 30
    const val MOCK_EXAM_FINISHED = 60
    const val MIKA_ANSWER = 5
    const val EXERCISE_SOLVED = 15
    const val FOCUS_SESSION = 40
    const val DAILY_GOAL = 50
    const val DAILY_CAP = 5000
    const val FOCUS_MINUTES = 25
    val LEAGUES = listOf(
        XpLeague("bronze", 0),
        XpLeague("silver", 200),
        XpLeague("gold", 500),
        XpLeague("sapphire", 1000),
        XpLeague("diamond", 2000),
    )
}

/** Ce qui rapporte de l'XP (`XpReason`), et combien. */
enum class XpReason(val amount: Int) {
    CORRECT_ANSWER(XpRules.CORRECT_ANSWER),
    WRONG_ANSWER(XpRules.WRONG_ANSWER),
    CARD_REVIEWED(XpRules.CARD_REVIEWED),
    CIRCLE_COMPLETED(XpRules.CIRCLE_COMPLETED),
    LESSON_CREATED(XpRules.LESSON_CREATED),
    MOCK_EXAM_FINISHED(XpRules.MOCK_EXAM_FINISHED),
    MIKA_ANSWER(XpRules.MIKA_ANSWER),
    EXERCISE_SOLVED(XpRules.EXERCISE_SOLVED),
    FOCUS_SESSION(XpRules.FOCUS_SESSION),
}

/**
 * **Le calcul de l'XP, sans rien autour** (les fonctions de `xp.ts`) : le journal est l'XP de
 * chaque jour local, `{ "2026-11-10": 120 }`. La semaine commence le lundi, en jour local.
 */
object XpMath {
    /** La date `AAAA-MM-JJ` d'un jour local. */
    fun dayKey(date: LocalDate): String = date.toString()

    /** Le lundi de la semaine de `date` : la semaine de la ligue commence là. */
    fun weekStart(date: LocalDate): LocalDate = date.minusDays((date.dayOfWeek.value - 1).toLong())

    /** Ajoute `amount` au jour `day`, sans dépasser le plafond du jour (`addXp`). */
    fun add(ledger: Map<String, Int>, amount: Int, day: LocalDate): Map<String, Int> {
        val key = dayKey(day)
        val today = ledger[key] ?: 0
        val next = minOf(XpRules.DAILY_CAP, today + maxOf(0, amount))
        return ledger + (key to next)
    }

    fun today(ledger: Map<String, Int>, day: LocalDate): Int = ledger[dayKey(day)] ?: 0

    /** L'XP de la semaine en cours, du lundi à aujourd'hui (`xpThisWeek`). */
    fun week(ledger: Map<String, Int>, day: LocalDate): Int {
        val start = dayKey(weekStart(day))
        val end = dayKey(day)
        return ledger.filterKeys { it >= start && it <= end }.values.sum()
    }

    /** Le journal ne garde que les quinze derniers jours ; le total vit à part (`pruneLedger`). */
    fun prune(ledger: Map<String, Int>, day: LocalDate, keepDays: Long = 15): Map<String, Int> {
        val floor = dayKey(day.minusDays(keepDays))
        return ledger.filterKeys { it > floor }
    }

    /** La ligue d'une XP de semaine (`leagueFor`). */
    fun leagueFor(weekly: Int): XpLeague = XpRules.LEAGUES.lastOrNull { weekly >= it.floor } ?: XpRules.LEAGUES.first()

    /** La ligue suivante et ce qui manque pour l'atteindre ; rien en Diamant (`xpToNextLeague`). */
    fun nextLeague(weekly: Int): Pair<XpLeague, Int>? =
        XpRules.LEAGUES.firstOrNull { it.floor > weekly }?.let { it to it.floor - weekly }

    /** Le journal en une ligne, pour les préférences : `2026-11-10=120;2026-11-11=30`. */
    fun encode(ledger: Map<String, Int>): String = ledger.entries.sortedBy { it.key }.joinToString(";") { "${it.key}=${it.value}" }

    fun decode(raw: String): Map<String, Int> = raw.split(';').mapNotNull { part ->
        val key = part.substringBefore('=', "")
        val value = part.substringAfter('=', "").toIntOrNull()
        if (key.length == 10 && value != null && value > 0) key to minOf(value, XpRules.DAILY_CAP) else null
    }.toMap()
}

/** Où en est l'élève : l'XP du jour, de la semaine (depuis lundi), le total, et le lundi. */
data class XpStatus(val today: Int = 0, val week: Int = 0, val total: Long = 0, val weekStart: String = "") {
    val league: XpLeague get() = XpMath.leagueFor(week)
    val goalReached: Boolean get() = today >= XpRules.DAILY_GOAL
    /** L'anneau de « Aujourd'hui », de 0 à 1. */
    val goalProgress: Float get() = (today.toFloat() / XpRules.DAILY_GOAL).coerceIn(0f, 1f)
}

/** Un gain, pour le petit « +10 XP » qui monte : `toast` faux quand l'écran le montre déjà. */
data class XpGain(val amount: Int, val reason: XpReason, val toast: Boolean)

/**
 * **L'XP de l'élève**, gardée sur le téléphone comme la série (`Streak`) : un journal par jour
 * local (les quinze derniers jours), un total à part, et l'XP de la semaine apprise d'un autre
 * appareil (`mergeRemote`). Elle monte avec le profil (`CloudSync.pushProfile`), elle ne bloque
 * jamais rien : un geste qui la fait gagner se fait d'abord, l'XP suit.
 */
class Xp(context: Context, private val clock: () -> LocalDate = { LocalDate.now() }) {
    private val prefs = context.getSharedPreferences("micabo", Context.MODE_PRIVATE)
    private val lock = Any()

    private val _status = MutableStateFlow(compute(clock()))
    val status: StateFlow<XpStatus> = _status.asStateFlow()

    private val _gains = MutableSharedFlow<XpGain>(extraBufferCapacity = 16, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val gains: SharedFlow<XpGain> = _gains.asSharedFlow()

    /** Vrai quand l'objectif du jour vient d'être atteint, jusqu'à ce que la fête ait été montrée. */
    private val _celebrate = MutableStateFlow(false)
    val celebrate: StateFlow<Boolean> = _celebrate.asStateFlow()

    fun celebrated() {
        _celebrate.value = false
    }

    private fun ledger(): Map<String, Int> = XpMath.decode(prefs.getString(LEDGER, "").orEmpty())

    /** L'XP de la semaine apprise d'un autre appareil, valable pour son lundi seulement. */
    private fun carry(weekStart: String): Int {
        val raw = prefs.getString(CARRY, "").orEmpty()
        return if (raw.substringBefore('=') == weekStart) raw.substringAfter('=').toIntOrNull()?.coerceAtLeast(0) ?: 0 else 0
    }

    private fun compute(day: LocalDate): XpStatus {
        val ledger = ledger()
        val start = XpMath.dayKey(XpMath.weekStart(day))
        return XpStatus(
            today = XpMath.today(ledger, day),
            week = (XpMath.week(ledger, day) + carry(start)).coerceAtMost(MAX_WEEK),
            total = prefs.getLong(TOTAL, 0L).coerceAtLeast(0L),
            weekStart = start,
        )
    }

    /**
     * **Un geste rapporte de l'XP.** Rend ce qui a vraiment été ajouté (0 au plafond du jour).
     * Atteindre l'objectif du jour arme la fête, une fois par jour.
     */
    fun award(reason: XpReason, toast: Boolean = true): Int {
        val day = clock()
        val added: Int
        var goal = false
        synchronized(lock) {
            val ledger = XpMath.prune(ledger(), day)
            val before = XpMath.today(ledger, day)
            val next = XpMath.add(ledger, reason.amount, day)
            added = XpMath.today(next, day) - before
            if (added <= 0) return 0
            val key = XpMath.dayKey(day)
            if (before < XpRules.DAILY_GOAL && before + added >= XpRules.DAILY_GOAL && prefs.getString(CELEBRATED, "") != key) goal = true
            prefs.edit {
                putString(LEDGER, XpMath.encode(next))
                putLong(TOTAL, prefs.getLong(TOTAL, 0L) + added)
                if (goal) putString(CELEBRATED, key)
            }
            _status.value = compute(day)
        }
        if (goal) _celebrate.value = true
        _gains.tryEmit(XpGain(added, reason, toast))
        return added
    }

    /**
     * **Ce que le compte sait déjà** (`profiles`, rempli par un autre appareil) : le total ne
     * redescend jamais, et l'XP de la même semaine reprend la plus grande des deux. Sans ça, un
     * téléphone neuf aurait remonté zéro par-dessus des mois d'XP.
     */
    fun mergeRemote(total: Long?, week: Int?, weekStart: String?) {
        synchronized(lock) {
            val day = clock()
            val start = XpMath.dayKey(XpMath.weekStart(day))
            if (total != null && total > prefs.getLong(TOTAL, 0L)) prefs.edit { putLong(TOTAL, total.coerceAtMost(MAX_TOTAL)) }
            if (week != null && weekStart == start) {
                val local = XpMath.week(ledger(), day)
                if (week > local + carry(start)) prefs.edit { putString(CARRY, "$start=${(week - local).coerceIn(0, MAX_WEEK)}") }
            }
            _status.value = compute(day)
        }
    }

    /** À relire au retour dans l'app : minuit (ou lundi) a pu passer. */
    fun refresh() {
        synchronized(lock) { _status.value = compute(clock()) }
    }

    /** « Tout effacer », ou un compte qui s'en va : l'XP d'ici repart de zéro. */
    fun reset() {
        synchronized(lock) {
            prefs.edit {
                remove(LEDGER)
                remove(TOTAL)
                remove(CARRY)
                remove(CELEBRATED)
            }
            _status.value = compute(clock())
        }
        _celebrate.value = false
    }

    companion object {
        private const val LEDGER = "xp.ledger"
        private const val TOTAL = "xp.total"
        private const val CARRY = "xp.carry"
        private const val CELEBRATED = "xp.celebrated"
        /** Les bornes de la base (`profiles_xp_bounds`) : sept jours au plafond, cent millions au total. */
        const val MAX_WEEK = 7 * XpRules.DAILY_CAP
        const val MAX_TOTAL = 100_000_000L
    }
}
