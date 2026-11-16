package com.micabo.app.onboarding

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * **Le maintien pour s'engager** (`CommitHold`) : une machine pure. Seul un maintien de
 * 1,5 s engage ; un appui court ou un geste annulé ne valide jamais.
 */
class CommitHold {
    var pressedAt: Long? = null
        private set

    fun progress(now: Long): Float = pressedAt?.let { progress(it, now) } ?: 0f

    fun press(now: Long) {
        if (pressedAt == null) pressedAt = now
    }

    /** Vrai quand le maintien est allé au bout (le doigt est encore posé). */
    fun tick(now: Long): Boolean {
        if (progress(now) < 1f) return false
        pressedAt = null
        return true
    }

    /** Le doigt se lève : vrai seulement si le maintien était allé au bout. */
    fun release(now: Long): Boolean {
        val complete = progress(now) >= 1f
        pressedAt = null
        return complete
    }

    fun cancel() {
        pressedAt = null
    }

    companion object {
        const val DURATION_MS = 1_500L

        fun progress(start: Long, now: Long): Float = ((now - start).toFloat() / DURATION_MS).coerceIn(0f, 1f)
    }
}

/**
 * **Les dates de l'essai**, à la même source que le paywall (`PaywallTimeline`,
 * `TrialEndReminder.fireDate`) : la fin, `trialDays` × 24 h après l'achat ; le rappel, la
 * veille, s'il tombe plus d'une heure après l'achat.
 */
object TrialDates {
    private const val DAY_MS = 86_400_000L
    private const val HOUR_MS = 3_600_000L

    fun end(now: Long, trialDays: Int): Long = now + trialDays * DAY_MS

    /** Le rappel de fin d'essai, ou `null` quand l'essai est trop court pour en avoir un. */
    fun reminder(now: Long, trialDays: Int): Long? {
        if (trialDays < 2) return null
        val fire = end(now, trialDays) - DAY_MS
        return if (fire > now + HOUR_MS) fire else null
    }

    /**
     * **Le jour d'une date, dans la langue et le fuseau donnés** (« 15 novembre ») : le fuseau
     * est celui du calendrier, pas celui du système, comme sur l'iPhone.
     */
    fun dayText(at: Long, locale: Locale, zone: ZoneId = ZoneId.systemDefault()): String {
        val pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "dMMMM")
        return DateTimeFormatter.ofPattern(pattern, locale).withZone(zone).format(Instant.ofEpochMilli(at))
    }

    /** La même, sans dépendre d'Android (les tests JVM purs). */
    fun dayTextPortable(at: Long, locale: Locale, zone: ZoneId): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale).withZone(zone).format(Instant.ofEpochMilli(at))
}

/**
 * **Le récit d'exemple du chapitre 7, selon le pays** (lot 16) : la Révolution française en
 * France, la Magna Carta au Royaume-Uni, la Révolution américaine aux États-Unis, la
 * réunification en Allemagne, l'unité italienne, la Transition espagnole, la révolution des
 * Œillets, Solidarność, la République turque ; ailleurs, la révolution industrielle.
 */
enum class HistoryStory(val years: List<String>) {
    france(listOf("1792", "1789", "1804")),
    uk(listOf("1066", "1215", "1688")),
    us(listOf("1783", "1776", "1789")),
    germany(listOf("1961", "1989", "1990")),
    italy(listOf("1848", "1861", "1870")),
    spain(listOf("1975", "1978", "1982")),
    portugal(listOf("1968", "1974", "1986")),
    poland(listOf("1956", "1980", "1989")),
    turkey(listOf("1919", "1923", "1938")),
    world(listOf("1712", "1769", "1830"));

    val rightYear: String get() = years[1]

