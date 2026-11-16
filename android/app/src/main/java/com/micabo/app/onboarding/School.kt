package com.micabo.app.onboarding

import java.text.Normalizer
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.Locale

/**
 * **Le système scolaire d'un pays**, recopié de l'iPhone (`SchoolSystem.swift`,
 * `SchoolSystemWorld.swift`, `SchoolExams.swift`, `GradeScale.swift`) : les filières, les années,
 * les matières (dans la langue du pays, délibérément), les examens et leurs dates, le barème.
 * Les données elles-mêmes sont engendrées dans `SchoolSystemData` par
 * `android/tools/generate_school_systems.py`.
 *
 * `level` est le registre d'écriture (`StudyLevel` : lycee, prepa, licence, sante, master,
 * concours, other), `tier` la marche d'études (`EducationTier`).
 */
data class SchoolTrack(
    val id: String,
    val title: String,
    val emoji: String,
    val level: String,
    val tier: String,
    val years: List<SchoolYear>,
    val exams: List<String> = emptyList(),
)

data class SchoolYear(
    val id: String,
    val title: String,
    val subjects: List<String> = emptyList(),
    val exams: List<String> = emptyList(),
)

data class SchoolExam(
    val id: String,
    val title: String,
    val month: Int? = null,
    val day: Int? = null,
    val emoji: String = "📝",
)

/** Le palier large, pour un pays qui n'est pas décrit en détail (`EducationStage.genericStages`). */
data class EducationStage(val id: String, val title: String, val emoji: String, val level: String, val tier: String)

/** **Les pays de la liste**, dans l'ordre des pastilles de l'iPhone (`SchoolingCountry`). */
object Countries {
    val listed = listOf(
        "fr", "uk", "de", "it", "es", "pt", "cz", "nl", "gr", "hu", "pl", "ro", "se", "tr",
        "be", "ch", "ca", "lu", "ma", "dz", "tn", "sn", "ci", "us",
    )

    /** Le code ISO d'un pays de la liste (« GB » pour le Royaume-Uni). */
    fun regionCode(country: String): String? = when (country) {
        "uk" -> "GB"
        "other", "" -> null
        else -> country.uppercase(Locale.ROOT)
    }

    /** Le pays de la liste d'un code ISO, s'il y en a un. */
    fun listedOf(code: String): String? {
        val upper = code.uppercase(Locale.ROOT)
        return listed.firstOrNull { regionCode(it) == upper }
    }

    fun flag(code: String): String {
        val region = (regionCode(code) ?: code).uppercase(Locale.ROOT)
        if (region.length != 2 || region.any { it !in 'A'..'Z' }) return "🌍"
        return region.map { String(Character.toChars(0x1F1E6 + (it - 'A'))) }.joinToString("")
    }

    /** La langue des cours de chaque pays de la liste. */
    private val language = mapOf(
        "fr" to "fr", "uk" to "en", "de" to "de", "it" to "it", "es" to "es", "pt" to "pt", "cz" to "cs",
        "nl" to "nl", "gr" to "el", "hu" to "hu", "pl" to "pl", "ro" to "ro", "se" to "sv", "tr" to "tr",
        "be" to "fr", "ch" to "fr", "ca" to "fr", "lu" to "fr", "ma" to "fr", "dz" to "fr", "tn" to "fr",
        "sn" to "fr", "ci" to "fr", "us" to "en",
    )

    private val byLanguage = mapOf(
        "fr" to "fr", "en" to "us", "de" to "de", "it" to "it", "es" to "es", "pt" to "pt", "cs" to "cz", "nl" to "nl",
        "el" to "gr", "hu" to "hu", "pl" to "pl", "ro" to "ro", "sv" to "se", "tr" to "tr",
    )

    /**
     * **Le pays présélectionné** (`SchoolingCountry.detected`) : les langues du téléphone,
     * région comprise quand ce pays parle la langue. `null` : aucune langue n'en désigne un.
     */
    fun detected(tags: List<String>): String? {
        for (tag in tags.map { it.lowercase(Locale.ROOT).replace('_', '-') }) {
            val parts = tag.split('-')
            val lang = parts.firstOrNull() ?: continue
            for (region in parts.drop(1).filter { it.length == 2 }) {
                val country = if (region == "gb" || region == "uk") "uk" else region.takeIf { it in listed } ?: continue
                if (byLanguage[lang] == null || language[country]?.startsWith(lang) == true) return country
            }
        }
        for (tag in tags) {
            val lang = tag.lowercase(Locale.ROOT).split('-', '_').first()
            byLanguage[lang]?.let { return it }
        }
        return null
    }

