package com.micabo.app.onboarding

import kotlin.math.ceil
import kotlin.math.roundToInt

/**
 * **Les séances de concentration, plafonnées à une heure** (lot 16, `FocusPlan.maxMinutes`,
 * `RevisionPlanner.sessionLengths`) : au-delà d'une heure par jour, le plan découpe le temps en
 * plusieurs séances égales (au plus 60 min chacune, au moins 15, arrondies à 5 min) ; une durée
 * enregistrée avant ce plafond est ramenée à 60 min.
 */
object FocusPlan {
    const val MAX_MINUTES = 60
    const val MIN_SESSION = 15
    /** Le temps par jour que le plan accepte (`RevisionPlanner.maxDailyMinutes`). */
    const val MAX_DAILY_MINUTES = 120
    /** Une séance pleine : 25 minutes, comme le minuteur (`XPRules.focusMinutes`). */
    const val FOCUS_MINUTES = 25
    /** L'XP d'une séance pleine (`XPRules.focusSession`). */
    const val FOCUS_XP = 40

    /** Les séances d'une journée, toutes de la même longueur. */
    fun sessionLengths(dailyMinutes: Int): List<Int> {
        val total = dailyMinutes.coerceIn(MIN_SESSION, MAX_DAILY_MINUTES)
        val count = maxOf(1, ceil(total.toDouble() / MAX_MINUTES).toInt())
        val each = (total.toDouble() / count / 5).roundToInt() * 5
        return List(count) { each.coerceIn(MIN_SESSION, MAX_MINUTES) }
    }

    fun sessionLength(dailyMinutes: Int): Int = sessionLengths(dailyMinutes).first()

    /** Une durée enregistrée avant le plafond : ramenée à une heure. */
    fun clamp(minutes: Int): Int = minutes.coerceIn(1, MAX_MINUTES)

    /** La séance de la démo du parcours : celle du plan, entre 25 et 60 minutes. */
    fun demoMinutes(dailyMinutes: Int): Int = sessionLength(dailyMinutes).coerceIn(FOCUS_MINUTES, MAX_MINUTES)

    /** L'XP réelle de cette séance (`FocusPhases.xp`) : 40 XP par bloc de 25 minutes mené au bout. */
    fun demoXp(dailyMinutes: Int): Int = completedBlocks(demoMinutes(dailyMinutes) * 60) * FOCUS_XP

    fun completedBlocks(workSeconds: Int): Int = ((maxOf(0, workSeconds) + 0.5) / (FOCUS_MINUTES * 60)).toInt()
}
