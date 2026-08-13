import Foundation

/// Objectif déclaré à l'inscription. Sert plus tard à ajuster les rappels et les suggestions.
enum LearningGoal: String, CaseIterable, Identifiable {
    case language
    case exam
    case competition
    case lectures
    case profession
    case curiosity
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .language: "Apprendre une langue"
        case .exam: "Réviser pour un examen"
        case .competition: "Préparer un concours"
        case .lectures: "Retenir mes cours"
        case .profession: "Monter en compétences pour le travail"
        case .curiosity: "Nourrir ma culture générale"
        case .other: "Autre chose"
        }
    }

    var subtitle: String {
        switch self {
        case .language: "Vocabulaire, conjugaison, expressions"
        case .exam: "Bac, partiels, certification"
        case .competition: "Prépa, médecine, fonction publique"
        case .lectures: "Amphis, PDF, prises de notes"
        case .profession: "Process, produits, certifications"
        case .curiosity: "Histoire, sciences, arts"
        case .other: "On s'adapte quand même"
        }
    }

    var systemImage: String {
        switch self {
        case .language: "globe.europe.africa"
        case .exam: "graduationcap"
        case .competition: "flag.checkered"
        case .lectures: "text.book.closed"
        case .profession: "briefcase"
        case .curiosity: "sparkles"
        case .other: "ellipsis.circle"
        }
    }
}

/// Réponses de l'onboarding, conservées localement pour personnaliser l'app.
enum OnboardingPreferences {
    enum Key {
        static let completed = "micabo.onboarding.completed"
        static let goal = "micabo.onboarding.goal"
        static let goals = "micabo.onboarding.goals"
        static let forgetsOften = "micabo.onboarding.forgetsOften"
        static let subjects = "micabo.onboarding.subjects"
        static let institutionId = "micabo.onboarding.institutionId"
        static let institutionName = "micabo.onboarding.institutionName"
        static let dailyMinutes = "micabo.onboarding.dailyMinutes"
        static let notificationsOptIn = "micabo.onboarding.notificationsOptIn"
        static let completedAt = "micabo.onboarding.completedAt"

        static let all = [
            completed, goal, goals, forgetsOften, subjects,
            institutionId, institutionName,
            dailyMinutes, notificationsOptIn, completedAt
        ]
    }

    private static var defaults: UserDefaults { .standard }

    static var isCompleted: Bool {
        get { defaults.bool(forKey: Key.completed) }
        set { defaults.set(newValue, forKey: Key.completed) }
    }

    /// Objectifs déclarés. Une seule réponse était possible auparavant : la clé
    /// historique est relue tant que la nouvelle n'a pas été écrite.
    static var goals: [String] {
        get {
            if let stored = defaults.stringArray(forKey: Key.goals) { return stored }
            return defaults.string(forKey: Key.goal).map { [$0] } ?? []
        }
        set { defaults.set(newValue, forKey: Key.goals) }
    }

    static var learningGoals: [LearningGoal] {
        goals.compactMap(LearningGoal.init(rawValue:))
    }

    static var forgetsOften: Bool? {
        get {
            guard defaults.object(forKey: Key.forgetsOften) != nil else { return nil }
            return defaults.bool(forKey: Key.forgetsOften)
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.forgetsOften)
            } else {
                defaults.removeObject(forKey: Key.forgetsOften)
            }
        }
    }

    static var subjects: [String] {
        get { defaults.stringArray(forKey: Key.subjects) ?? [] }
        set { defaults.set(newValue, forKey: Key.subjects) }
    }

    static var institutionId: String? {
        get { defaults.string(forKey: Key.institutionId) }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: Key.institutionId)
            } else {
                defaults.removeObject(forKey: Key.institutionId)
            }
        }
    }

    static var institutionName: String? {
        get { defaults.string(forKey: Key.institutionName) }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: Key.institutionName)
            } else {
                defaults.removeObject(forKey: Key.institutionName)
            }
        }
    }

    /// Objectif quotidien en minutes. 15 minutes par défaut, comme le curseur.
    static var dailyMinutes: Int {
        get {
            let stored = defaults.integer(forKey: Key.dailyMinutes)
            return stored == 0 ? 15 : stored
        }
        set { defaults.set(newValue, forKey: Key.dailyMinutes) }
    }

    static var notificationsOptIn: Bool {
        get { defaults.bool(forKey: Key.notificationsOptIn) }
        set { defaults.set(newValue, forKey: Key.notificationsOptIn) }
    }

    static func markCompleted() {
        defaults.set(Date(), forKey: Key.completedAt)
        isCompleted = true
    }

    /// Remet le parcours à zéro (bouton de test dans les réglages).
    static func reset() {
        Key.all.forEach(defaults.removeObject(forKey:))
    }
}