    /** Les paliers d'un pays qu'on ne décrit pas : courts, dans l'ordre du parcours scolaire. */
    val genericStages = listOf(
        EducationStage("generic.middle", "Middle school", "🎒", "lycee", "lowerSecondary"),
        EducationStage("generic.high", "High school", "🏫", "lycee", "upperSecondary"),
        EducationStage("generic.college", "College", "🎓", "licence", "undergraduate"),
        EducationStage("generic.university", "University", "🔬", "master", "graduate"),
        EducationStage("generic.other", "Other", "✨", "other", "other"),
    )
}

/** **Un pays du monde**, trouvé dans la recherche (`WorldCountries`). */
data class WorldCountry(val code: String, val name: String) {
    val flag: String get() = Countries.flag(code)
}

object WorldCountries {
    private val cache = HashMap<String, List<WorldCountry>>()

    fun all(locale: Locale): List<WorldCountry> = synchronized(cache) {
        cache.getOrPut(locale.toLanguageTag()) {
            Locale.getISOCountries()
                .map { WorldCountry(it, Locale("", it).getDisplayCountry(locale)) }
                .filter { it.name.isNotBlank() && it.name != it.code }
                .sortedWith(compareBy(java.text.Collator.getInstance(locale)) { it.name })
        }
    }

    fun matches(query: String, locale: Locale, limit: Int = 6): List<WorldCountry> {
        val needle = fold(query)
        if (needle.isEmpty()) return emptyList()
        return all(locale).mapNotNull { country ->
            val name = fold(country.name)
            when {
                name.startsWith(needle) -> country to 0
                name.contains(needle) -> country to 1
                country.code.lowercase(Locale.ROOT) == needle -> country to 2
                else -> null
            }
        }.sortedBy { it.second }.take(limit).map { it.first }
    }

    fun country(code: String?, locale: Locale): WorldCountry? {
        val upper = code?.trim()?.uppercase(Locale.ROOT)?.takeIf { it.isNotEmpty() } ?: return null
        return all(locale).firstOrNull { it.code == upper } ?: WorldCountry(upper, Locale("", upper).getDisplayCountry(locale))
    }

    fun fold(text: String): String =
        Normalizer.normalize(text, Normalizer.Form.NFD).replace(Regex("\\p{M}+"), "").lowercase(Locale.ROOT).trim()
}

object SchoolSystem {
    /** Les filières d'un pays, par son code ISO ; vides quand on n'en connaît que les paliers. */
    fun tracks(region: String?, germanSwiss: Boolean = Locale.getDefault().language == "de"): List<SchoolTrack> {
        val code = region?.uppercase(Locale.ROOT) ?: return emptyList()
        return SchoolSystemData.tracks(code, germanSwiss)
    }

    fun isDetailed(region: String?): Boolean = tracks(region).isNotEmpty()

    val describedRegions: List<String> get() = SchoolSystemData.describedRegions

    /** La filière d'identifiant donné ; son préfixe désigne son pays (`at.ahsOberstufe`). */
    fun track(id: String?, region: String?): SchoolTrack? {
        if (id.isNullOrEmpty()) return null
        tracks(region).firstOrNull { it.id == id }?.let { return it }
        val prefix = id.substringBefore('.').let { if (it == "uk") "GB" else it }
        return tracks(prefix).firstOrNull { it.id == id }
    }

    fun year(id: String?, track: SchoolTrack?): SchoolYear? {
        if (id.isNullOrEmpty() || track == null) return null
        return track.years.firstOrNull { it.id == id }
    }

    /** Les matières d'une année précise (`SchoolSubjects.forYear`). */
    fun subjectsForYear(track: SchoolTrack?, year: SchoolYear?): List<String>? {
        track ?: return null
        year?.subjects?.takeIf { it.isNotEmpty() }?.let { return it }
        return track.years.firstNotNullOfOrNull { y -> y.subjects.takeIf { it.isNotEmpty() } }
    }

