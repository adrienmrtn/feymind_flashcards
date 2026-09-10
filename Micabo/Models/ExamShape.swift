import Foundation

/// **Ce qu'une épreuve est, et d'où l'on part dessus.**
///
/// Deux réglages que le site demande à la création d'un plan et que le téléphone ne demandait
/// pas : le **type** d'épreuve et le **point de départ**. Ils vivent ici plutôt que sur `Exam`
/// parce que ce sont des vocabulaires partagés avec le noyau (`srs/term.ts`), pas des
/// propriétés d'un modèle : la même chaîne voyage jusqu'à `exams.kind` et
/// `exams.starting_point`, et les deux plateformes doivent la lire pareil.

/// Le type d'épreuve. **Il ne change pas la replanification** : il décide des formats proposés
/// et de l'existence d'un examen blanc - on ne s'entraîne pas à un oral avec un QCM.
enum ExamKind: String, CaseIterable, Identifiable, Codable {
    case exam
    case midterm
    case final
    case quiz
    case oral
    case mock

    var id: String { rawValue }

    static func from(_ raw: String?) -> ExamKind {
        guard let raw, let kind = ExamKind(rawValue: raw) else { return .exam }
        return kind
    }

    func title(locale: UiLocale = .resolved()) -> String {
        L10n.t("app.plan.kind.\(rawValue)", locale: locale)
    }

    /// Vrai quand un examen blanc a du sens. **L'oral en est le seul exclu** : on ne s'entraîne
    /// pas à parler devant un jury avec vingt questions écrites, et lui en poser prendrait du
    /// temps de révision pour ne rien mesurer d'utile. C'est la règle de `wantsMock` côté
    /// noyau, à la lettre.
    var wantsMock: Bool { self != .oral }
}

/// **D'où l'on part sur ce programme.**
///
/// Micabo ne voit que ce qui a été travaillé *dans l'app* ; il ne sait rien d'un cours suivi en
/// amphi toute l'année. Deux étudiants avec les mêmes cartes neuves peuvent être à des
/// distances très différentes de leur épreuve, et c'est la seule chose que l'app ne peut pas
/// deviner.
enum ExamStartingPoint: String, CaseIterable, Identifiable, Codable {
    /// Le cours est nouveau.
    case cold
    /// Suivi sans être retravaillé. Le rythme normal.
    case seen
    /// Déjà su, à entretenir.
    case solid

    var id: String { rawValue }

    static func from(_ raw: String?) -> ExamStartingPoint {
        guard let raw, let point = ExamStartingPoint(rawValue: raw) else { return .seen }
        return point
    }

    func title(locale: UiLocale = .resolved()) -> String {
        L10n.t("app.newPlan.start.\(rawValue)", locale: locale)
    }

    func detail(locale: UiLocale = .resolved()) -> String {
        L10n.t("app.newPlan.startDetail.\(rawValue)", locale: locale)
    }

    var emoji: String {
        switch self {
        case .cold: "🌱"
        case .seen: "📖"
        case .solid: "💪"
        }
    }

    /// **L'intensité corrigée du point de départ.**
    ///
    /// Découvrir un programme demande un passage de plus par carte, le réviser un de moins. On
    /// décale l'intensité plutôt que d'ajouter un paramètre à l'échelle : c'est la même
    /// grandeur - combien de fois chaque carte repasse - et un second réglage qui dit la même
    /// chose finirait par la contredire. C'est `intensityFor` du noyau, mot pour mot.
    func intensity(from intensity: ExamIntensity) -> ExamIntensity {
        let ladder: [ExamIntensity] = [.light, .standard, .intense]
        guard let index = ladder.firstIndex(of: intensity) else { return intensity }
        let shift = self == .cold ? 1 : self == .solid ? -1 : 0
        return ladder[max(0, min(ladder.count - 1, index + shift))]
    }
}
