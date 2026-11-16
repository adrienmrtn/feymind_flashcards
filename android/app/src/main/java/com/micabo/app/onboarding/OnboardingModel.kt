package com.micabo.app.onboarding

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.time.LocalDate
import java.util.Locale

/**
 * **Ce que le parcours garde entre deux ouvertures** (`OnboardingPreferences`) : les réponses,
 * écrites à chaque changement d'écran, et l'écran atteint. Les tests en donnent une en mémoire.
 */
interface OnboardingStore {
    fun string(key: String): String?
    fun putString(key: String, value: String?)
    fun strings(key: String): List<String>
    fun putStrings(key: String, value: List<String>)
}

class MemoryOnboardingStore : OnboardingStore {
    private val values = HashMap<String, Any?>()
    override fun string(key: String) = values[key] as? String
    override fun putString(key: String, value: String?) {
        values[key] = value
    }
    @Suppress("UNCHECKED_CAST")
    override fun strings(key: String) = (values[key] as? List<String>).orEmpty()
    override fun putStrings(key: String, value: List<String>) {
        values[key] = value
    }
}

/** La première leçon choisie : un sujet tapé, ou un cours à importer. */
enum class FirstLessonChoice { TOPIC, IMPORT }

/**
 * **L'état du parcours d'accueil** (`OnboardingModel.swift`) : une seule pile d'étapes, et
 * aucune attente. Avancer change l'étape ; la vue pousse la page.
 *
 * `track` reçoit les événements (`onboarding_answer`…) : jamais un texte tapé par l'élève (le
 * prénom, le sujet de la première leçon) ; seulement des identifiants de catalogue.
 */