    /** Les années de master rangées dans la filière « université » : marche du master. */
    private val graduateYears = setOf("fr.m1", "fr.m2", "de.master", "es.master", "tr.yukseklisans")

    fun tier(track: SchoolTrack?, year: SchoolYear?): String? {
        track ?: return null
        if (year != null && year.id in graduateYears) return "graduate"
        return track.tier
    }

    /** **L'examen phare d'un pays** (les stories) : celui de la dernière année du lycée. */
    fun flagshipExam(region: String?): String? {
        val tracks = tracks(region)
        val ordered = tracks.filter { it.tier == "upperSecondary" } + tracks.filter { it.tier != "upperSecondary" }
        for (track in ordered) {
            val ids = track.years.lastOrNull()?.exams?.takeIf { it.isNotEmpty() } ?: track.exams
            ids.firstNotNullOfOrNull { SchoolExams.catalog[it] }?.let { return it.title }
        }
        return null
    }
}

/** **Ce qui arrive en premier** : un examen du pays, un contrôle, les partiels, ou rien. */
sealed interface ExamChoice {
    val id: String
    val hasDate: Boolean get() = this != None

    data class Named(val exam: SchoolExam) : ExamChoice {
        override val id: String get() = exam.id
    }
    data object Test : ExamChoice {
        override val id = SchoolExams.TEST
    }
    data object Finals : ExamChoice {
        override val id = SchoolExams.FINALS
    }
    data object None : ExamChoice {
        override val id = SchoolExams.NONE
    }
}

object SchoolExams {
    const val TEST = "exam.test"
    const val FINALS = "exam.finals"
    const val NONE = "exam.none"

    val catalog: Map<String, SchoolExam> by lazy { SchoolSystemData.exams.associateBy { it.id } }

    fun choices(track: SchoolTrack?, year: SchoolYear?, tier: String?): List<ExamChoice> {
        val ids = year?.exams?.takeIf { it.isNotEmpty() } ?: track?.exams ?: emptyList()
        val result = ids.mapNotNull { catalog[it] }.map { ExamChoice.Named(it) }.toMutableList<ExamChoice>()
        when (track?.tier ?: tier) {
            "undergraduate", "graduate", "health", "preUniversity", "competitive" -> result += ExamChoice.Finals
            else -> result += ExamChoice.Test
        }
        result += ExamChoice.None
        return result
    }

    fun choice(id: String?): ExamChoice? = when (id) {
        null, "" -> null
        TEST -> ExamChoice.Test
        FINALS -> ExamChoice.Finals
        NONE -> ExamChoice.None
        else -> catalog[id]?.let { ExamChoice.Named(it) }
    }

    /** La date proposée pour un examen, d'après le calendrier du pays (`suggestedDate`). */
    fun suggestedDate(choice: ExamChoice, today: LocalDate): LocalDate? = when (choice) {
        ExamChoice.None -> null
        ExamChoice.Test -> today.plusDays(14)
        ExamChoice.Finals -> {
            val earliest = today.plusDays(21)
            listOfNotNull(next(1, 15, earliest), next(6, 5, earliest)).minOrNull()
        }
        is ExamChoice.Named -> {
            val month = choice.exam.month
            val day = choice.exam.day
            if (month == null || day == null) today.plusDays(60) else next(month, day, today.plusDays(7))
        }
    }

    fun next(month: Int, day: Int, after: LocalDate): LocalDate? {
        for (year in listOf(after.year, after.year + 1)) {
            val found = runCatching { LocalDate.of(year, month, day) }.getOrNull() ?: continue
            if (!found.isBefore(after)) return found
        }
        return null
    }

    fun daysLeft(until: LocalDate, from: LocalDate): Int = maxOf(0, ChronoUnit.DAYS.between(from, until).toInt())
}

/** Un cran du barème : le score sur l'échelle 10–20 du produit, et son libellé dans le pays. */
data class GradeTick(val score: Int, val label: String)

object TargetScore {
    const val MIN = 10
    const val MAX = 20
    fun clamp(score: Int) = score.coerceIn(MIN, MAX)
    fun percent(score: Int) = Math.round(clamp(score).toDouble() / MAX * 100).toInt()
}

