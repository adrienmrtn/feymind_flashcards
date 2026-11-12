import Observation
import SwiftData
import SwiftUI

/// État partagé du parcours d'accueil. Les réponses sont écrites au fil de l'eau
/// dans `OnboardingPreferences` : quitter l'app en cours de route ne les perd pas, et
/// l'écran atteint non plus (`resuming(in:)`).
///
/// **Une seule pile d'étapes, et aucune attente.** Avancer change l'étape, et c'est tout :
/// la vue du parcours pousse la page (`OnboardingFlowView`). Il n'y a ni temps minimal sur
/// une page, ni appui mis en file : un bouton est actif dès que la réponse est valide.
@Observable
final class OnboardingModel {
    private(set) var step: OnboardingStep = .hookLogo {
        didSet {
            guard !isRestoring else { return }
            OnboardingPreferences.resumeStep = step
        }
    }

    /// **Le sens du dernier changement d'écran.** En avançant, la page arrive par le bord de
    /// fin et l'ancienne part par le bord de début ; au retour, l'inverse. Il est posé avant
    /// l'étape, et lu par la transition au moment où elle se joue (`OnboardingPush`).
    private(set) var isMovingForward = true

    /// **Posé par la vue du parcours** : avec lui, chaque changement d'étape est animé, et un
    /// second appui pendant qu'une page glisse n'en empile pas une troisième. Les tests n'ont
    /// pas de vue : ils avancent librement, sans animation.
    @ObservationIgnored var animatesTransitions = false
    /// L'instant où la page a commencé à glisser ; `nil` une fois posée.
    @ObservationIgnored private var transitionStartedAt: Date?

    /// Vrai quand le parcours reprend là où une app fermée l'avait laissé.
    private(set) var isResumed = false

    /// **Vrai le temps de relire un parcours interrompu.** Les réponses relues ne sont pas
    /// des réponses données : elles ne repartent pas dans les statistiques, et elles ne
    /// réécrivent rien.
    @ObservationIgnored private var isRestoring = false

    init() {
        applyDetectedCountry()
    }

    /// **Le prénom, et rien d'autre.** Il ne sert qu'à s'adresser à quelqu'un. Il ne part
    /// pas au modèle, il ne part pas au serveur.
    var displayName: String = ""

    /// Le palier d'études, dans les termes du pays choisi.
    ///
    /// Le `didSet` marque la réponse plutôt que l'écran : « a vu l'écran du palier » et
    /// « a choisi un palier » sont deux chiffres différents, et c'est leur écart qui dit
    /// qu'une liste de choix ne parle pas.
    var stage: EducationStage? {
        didSet {
            guard let stage, stage != oldValue, !isRestoring else { return }
            Analytics.track(.onboardingAnswer, ["field": "stage", "value": .text(stage.id)])
        }
    }
    private(set) var country: SchoolingCountry = .guessed()
    /// Le pays choisi dans la recherche, quand il n'est pas dans la liste. Il choisit lui
    /// aussi un système scolaire (l'Autriche, le Brésil…) : en changer efface la filière et
    /// l'année, qui appartenaient à l'autre pays.
    var customCountry: WorldCountry? {
        didSet {
            guard customCountry != oldValue, !isRestoring else { return }
            track = nil
            year = nil
            examChoice = nil
            examDate = nil
            if let code = customCountry?.code {
                Analytics.track(.onboardingAnswer, ["field": "customCountry", "value": .text(code)])
            }
        }
    }

    /// Le code ISO du pays de l'élève, celui de la liste ou celui de la recherche.
    var regionCode: String? {
        SchoolRegion.code(country: country, custom: customCountry)
    }

    /// **Ce qui arrive en premier**, choisi dans les examens de son pays et de son année.
    var examChoice: ExamChoice? {
        didSet {
            guard let examChoice, examChoice != oldValue, !isRestoring else { return }
            Analytics.track(.onboardingAnswer, ["field": "exam", "value": .text(examChoice.id)])
        }
    }

    /// Le jour de cet examen : proposé d'après le calendrier du pays, corrigé par l'élève.
    var examDate: Date?

    /// Les examens proposés à cet élève-là (`SchoolExams.choices`).
    var examChoices: [ExamChoice] {
        SchoolExams.choices(track: track, year: year, tier: stage?.tier)
    }

