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
}

struct ExplainRequest {
    var selection: String
    var courseTitle: String
    var courseContext: String
    /// Angle demandé par l'étudiant (explication simple, exemple, etc.).
    var angle: ExplainAngle
}

enum ExplainAngle: String, CaseIterable, Identifiable {
    case explain
    case simpler
    case example
    case why

    var id: String { rawValue }

    var label: String {
        switch self {
        case .explain: "Expliquer"
        case .simpler: "Plus simple"
        case .example: "Un exemple"
        case .why: "Pourquoi ?"
        }
    }

    var systemImage: String {
        switch self {
        case .explain: "sparkles"
        case .simpler: "figure.child"
        case .example: "list.bullet.rectangle"
        case .why: "questionmark.circle"
        }
    }
}

struct GeneratedFlashcard: Codable, Hashable {
    var front: String
    var back: String
    var hint: String?
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
            "La réponse de l'IA n'a pas pu être lue. Réessayez."
        case .missingProviderKey:
            "La clé fal.ai est absente côté Supabase. Ajoutez le secret FAL_KEY à votre projet."
        }
    }
}

protocol AIService {
    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse
    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard]
    func explain(_ request: ExplainRequest) async throws -> String
    func generatePodcast(_ request: PodcastGenerationRequest) async throws -> GeneratedPodcast
}
