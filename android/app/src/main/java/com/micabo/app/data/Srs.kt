package com.micabo.app.data

import kotlinx.serialization.Serializable
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

/** La note donnée à une carte retournée. */
enum class Rating { AGAIN, HARD, GOOD, EASY }

/** Où en est une carte : nouvelle, en apprentissage, en révision, ou réapprise après un oubli. */
object CardState {
    const val NEW = "new"
    const val LEARNING = "learning"
    const val REVIEW = "review"
    const val RELEARNING = "relearning"
}

/** La mémoire d'une carte (`SM2CardSnapshot`), gardée dans la progression de la leçon. */
@Serializable
data class CardReview(
    val state: String = CardState.NEW,
    val interval: Double = 0.0,
    val ease: Double = Srs.STARTING_EASE,
    val reps: Int = 0,
    val lapses: Int = 0,
    val step: Int = 0,
    /** Le prochain rappel, en millisecondes. */
    val due: Long = 0,
)

/** Nouvelle, en cours, maîtrisée (`CardMastery`) : maîtrisée à trois semaines d'intervalle. */
enum class Mastery { NEW, LEARNING, MASTERED }

val CardReview.mastery: Mastery
    get() = when {
        state == CardState.NEW -> Mastery.NEW
        interval >= 21 -> Mastery.MASTERED
        else -> Mastery.LEARNING
    }

/** Une carte de la leçon, avec sa clé (`thème:rang`) et sa mémoire. */
data class CardEntry(val key: String, val card: Flashcard, val review: CardReview)

fun Lesson.cardEntries(): List<CardEntry> = themes.withIndex().flatMap { (theme, value) ->
    value.flashcards.withIndex().map { (index, card) ->
        val key = "$theme:$index"
        CardEntry(key, card, progress.cards[key] ?: CardReview())
    }
}

/**
 * Les cartes de la séance (`LessonSession.studyQueue`) : celles dont le rappel est passé, les
 * plus en retard d'abord, puis quinze nouvelles au plus ; trente en tout.
 */
fun Lesson.studyQueue(now: Long = System.currentTimeMillis()): List<CardEntry> {
    val entries = cardEntries()
    val due = entries.filter { it.review.state != CardState.NEW && it.review.due <= now }.sortedBy { it.review.due }
    val fresh = entries.filter { it.review.state == CardState.NEW }.take(Srs.NEW_PER_SESSION)
    return (due + fresh).take(30)
}

/** Les cartes apprises : leur prochain rappel est à plus de sept jours (`HomeStats.learnedCards`). */
fun Lesson.learnedCards(now: Long = System.currentTimeMillis()): Int =
    progress.cards.values.count { it.state == CardState.REVIEW && it.due - now > 7 * Srs.DAY }

/** Les cartes à revoir aujourd'hui. */
fun Lesson.dueCards(now: Long = System.currentTimeMillis()): Int =
    progress.cards.values.count { it.state != CardState.NEW && it.due <= now }

/**
 * **SM-2, réglages d'Anki** (`SM2Scheduler`) : paliers d'apprentissage d'une et dix minutes,
 * un jour à la sortie, quatre pour « Facile », facilité de départ 2,5.
 */
object Srs {
    const val STARTING_EASE = 2.5
    const val NEW_PER_SESSION = 15
    const val MINUTE = 60_000L
    const val DAY = 86_400_000L

    private val learningSteps = listOf(1.0, 10.0)
    private val relearningSteps = listOf(10.0)
    private const val GRADUATING = 1.0
    private const val EASY_INTERVAL = 4.0
    private const val EASY_BONUS = 1.3
    private const val HARD_MULTIPLIER = 1.2
    private const val MIN_EASE = 1.3
    private const val MAX_INTERVAL = 36_500.0

    fun schedule(card: CardReview, rating: Rating, now: Long = System.currentTimeMillis()): CardReview = when (card.state) {
        CardState.REVIEW -> review(card, rating, now)
        CardState.RELEARNING -> steps(card, rating, now, relearningSteps, CardState.RELEARNING, graduateAt = max(card.interval, 1.0), easyAt = max(card.interval, 1.0) + 1)
        else -> steps(card, rating, now, learningSteps, CardState.LEARNING, graduateAt = GRADUATING, easyAt = EASY_INTERVAL)
    }