    /// Choisit un examen, et sa date proposée quand l'élève n'en avait pas déjà choisi une
    /// pour lui.
    func choose(exam choice: ExamChoice, now: Date = Date()) {
        guard choice != examChoice else { return }
        examChoice = choice
        examDate = SchoolExams.suggestedDate(for: choice, from: now)
    }

    /// Les jours avant l'examen, quand il y en a un.
    func examDaysLeft(now: Date = Date()) -> Int? {
        guard let examChoice, examChoice.hasDate, let examDate else { return nil }
        return SchoolExams.daysLeft(until: examDate, from: now)
    }

    /// **Le barème que l'élève connaît**, pour les deux moyennes.
    var gradeScale: StudentGradeScale {
        StudentGradeScale.for(region: regionCode, country: country, track: track)
    }

    /// **L'objectif n°1**, choisi à l'écran `goal` parmi ceux de son niveau
    /// (`LearningGoal.offered(for:)`) ; ou, à la reprise, ce qu'un parcours d'avant avait gardé.
    var goals: Set<LearningGoal> = [] {
        didSet {
            guard goals != oldValue, !isRestoring, let first = LearningGoal.allCases.first(where: { goals.contains($0) }) else { return }
            Analytics.track(.onboardingAnswer, ["field": "goal", "value": .text(first.rawValue)])
        }
    }

    /// L'objectif n°1 tel que l'écran le montre : le premier choisi parmi ceux proposés à ce
    /// niveau. Un objectif d'un autre niveau (l'élève est revenu changer de classe) ne
    /// s'affiche pas coché.
    var mainGoal: LearningGoal? {
        LearningGoal.offered(for: stage?.tier).first { goals.contains($0) }
    }

    /// **Pourquoi il apprend** : l'objectif n°1, plus ce que l'examen dit déjà. Un examen daté
    /// ajoute « réviser pour un examen », « rien pour l'instant » ajoute « retenir mes cours ».
    /// C'est ce que le cloud garde (`learning_goals`).
    var learningGoals: Set<LearningGoal> {
        var result = goals
        if let examChoice {
            result.insert(examChoice.hasDate ? .exam : .lectures)
        }
        return result
    }

    var subjects: Set<String> = []

    /// **Ce qui le bloque.** Plusieurs réponses ; `solutionMap` répond aux trois premières
    /// cochées.
    var worries: Set<StudyWorry> = [] {
        didSet {
            guard worries != oldValue else { return }
            // L'ordre coché suit l'ensemble : ce qui est décoché s'en va, ce qui arrive se
            // range à la fin (dans l'ordre de la liste quand plusieurs arrivent d'un coup).
            worriesInOrder.removeAll { !worries.contains($0) }
            for worry in StudyWorry.allCases where worries.contains(worry) && !worriesInOrder.contains(worry) {
                worriesInOrder.append(worry)
            }
            guard !worries.isEmpty, !isRestoring else { return }
            let ids = StudyWorry.allCases.filter { worries.contains($0) }.map(\.rawValue)
            Analytics.track(.onboardingAnswer, ["field": "worries", "value": .text(ids.joined(separator: ","))])
        }
    }

    /// **Les blocages dans l'ordre où ils ont été cochés** : c'est l'ordre des cartes de
    /// `solutionMap`.
    private(set) var worriesInOrder: [StudyWorry] = []

    /// Coche ou décoche un blocage.
    func toggle(worry: StudyWorry) {
        if worries.contains(worry) {
            worries.remove(worry)
        } else {
            worries.insert(worry)
        }
    }

    /// Les blocages auxquels `solutionMap` répond : les trois premiers cochés.
    var answeredWorries: [StudyWorry] {
        Array(worriesInOrder.prefix(StudyWorry.answeredAtMost))
    }