data class DesiredGradeScale(val ticks: List<GradeTick>) {
    /** Les crans distincts, sans répéter un libellé. */
    val choices: List<GradeTick> get() {
        val seen = HashSet<String>()
        return ticks.filter { seen.add(it.label) }
    }

    fun label(score: Int): String = ticks[TargetScore.clamp(score) - TargetScore.MIN].label

    companion object {
        const val BELOW_SCORE = TargetScore.MIN - 1

        fun of(labels: List<String>) = DesiredGradeScale(labels.mapIndexed { index, label -> GradeTick(TargetScore.MIN + index, label) })

        /** Le barème d'un pays de la liste (`DesiredGradeScale.for`). */
        fun forCountry(country: String): DesiredGradeScale = of(
            when (country) {
                "fr", "be", "ma", "dz", "tn", "sn", "ci", "pt", "gr" -> (10..20).map { "$it/20" }
                "uk" -> listOf("C", "C", "C", "B", "B", "B", "A", "A", "A", "A*", "A*")
                "se" -> listOf("E", "E", "D", "D", "C", "C", "B", "B", "A", "A", "A")
                "ca", "tr" -> (10..20).map { "${60 + (it - 10) * 4} %" }
                "de" -> listOf("4,0", "3,7", "3,3", "3,0", "2,7", "2,3", "2,0", "1,7", "1,3", "1,0", "1,0")
                "ch" -> listOf("4", "4", "4,5", "4,5", "5", "5", "5,5", "5,5", "6", "6", "6")
                "it", "es" -> listOf("6/10", "6/10", "7/10", "7/10", "8/10", "8/10", "9/10", "9/10", "10/10", "10/10", "10/10")
                "lu" -> (10..20).map { "${30 + (it - 10) * 3}/60" }
                "cz" -> listOf("4", "4", "3", "3", "3", "2", "2", "2", "1", "1", "1")
                "nl" -> listOf("6", "6", "7", "7", "8", "8", "9", "9", "10", "10", "10")
                "hu", "pl" -> listOf("3", "3", "3", "3", "4", "4", "4", "4", "5", "5", "5")
                "ro" -> listOf("5", "5", "6", "6", "7", "8", "8", "9", "9", "10", "10")
                else -> listOf("C-", "C-", "C", "C+", "B-", "B", "B+", "A-", "A", "A", "A+")
            },
        )
    }
}

/** **Le barème que l'élève connaît** (`StudentGradeScale`). */
data class StudentGradeScale(val scale: DesiredGradeScale, val lowerIsBetter: Boolean, val unitKey: String?) {
    val best: String get() = scale.ticks.last().label

