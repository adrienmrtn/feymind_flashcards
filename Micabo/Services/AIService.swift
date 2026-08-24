import Foundation

struct CourseGenerationRequest {
    var rawText: String
    /// Pages rendues en JPEG (base64) pour que le modèle lise schémas et figures.
    var pageImages: [Data]
    var hintTitle: String?
    var sourceName: String?
}

struct FlashcardGenerationRequest {
    var courseTitle: String
    var courseContext: String
    var desiredCount: Int
    var existingFronts: [String]
    var mix: QuestionMix = .default
}

/// Un passage de la fiche que l'utilisateur a sélectionné et veut comprendre.
///
/// Le passage seul ne suffit pas : « la Rubisco » n'a de sens que dans son cours. On envoie
/// donc aussi le contexte, et le modèle répond en s'appuyant dessus au lieu de réciter une
/// définition d'encyclopédie.
struct SelectionExplanationRequest {
    var selection: String
    var courseTitle: String
    var subject: String?
    var courseContext: String
}

/// Ce que l'IA renvoie sur un passage sélectionné.
///
/// La réponse est découpée, et pas rendue en un bloc de texte, pour une raison
/// d'affichage : `headline` est ce qu'on lit en premier et doit répondre seule, `body`
/// développe, et les deux derniers champs n'apparaissent que s'ils apportent quelque
/// chose. Le texte porte le balisage de la fiche, donc du gras et du surlignage.
struct SelectionExplanation: Codable, Equatable {
    /// Une phrase qui répond, sans préambule.
    var headline: String
    /// Deux à quatre phrases qui développent.
    var body: String
    /// Un exemple concret, s'il éclaire vraiment.
    var example: String?
    /// La confusion classique sur ce point.
    var watchOut: String?
    /// Une carte prête à être ajoutée au cours, pour ne pas reperdre ce qu'on vient de
    /// comprendre.
    var card: GeneratedFlashcard?

    var isUsable: Bool {
        !headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Formats de questions autorisés pour une génération.
///
/// Le recto verso est toujours là : c'est le format qui marche pour n'importe quel
/// cours. Les deux autres viennent en plus, et l'utilisateur les coupe au moment de
/// lancer la génération s'il ne veut que des cartes classiques.
struct QuestionMix: Equatable {
    var includesCloze: Bool
    var includesChoice: Bool

    static let `default` = QuestionMix(includesCloze: true, includesChoice: true)
    static let basicOnly = QuestionMix(includesCloze: false, includesChoice: false)

    var kinds: [CardKind] {
        var result: [CardKind] = [.basic]
        if includesCloze { result.append(.cloze) }
        if includesChoice { result.append(.choice) }
        return result
    }

    var wireValues: [String] {
        kinds.map(\.rawValue)
    }
}

/// Les réglages de génération, retenus d'un cours à l'autre : personne n'a envie de les
/// refaire à chaque fois.
enum QuestionMixPreferences {
    enum Key {
        static let cloze = "micabo.generation.cloze"
        static let choice = "micabo.generation.choice"
        static let count = "micabo.generation.count"
    }

    /// Absent vaut activé : un nouvel utilisateur doit voir les trois formats avant de
    /// décider d'en couper.
    static var current: QuestionMix {
        let defaults = UserDefaults.standard
        return QuestionMix(
            includesCloze: defaults.object(forKey: Key.cloze) as? Bool ?? true,
            includesChoice: defaults.object(forKey: Key.choice) as? Bool ?? true
        )
    }

    /// Volumes proposés. Douze cartes est le défaut : de quoi couvrir un chapitre sans
    /// transformer la première session en épreuve d'endurance.
    static let countChoices = [8, 12, 20]
    static let defaultCount = 12

    static var count: Int {
        let stored = UserDefaults.standard.object(forKey: Key.count) as? Int
        guard let stored, countChoices.contains(stored) else { return defaultCount }
        return stored
    }
}

struct GeneratedFlashcard: Codable, Hashable {
    var front: String
    var back: String
    var hint: String? = nil
    /// Format annoncé par le modèle : « basic », « cloze » ou « choice ». Absent vaut
    /// recto verso.
    var kind: String? = nil
    /// Propositions d'un QCM, dans l'ordre d'affichage.
    var choices: [String]? = nil
    /// Index de la bonne proposition dans `choices`.
    var answerIndex: Int? = nil

    /// Format retenu côté app. Une occlusion ne se génère pas depuis du texte : elle se
    /// dessine sur une image, donc on la refuse ici.
    var resolvedKind: CardKind {
        guard let kind, let parsed = CardKind(rawValue: kind), parsed != .occlusion else {
            return .basic
        }
        return parsed
    }
}

enum AIServiceError: LocalizedError {
    case notConfigured
    case emptySource
    case network(String)
    case server(String)
    case invalidResponse
    case missingProviderKey

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "L'accès à l'IA n'est pas configuré. Renseignez l'URL Supabase dans Profil, Réglages."
        case .emptySource:
            "Il n'y a pas assez de texte à analyser."
        case .network(let message):
            "Connexion impossible. \(message)"
        case .server(let message):
            message
        case .invalidResponse:
            "La réponse de l'IA n'a pas pu être lue. Réessaie."
        case .missingProviderKey:
            "La clé fal.ai est absente côté Supabase. Ajoute le secret FAL_KEY à ton projet."
        }
    }
}

protocol AIService {
    /// Analyse un import et en écrit la fiche.
    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse
    /// Écrit des cartes à partir d'un cours déjà fiché.
    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard]
    /// Explique un passage sélectionné dans la fiche.
    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation
}
