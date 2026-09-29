import Observation
import SwiftUI

/// État partagé du parcours d'accueil. Les réponses sont écrites au fil de l'eau
/// dans `OnboardingPreferences` : quitter l'app en cours de route ne les perd pas.
@Observable
final class OnboardingModel {
    private(set) var step: OnboardingStep = .hookLogo

    /// **Vrai le temps qu'une page glisse.** Posé par la vue du parcours, relu par
    /// `advance()` : un second appui pendant le glissement n'empile pas deux pages. Les
    /// tests n'ont pas de vue, donc pas de verrou, et avancent librement.
    var transitionLock = false

    /// **Le prénom, et rien d'autre.** Il ne sert qu'à s'adresser à quelqu'un : la
    /// bienvenue, le bravo, l'accueil. Il ne part pas au modèle, il ne part pas au serveur.
    var displayName: String = ""

    /// Le palier d'études, dans les termes du pays choisi. Il n'est proposé qu'après le
    /// pays, faute de quoi il n'y aurait rien de juste à proposer.
    ///
    /// Le `didSet` marque la réponse plutôt que l'écran : « a vu l'écran du palier » et
    /// « a choisi un palier » sont deux chiffres différents, et c'est leur écart qui dit
    /// qu'une liste de choix ne parle pas.
    var stage: EducationStage? {
        didSet {
            guard let stage, stage != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "stage", "value": .text(stage.id)])
        }
    }
    private(set) var country: SchoolingCountry = .guessed()
    /// Le pays nommé à la main, quand la réponse est « Autre pays ». Il n'a de sens que dans
    /// ce cas-là, et il est effacé dès qu'on revient sur une pastille.
    var customCountry: WorldCountry?
    var goals: Set<LearningGoal> = []
    var subjects: Set<String> = []

    /// **Ce qui l'inquiète dans ses études.** Plusieurs réponses ; la première, dans l'ordre
    /// de la liste, donne son titre à l'écran « on s'en occupe ».
    var worries: Set<StudyWorry> = [] {
        didSet {
            guard worries != oldValue, !worries.isEmpty else { return }
            let ids = StudyWorry.allCases.filter { worries.contains($0) }.map(\.rawValue)
            Analytics.track(.onboardingAnswer, ["field": "worries", "value": .text(ids.joined(separator: ","))])
        }
    }

    /// L'inquiétude mise en avant : la première cochée, dans l'ordre de la liste.
    var leadWorry: StudyWorry? {
        StudyWorry.allCases.first { worries.contains($0) }
    }

    /// **La filière suivie**, dans les termes du pays. Elle ne se demande qu'aux pays
    /// décrits en détail ; ailleurs, le palier large (`stage`) est tout ce qu'on sait.
    var track: SchoolTrack? {
        didSet {
            guard let track, track != oldValue else { return }
            // Changer de filière efface l'année : « Terminale » accrochée à « Collège » est
            // une réponse que personne n'a donnée.
            if oldValue != nil { year = nil }
            // Le palier large suit la filière : c'est lui que la fonction Edge reçoit et que
            // le cloud synchronise, et il ne doit pas rester sur la réponse d'avant.
            stage = country.resolvedStage(id: nil, tier: track.tier, level: track.level)
            Analytics.track(.onboardingAnswer, ["field": "track", "value": .text(track.id)])
        }
    }

    /// L'année dans la filière. Elle décide des matières proposées deux écrans plus loin.
    var year: SchoolYear? {
        didSet {
            guard let year, year != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "year", "value": .text(year.id)])
        }
    }
    /// La moyenne d'aujourd'hui, sur l'échelle 10-20. `TargetScore.min - 1` veut dire « en
    /// dessous du barème » : c'est le seul cran hors échelle, et il existe parce qu'un
    /// parcours qui ne propose que la moyenne et au-dessus dit à celui qui rame qu'il n'est
    /// pas prévu.
    var currentScore: Int? {
        didSet {
            guard let currentScore, currentScore != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "currentScore", "value": .number(Double(currentScore))])
        }
    }
    /// La moyenne visée. Toujours au-dessus de l'actuelle.
    var targetScore: Int? {
        didSet {
            guard let targetScore, targetScore != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "targetScore", "value": .number(Double(targetScore))])
        }
    }

    /// Le temps qu'il se donne par jour, en minutes. C'est de lui que `DailyLoad` tire le
    /// nombre de cartes du plan.
    var dailyMinutes: Int? {
        didSet {
            guard let dailyMinutes, dailyMinutes != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "dailyMinutes", "value": .number(Double(dailyMinutes))])
        }
    }

    /// **L'heure à laquelle il révise**, de 5 à 23. C'est l'heure du rappel quotidien, et
    /// elle se règle au curseur, le soleil qui monte et descend avec elle.
    var studyHour: Int? {
        didSet {
            guard let studyHour, studyHour != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "studyHour", "value": .number(Double(studyHour))])
        }
    }

    // MARK: Le cours

    /// **A-t-il ses supports ?** La seule branche du parcours : oui mène aux cases de
    /// dépôt, non au choix d'un cours de démonstration. Sans réponse, les deux se sautent.
    var hasMaterials: Bool? {
        didSet {
            guard let hasMaterials, hasMaterials != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "hasMaterials", "value": .flag(hasMaterials)])
        }
    }

    /// Vrai quand le cours qu'on montre est le cours de démonstration, et non les supports
    /// de l'élève : les trois cartes d'entraînement viennent alors du jeu embarqué.
    var isDemoCourse: Bool {
        hasMaterials == false
    }

    /// Le registre de rédaction, seule forme sous laquelle le niveau sort du parcours.
    var level: StudyLevel? {
        stage?.level
    }

    /// La langue de rédaction : celle du pays, et elle ne se demande pas séparément.
    var language: ContentLanguage {
        country.language
    }

    /// Changer de pays change les réponses de la question suivante.
    ///
    /// Le palier déjà choisi est reporté sur son équivalent dans le nouveau pays — sa marche
    /// exacte, sinon la plus proche en montant — et abandonné quand il n'a pas d'équivalent :
    /// garder « PASS » après un passage aux États-Unis laisserait affichée une réponse qui
    /// n'existe pas dans la liste.
    func select(country newCountry: SchoolingCountry) {
        guard newCountry != country else { return }
        let previous = stage
        country = newCountry
        stage = newCountry.resolvedStage(id: nil, tier: previous?.tier, level: previous?.level)
        // La filière et l'année appartiennent à un système scolaire : « Fen Lisesi » n'existe
        // pas en France, et la garder afficherait une réponse introuvable dans la liste. Le
        // palier, lui, se reporte — c'est tout l'objet de `resolvedStage`.
        track = nil
        year = nil
        // Repartir sur une pastille efface le pays tapé à la main : le garder ferait dire à
        // l'écran « France » et « Brésil » en même temps.
        if newCountry != .other { customCountry = nil }
        Analytics.track(.onboardingAnswer, ["field": "country", "value": .text(newCountry.rawValue)])
    }

    /// Vrai quand la question du pays a une réponse complète. « Autre pays » n'en est une
    /// qu'une fois le pays choisi dans la liste : sans ça, on avance sur un « ailleurs » qui
    /// ne dit rien de plus que le silence.
    var hasAnsweredCountry: Bool {
        country != .other || customCountry != nil
    }

    /// Les filières proposées, vides quand le pays n'est pas décrit en détail.
    var tracks: [SchoolTrack] {
        SchoolSystem.tracks(for: country)
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

    private func isSkipped(_ step: OnboardingStep) -> Bool {
        step.isSkipped(for: country, hasMaterials: hasMaterials)
    }

    func advance() {
        guard !transitionLock else { return }
        persist()
        var next = step.next
        // Les écrans sans réponse possible se sautent plutôt que de s'afficher vides : un
        // pays dont on ne connaît que les paliers larges n'a ni filière ni année à proposer.
        while let candidate = next, isSkipped(candidate) {
            next = candidate.next
        }
        guard let next else { return }
        step = next
    }

    /// **Revenir d'un écran.**
    ///
    /// Une réponse donnée doit pouvoir se corriger : quelqu'un qui se trompe de pays au
    /// premier écran du quiz découvrirait son erreur douze écrans plus tard. On revient
    /// jusqu'au pays, et pas plus loin ; on ne revient plus après les rappels, parce que
    /// tout ce qui suit est un résultat, une démonstration, un compte ou une offre, et que
    /// rien de tout ça ne se défait.
    ///
    /// Les écrans sautés le restent, dans ce sens comme dans l'autre : on ne fait pas
    /// apparaître au retour une question qu'on n'a pas posée à l'aller.
    func goBack() {
        guard !transitionLock, canGoBack else { return }
        var previous = step.previous
        while let candidate = previous, isSkipped(candidate) {
            previous = candidate.previous
        }
        guard let previous, previous.rawValue >= OnboardingStep.firstReturnable.rawValue else { return }
        step = previous
    }

    /// Vrai quand il y a un écran en arrière qui accepte qu'on y revienne.
    var canGoBack: Bool {
        step.rawValue > OnboardingStep.firstReturnable.rawValue
            && step.rawValue <= OnboardingStep.lastReturnable.rawValue
    }

    /// Recopie les réponses dans les réglages à chaque changement d'écran :
    /// une sortie en cours de route ne perd que la question en cours.
    private func persist() {
        OnboardingPreferences.schoolingCountry = country
        OnboardingPreferences.customCountry = customCountry
        OnboardingPreferences.educationStage = stage
        OnboardingPreferences.goals = goals.map(\.rawValue).sorted()
        OnboardingPreferences.subjects = subjects.sorted()
        OnboardingPreferences.worries = StudyWorry.allCases.filter { worries.contains($0) }.map(\.rawValue)
        OnboardingPreferences.currentScore = currentScore
        OnboardingPreferences.targetScore = targetScore
        OnboardingPreferences.displayName = displayName.nilIfBlank
        OnboardingPreferences.schoolTrackID = track?.id
        OnboardingPreferences.schoolYearID = year?.id
        if let dailyMinutes { OnboardingPreferences.dailyMinutes = dailyMinutes }
        OnboardingPreferences.studyHour = studyHour
    }
}

