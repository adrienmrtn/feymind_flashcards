package com.micabo.app.data

import android.content.Context
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * **L'offre cadeau** (`DiscountOffer` sur iPhone), avec les mêmes nombres.
 *
 * **Un paywall refermé sans achat fait tomber le cadeau** : l'annuel à tarif réduit. Trois
 * appuis l'ouvrent, et le paywall qui suit vend le tarif. Refermé, il laisse une languette au
 * bord droit des onglets, avec le décompte des vingt-quatre heures, qui le rouvre d'un appui ;
 * le Profil garde une rangée qui y mène tant qu'on n'est pas abonné.
 *
 * Une seule horloge : l'instant où le cadeau a été ouvert (ou refermé sans l'ouvrir). Une
 * fenêtre finie se repose quarante-huit heures, puis l'offre revient.
 */
class GiftOffer(context: Context) {
    /** Par quel bout on entre dans l'offre (`DiscountPresentation`). */
    enum class Presentation {
        /** La boîte à déballer. */
        GIFT,
        /** Le tarif réduit : depuis le cadeau, la languette ou le Profil. */
        PAYWALL,
    }

    private val store = context.getSharedPreferences("micabo", Context.MODE_PRIVATE)

    private val _startedAt = MutableStateFlow(store.getLong(STARTED_AT, 0L))
    /** L'instant d'ouverture, en millisecondes. Zéro : jamais ouvert ici. */
    val startedAt: StateFlow<Long> = _startedAt.asStateFlow()

    private val _seen = MutableStateFlow(store.getBoolean(SEEN, false))
    /** Le cadeau s'est déjà présenté pendant cette fenêtre ; la languette prend le relais. */
    val seen: StateFlow<Boolean> = _seen.asStateFlow()

    private val _pending = MutableStateFlow(store.getBoolean(PENDING, false))
    /**
     * Un paywall s'est refermé sans achat et le cadeau attend d'être posé. Gardé : le paywall
     * du parcours d'accueil se referme pendant que les onglets arrivent.
     */
    val pending: StateFlow<Boolean> = _pending.asStateFlow()

    private val _presentation = MutableStateFlow<Presentation?>(null)
    /** Ce qui est ouvert par-dessus l'app, ou rien. */
    val presentation: StateFlow<Presentation?> = _presentation.asStateFlow()

    private val _savingsPercent = MutableStateFlow(store.getInt(PERCENT, DEFAULT_PERCENT))
    /** La remise sur l'annuel plein, d'après les prix du pays ; −40 % tant que Play n'a pas répondu. */
    val savingsPercent: StateFlow<Int> = _savingsPercent.asStateFlow()

    /** **Le paywall vient de se refermer sans achat** : le cadeau se pose, s'il est dû. */
    fun paywallClosed(isPro: Boolean, now: Long = System.currentTimeMillis()) {
        if (!shouldPresentGift(isPro, _seen.value, _startedAt.value, now)) return
        _pending.value = true
        store.edit { putBoolean(PENDING, true) }
    }

    /** La demande en attente, retirée en la lisant : le cadeau ne tombe qu'une fois. */
    fun takePending(): Boolean {
        if (!_pending.value) return false
        _pending.value = false
        store.edit { remove(PENDING) }
        return true
    }

    fun presentGift() {
        _presentation.value = Presentation.GIFT
    }

    /** Le tarif réduit, sans déballer : la fenêtre s'ouvre, ou continue. */
    fun presentPaywall() {
        begin()
        _presentation.value = Presentation.PAYWALL
    }

    /** Le cadeau ou le tarif refermé : vu, et la languette prend le relais. */
    fun dismiss() {
        markSeen()
        _presentation.value = null
    }

    /** Abonné depuis l'offre : plus rien ne s'affiche. */
    fun subscribed() {
        _presentation.value = null
    }