    private fun steps(card: CardReview, rating: Rating, now: Long, steps: List<Double>, state: String, graduateAt: Double, easyAt: Double): CardReview {
        val step = card.step.coerceIn(0, steps.lastIndex)
        return when (rating) {
            Rating.EASY -> graduate(card, easyAt, card.ease, now)
            Rating.GOOD -> if (step >= steps.lastIndex) graduate(card, graduateAt, card.ease, now) else stay(card, state, step + 1, steps[step + 1], now)
            Rating.AGAIN -> stay(card, state, 0, steps[0], now)
            Rating.HARD -> {
                // Anki : la moyenne des deux premiers paliers, ou une fois et demie le seul palier.
                val minutes = if (step == 0 && steps.size > 1) (steps[0] + steps[1]) / 2 else if (steps.size == 1) min(steps[0] * 1.5, steps[0] + 1440) else steps[step]
                stay(card, state, step, minutes, now)
            }
        }
    }

    private fun review(card: CardReview, rating: Rating, now: Long): CardReview {
        val previous = max(card.interval, 1.0)
        if (rating == Rating.AGAIN) {
            return card.copy(
                state = CardState.RELEARNING,
                due = now + (relearningSteps[0] * MINUTE).toLong(),
                interval = 1.0,
                ease = max(MIN_EASE, card.ease - 0.2),
                lapses = card.lapses + 1,
                step = 0,
            )
        }
        // Des jours entiers de retard, comme Anki (`daysLate`).
        val late = max(0.0, floor((now - card.due).toDouble() / DAY))
        val hard = constrained(previous * HARD_MULTIPLIER, previous)
        val good = constrained((previous + late / 2) * card.ease, hard)
        val easy = constrained((previous + late) * card.ease * EASY_BONUS, good)
        return when (rating) {
            Rating.HARD -> graduate(card, hard, card.ease - 0.15, now)
            Rating.EASY -> graduate(card, easy, card.ease + 0.15, now)
            else -> graduate(card, good, card.ease, now)
        }
    }

    /** Un intervalle entier (tronqué, pas arrondi), toujours plus long que le précédent (`constrainedIvl`). */
    private fun constrained(interval: Double, previous: Double): Double =
        min(MAX_INTERVAL, max(max(floor(interval), previous + 1), 1.0))

    private fun graduate(card: CardReview, interval: Double, ease: Double, now: Long): CardReview {
        val clamped = min(MAX_INTERVAL, max(1.0, interval))
        // Un peu de flou, comme Anki : les cartes apprises ensemble ne reviennent pas toutes le même jour.
        val shown = fuzzed(clamped)
        return card.copy(
            state = CardState.REVIEW,
            interval = shown,
            ease = max(MIN_EASE, ease),
            reps = card.reps + 1,
            step = 0,
            due = now + (shown * DAY).toLong(),
        )
    }

    /** La dispersion d'Anki (`fuzzIvlRange`) : un nombre entier de jours, celui qui est gardé. */
    private fun fuzzed(interval: Double): Double {
        val ivl = interval.toInt()
        val (low, high) = when {
            ivl < 2 -> 1 to 1
            ivl == 2 -> 2 to 3
            else -> {
                val fuzz = when {
                    ivl < 7 -> (ivl * 0.25).toInt()
                    ivl < 30 -> max(2, (ivl * 0.15).toInt())
                    else -> max(4, (ivl * 0.05).toInt())
                }.coerceAtLeast(1)
                (ivl - fuzz) to (ivl + fuzz)
            }
        }
        return min(MAX_INTERVAL, max(1.0, Random.nextInt(low, high + 1).toDouble()))
    }

    private fun stay(card: CardReview, state: String, step: Int, minutes: Double, now: Long): CardReview =
        card.copy(state = state, step = step, due = now + (minutes * MINUTE).toLong())
}