class OnboardingModel(
    private val store: OnboardingStore = MemoryOnboardingStore(),
    private val track: (String, Map<String, Any>) -> Unit = { _, _ -> },
    /** L'essai gratuit proposé à cet élève (`OnboardingTrial.isOffered`). */
    private val trialOffered: () -> Boolean = { true },
    /** Les langues du téléphone, pour le pays présélectionné. */
    deviceLanguages: List<String> = listOf(Locale.getDefault().toLanguageTag()),
    /** La région du téléphone, quand ses langues ne désignent aucun pays. */
    deviceRegion: String? = Locale.getDefault().country,
    private val today: () -> LocalDate = { LocalDate.now() },
) {
    var step by mutableStateOf(OnboardingStep.hookLogo)
        private set
    var isMovingForward by mutableStateOf(true)
        private set

    private var restoring = false

    var displayName by mutableStateOf("")
    /** « Et toi, tu es… ? » : facultatif, nul quand la question est passée. */
    var gender by mutableStateOf<StudentGender?>(null)
        private set
    var country by mutableStateOf("fr")
        private set
    var customCountry by mutableStateOf<String?>(null)
        private set
    var stage by mutableStateOf<EducationStage?>(null)
    var schoolTrack by mutableStateOf<SchoolTrack?>(null)
        private set
    var schoolYear by mutableStateOf<SchoolYear?>(null)
        private set
    var examChoice by mutableStateOf<ExamChoice?>(null)
        private set
    var examDate by mutableStateOf<LocalDate?>(null)
    val subjects = mutableStateListOf<String>()
    var hardestSubject by mutableStateOf<String?>(null)
        private set
    var goal by mutableStateOf<LearningGoal?>(null)
        private set
    val worriesInOrder = mutableStateListOf<StudyWorry>()
    var weeklyStudy by mutableStateOf<WeeklyStudy?>(null)
        private set
    var studyMethod by mutableStateOf<StudyMethod?>(null)
        private set
    var currentScore by mutableStateOf<Int?>(null)
    var targetScore by mutableStateOf<Int?>(null)
    var didSkipAverages by mutableStateOf(false)
        private set
    var dailyMinutes by mutableStateOf<Int?>(null)
    var studyHour by mutableStateOf<Int?>(null)
    var hasCommitted by mutableStateOf(false)
        private set
    var firstLessonChoice by mutableStateOf<FirstLessonChoice?>(null)
    var firstLessonTopic by mutableStateOf("")
    var isResumed = false
        private set

    /** La languette du compte, montée en quittant le plan révélé. */
    var isAccountSheetPresented by mutableStateOf(false)
    private var didAnswerAccount = false
    /** Un compte est déjà ouvert : la languette ne monte pas pour rien. */
    var hasAccount = false
    private var hasChosenCountry = false

    init {
        applyDetectedCountry(deviceLanguages, deviceRegion)
    }

    private fun answer(field: String, value: Any) {
        if (!restoring) track("onboarding_answer", mapOf("field" to field, "value" to value))
    }

    // MARK: Le genre

    fun chooseGender(value: StudentGender) {
        if (gender == value) return
        gender = value
        answer("gender", value.name)
    }

    /** « Passer » le genre : rien n'est gardé, et le parcours continue. */
    fun skipGender() {
        if (step != OnboardingStep.gender) return
        gender = null
        answer("gender", "passer")
        advance()
    }

    // MARK: Le pays et l'école

    val regionCode: String? get() = if (country == "other") customCountry else Countries.regionCode(country)

    val tracks: List<SchoolTrack> get() = SchoolSystem.tracks(regionCode)

    val isDetailed: Boolean get() = tracks.isNotEmpty()

    val hasAnsweredCountry: Boolean get() = country != "other" || customCountry != null

    /** La marche lue par les écrans : celle de la filière, sinon celle du palier. */
    val tier: String? get() = SchoolSystem.tier(schoolTrack, schoolYear) ?: stage?.tier

    val level: String? get() = schoolTrack?.level ?: stage?.level

    fun selectCountry(code: String) {
        hasChosenCountry = true
        if (code == country && code != "other") return
        country = code
        schoolTrack = null
        schoolYear = null
        examChoice = null
        examDate = null
        if (code != "other") customCountry = null
        answer("country", code)
    }

    /** Un pays trouvé par la recherche : celui de la liste s'il y est, sinon « autre pays ». */
    fun selectWorld(code: String) {
        val listed = Countries.listedOf(code)
        if (listed != null) {
            selectCountry(listed)
        } else {
            selectCountry("other")
            if (customCountry != code.uppercase(Locale.ROOT)) {
                customCountry = code.uppercase(Locale.ROOT)
                stage = null
                answer("customCountry", customCountry!!)
            }
        }
    }

    fun chooseTrack(value: SchoolTrack) {
        if (schoolTrack?.id == value.id) return
        if (schoolTrack != null) {
            schoolYear = null
            examChoice = null
            examDate = null
        }
        schoolTrack = value
        stage = EducationStage(value.id, value.title, value.emoji, value.level, value.tier)
        answer("track", value.id)
    }

    fun chooseYear(value: SchoolYear) {
        if (schoolYear?.id == value.id) return
        if (schoolYear != null) {
            examChoice = null
            examDate = null
        }
        schoolYear = value
        answer("year", value.id)
    }

    fun chooseStage(value: EducationStage) {
        stage = value
        answer("stage", value.id)
    }

    val examChoices: List<ExamChoice> get() = SchoolExams.choices(schoolTrack, schoolYear, stage?.tier)

    fun chooseExam(choice: ExamChoice) {
        if (choice == examChoice) return
        examChoice = choice
        examDate = SchoolExams.suggestedDate(choice, today())
        answer("exam", choice.id)
    }

    fun examDaysLeft(): Int? {
        val choice = examChoice ?: return null
        val date = examDate ?: return null
        if (!choice.hasDate) return null
        return SchoolExams.daysLeft(date, today())
    }

    val datedExam: Pair<ExamChoice, LocalDate>?
        get() {
            val choice = examChoice ?: return null
            val date = examDate ?: return null
            return if (choice.hasDate) choice to date else null
        }

    /** La classe telle qu'un écran la nomme : l'année, sinon la filière, sinon le palier. */
    val classLabel: String? get() = schoolYear?.title ?: schoolTrack?.title ?: stage?.title?.takeUnless { stage?.id?.startsWith("generic.") == true }

    /** Les matières de sa classe, quand son pays est décrit (`SubjectsStepView.classSubjects`). */
    val classSubjects: List<String>
        get() = if (!isDetailed) emptyList() else SchoolSystem.subjectsForYear(schoolTrack, schoolYear).orEmpty()

    fun toggleSubject(subject: String) {
        if (subjects.contains(subject)) subjects.remove(subject) else subjects.add(subject)
        if (hardestSubject != null && hardestSubject !in subjects) hardestSubject = null
    }

    fun chooseHardest(subject: String) {
        hardestSubject = subject
        answer("hardestSubject", subject)
    }

    /** La matière des démonstrations : la plus dure, sinon la seule cochée. */
    val focusSubject: String? get() = hardestSubject ?: subjects.singleOrNull()

    val hasScienceSubject: Boolean get() = subjects.any { SubjectKind.isScience(it) }

    /** Ses matières, la plus dure d'abord. */
    val orderedSubjects: List<String>
        get() {
            val ordered = subjects.sorted().toMutableList()
            hardestSubject?.let { if (ordered.remove(it)) ordered.add(0, it) }
            return ordered
        }

    // MARK: Ce qui coince

    fun chooseGoal(value: LearningGoal) {
        goal = value
        answer("goal", value.name)
    }

    /** L'objectif n°1 tel que l'écran le montre : seulement s'il est proposé à ce niveau. */
    val mainGoal: LearningGoal? get() = goal?.takeIf { it in LearningGoal.offered(tier) }

    fun toggleWorry(worry: StudyWorry) {
        if (worriesInOrder.contains(worry)) worriesInOrder.remove(worry) else worriesInOrder.add(worry)
        if (worriesInOrder.isNotEmpty()) {
            answer("worries", StudyWorry.entries.filter { it in worriesInOrder }.joinToString(",") { it.name })
        }
    }

    val worries: Set<StudyWorry> get() = worriesInOrder.toSet()

    fun chooseWeekly(value: WeeklyStudy) {
        weeklyStudy = value
        answer("weeklyStudy", value.name)
    }

    fun chooseMethod(value: StudyMethod) {
        studyMethod = value
        answer("studyMethod", value.name)
    }

    // MARK: Les notes

    val gradeScale: StudentGradeScale get() = StudentGradeScale.of(regionCode, country, schoolTrack)

    fun gradeLabel(score: Int, below: (String) -> String): String {
        val scale = gradeScale.scale
        return if (score < TargetScore.MIN) below(scale.choices.first().label) else scale.label(score)
    }

    val targetChoices: List<GradeTick>
        get() {
            val floor = currentScore ?: DesiredGradeScale.BELOW_SCORE
            return gradeScale.scale.choices.filter { it.score >= floor }
        }

    fun setCurrent(score: Int) {
        currentScore = score
        targetScore?.let { if (it < score) targetScore = null }
    }

    fun answerCurrentAverage() {
        didSkipAverages = false
        currentScore?.let { answer("currentScore", it) }
    }

    fun skipAverages() {
        if (step != OnboardingStep.currentAverage) return
        currentScore = null
        targetScore = null
        didSkipAverages = true
        answer("averages", "passer")
        advance()
    }

    // MARK: Le temps, le rappel, l'engagement

    val minutesPerDay: Int get() = dailyMinutes ?: 15
    val cardsPerDay: Int get() = DailyLoad.newCardsPerDay(minutesPerDay)
    val reminderHour: Int get() = studyHour ?: DEFAULT_HOUR

    fun commit() {
        if (hasCommitted) return
        hasCommitted = true
        answer("commitment", "pris")
    }

    // MARK: La première leçon

    val firstLessonSubject: String? get() = if (firstLessonChoice == FirstLessonChoice.TOPIC) firstLessonTopic.trim().ifEmpty { null } else null

    val hasAnsweredFirstLesson: Boolean
        get() = when (firstLessonChoice) {
            FirstLessonChoice.TOPIC -> firstLessonSubject != null
            FirstLessonChoice.IMPORT -> true
            null -> false
        }

    /** « Continuer » : le choix part à l'accueil, qui le proposera. Les statistiques ne gardent que sa forme. */
    fun confirmFirstLesson() {
        if (step != OnboardingStep.firstLesson || !hasAnsweredFirstLesson) return
        track("onboarding_first_lesson", mapOf("choice" to if (firstLessonSubject != null) "topic" else "import"))
        advance()
    }

    fun skipFirstLesson() {
        if (step != OnboardingStep.firstLesson) return
        firstLessonChoice = null
        firstLessonTopic = ""
        track("onboarding_first_lesson", mapOf("choice" to "later"))
        advance()
    }

    // MARK: Le récit d'exemple

    val story: HistoryStory get() = HistoryStory.of(country, regionCode)

    // MARK: Avancer, revenir

    /**
     * **Les écrans sautés** : la question de niveau que le pays n'a pas ; la matière la plus
     * dure avec une seule matière ; le scanner sans matière scientifique ; la moyenne visée
     * quand la moyenne est passée ; les deux écrans de l'essai sans essai offert.
     */
    fun isSkipped(target: OnboardingStep): Boolean = when (target) {
        OnboardingStep.schoolType, OnboardingStep.year -> !isDetailed
        OnboardingStep.level -> isDetailed
        OnboardingStep.targetAverage -> didSkipAverages
        OnboardingStep.hardestSubject -> subjects.size < 2
        OnboardingStep.scanDemo -> !hasScienceSubject
        OnboardingStep.freeTrialIntro, OnboardingStep.trialOffer -> !trialOffered()
        else -> false
    }

    fun finishAccountSheet() {
        didAnswerAccount = true
        isAccountSheetPresented = false
        advance()
    }

    /** Passe à l'écran suivant ; faux quand il n'y a plus rien après. */
    fun advance(): Boolean {
        if (step == OnboardingStep.accountStep && !didAnswerAccount && !hasAccount) {
            isAccountSheetPresented = true
            return true
        }
        persist()
        if (step == OnboardingStep.subjects && subjects.isNotEmpty() && !restoring) {
            track("onboarding_answer", mapOf<String, Any>("field" to "subjects") + analyticsList("value", subjects.sorted()))
        }
        var next = step.next
        while (next != null && isSkipped(next)) next = next.next
        next ?: return false
        move(next, forward = true)
        return true
    }

    /**
     * **Toutes les réponses, à plat**, pour `onboarding_profile` (`analyticsProfile`). Des
     * identifiants et des nombres ; les seuls textes libres sont des noms de matières,
     * raccourcis. Le prénom n'y est pas, et n'y sera pas.
     */
    fun analyticsProfile(uiLanguage: String): Map<String, Any> {
        val profile = LinkedHashMap<String, Any>()
        fun putText(key: String, value: String?) {
            value?.trim()?.take(120)?.takeIf { it.isNotEmpty() }?.let { profile[key] = it }
        }
        fun putNumber(key: String, value: Int?) {
            value?.let { profile[key] = it }
        }
        putText("ui_language", uiLanguage)
        putText("country", country)
        putText("custom_country", customCountry)
        profile["gender"] = gender?.name ?: "passer"
        putText("stage", stage?.id)
        putText("level", level)
        putText("track", schoolTrack?.id)
        putText("year", schoolYear?.id)
        putText("exam", examChoice?.id)
        if (examChoice?.hasDate == true) putText("exam_date", examDate?.toString())
        if (subjects.isNotEmpty()) {
            profile.putAll(analyticsList("subjects", subjects.sorted()))
            profile["subject_count"] = subjects.size
        }
        putText("hardest_subject", hardestSubject)
        putText("goal", mainGoal?.name)
        if (worriesInOrder.isNotEmpty()) putText("worries", worriesInOrder.joinToString(",") { it.name })
        putText("weekly_study", weeklyStudy?.name)
        putText("study_method", studyMethod?.name)
        putNumber("current_score", currentScore)
        putNumber("target_score", targetScore)
        putNumber("daily_minutes", dailyMinutes)
        putNumber("study_hour", studyHour)
        profile["first_lesson"] = when (firstLessonChoice) {
            FirstLessonChoice.TOPIC -> "topic"
            FirstLessonChoice.IMPORT -> "import"
            null -> "later"
        }
        profile["committed"] = hasCommitted
        profile["has_account"] = hasAccount
        profile["skipped_averages"] = didSkipAverages
        return profile
    }

    val canGoBack: Boolean get() = step.allowsReturn && returnTarget != null

    private val returnTarget: OnboardingStep?
        get() {
            var previous = step.previous
            while (previous != null && (isSkipped(previous) || previous.isLoading)) previous = previous.previous
            return previous
        }

    fun goBack() {
        if (!canGoBack) return
        returnTarget?.let { move(it, forward = false) }
    }

    /** Pose le parcours sur un écran, sans rien écrire : pour les rendus et les tests. */
    fun place(target: OnboardingStep) {
        restoring = true
        step = target
        restoring = false
    }

    private fun move(next: OnboardingStep, forward: Boolean) {
        isMovingForward = forward
        step = next
        if (!restoring) {
            store.putString(Keys.STEP, next.analyticsName)
            track("onboarding_step", mapOf("step" to next.analyticsName))
        }
    }

    // MARK: La présélection du pays

    private fun applyDetectedCountry(languages: List<String>, region: String?) {
        val detected = Countries.detected(languages)
        if (detected != null) {
            country = detected
            customCountry = null
            return
        }
        val code = region?.uppercase(Locale.ROOT)?.takeIf { it.length == 2 }
        val listed = code?.let { Countries.listedOf(it) }
        when {
            listed != null -> country = listed
            code != null -> {
                country = "other"
                customCountry = code
            }
            else -> country = "fr"
        }
    }

    // MARK: Garder, reprendre

    private object Keys {
        const val STEP = "onb.step"
        const val NAME = "onb.name"
        const val GENDER = GENDER_KEY
        const val COUNTRY = "onb.country"
        const val CUSTOM = "onb.customCountry"
        const val STAGE = "onb.stage"
        const val TRACK = "onb.track"
        const val YEAR = "onb.year"
        const val EXAM = "onb.exam"
        const val EXAM_DATE = "onb.examDate"
        const val SUBJECTS = "onb.subjects"
        const val HARDEST = "onb.hardest"
        const val GOAL = "onb.goal"
        const val WORRIES = "onb.worries"
        const val WEEKLY = "onb.weekly"
        const val METHOD = "onb.method"
        const val CURRENT = "onb.current"
        const val TARGET = "onb.target"
        const val DAILY = "onb.daily"
        const val HOUR = "onb.hour"
        const val COMMITTED = "onb.committed"
        const val LESSON = "onb.lesson"
        const val TOPIC = "onb.topic"
        const val CHOSEN = "onb.countryChosen"
    }

    /** Recopie les réponses à chaque changement d'écran : une sortie ne perd que l'écran en cours. */
    fun persist() {
        if (restoring) return
        store.putString(Keys.NAME, displayName.trim().ifEmpty { null })
        store.putString(Keys.GENDER, gender?.name)
        store.putString(Keys.COUNTRY, country)
        store.putString(Keys.CUSTOM, customCountry)
        store.putString(Keys.STAGE, stage?.id)
        store.putString(Keys.TRACK, schoolTrack?.id)
        store.putString(Keys.YEAR, schoolYear?.id)
        store.putString(Keys.EXAM, examChoice?.id)
        store.putString(Keys.EXAM_DATE, if (examChoice?.hasDate == true) examDate?.toString() else null)
        store.putStrings(Keys.SUBJECTS, subjects.toList())
        store.putString(Keys.HARDEST, hardestSubject)
        store.putString(Keys.GOAL, goal?.name)
        store.putStrings(Keys.WORRIES, worriesInOrder.map { it.name })
        store.putString(Keys.WEEKLY, weeklyStudy?.name)
        store.putString(Keys.METHOD, studyMethod?.name)
        store.putString(Keys.CURRENT, currentScore?.toString())
        store.putString(Keys.TARGET, targetScore?.toString())
        store.putString(Keys.DAILY, dailyMinutes?.toString())
        store.putString(Keys.HOUR, studyHour?.toString())
        store.putString(Keys.COMMITTED, if (hasCommitted) "1" else null)
        store.putString(Keys.LESSON, firstLessonChoice?.name)
        store.putString(Keys.TOPIC, firstLessonTopic.ifEmpty { null })
        store.putString(Keys.CHOSEN, if (hasChosenCountry) "1" else null)
    }

    /**
     * **Reprend un parcours interrompu** : les réponses relues ne repartent pas dans les
     * statistiques. Un écran retiré depuis reprend sur celui qui le remplace ; un écran que ce
     * parcours-ci saute, sur le suivant.
     */
    fun resume() {
        val saved = OnboardingStep.restored(store.string(Keys.STEP)) ?: return
        if (saved == OnboardingStep.hookLogo) return
        restoring = true
        try {
            displayName = store.string(Keys.NAME).orEmpty()
            gender = store.string(Keys.GENDER)?.let { name -> StudentGender.entries.firstOrNull { it.name == name } }
            if (store.string(Keys.CHOSEN) != null) {
                hasChosenCountry = true
                country = store.string(Keys.COUNTRY) ?: country
                customCountry = store.string(Keys.CUSTOM)
            }
            schoolTrack = SchoolSystem.track(store.string(Keys.TRACK), regionCode)
            schoolYear = SchoolSystem.year(store.string(Keys.YEAR), schoolTrack)
            val stageId = store.string(Keys.STAGE)
            stage = schoolTrack?.let { EducationStage(it.id, it.title, it.emoji, it.level, it.tier) }
                ?: Countries.genericStages.firstOrNull { it.id == stageId }
            examChoice = SchoolExams.choice(store.string(Keys.EXAM))
            examDate = store.string(Keys.EXAM_DATE)?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
            subjects.clear()
            subjects.addAll(store.strings(Keys.SUBJECTS))
            hardestSubject = store.string(Keys.HARDEST)?.takeIf { it in subjects }
            goal = store.string(Keys.GOAL)?.let { name -> LearningGoal.entries.firstOrNull { it.name == name } }
            worriesInOrder.clear()
            worriesInOrder.addAll(store.strings(Keys.WORRIES).mapNotNull { name -> StudyWorry.entries.firstOrNull { it.name == name } })
            weeklyStudy = store.string(Keys.WEEKLY)?.let { name -> WeeklyStudy.entries.firstOrNull { it.name == name } }
            studyMethod = store.string(Keys.METHOD)?.let { name -> StudyMethod.entries.firstOrNull { it.name == name } }
            currentScore = store.string(Keys.CURRENT)?.toIntOrNull()
            targetScore = store.string(Keys.TARGET)?.toIntOrNull()
            dailyMinutes = store.string(Keys.DAILY)?.toIntOrNull()
            studyHour = store.string(Keys.HOUR)?.toIntOrNull()
            hasCommitted = store.string(Keys.COMMITTED) != null
            firstLessonChoice = store.string(Keys.LESSON)?.let { name -> FirstLessonChoice.entries.firstOrNull { it.name == name } }
            firstLessonTopic = store.string(Keys.TOPIC).orEmpty()

            var target = saved.resumePoint(hasName = displayName.isNotBlank())
            if (target == OnboardingStep.hookLogo) {
                restoring = false
                return
            }
            didSkipAverages = currentScore == null && targetScore == null && target.ordinal > OnboardingStep.currentAverage.ordinal
            while (isSkipped(target)) target = target.next ?: break
            step = target
            isResumed = true
        } finally {
            restoring = false
        }
    }

    companion object {
        /** L'heure du rappel quotidien par défaut (`DailyReminder.defaultHour`). */
        const val DEFAULT_HOUR = 18

        /** Où le genre est gardé : les statistiques le relisent à chaque ouverture (`app_opened`). */
        const val GENDER_KEY = "onb.gender"

        /**
         * **Une liste de noms, en morceaux** (`analyticsList`) : une valeur est coupée à 120
         * signes, dix matières n'y tiennent pas. La liste part sous `key`, puis `key_2`, `key_3`,
         * chaque morceau fait de noms entiers (60 signes au plus) ; la suite est omise.
         */
        fun analyticsList(key: String, names: List<String>): Map<String, Any> {
            val chunks = mutableListOf<String>()
            for (name in names.map { it.take(60) }) {
                val last = chunks.lastOrNull()
                if (last != null && last.length + 1 + name.length <= 120) chunks[chunks.size - 1] = "$last,$name" else chunks.add(name)
            }
            return chunks.take(3).withIndex().associate { (index, chunk) -> (if (index == 0) key else "${key}_${index + 1}") to chunk }
        }

        /** **Les réponses de Lina** (France, Terminale, 45 min, 18 h), pour les rendus et les tests. */
        fun lina(step: OnboardingStep = OnboardingStep.hookLogo, trial: Boolean = true, today: LocalDate = LocalDate.of(2026, 11, 12)): OnboardingModel {
            val model = OnboardingModel(trialOffered = { trial }, deviceLanguages = listOf("fr-FR"), deviceRegion = "FR", today = { today })
            model.displayName = "Lina"
            model.selectCountry("fr")
            model.tracks.firstOrNull { it.id == "fr.lyceeGeneral" }?.let { track ->
                model.chooseTrack(track)
                track.years.firstOrNull { it.id == "fr.terminale" }?.let(model::chooseYear)
            }
            model.examChoices.firstOrNull { it.id == "fr.bac" }?.let(model::chooseExam)
            model.subjects.addAll(listOf("Philosophie", "Histoire-Géographie", "Mathématiques", "Physique-Chimie"))
            model.hardestSubject = "Mathématiques"
            model.goal = LearningGoal.grades
            model.worriesInOrder.addAll(listOf(StudyWorry.forgetting, StudyWorry.examStress))
            model.weeklyStudy = WeeklyStudy.oneToThree
            model.studyMethod = StudyMethod.rereading
            model.currentScore = 12
            model.targetScore = 16
            model.dailyMinutes = 45
            model.studyHour = 18
            model.place(step)
            return model
        }
    }
}