    companion object {
        fun of(region: String?, country: String, track: SchoolTrack?, locale: Locale = Locale.getDefault()): StudentGradeScale {
            val tier = track?.tier
            val university = tier == "undergraduate" || tier == "graduate" || tier == "health"
            fun make(labels: List<String>, lower: Boolean = false, unit: String? = null) =
                StudentGradeScale(DesiredGradeScale.of(labels), lower, unit)
            fun percent(low: Int) = (0..10).map { java.text.NumberFormat.getPercentInstance(locale).format((low + it * (100 - low) / 10) / 100.0) }
            when (region?.uppercase(Locale.ROOT).orEmpty()) {
                "DE" -> if (track?.id == "de.gymnasium") return make(listOf("05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15"), unit = "ios.onb5.grade.points")
                "AT", "SK" -> return make(listOf("4", "4", "3", "3", "3", "2", "2", "2", "1", "1", "1"), lower = true)
                "GB" -> return when {
                    track?.id == "uk.gcse" || track?.id == "uk.ks3" -> make(listOf("4", "4", "5", "5", "6", "6", "7", "7", "8", "8", "9"))
                    university -> make(listOf("Third", "Third", "2:2", "2:2", "2:1", "2:1", "2:1", "First", "First", "First", "First"))
                    else -> make(listOf("E", "D", "C", "C", "B", "B", "A", "A", "A", "A*", "A*"))
                }
                "US" -> return make(listOf("2.0", "2.3", "2.5", "2.7", "3.0", "3.3", "3.5", "3.7", "3.8", "3.9", "4.0"))
                "IT" -> if (university) return make(listOf("18", "20", "22", "24", "25", "26", "27", "28", "29", "30", "30L"))
                "BR" -> return make(listOf("5", "5,5", "6", "6,5", "7", "7,5", "8", "8,5", "9", "9,5", "10"))
                "MX" -> return make(listOf("6", "6", "7", "7", "8", "8", "9", "9", "10", "10", "10"))
                "CO" -> return make(listOf("3,0", "3,2", "3,5", "3,7", "4,0", "4,2", "4,4", "4,6", "4,8", "5,0", "5,0"))
                "CL" -> return make(listOf("4,0", "4,3", "4,6", "5,0", "5,3", "5,6", "6,0", "6,3", "6,6", "6,8", "7,0"))
                "PL" -> return make(listOf("2", "3", "3", "3", "4", "4", "4", "5", "5", "5", "6"))
                "HU", "EE", "HR", "SI", "RS" -> return make(listOf("2", "2", "3", "3", "3", "4", "4", "4", "5", "5", "5"))
                "RU" -> return make(listOf("3", "3", "3", "4", "4", "4", "4", "5", "5", "5", "5"))
                "BG" -> return make(listOf("3", "3", "4", "4", "4", "5", "5", "5", "6", "6", "6"))
                "DK" -> return make(listOf("02", "02", "4", "4", "4", "7", "7", "7", "10", "12", "12"))
                "FI" -> return make(listOf("6", "6", "7", "7", "7", "8", "8", "9", "9", "10", "10"))
                "NL" -> return make(listOf("5,5", "6", "6,5", "7", "7,5", "8", "8,5", "9", "9,5", "10", "10"))
                "TR" -> return make(listOf("50", "55", "60", "65", "70", "75", "80", "85", "90", "95", "100"))
                "EG", "SA" -> return make(percent(50))
                "CA" -> return make(percent(60))
            }
            val inverted = region?.uppercase(Locale.ROOT) == "DE" || region?.uppercase(Locale.ROOT) == "CZ"
            return StudentGradeScale(DesiredGradeScale.forCountry(country), inverted, null)
        }
    }
}

/** **Le temps par jour** (`DailyLoad`) : de 5 minutes à 2 heures. */
object DailyLoad {
    val steps = listOf(5, 10, 15, 20, 25, 30, 45, 60, 75, 90, 105, 120)
    val minimumMinutes get() = steps.first()
    val maximumMinutes get() = steps.last()

    fun newCardsPerDay(dailyMinutes: Int): Int = maxOf(2, Math.round(dailyMinutes * 4.0 / 8.0).toInt())
    fun nearestStep(minutes: Int): Int = steps.minByOrNull { kotlin.math.abs(it - minutes) } ?: minimumMinutes
    fun stepIndex(minutes: Int): Int = steps.indexOf(nearestStep(minutes)).coerceAtLeast(0)
    fun minutes(index: Int): Int = steps.getOrElse(index) { minimumMinutes }
}

/** **Les matières, en groupes** (lot 16) : les principales, les langues, et aussi. */
enum class SubjectGroup(val titleKey: String) {
    MAIN("ios.onb16.subjects.main"),
    LANGUAGES("ios.onb16.subjects.languages"),
    OTHER("ios.onb16.subjects.other");