    /// **La filière suivie**, dans les termes du pays. Elle ne se demande qu'aux pays
    /// décrits en détail ; ailleurs, le palier large (`stage`) est tout ce qu'on sait.
    var track: SchoolTrack? {
        didSet {
            guard let track, track != oldValue, !isRestoring else { return }
            // Changer de filière efface l'année : « Terminale » accrochée à « Collège » est
            // une réponse que personne n'a donnée.
            if oldValue != nil {
                year = nil
                examChoice = nil
                examDate = nil
            }
            // Le palier large suit la filière : c'est lui que la fonction Edge reçoit et que
            // le cloud synchronise. Un pays hors liste n'a que l'échelle générique : la
            // filière s'y décrit elle-même plutôt que de rester sans palier.
            stage = country.resolvedStage(id: nil, tier: track.tier, level: track.level)
                ?? EducationStage(id: track.id, title: track.title, emoji: track.emoji, level: track.level, tier: track.tier)
            Analytics.track(.onboardingAnswer, ["field": "track", "value": .text(track.id)])
        }
    }

    /// L'année dans la filière. Elle décide des matières et des examens proposés ensuite.
    var year: SchoolYear? {
        didSet {
            guard let year, year != oldValue, !isRestoring else { return }
            // L'examen appartenait à l'autre année : le brevet ne suit pas en seconde.
            if oldValue != nil {
                examChoice = nil
                examDate = nil
            }
            Analytics.track(.onboardingAnswer, ["field": "year", "value": .text(year.id)])
        }
    }

    /// La moyenne d'aujourd'hui, sur l'échelle 10-20 du produit. `TargetScore.min - 1` veut
    /// dire « en dessous du barème » : c'est le seul cran hors échelle, et il existe parce
    /// qu'un parcours qui ne propose que la moyenne et au-dessus dit à celui qui rame qu'il
    /// n'est pas prévu.
    var currentScore: Int? {
        didSet {
            guard let currentScore, currentScore != oldValue, !isRestoring else { return }
            Analytics.track(.onboardingAnswer, ["field": "currentScore", "value": .number(Double(currentScore))])
        }
    }
    /// La moyenne visée. Jamais en dessous de l'actuelle ; la même, c'est « tenir ».
    var targetScore: Int? {
        didSet {
            guard let targetScore, targetScore != oldValue, !isRestoring else { return }
            Analytics.track(.onboardingAnswer, ["field": "targetScore", "value": .number(Double(targetScore))])
        }
    }

    /// **La moyenne a été passée** (« Passer », en haut de `currentAverage`) : la moyenne
    /// visée ne se demande pas non plus, et la projection se dessine sans chiffres.
    private(set) var didSkipAverages = false

    /// Le temps qu'il se donne par jour, en minutes. C'est de lui que `DailyLoad` tire le
    /// nombre de cartes du plan.
    var dailyMinutes: Int? {
        didSet {
            guard let dailyMinutes, dailyMinutes != oldValue, !isRestoring else { return }
            Analytics.track(.onboardingAnswer, ["field": "dailyMinutes", "value": .number(Double(dailyMinutes))])
        }
    }

    /// **L'heure du rappel quotidien**, de 5 à 23. Elle se règle sur l'écran des rappels.
    var studyHour: Int? {
        didSet {
            guard let studyHour, studyHour != oldValue, !isRestoring else { return }
            Analytics.track(.onboardingAnswer, ["field": "studyHour", "value": .number(Double(studyHour))])
        }
    }

    // MARK: La première leçon

    /// Les deux façons de commencer : un sujet qu'on écrit, ou un cours qu'on a sous la main.
    enum FirstLessonChoice: Equatable {
        case topic
        case importSource
    }

    /// **Par quel cours on commence** (`firstLesson`). `nil` tant que rien n'est choisi, ou
    /// après « Plus tard ».
    var firstLessonChoice: FirstLessonChoice?
    /// Le sujet tel qu'il est tapé. Il reste sur l'appareil : il ne part pas dans les
    /// statistiques.
    var firstLessonTopic: String = ""

    /// Le sujet de la première leçon, quand il y en a un d'écrit.
    var firstLessonSubject: String? {
        firstLessonChoice == .topic ? firstLessonTopic.nilIfBlank : nil
    }

    /// Vrai quand la question a une réponse : un sujet écrit, ou l'import choisi.
    var hasAnsweredFirstLesson: Bool {
        switch firstLessonChoice {
        case .topic: firstLessonTopic.nilIfBlank != nil
        case .importSource: true
        case nil: false
        }
    }