    private fun key(field: String): String {
        if (this == france) {
            return when (field) {
                "lesson" -> "ios.onb14.story.lesson"
                "question" -> "ios.onb14.story.create.question"
                "node1" -> "ios.onb14.story.node.estates"
                "node2" -> "ios.onb14.story.node.bastille"
                "quiz" -> "ios.onb14.story.quiz.q"
                "askQ" -> "ios.onb14.story.ask.q"
                else -> "ios.onb15.story.ask.a"
            }
        }
        return "ios.onb16.story.$name.$field"
    }

    val lessonKey get() = key("lesson")
    val questionKey get() = key("question")
    val node1Key get() = key("node1")
    val node2Key get() = key("node2")
    val quizKey get() = key("quiz")
    val askQuestionKey get() = key("askQ")
    val askAnswerKey get() = key("askA")

    companion object {
        /** Le récit de l'élève : son pays de la liste, ou son code ISO choisi dans la recherche. */
        fun of(country: String, region: String?): HistoryStory = when (country) {
            "fr" -> france
            "uk" -> uk
            "us" -> us
            "de" -> germany
            "it" -> italy
            "es" -> spain
            "pt" -> portugal
            "pl" -> poland
            "tr" -> turkey
            "other" -> when (region?.uppercase(Locale.ROOT)) {
                "FR" -> france
                "GB" -> uk
                "US" -> us
                "DE" -> germany
                "IT" -> italy
                "ES" -> spain
                "PT" -> portugal
                "PL" -> poland
                "TR" -> turkey
                else -> world
            }
            else -> world
        }
    }
}

/** **L'exercice du scanner, de sa classe** (lot 15) : Pythagore, le second degré, une intégrale. */
enum class ScanExercise(val problem: String?, val steps: List<Pair<String, String>>, val resultKey: String?, val result: String) {
    pythagoras(null, listOf("ios.onb15.scan.pyth.1" to "BC² = 6² + 8²", "ios.onb15.scan.pyth.2" to "BC² = 36 + 64 = 100"), null, "BC = 10 cm"),
    quadratic("x² − 4x + 3 = 0", listOf("ios.onb15.scan.quad.1" to "Δ = 16 − 12 = 4", "ios.onb15.scan.quad.2" to "x = (4 ± 2) / 2"), "ios.onb10.story.result", "x = 1 / x = 3"),
    integral("∫₀¹ 2x dx", listOf("ios.onb15.scan.int.1" to "F(x) = x²", "ios.onb15.scan.int.2" to "F(1) − F(0) = 1 − 0"), null, "∫₀¹ 2x dx = 1");

    companion object {
        fun forTier(tier: String?): ScanExercise = when (band(tier)) {
            "lower" -> pythagoras
            "higher" -> integral
            else -> quadratic
        }

        fun band(tier: String?): String = when (tier) {
            "lowerSecondary" -> "lower"
            "undergraduate", "graduate", "health", "competitive" -> "higher"
            else -> "upper"
        }
    }
}

/** **L'écart entre la moyenne et l'objectif** (`OnboardingGradeGap`). */
data class GradeGap(val size: Size, val from: String, val to: String, val amount: String?, val isWhole: Boolean) {
    enum class Size { HOLD, SMALL, MEDIUM, LARGE }

