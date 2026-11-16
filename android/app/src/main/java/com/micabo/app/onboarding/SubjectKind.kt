package com.micabo.app.onboarding

/**
 * **L'icône d'une matière**, lue dans son nom (`MicaboIcon.subjectIcon`) : la première matière
 * reconnue gagne, dans l'ordre de l'iPhone. Les maths passent avant la physique, la chimie
 * avant la biologie, l'histoire avant la géographie.
 */
enum class SubjectKind {
    CALCULATOR, ATOM, FLASK, SCROLL, GLOBE, BRAIN, PALETTE, QUILL, DIPLOMA, ROCKET, BOOK;

    companion object {
        private val keywords: List<Pair<SubjectKind, List<String>>> = listOf(
            CALCULATOR to listOf("math", "algebr", "geometr", "statisti", "calcul", "matemat", "probabil", "wiskunde", "matma", "математ", "رياضيات"),
            ATOM to listOf("physi", "fizik", "fisica", "fysik", "fyzik", "fizyk", "natuurkunde", "mecaniq", "electric", "optique", "quantum", "физик", "فيزياء"),
            FLASK to listOf("chimi", "chemi", "kimya", "quimic", "kemi", "biolog", "svt", "biyoloji", "life science", "scienze naturali", "ciencias naturales", "хими", "биолог", "كيمياء", "أحياء", "احياء", "علوم"),
            SCROLL to listOf("histoir", "history", "histori", "tarih", "geschicht", "storia", "dejepis", "droit", "law", "recht", "derecho", "diritto", "истори", "تاريخ"),
            GLOBE to listOf("geograph", "geografi", "cografya", "erdkunde", "aardrijkskunde", "maantieto", "environnement", "climat", "географ", "جغرافيا"),
            BRAIN to listOf("philo", "psycho", "socio", "neuro", "filosof", "felsefe", "ethik", "ethique", "философ", "فلسفة"),
            PALETTE to listOf("arts", "dessin", "design", "musique", "music", "muzik", "musik", "musica", "kunst"),
            QUILL to listOf("litter", "literat", "francais", "french", "edebiyat", "poesie", "lettres", "deutsch", "turkce", "lengua castellana", "عربية"),
            DIPLOMA to listOf("econom", "finance", "gestion", "ekonomi", "wirtschaft"),
            ROCKET to listOf("informati", "computer", "program", "bilgisayar", "numerique"),
        ).map { (kind, keys) -> kind to keys.map(WorldCountries::fold) }

        private val languages = listOf(
            "anglais", "english", "englisch", "ingles", "inglese", "engels", "ingilizce",
            "espagnol", "spanish", "spanisch", "espanol", "spagnolo",
            "allemand", "german", "aleman", "tedesco", "almanca",
            "italien", "italian", "italiano", "latin", "latein", "grec", "greek",
            "langue", "language", "sprache", "idioma", "lingua", "langues vivantes",
            "английск", "إنجليزية", "انجليزية", "فرنسية",
        ).map(WorldCountries::fold)

        /** L'icône d'une matière, ou `null` quand le nom ne dit rien. */
        fun of(subject: String?): SubjectKind? {
            if (subject.isNullOrBlank()) return null
            val text = WorldCountries.fold(subject)
            for ((kind, keys) in keywords) if (keys.any { text.contains(it) }) return kind
            return if (languages.any { text.contains(it) }) BOOK else null
        }

        /**
         * **Une matière scientifique** (maths, physique, chimie) : le scanner d'exercices se
         * montre sur un exercice de maths de sa classe (lot 15).
         */
        fun isScience(subject: String): Boolean {
            val text = WorldCountries.fold(subject)
            if (keywords[0].second.any { text.contains(it) } || keywords[1].second.any { text.contains(it) }) return true
            return listOf("chimi", "chemi", "kimya", "quimic", "kemi", "хими", "كيمياء").map(WorldCountries::fold).any { text.contains(it) }
        }

        /** La teinte d'une matière (`LessonTone.forSubject`) : 0 jaune, 1 menthe, 2 bleu, 3 rose, 4 lilas. */
        fun tone(kind: SubjectKind?): Int = when (kind) {
            CALCULATOR, ROCKET -> 2
            ATOM, BRAIN -> 4
            FLASK, GLOBE -> 1
            SCROLL, DIPLOMA -> 0
            QUILL, BOOK, PALETTE -> 3
            null -> 2
        }
    }
}