    /// **« Continuer »** sur la première leçon : le choix part à la Home, qui le lancera à la
    /// sortie du parcours (`FirstLessonIntent`). Les statistiques ne gardent que la forme de
    /// la réponse, jamais le sujet.
    func confirmFirstLesson() {
        guard step == .firstLesson, hasAnsweredFirstLesson else { return }
        if let subject = firstLessonSubject {
            FirstLessonIntent.pending = .topic(subject)
            Analytics.track(.onboardingFirstLesson, ["choice": "topic"])
        } else {
            FirstLessonIntent.pending = .importSource
            Analytics.track(.onboardingFirstLesson, ["choice": "import"])
        }
        advance()
    }

    /// **« Plus tard »** : rien n'attend la Home, et le plan n'annonce pas de première leçon.
    func skipFirstLesson() {
        guard step == .firstLesson else { return }
        firstLessonChoice = nil
        FirstLessonIntent.pending = nil
        Analytics.track(.onboardingFirstLesson, ["choice": "later"])
        advance()
    }

    /// Le registre de rédaction, seule forme sous laquelle le niveau sort du parcours.
    var level: StudyLevel? {
        stage?.level
    }

    /// La langue de rédaction : celle de l'app, et elle ne se demande pas séparément.
    var language: ContentLanguage {
        OnboardingPreferences.contentLanguage
    }

    /// Changer de pays change les réponses de la question suivante.
    ///
    /// Le palier déjà choisi est reporté sur son équivalent dans le nouveau pays (sa marche
    /// exacte, sinon la plus proche en montant) et abandonné quand il n'a pas d'équivalent.
    func select(country newCountry: SchoolingCountry) {
        guard newCountry != country else { return }
        let previous = stage
        country = newCountry
        stage = newCountry.resolvedStage(id: nil, tier: previous?.tier, level: previous?.level)
        // La filière et l'année appartiennent à un système scolaire : « Fen Lisesi » n'existe
        // pas en France. Le palier, lui, se reporte.
        track = nil
        examChoice = nil
        examDate = nil
        year = nil
        // Repartir sur un pays de la liste efface celui de la recherche.
        if newCountry != .other { customCountry = nil }
        Analytics.track(.onboardingAnswer, ["field": "country", "value": .text(newCountry.rawValue)])
    }

    /// **Choisit un pays trouvé par la recherche** : un pays de la liste se range sous son
    /// nom de la liste (les États-Unis restent `.us`) ; les autres sous « autre pays », avec
    /// leur code.
    func select(worldCountry: WorldCountry) {
        if let listed = SchoolingCountry.allCases.first(where: { $0.regionCode == worldCountry.code.uppercased() }) {
            select(country: listed)
        } else {
            select(country: .other)
            customCountry = worldCountry
        }
    }

    // MARK: Le pays détecté

    /// **Le pays du téléphone, quand ni ses langues ni la liste courte n'en désignent un**
    /// (un iPhone en arabe réglé sur l'Arabie saoudite, en japonais sur le Japon…). Les
    /// langues décident d'abord (`SchoolingCountry.detected`) ; sans réponse de leur part,
    /// c'est la région du téléphone, et plus la France par défaut.
    static func deviceCountry(
        languages: [String] = Locale.preferredLanguages,
        chosen: String? = UserDefaults.standard.string(forKey: UiLocale.storageKey),
        region: String? = Locale.current.region?.identifier,
        locale: UiLocale = .resolved()
    ) -> WorldCountry? {
        guard SchoolingCountry.detected(languages: languages, chosen: chosen) == nil,
              let code = region?.uppercased(),
              !SchoolingCountry.allCases.contains(where: { $0.regionCode == code })
        else { return nil }
        return WorldCountries.country(code: code, locale: locale)
    }

    /// Pose le pays présélectionné : celui que l'appareil désigne. Ce n'est pas une réponse,
    /// et rien ne part dans les statistiques.
    private func applyDetectedCountry() {
        let wasRestoring = isRestoring
        isRestoring = true
        defer { isRestoring = wasRestoring }
        if let device = Self.deviceCountry() {
            country = .other
            customCountry = device
        } else {
            country = .guessed()
            customCountry = nil
        }
    }

    /// **En quittant les stories** : la langue a pu changer sur le premier écran, et le pays
    /// présélectionné la suit, tant que l'élève n'a pas répondu lui-même.
    func adoptDetectedCountry() {
        guard step == .hookLogo, !OnboardingPreferences.hasChosenCountry else { return }
        applyDetectedCountry()
    }

