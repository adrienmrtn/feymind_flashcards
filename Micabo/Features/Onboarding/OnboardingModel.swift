import Observation
import SwiftUI

/// État partagé du parcours d'accueil. Les réponses sont écrites au fil de l'eau
/// dans `OnboardingPreferences` : quitter l'app en cours de route ne les perd pas.
@Observable
final class OnboardingModel {
    private(set) var step: OnboardingStep = .hookVideo

    /// **Le prénom, et rien d'autre.** Il ne sert qu'à s'adresser à quelqu'un : l'écran
    /// « merci » et l'accueil. Il ne part pas au modèle, il ne part pas au serveur.
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

    // MARK: Les questions du quiz

    /// **D'où il vient.** La réponse ne change rien au plan : elle sert la mesure, et elle
    /// fait lire — c'est la question la plus facile du parcours, posée juste après les
    /// matières pour relancer.
    var source: OnboardingSource? {
        didSet {
            guard let source, source != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "source", "value": .text(source.rawValue)])
        }
    }

    /// A-t-il déjà essayé une app de révision.
    var triedApps: Bool? {
        didSet {
            guard let triedApps, triedApps != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "triedApps", "value": .text(triedApps ? "yes" : "no")])
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

    /// Ce qui le bloque quand il révise.
    var blocker: OnboardingBlocker? {
        didSet {
            guard let blocker, blocker != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "blocker", "value": .text(blocker.rawValue)])
        }
    }

    /// Sa prochaine échéance, en horizon plutôt qu'en date : personne ne connaît la date de
    /// son prochain contrôle au troisième écran d'une app.
    var examHorizon: OnboardingExamHorizon? {
        didSet {
            guard let examHorizon, examHorizon != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "examHorizon", "value": .text(examHorizon.rawValue)])
        }
    }

    /// Comment il révise aujourd'hui.
    var method: OnboardingMethod? {
        didSet {
            guard let method, method != oldValue else { return }
            Analytics.track(.onboardingAnswer, ["field": "method", "value": .text(method.rawValue)])
        }
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

    /// Le nombre de jours avant la prochaine échéance, tel que le plan l'affiche.
    var daysToExam: Int {
        (examHorizon ?? .term).days
    }

    // MARK: Avancer, revenir

    func advance() {
        persist()
        var next = step.next
        // Les écrans sans réponse possible se sautent plutôt que de s'afficher vides : un
        // pays dont on ne connaît que les paliers larges n'a ni filière ni année à proposer.
        while let candidate = next, candidate.isSkipped(for: country) {
            next = candidate.next
        }
        guard let next else { return }
        step = next
    }

    /// **Revenir d'un écran.**
    ///
    /// Une réponse donnée doit pouvoir se corriger : quelqu'un qui se trompe de pays au
    /// premier écran du quiz découvrirait son erreur douze écrans plus tard. On revient
    /// jusqu'au pays, et pas plus loin ; on ne revient pas après le prénom, parce que tout
    /// ce qui suit est un résultat, un compte ou une offre, et que rien de tout ça ne se
    /// défait.
    ///
    /// Les écrans sautés le restent, dans ce sens comme dans l'autre : on ne fait pas
    /// apparaître au retour une question qu'on n'a pas posée à l'aller.
    func goBack() {
        var previous = OnboardingStep(rawValue: step.rawValue - 1)
        while let candidate = previous, candidate.isSkipped(for: country) {
            previous = OnboardingStep(rawValue: candidate.rawValue - 1)
        }
        guard let previous, previous.rawValue >= OnboardingStep.country.rawValue else { return }
        step = previous
    }

    /// Vrai quand il y a un écran en arrière qui accepte qu'on y revienne.
    var canGoBack: Bool {
        step.rawValue > OnboardingStep.country.rawValue
            && step.rawValue <= OnboardingStep.name.rawValue
    }

    /// Recopie les réponses dans les réglages à chaque changement d'écran :
    /// une sortie en cours de route ne perd que la question en cours.
    private func persist() {
        OnboardingPreferences.schoolingCountry = country
        OnboardingPreferences.customCountry = customCountry
        OnboardingPreferences.educationStage = stage
        OnboardingPreferences.goals = goals.map(\.rawValue).sorted()
        OnboardingPreferences.subjects = subjects.sorted()
        OnboardingPreferences.currentScore = currentScore
        OnboardingPreferences.targetScore = targetScore
        OnboardingPreferences.displayName = displayName.nilIfBlank
        OnboardingPreferences.schoolTrackID = track?.id
        OnboardingPreferences.schoolYearID = year?.id
        if let dailyMinutes { OnboardingPreferences.dailyMinutes = dailyMinutes }
        OnboardingPreferences.source = source?.rawValue
        OnboardingPreferences.triedApps = triedApps
        OnboardingPreferences.blocker = blocker?.rawValue
        OnboardingPreferences.examHorizon = examHorizon?.rawValue
        OnboardingPreferences.method = method?.rawValue
    }
}

// MARK: - Les réponses du quiz

/// D'où l'élève a entendu parler de Micabo.
enum OnboardingSource: String, CaseIterable, Identifiable {
    case tiktok
    case instagram
    case youtube
    case friend
    case appStore
    case other

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .tiktok: "🎵"
        case .instagram: "📸"
        case .youtube: "▶️"
        case .friend: "💬"
        case .appStore: "🍎"
        case .other: "✏️"
        }
    }
}

/// Ce qui bloque quand il révise.
enum OnboardingBlocker: String, CaseIterable, Identifiable {
    case forget
    case procrastinate
    case tooMuch
    case noMethod
    case stress

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .forget: "🫠"
        case .procrastinate: "⏳"
        case .tooMuch: "📚"
        case .noMethod: "🧭"
        case .stress: "😰"
        }
    }
}

/// La prochaine échéance, en horizon. `days` est ce que le plan affiche.
enum OnboardingExamHorizon: String, CaseIterable, Identifiable {
    case week
    case month
    case term
    case yearEnd
    case none

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .week: "🔥"
        case .month: "📅"
        case .term: "🗓️"
        case .yearEnd: "🎓"
        case .none: "🧘"
        }
    }

    /// Le compte à rebours affiché sur le plan. Un horizon n'a pas de date : ce sont des
    /// ordres de grandeur, et ils sont écrits pour se lire comme tels.
    var days: Int {
        switch self {
        case .week: 6
        case .month: 24
        case .term: 68
        case .yearEnd: OnboardingExamHorizon.daysToJune
        case .none: 90
        }
    }

    /// Les jours jusqu'au premier juin qui vient : la fin d'année scolaire, pour à peu près
    /// tout le monde dans les pays décrits.
    private static var daysToJune: Int {
        let calendar = MicaboCalendar.shared
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        var components = DateComponents()
        components.year = month >= 6 ? year + 1 : year
        components.month = 6
        components.day = 1
        guard let june = calendar.date(from: components) else { return 180 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: june).day ?? 180
        return max(1, days)
    }
}

/// Comment il révise aujourd'hui.
enum OnboardingMethod: String, CaseIterable, Identifiable {
    case reread
    case rewrite
    case flashcards
    case lastMinute
    case notAtAll

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .reread: "👀"
        case .rewrite: "✍️"
        case .flashcards: "🃏"
        case .lastMinute: "🌙"
        case .notAtAll: "🤷"
        }
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
}
