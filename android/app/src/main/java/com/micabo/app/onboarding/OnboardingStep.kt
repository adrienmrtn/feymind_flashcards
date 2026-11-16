package com.micabo.app.onboarding

/**
 * **Les écrans du parcours d'accueil, dans l'ordre** (`OnboardingStep.swift`, état du lot 16) :
 * les stories, puis sept chapitres courts, chacun ouvert par Mika, et le paywall.
 *
 * 1. Faisons connaissance · 2. Ce qui coince · 3. Comment Mika t'aide · 4. Ton objectif ·
 * 5. Ton organisation · 6. Ton plan · 7. Ta première leçon.
 *
 * **Les noms sont ceux des statistiques** (`onboarding_step`), les mêmes que sur l'iPhone.
 */
enum class OnboardingStep(val kind: Kind, val chapter: Int) {
    hookLogo(Kind.STORIES, 0),

    welcome(Kind.CHAPTER, 0),
    /** « Comment tu t'appelles ? » : `name` dans les statistiques (le nom Kotlin est pris). */
    yourName(Kind.QUESTION, 0),
    country(Kind.QUESTION, 0),
    level(Kind.QUESTION, 0),
    schoolType(Kind.QUESTION, 0),
    year(Kind.QUESTION, 0),
    exam(Kind.QUESTION, 0),
    subjects(Kind.QUESTION, 0),

    studyIntro(Kind.CHAPTER, 1),
    hardestSubject(Kind.QUESTION, 1),
    goal(Kind.QUESTION, 1),
    worries(Kind.QUESTION, 1),
    studyHours(Kind.QUESTION, 1),
    studyMethod(Kind.QUESTION, 1),
    solutionMap(Kind.MOMENT, 1),

    helpIntro(Kind.CHAPTER, 2),
    origin(Kind.DEMO, 2),
    lessonDemo(Kind.DEMO, 2),
    scanDemo(Kind.DEMO, 2),
    research(Kind.PAGE, 2),

    goalIntro(Kind.CHAPTER, 3),
    currentAverage(Kind.QUESTION, 3),
    targetAverage(Kind.QUESTION, 3),
    startingPoint(Kind.PAGE, 3),
    dailyTime(Kind.QUESTION, 3),

    organizeIntro(Kind.CHAPTER, 4),
    planDemo(Kind.DEMO, 4),
    focusDemo(Kind.DEMO, 4),
    notifications(Kind.PAGE, 4),
    commitment(Kind.PAGE, 4),

    planBuilding(Kind.MOMENT, 5),
    profileSummary(Kind.MOMENT, 5),

    storyIntro(Kind.CHAPTER, 6),
    storyCreate(Kind.PAGE, 6),
    storyPath(Kind.PAGE, 6),
    storyPractice(Kind.PAGE, 6),
    storyAsk(Kind.PAGE, 6),
    storyClose(Kind.MOMENT, 6),
    firstLesson(Kind.QUESTION, 6),
    freeTrialIntro(Kind.PAGE, 6),
    trialOffer(Kind.PAGE, 6),
    paywall(Kind.PAYWALL, 6);

    enum class Kind { STORIES, CHAPTER, MOMENT, QUESTION, DEMO, PAGE, PAYWALL }

    /** Le nom dans les statistiques : renommer un cas coupe sa courbe en deux. */
    val analyticsName: String get() = if (this == yourName) "name" else name

    val next: OnboardingStep? get() = entries.getOrNull(ordinal + 1)
    val previous: OnboardingStep? get() = entries.getOrNull(ordinal - 1)

    /** Un choix unique avance tout seul et n'a pas de bouton. */
    val advancesOnChoice: Boolean
        get() = this in setOf(country, level, schoolType, year, hardestSubject, goal, studyHours, studyMethod)

    /** La barre du haut se retire des écrans qui sont un moment à eux seuls. */
    val showsChrome: Boolean get() = this !in setOf(hookLogo, planBuilding, profileSummary, paywall)

    val isLoading: Boolean get() = this == planBuilding

    val allowsReturn: Boolean get() = this !in setOf(hookLogo, profileSummary, paywall) && !isLoading

    /** L'écran qui ouvre un chapitre : celui où Mika parle seul, en grand. */
    val opensChapter: Boolean get() = kind == Kind.CHAPTER || this == planBuilding

    /** **L'avancée dans le chapitre**, de 0 à 1 (exclus). */
    val chapterFraction: Float
        get() {
            val steps = inChapter(chapter)
            val index = steps.indexOf(this)
            if (index < 0) return 0f
            return (index + 1).toFloat() / (steps.size + 1)
        }

    /** Où reprendre un parcours laissé sur cet écran : l'accroche se refait. */
    fun resumePoint(hasName: Boolean): OnboardingStep = when {
        this == hookLogo || this == welcome || this == yourName -> hookLogo
        !hasName -> hookLogo
        else -> this
    }

    companion object {
        const val CHAPTER_COUNT = 7

        /** **La languette du compte** se propose en quittant le plan révélé. */
        val accountStep = profileSummary

        fun inChapter(chapter: Int): List<OnboardingStep> =
            entries.filter { it.chapter == chapter && it != hookLogo && it != paywall }

        fun chapterTitleKey(chapter: Int) = "ios.onb14.chapter.${chapter + 1}"

        fun named(name: String): OnboardingStep? = entries.firstOrNull { it.analyticsName == name }

        /**
         * **L'écran qui suit un écran retiré**, pour reprendre un parcours commencé avant cette
         * version : le suivant qui existe encore, pas le début (`replacement(forRetired:)`).
         */
        fun replacement(retired: String): OnboardingStep? = when (retired) {
            "studyTime" -> notifications
            "building", "featuresIntro", "mikaMission", "mikaSources", "mikaPaths" -> currentAverage
            "mikaDesign", "mikaTutor", "mikaSolution", "mikaRelief", "socialProof" -> planBuilding
            "proofRetention", "founders", "aiCompanion" -> startingPoint
            "supportUs" -> planBuilding
            "trialReminder" -> trialOffer
            "lessonBuilding", "lessonReady" -> freeTrialIntro
            "whyNow" -> paywall
            "cardsDemo" -> scanDemo
            "examDemo" -> research
            "sampleCard" -> currentAverage
            "chatDemo" -> research
            "notJustChat" -> research
            // Les écrans de l'ancien parcours Android, avant le lot 16.
            "language" -> yourName
            else -> null
        }

        /** L'écran d'un nom enregistré : le sien, ou celui qui remplace un écran retiré. */
        fun restored(name: String?): OnboardingStep? = name?.let { named(it) ?: replacement(it) }
    }
}