    /// Vrai quand la question du pays a une réponse complète. « Autre pays » n'en est une
    /// qu'une fois le pays choisi dans la recherche.
    var hasAnsweredCountry: Bool {
        country != .other || customCountry != nil
    }

    /// Les filières proposées, vides quand le pays n'est pas décrit en détail.
    var tracks: [SchoolTrack] {
        SchoolSystem.tracks(for: country, custom: customCountry)
    }

    // MARK: Ce que le plan affiche

    /// Le nombre de cartes par jour que le plan annonce, tiré du temps choisi.
    var cardsPerDay: Int {
        DailyLoad.newCardsPerDay(dailyMinutes: dailyMinutes ?? OnboardingPreferences.dailyMinutes)
    }

    /// Le temps par jour que le plan affiche, en minutes.
    var minutesPerDay: Int {
        dailyMinutes ?? OnboardingPreferences.dailyMinutes
    }

    // MARK: Avancer, revenir

    /// **Les écrans sautés, selon ce qui a été répondu** : la question de niveau que le pays
    /// n'a pas ; la moyenne visée quand la moyenne a été passée ; les deux écrans de l'essai
    /// quand la boutique dit que cet élève n'y a plus droit (on ne promet pas trois jours
    /// qu'Apple ne donnera pas).
    func isSkipped(_ step: OnboardingStep) -> Bool {
        if step.isSkipped(for: country, custom: customCountry) { return true }
        switch step {
        case .targetAverage: return didSkipAverages
        case .freeTrialIntro, .trialOffer: return !OnboardingTrial.isOffered
        default: return false
        }
    }

    /// **La languette du compte**, montée en quittant le plan révélé. Apple, Google, le
    /// courriel, ou « Plus tard » : aucune ne coûte une page au parcours.
    var isAccountSheetPresented = false
    /// Vrai une fois la languette refermée, par une connexion ou par « Plus tard ». Le
    /// retour n'y ramène pas : on ne redemande pas un compte à qui vient de répondre.
    private(set) var didAnswerAccount = false
    /// Vrai quand un compte est déjà ouvert (une session restaurée, un lien de connexion) :
    /// la languette ne monte pas pour rien. Tenu à jour par la vue du parcours.
    var hasAccount = false

    /// La connexion a abouti, ou l'élève a passé : la languette se referme, et le parcours
    /// reprend là où elle l'avait arrêté.
    func finishAccountSheet() {
        didAnswerAccount = true
        isAccountSheetPresented = false
        advance()
    }

    /// Passe à l'écran suivant. Rend vrai quand l'appui est pris (la page avance, ou la
    /// languette du compte monte) et faux quand il est refusé : une page qui glisse encore,
    /// ou plus rien après.
    @discardableResult
    func advance() -> Bool {
        guard !isTransitioning else { return false }
        // Le compte se demande en quittant le plan révélé, juste avant l'offre.
        if step == OnboardingStep.accountStep, !didAnswerAccount, !hasAccount {
            isAccountSheetPresented = true
            return true
        }
        persist()
        var next = step.next
        // Les écrans sans réponse possible se sautent plutôt que de s'afficher vides.
        while let candidate = next, isSkipped(candidate) {
            next = candidate.next
        }
        guard let next else { return false }
        move(to: next, forward: true)
        return true
    }

    /// **« Passer » la moyenne** : ni la moyenne d'aujourd'hui ni celle visée ne sont
    /// gardées, et le parcours continue sur la projection, sans chiffres.
    func skipAverages() {
        guard step == .currentAverage, !isTransitioning else { return }
        currentScore = nil
        targetScore = nil
        didSkipAverages = true
        Analytics.track(.onboardingAnswer, ["field": "averages", "value": "passer"])
        advance()
    }

    /// La moyenne d'aujourd'hui est donnée : celle visée se redemande.
    func answerCurrentAverage() {
        didSkipAverages = false
    }

    /// **Revenir d'un écran.**
    ///
    /// Une réponse donnée doit pouvoir se corriger, et la langue se rechoisir. Le retour
    /// enjambe le chargement (il avance seul : y revenir renverrait aussitôt en avant) et les
    /// écrans sautés à l'aller : on ne fait pas apparaître au retour une question qu'on n'a
    /// pas posée.
    func goBack() {
        guard !isTransitioning, canGoBack, let previous = returnTarget else { return }
        move(to: previous, forward: false)
    }