// MARK: - Les réponses du quiz

/// Ce qui l'inquiète dans ses études. Plusieurs réponses possibles.
///
/// L'ordre de déclaration est l'ordre des rangées, et c'est lui qui choisit l'inquiétude
/// mise en avant sur l'écran suivant quand plusieurs sont cochées.
enum StudyWorry: String, CaseIterable, Identifiable {
    case examStress
    case hardLessons
    case homework
    case forgetting
    case noStart
    case motivation

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .examStress: "😰"
        case .hardLessons: "🤯"
        case .homework: "⏳"
        case .forgetting: "🫥"
        case .noStart: "🧭"
        case .motivation: "🔋"
        }
    }

    /// Le libellé de la rangée.
    func title(locale: UiLocale) -> String {
        L10n.t("ios.onb.worry.\(rawValue)", locale: locale)
    }

    /// **La forme courte**, pour le titre de « on s'en occupe » : « Le stress des examens ?
    /// On s'en occupe. » La rangée entière y serait trop longue.
    func echo(locale: UiLocale) -> String {
        L10n.t("ios.onb.worry.\(rawValue).echo", locale: locale)
    }
}

/// Le temps par jour, en minutes. Quatre crans, et le nombre de cartes qui va avec.
enum OnboardingDailyTime: Int, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case fifteen = 15
    case thirty = 30

    var id: Int { rawValue }

    var emoji: String {
        switch self {
        case .five: "☕️"
        case .ten: "🚌"
        case .fifteen: "📖"
        case .thirty: "🎯"
        }
    }

    /// Le mot qui qualifie le cran, sous la courbe : « un bon début » jusqu'à « énorme ».
    func caption(locale: UiLocale) -> String {
        L10n.t("ios.quiz.time.caption.\(rawValue)", locale: locale)
    }
}
