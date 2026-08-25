import Foundation

/// Objectif déclaré à l'inscription. Sert plus tard à ajuster les rappels et les suggestions.
///
/// Un libellé, et rien d'autre. Le sous-titre et l'icône qui accompagnaient chaque objectif
/// ont disparu avec les rangées qui les affichaient : sept lignes à picto et sous-titre font
/// lire des pictogrammes au lieu des réponses.
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

}

/// Où en est l'étudiant dans ses études.
///
/// Une seule réponse, et sept possibilités : c'est la question qui situe tout le reste, et
/// elle est posée juste après l'accroche parce qu'un lycéen et un PASS n'ont ni les mêmes
/// matières, ni les mêmes examens, ni le même rythme.
enum StudyLevel: String, CaseIterable, Identifiable {
    case lycee
    case prepa
    case licence
    case sante
    case master
    case concours
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lycee: "Lycée"
        case .prepa: "Prépa"
        case .licence: "Licence"
        case .sante: "PASS, santé"
        case .master: "Master"
        case .concours: "Concours"
        case .other: "Autre"
        }
    }
}

/// Rapport de l'étudiant à l'oubli.
///
/// Quatre réponses là où il n'y avait qu'un oui et un non. Une question fermée à deux
/// branches sur un sujet aussi personnel force la caricature : celui qui retient bien
/// quand il s'y prend correctement n'est ni « oui, tout le temps » ni « non, ça va », et
/// devant deux cases il choisit celle qui le décrit le moins mal, ce qui ne renseigne
/// personne. Les deux réponses du milieu sont d'ailleurs les plus utiles : elles disent
/// que le problème est la méthode, ce que Micabo apporte.
enum ForgettingHabit: String, CaseIterable, Identifiable {
    case always
    case withMethod
    case sometimes
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .always: "Oui, tout le temps"
        case .withMethod: "Oui, mais quand j'ai les bonnes méthodes je retiens bien"
        case .sometimes: "Non, mais ça m'arrive d'oublier des notions"
        case .never: "Non, jamais"
        }
    }

    /// Ce que la réponse dit en oui ou non, pour le réglage historique.
    var forgetsOften: Bool {
        self == .always || self == .withMethod
    }
}

/// Réponses de l'onboarding, conservées localement pour personnaliser l'app.
enum OnboardingPreferences {
    enum Key {
        static let completed = "micabo.onboarding.completed"
        static let level = "micabo.onboarding.level"
        static let goal = "micabo.onboarding.goal"
        static let goals = "micabo.onboarding.goals"
        static let forgetting = "micabo.onboarding.forgetting"
        static let forgetsOften = "micabo.onboarding.forgetsOften"
        static let subjects = "micabo.onboarding.subjects"
        static let institutionId = "micabo.onboarding.institutionId"
        static let institutionName = "micabo.onboarding.institutionName"
        static let dailyMinutes = "micabo.onboarding.dailyMinutes"
        static let notificationsOptIn = "micabo.onboarding.notificationsOptIn"
        static let completedAt = "micabo.onboarding.completedAt"

        static let all = [
            completed, level, goal, goals, forgetting, forgetsOften, subjects,
            institutionId, institutionName,
            dailyMinutes, notificationsOptIn, completedAt
        ]
    }

    private static var defaults: UserDefaults { .standard }

    static var isCompleted: Bool {
        get { defaults.bool(forKey: Key.completed) }
        set { defaults.set(newValue, forKey: Key.completed) }
    }

    static var level: String? {
        get { defaults.string(forKey: Key.level) }
        set {
            if let newValue, !newValue.isEmpty {
                defaults.set(newValue, forKey: Key.level)
            } else {
                defaults.removeObject(forKey: Key.level)
            }
        }
    }

    static var studyLevel: StudyLevel? {
        level.flatMap(StudyLevel.init(rawValue:))
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

    /// La réponse détaillée à la question de l'oubli.
    static var forgetting: ForgettingHabit? {
        get { defaults.string(forKey: Key.forgetting).flatMap(ForgettingHabit.init(rawValue:)) }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Key.forgetting)
            } else {
                defaults.removeObject(forKey: Key.forgetting)
            }
        }
    }

    /// Le même rapport à l'oubli, en oui ou non. Conservé parce que la clé est déjà posée
    /// sur les appareils qui ont fait le parcours à deux réponses.
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