    /// Vrai quand il y a un écran en arrière qui accepte qu'on y revienne.
    var canGoBack: Bool {
        step.allowsReturn && returnTarget != nil
    }

    /// L'écran où le retour mène : le précédent qui n'est ni sauté ni un chargement.
    private var returnTarget: OnboardingStep? {
        var previous = step.previous
        while let candidate = previous, isSkipped(candidate) || candidate.isLoading {
            previous = candidate.previous
        }
        return previous
    }

    /// **Pose le parcours sur un écran**, sans transition et sans rien écrire : pour les
    /// rendus et les aperçus. Le parcours lui-même n'avance que par `advance` et `goBack`.
    func place(on target: OnboardingStep) {
        let wasRestoring = isRestoring
        isRestoring = true
        step = target
        isRestoring = wasRestoring
    }

    // MARK: Le changement d'étape

    /// Vrai le temps qu'une page glisse. Le filet (huit dixièmes de seconde) ne laisse pas
    /// le parcours verrouillé si la fin de l'animation ne revient jamais.
    private var isTransitioning: Bool {
        guard let started = transitionStartedAt else { return false }
        return Date().timeIntervalSince(started) < 0.8
    }

    /// **Change d'étape.** Avec une vue, sous la courbe standard de l'app (un fondu bref si
    /// le mouvement est réduit) : c'est ce qui fait glisser la page. Le verrou tombe à la fin
    /// de l'animation, pas sur une minuterie.
    private func move(to next: OnboardingStep, forward: Bool) {
        isMovingForward = forward
        guard animatesTransitions else {
            step = next
            return
        }
        transitionStartedAt = Date()
        let curve = MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: UIAccessibility.isReduceMotionEnabled)
        withAnimation(curve, completionCriteria: .logicallyComplete) {
            step = next
        } completion: { [weak self] in
            self?.transitionStartedAt = nil
        }
    }

    /// Recopie les réponses dans les réglages à chaque changement d'écran :
    /// une sortie en cours de route ne perd que la question en cours.
    private func persist() {
        OnboardingPreferences.schoolingCountry = country
        OnboardingPreferences.customCountry = customCountry
        OnboardingPreferences.educationStage = stage
        OnboardingPreferences.goals = learningGoals.map(\.rawValue).sorted()
        OnboardingPreferences.subjects = subjects.sorted()
        OnboardingPreferences.worries = StudyWorry.allCases.filter { worries.contains($0) }.map(\.rawValue)
        OnboardingPreferences.currentScore = currentScore
        OnboardingPreferences.targetScore = targetScore
        OnboardingPreferences.displayName = displayName.nilIfBlank
        OnboardingPreferences.schoolTrackID = track?.id
        OnboardingPreferences.schoolYearID = year?.id
        if let dailyMinutes { OnboardingPreferences.dailyMinutes = dailyMinutes }
        OnboardingPreferences.studyHour = studyHour
        OnboardingPreferences.examID = examChoice?.id
        OnboardingPreferences.examDate = examChoice?.hasDate == true ? examDate : nil
    }
}

// MARK: - La reprise

extension OnboardingModel {
    /// **Le parcours tel qu'une app fermée l'a laissé**, ou un parcours neuf s'il n'y a
    /// rien à reprendre.
    ///
    /// Les réponses sont relues de `OnboardingPreferences`, où `persist()` les écrit à
    /// chaque écran. L'écran de reprise est celui de `OnboardingStep.resumePoint`.
    ///
    /// `OnboardingModel()` reste un parcours neuf : seule la vue du parcours reprend.
    static func resuming(in context: ModelContext?) -> OnboardingModel {
        let model = OnboardingModel()
        guard let saved = OnboardingPreferences.resumeStep, saved != .hookLogo else { return model }

        model.isRestoring = true
        defer { model.isRestoring = false }

        model.restoreAnswers()
        // Qui a passé la connexion ne la revoit pas : `RootView` lit le même drapeau.
        model.didAnswerAccount = UserDefaults.standard.bool(forKey: AccountGate.skippedKey)

        var target = saved.resumePoint(hasName: model.displayName.nilIfBlank != nil)
        guard target != .hookLogo else { return OnboardingModel() }
        // Les moyennes passées se relisent à leur absence, une fois leur écran dépassé.
        model.didSkipAverages = model.currentScore == nil && model.targetScore == nil
            && target.rawValue > OnboardingStep.currentAverage.rawValue
        // Un écran que ce parcours-ci saute (l'autre question de niveau, par exemple) se
        // reprend sur le suivant.
        while model.isSkipped(target), let next = target.next {
            target = next
        }
        model.step = target
        model.isResumed = true
        return model
    }