    /**
     * Ouvre la fenêtre, ou rend celle qui court. Une fenêtre en cours ne se remet pas à zéro ;
     * une fenêtre finie ouvre la suivante, et le « déjà vu » repart.
     */
    fun begin(now: Long = System.currentTimeMillis()): Long {
        val existing = _startedAt.value
        if (existing > 0 && isLive(existing, now)) return existing
        _startedAt.value = now
        _seen.value = false
        store.edit {
            putLong(STARTED_AT, now)
            putBoolean(SEEN, false)
        }
        return now
    }

    /**
     * Le cadeau a été montré, **et la fenêtre démarre ici aussi** : refermé avant le troisième
     * appui, il laissait sinon un « déjà vu » sans décompte, et le tarif devenait introuvable.
     */
    fun markSeen(now: Long = System.currentTimeMillis()) {
        begin(now)
        _seen.value = true
        store.edit { putBoolean(SEEN, true) }
    }

    fun rememberSavings(percent: Int) {
        if (percent <= 0 || percent >= 100 || percent == _savingsPercent.value) return
        _savingsPercent.value = percent
        store.edit { putInt(PERCENT, percent) }
    }

    companion object {
        /** Appuis sur le cadeau avant qu'il s'ouvre. */
        const val TAPS = 3
        /** La durée de l'offre : vingt-quatre heures. */
        const val WINDOW_MS = 86_400_000L
        /** Le repos entre deux fenêtres : quarante-huit heures. */
        const val REST_MS = 172_800_000L
        const val DEFAULT_PERCENT = 40

        private const val STARTED_AT = "discount.startedAt"
        private const val SEEN = "discount.seen"
        private const val PENDING = "discount.pending"
        private const val PERCENT = "discount.percent"

        /** Les millisecondes qui restent, jamais négatives ni plus que la fenêtre. */
        fun windowRemaining(startedAt: Long, now: Long = System.currentTimeMillis()): Long =
            (WINDOW_MS - (now - startedAt)).coerceIn(0L, WINDOW_MS)

        fun isLive(startedAt: Long, now: Long = System.currentTimeMillis()): Boolean = windowRemaining(startedAt, now) > 0

        /** La fenêtre est finie **et** le repos est passé : l'offre peut revenir. */
        fun hasRested(startedAt: Long, now: Long = System.currentTimeMillis()): Boolean = now - startedAt >= WINDOW_MS + REST_MS

        /** Faut-il poser le cadeau ? `startedAt` à zéro : jamais ouvert ici. */
        fun shouldPresentGift(isPro: Boolean, seen: Boolean, startedAt: Long, now: Long = System.currentTimeMillis()): Boolean {
            if (isPro) return false
            if (startedAt <= 0) return true
            if (isLive(startedAt, now)) return !seen
            return hasRested(startedAt, now)
        }

        /** Faut-il garder la languette et son décompte ? */
        fun shouldShowBadge(isPro: Boolean, seen: Boolean, startedAt: Long, now: Long = System.currentTimeMillis()): Boolean =
            !isPro && seen && startedAt > 0 && isLive(startedAt, now)

        /** « 59:59 » sous l'heure, « 23:14:07 » au-dessus, deux chiffres partout. */
        fun countdown(millis: Long): String {
            val total = (millis / 1000).coerceAtLeast(0)
            val hours = total / 3600
            val minutes = (total % 3600) / 60
            val seconds = total % 60
            return if (hours > 0) "%02d:%02d:%02d".format(hours, minutes, seconds) else "%02d:%02d".format(minutes, seconds)
        }

        /** La remise du tarif réduit sur l'annuel plein, en pourcentage entier. */
        fun savings(discountMicros: Long, referenceMicros: Long): Int? {
            if (discountMicros <= 0 || referenceMicros <= 0 || discountMicros >= referenceMicros) return null
            return Math.round((1.0 - discountMicros.toDouble() / referenceMicros) * 100).toInt()
        }
    }
}