    companion object {
        fun grouped(subjects: List<String>, country: String): List<Pair<SubjectGroup, List<String>>> {
            val tagged = subjects.map { it to of(it, country) }
            return entries.mapNotNull { group ->
                tagged.filter { it.second == group }.map { it.first }.takeIf { it.isNotEmpty() }?.let { group to it }
            }
        }

        fun of(subject: String, country: String): SubjectGroup {
            val text = fold(subject)
            val words = text.split(Regex("[^\\p{L}\\p{N}]+")).filter { it.isNotEmpty() }.toSet()
            if (words.any { it in otherWords } || otherKeys.any { text.contains(it) }) return OTHER
            if (languageKeys.any { text.contains(it) } && !isNative(text, country)) return LANGUAGES
            return MAIN
        }

        fun isSport(subject: String): Boolean {
            val text = fold(subject)
            return sportKeys.any { text.contains(it) } || text.split(Regex("[^\\p{L}]+")).contains("eps")
        }

        private fun fold(text: String) = WorldCountries.fold(text)

        private fun isNative(text: String, country: String): Boolean {
            val native = when (country) {
                "fr", "be", "lu", "ch", "ma", "dz", "tn", "sn", "ci", "ca" -> listOf("francais", "french", "lettres")
                "uk", "us" -> listOf("english")
                "de" -> listOf("deutsch", "german")
                "es" -> listOf("castellan")
                "it" -> listOf("italiano")
                "pt" -> listOf("portugues")
                "nl" -> listOf("nederlands")
                "tr" -> listOf("turk")
                "pl" -> listOf("polski")
                "cz" -> listOf("cestina", "cesky")
                "gr" -> listOf("ελληνικ", "neoelli", "greek")
                "hu" -> listOf("magyar")
                "ro" -> listOf("romana", "romanian")
                "se" -> listOf("svenska")
                else -> emptyList()
            }
            return native.any { text.contains(it) }
        }

        private val otherWords = setOf("eps", "emc", "art", "arts", "pe", "musik", "musique", "music")
        private val sportKeys = listOf(
            "sport", "education physique", "physical education", "educacion fisica", "educazione fisica",
            "beden egitimi", "wychowanie fizyczne", "lichamelijke", "idrott", "testneveles", "telesna", "liikunta",
        )
        private val otherKeys = sportKeys + listOf(
            "civique", "citizenship", "civic", "ciudadania", "cittadinanza", "arts plastiques", "education musicale",
            "dessin", "grand oral", "brevet", "religion", "religio", "theatre", "danse", "dance", "musica", "muzik",
            "kunst", "beeldende", "zene", "rysunek",
        )
        private val languageKeys = listOf(
            "anglais", "english", "englisch", "ingles", "inglese", "engels", "ingilizce", "angielski", "anglictina",
            "angol", "engleza", "engelska", "engelsk", "englanti", "inglise",
            "espagnol", "spanish", "spanisch", "espanol", "spagnolo", "hiszpanski", "spaans",
            "allemand", "german", "deutsch", "aleman", "tedesco", "almanca", "niemiecki", "duits",
            "italien", "italian", "italiano", "portugais", "portuguese", "latin", "latein", "grec ancien",
            "chinois", "chinese", "japonais", "japanese", "arabe", "arabic", "russe", "russian",
            "francais", "french", "franzosisch", "frances", "francese", "fransizca", "francuski", "frans",
            "llcer", "langue", "language", "sprache", "idioma", "lingua", "lv1", "lv2",
            "extranjera", "straniera", "fremdsprache", "foreign", "yabanci dil",
            "английск", "إنجليزية", "انجليزية", "فرنسية",
        )
    }
}

/** **Le nom d'une matière du catalogue dans la langue de l'app** (`SubjectDisplay.subject`). */
object SubjectDisplay {
    fun subject(name: String, locale: String): String {
        val names = SchoolSystemData.subjectNames[name] ?: return name
        return names[locale] ?: names[locale.substringBefore('-')] ?: names["en"] ?: name
    }
}

/** **Le catalogue général des matières** (`SubjectCatalog`), quand le pays n'en propose pas. */
object SubjectCatalog {
    val all = listOf(
        "Mathématiques", "Physique", "Chimie", "SVT", "Statistiques", "Astronomie", "Géologie",
        "Médecine", "Pharmacie", "Soins infirmiers", "Kinésithérapie", "Anatomie", "Nutrition",
        "Histoire", "Géographie", "Philosophie", "Sociologie", "Psychologie", "Sciences politiques",
        "Anglais", "Espagnol", "Allemand", "Italien", "Portugais", "Japonais", "Chinois", "Arabe", "Russe", "Latin & grec", "Français",
        "Droit", "Économie", "Comptabilité", "Finance", "Management", "Marketing",
        "Informatique", "Algorithmique", "Réseaux", "Électronique", "Mécanique", "Génie civil", "Architecture",
        "Arts", "Musique", "Cinéma", "Théâtre", "Danse", "Photographie", "Journalisme", "Pédagogie", "Sport & STAPS", "Code de la route", "Culture générale",
    )
}