    private func restoreAnswers() {
        displayName = OnboardingPreferences.displayName ?? ""
        if OnboardingPreferences.hasChosenCountry {
            country = OnboardingPreferences.schoolingCountry
        }
        customCountry = OnboardingPreferences.customCountry
        track = SchoolSystem.track(id: OnboardingPreferences.schoolTrackID, in: country)
        year = SchoolSystem.year(id: OnboardingPreferences.schoolYearID, in: track)
        stage = OnboardingPreferences.educationStage
        goals = Set(OnboardingPreferences.learningGoals)
        subjects = Set(OnboardingPreferences.subjects)
        worries = Set(OnboardingPreferences.worries.compactMap(StudyWorry.init(rawValue:)))
        currentScore = OnboardingPreferences.currentScore
        targetScore = OnboardingPreferences.targetScore
        dailyMinutes = OnboardingPreferences.answeredDailyMinutes
        studyHour = OnboardingPreferences.studyHour
        examChoice = SchoolExams.choice(id: OnboardingPreferences.examID)
        examDate = OnboardingPreferences.examDate
        switch FirstLessonIntent.pending {
        case .topic(let topic):
            firstLessonChoice = .topic
            firstLessonTopic = topic
        case .importSource:
            firstLessonChoice = .importSource
        case nil:
            break
        }
    }
}

// MARK: - L'essai

/// **L'essai gratuit tel que la boutique le propose à cet élève** : sa durée vient du
/// produit, et il ne s'annonce que s'il peut être tenu (`PaywallPlan.hasTrial`).
enum OnboardingTrial {
    /// Les jours offerts par l'offre recommandée.
    static var days: Int { PaywallCatalog.yearly.trialDays }

    /// Vrai tant qu'une offre propose encore l'essai à cet élève. Tant que la boutique n'a
    /// rien dit, on suit le catalogue : c'est le cas d'un premier lancement.
    static var isOffered: Bool {
        PaywallCatalog.yearly.hasTrial || PaywallCatalog.weekly.hasTrial
    }
}

// MARK: - Les réponses du quiz

/// Ce qui le bloque dans ses études. Plusieurs réponses possibles.
///
/// L'ordre de déclaration est l'ordre des rangées.
enum StudyWorry: String, CaseIterable, Identifiable {
    case examStress
    case hardLessons
    case homework
    case forgetting
    case noStart
    case motivation

    var id: String { rawValue }

    /// `solutionMap` répond à trois blocages au plus : un écran, pas une liste.
    static let answeredAtMost = 3

    /// Le libellé de la rangée.
    func title(locale: UiLocale) -> String {
        L10n.t("ios.onb.worry.\(rawValue)", locale: locale)
    }

    /// **La fonctionnalité qui répond à ce blocage**, sur `solutionMap` : son nom.
    func solutionTitle(locale: UiLocale) -> String {
        L10n.t("ios.onb10.solution.\(rawValue).title", locale: locale)
    }

    /// Ce qu'elle fait, en une ligne, dite par Mika.
    func solutionBody(locale: UiLocale) -> String {
        L10n.t("ios.onb10.solution.\(rawValue).body", locale: locale)
    }
}

/// Le temps par jour, en minutes. Quatre crans.
enum OnboardingDailyTime: Int, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case fifteen = 15
    case thirty = 30

    var id: Int { rawValue }

    /// « 5 min · Tranquille » : la durée, puis le mot qui qualifie le cran.
    func title(locale: UiLocale) -> String {
        let minutes = L10n.t("ios.quiz.time.short", locale: locale, vars: ["n": "\(rawValue)"])
        return "\(minutes) · \(L10n.t("ios.onb10.time.\(rawValue)", locale: locale))"
    }
}