    companion object {
        fun of(current: Int, target: Int, scale: StudentGradeScale, from: String, to: String): GradeGap {
            val steps = maxOf(0, target - current)
            val size = when {
                steps == 0 -> Size.HOLD
                steps <= 2 -> Size.SMALL
                steps <= 4 -> Size.MEDIUM
                else -> Size.LARGE
            }
            var amount: String? = null
            var whole = false
            if (steps > 0 && !scale.lowerIsBetter && current >= TargetScore.MIN) {
                val low = number(scale.scale.label(current))
                val high = number(scale.scale.label(target))
                if (low != null && high != null && low.denominator == high.denominator && high.value > low.value) {
                    val difference = high.value - low.value
                    whole = low.isWhole && high.isWhole
                    amount = if (whole) Math.round(difference).toString() else {
                        val text = String.format(Locale.ROOT, "%.1f", difference)
                        if (low.usesComma || high.usesComma) text.replace('.', ',') else text
                    }
                }
            }
            return GradeGap(size, from, to, amount, whole)
        }

        data class Number(val value: Double, val denominator: String?, val isWhole: Boolean, val usesComma: Boolean)

        fun number(label: String): Number? {
            var text = label
            for (sign in listOf("%", "٪", " ", " ", " ")) text = text.replace(sign, "")
            var denominator: String? = null
            val slash = text.indexOf('/')
            if (slash >= 0) {
                denominator = text.substring(slash + 1)
                text = text.substring(0, slash)
            }
            if (text.isEmpty()) return null
            val digits = StringBuilder()
            var comma = false
            var separators = 0
            for (c in text) {
                when {
                    c.isDigit() -> digits.append(Character.getNumericValue(c))
                    c == ',' || c == '.' || c == '٫' -> {
                        comma = comma || c != '.'
                        separators++
                        digits.append('.')
                    }
                    else -> return null
                }
            }
            if (separators > 1) return null
            val value = digits.toString().toDoubleOrNull() ?: return null
            return Number(value, denominator, separators == 0, comma)
        }
    }
}

/** **Ce qui le bloque** : plusieurs réponses, dans l'ordre de la liste. */
enum class StudyWorry { examStress, hardLessons, homework, forgetting, noStart, motivation }

/** **Le genre de l'élève**, tel qu'il le dit. Les noms sont ceux des statistiques (`gender`). */
enum class StudentGender {
    male, female, other;

    val titleKey: String get() = "ios.onb18.gender.$name"
}

/** **Le temps de révision d'aujourd'hui, par semaine** (lot 12). */
enum class WeeklyStudy(val titleKey: String, val reactionKey: String) {
    underOne("ios.onb12.hours.underOne", "ios.onb16.react.hours.underOne"),
    oneToThree("ios.onb12.hours.oneToThree", "ios.onb12.react.hours.oneToThree"),
    threeToSix("ios.onb12.hours.threeToSix", "ios.onb12.react.hours.threeToSix"),
    overSix("ios.onb12.hours.overSix", "ios.onb12.react.hours.overSix"),
}

/** **Comment il révise aujourd'hui** (lot 12). */
enum class StudyMethod(val titleKey: String, val recapKey: String) {
    rereading("ios.onb12.method.rereading", "ios.onb12.recap.method.rereading"),
    notes("ios.onb12.method.notes", "ios.onb12.recap.method.notes"),
    exercises("ios.onb12.method.exercises", "ios.onb12.recap.method.exercises"),
    nothingFixed("ios.onb12.method.nothingFixed", "ios.onb12.recap.method.nothingFixed"),
}

/** **L'objectif n°1**, parmi ceux de son niveau (`LearningGoal.offered(for:)`). */
enum class LearningGoal(val emoji: String) {
    language("🗣️"), exam("📝"), competition("🏁"), lectures("📚"), profession("💼"), curiosity("🧠"), other("✨"),
    grades("📈"), dreamSchool("🎓"), understand("💡"), faster("⚡"), ahead("🚀"), passYear("✅");

    val titleKey: String
        get() = when (this) {
            grades, dreamSchool, understand, faster, ahead, passYear -> "ios.onb9.goal.$name"
            else -> "ios.goal.$name"
        }

    companion object {
        fun offered(tier: String?): List<LearningGoal> = when (tier) {
            "lowerSecondary" -> listOf(grades, understand, faster, ahead, curiosity)
            "upperSecondary", "preUniversity" -> listOf(grades, dreamSchool, understand, faster, ahead)
            "undergraduate", "graduate" -> listOf(passYear, grades, understand, faster, profession)
            "health", "competitive" -> listOf(competition, grades, understand, faster)
            else -> listOf(grades, understand, faster, language, curiosity, profession)
        }
    }
}
