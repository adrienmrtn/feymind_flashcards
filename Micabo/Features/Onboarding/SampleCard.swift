import Foundation

// MARK: - Les questions

/// **Les questions d'essai, une par grande famille de matières.** La réponse juste est
/// toujours la première des options ; l'ordre d'affichage la place ailleurs.
///
/// Les réponses chiffrées ou symboliques ne se traduisent pas (« π × r² », « H₂O », « 46 »,
/// « 1989 ») ; seules celles de philosophie (des noms propres) ont leur clé, pour leur
/// écriture dans chaque alphabet.
enum SampleCard: String, CaseIterable {
    case math
    case chemistry
    case biology
    case history
    case philosophy

    /// **La seule étude du parcours** : ce qu'il reste d'un cours une semaine après, en se
    /// testant et en le relisant, en pourcentage. Karpicke & Roediger, Science, 2008.
    static let retainedByTesting = 80
    static let retainedByRereading = 36

    /// La matière du catalogue qui porte la question quand l'élève n'en a coché aucune qui
    /// lui corresponde.
    var catalogSubject: String {
        switch self {
        case .math: "Mathématiques"
        case .chemistry: "Chimie"
        case .biology: "SVT"
        case .history: "Histoire"
        case .philosophy: "Philosophie"
        }
    }

    /// La question. Celle d'histoire est la question du mur de Berlin, déjà écrite dans
    /// toutes les langues.
    var questionKey: String {
        self == .history ? "ios.onb.mika.design.question" : "ios.onb7.card.\(rawValue).q"
    }

    /// Les options, la juste en premier.
    private var options: [String] {
        switch self {
        case .math: ["π × r²", "2 × π × r", "π × r"]
        case .chemistry: ["H₂O", "CO₂", "H₂O₂"]
        case .biology: ["46", "23", "48"]
        case .history: ["1989", "1961", "1991"]
        case .philosophy: ["ios.onb7.card.philosophy.a1", "ios.onb7.card.philosophy.a2", "ios.onb7.card.philosophy.a3"]
        }
    }

    /// L'ordre dans lequel les trois options s'affichent : la bonne n'est jamais en tête.
    var displayOrder: [Int] {
        switch self {
        case .math, .history: [1, 0, 2]
        case .chemistry, .philosophy: [2, 0, 1]
        case .biology: [1, 2, 0]
        }
    }

    func isRight(_ option: Int) -> Bool { option == 0 }

    func option(_ index: Int, locale: UiLocale) -> String {
        let value = options[index]
        return value.hasPrefix("ios.") ? L10n.t(value, locale: locale) : value
    }

    /// La question d'une matière, d'après l'emoji que l'app lui donne (`CourseEmoji`) : la
    /// même table que les cours importés, qui connaît les noms dans les langues des systèmes
    /// scolaires décrits.
    static func card(forEmoji emoji: String) -> SampleCard? {
        switch emoji {
        case "📐", "📊": .math
        case "🧪", "⚛️", "🔬", "🔭": .chemistry
        case "🧬", "🌿", "🫀", "🩺", "💊", "🥗", "🦴", "🏥": .biology
        case "🏛️", "🗺️", "🌍", "🗳️": .history
        case "🤔", "👥", "🧠": .philosophy
        default: nil
        }
    }

    struct Pick: Equatable {
        let card: SampleCard
        /// La matière affichée sur la pastille : celle de l'élève, ou celle du catalogue.
        let subject: String
        let emoji: String
    }

    /// **La question d'une matière que l'élève a cochée**, dans l'ordre alphabétique pour que
    /// le choix ne change pas d'un affichage à l'autre. Aucune ne correspond (des langues
    /// vivantes, une matière que la table ne connaît pas) : la question d'histoire, présentée
    /// comme de la culture générale, jamais comme une matière qu'il n'a pas choisie.
    static func pick(for subjects: Set<String>) -> Pick {
        for subject in subjects.sorted() {
            let emoji = SubjectCatalog.emoji(for: subject)
            if let card = card(forEmoji: emoji) {
                return Pick(card: card, subject: subject, emoji: emoji)
            }
        }
        let general = "Culture générale"
        return Pick(card: .history, subject: general, emoji: SubjectCatalog.emoji(for: general))
    }
}
