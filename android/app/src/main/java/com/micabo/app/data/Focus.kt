package com.micabo.app.data

import android.content.Context
import android.os.SystemClock
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Une séance du minuteur, en millisecondes de `SystemClock.elapsedRealtime` : l'heure du
 * départ, celle de la pause en cours (0 sans pause) et le temps déjà passé en pause.
 */
data class FocusState(val startedAt: Long = 0, val pausedAt: Long = 0, val pausedTotal: Long = 0) {
    val active: Boolean get() = startedAt > 0
    val paused: Boolean get() = pausedAt > 0

    fun elapsed(now: Long): Long = if (!active) 0 else ((if (paused) pausedAt else now) - startedAt - pausedTotal).coerceAtLeast(0)

    fun remaining(now: Long, duration: Long = FocusTimer.DURATION): Long = (duration - elapsed(now)).coerceAtLeast(0)
}

/**
 * **Le minuteur de concentration** : vingt-cinq minutes, sans service au premier plan ni
 * permission. Il ne compte rien en arrière-plan : il se souvient seulement de l'heure du départ
 * et des pauses, et le temps restant se recalcule à chaque coup d'œil. L'app peut passer en
 * arrière-plan, être tuée, revenir : la séance est toujours là, à la bonne seconde. Une séance
 * menée au bout rapporte `focusSession`, et son temps rejoint les heures de révision de l'accueil.
 */
class FocusTimer(
    context: Context,
    private val xp: Xp,
    private val clock: () -> Long = { SystemClock.elapsedRealtime() },
) {
    private val prefs = context.getSharedPreferences("micabo", Context.MODE_PRIVATE)

    private val _state = MutableStateFlow(read())
    val state: StateFlow<FocusState> = _state.asStateFlow()

    /** Le temps des séances menées au bout, en secondes : il compte dans « temps de révision ». */
    private val _seconds = MutableStateFlow(prefs.getLong(SECONDS, 0L))
    val seconds: StateFlow<Long> = _seconds.asStateFlow()

    fun now(): Long = clock()

    private fun read(): FocusState {
        val state = FocusState(prefs.getLong(STARTED, 0L), prefs.getLong(PAUSED, 0L), prefs.getLong(PAUSED_TOTAL, 0L))
        // Un redémarrage du téléphone remet l'horloge à zéro : la séance d'avant ne veut plus rien dire.
        return if (state.startedAt > clock() || state.pausedAt > clock()) FocusState() else state
    }

    private fun write(state: FocusState) {
        prefs.edit {
            putLong(STARTED, state.startedAt)
            putLong(PAUSED, state.pausedAt)
            putLong(PAUSED_TOTAL, state.pausedTotal)
        }
        _state.value = state
    }

    fun start() = write(FocusState(startedAt = clock().coerceAtLeast(1)))

    fun pause() {
        val state = _state.value
        if (state.active && !state.paused) write(state.copy(pausedAt = clock().coerceAtLeast(1)))
    }

    fun resume() {
        val state = _state.value
        if (state.paused) write(state.copy(pausedAt = 0, pausedTotal = state.pausedTotal + (clock() - state.pausedAt).coerceAtLeast(0)))
    }

    fun stop() = write(FocusState())

    /**
     * La séance est arrivée à zéro : l'XP, le temps de révision, et le minuteur se vide. Rend
     * vrai une seule fois par séance.
     */
    fun finishIfDue(): Boolean {
        val state = _state.value
        if (!state.active || state.remaining(clock()) > 0) return false
        write(FocusState())
        val total = prefs.getLong(SECONDS, 0L) + DURATION / 1_000
        prefs.edit { putLong(SECONDS, total) }
        _seconds.value = total
        // La fête de fin de séance montre déjà le gain : pas de pastille qui monte en plus.
        xp.award(XpReason.FOCUS_SESSION, toast = false)
        return true
    }

    /** Après « Tout effacer » : les préférences sont déjà vides, l'état se relit. */
    fun reload() {
        _state.value = read()
        _seconds.value = prefs.getLong(SECONDS, 0L)
    }

    companion object {
        const val DURATION = XpRules.FOCUS_MINUTES * 60_000L
        private const val STARTED = "focus.startedAt"
        private const val PAUSED = "focus.pausedAt"
        private const val PAUSED_TOTAL = "focus.pausedTotal"
        private const val SECONDS = "focus.seconds"
    }
}
