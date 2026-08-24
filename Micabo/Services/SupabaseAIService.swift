import Foundation

/// Appelle les Edge Functions Supabase, qui relaient vers fal.ai.
/// La clé fal reste côté serveur : l'application n'envoie que la clé publique Supabase.
struct SupabaseAIService: AIService {
    var functions = SupabaseFunctions.shared

    // MARK: - Cours

    func generateCourse(_ request: CourseGenerationRequest) async throws -> GeneratedCourse {
        let trimmed = request.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 40 || !request.pageImages.isEmpty else {
            throw AIServiceError.emptySource
        }

        let payload: [String: Any] = [
            "text": String(trimmed.prefix(60_000)),
            "images": request.pageImages.map { "data:image/jpeg;base64," + $0.base64EncodedString() },
            "hintTitle": request.hintTitle ?? "",
            "sourceName": request.sourceName ?? "",
            "model": AppConfig.aiModel
        ]

        let envelope = try await post("generate-course", payload: payload)
        return try decode(GeneratedCourse.self, from: envelope, key: "course")
    }

    // MARK: - Flashcards

    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] {
        let payload: [String: Any] = [
            "title": request.courseTitle,
            "context": String(request.courseContext.prefix(40_000)),
            "count": request.desiredCount,
            "existing": request.existingFronts,
            "kinds": request.mix.wireValues,
            "model": AppConfig.aiModel
        ]

        let envelope = try await post("generate-flashcards", payload: payload)
        return try decode([GeneratedFlashcard].self, from: envelope, key: "cards")
    }

    // MARK: - Explication d'un passage

    func explain(_ request: SelectionExplanationRequest) async throws -> SelectionExplanation {
        let selection = request.selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard selection.count >= SheetSelection.minimumCharacters else {
            throw AIServiceError.emptySource
        }

        let payload: [String: Any] = [
            "selection": String(selection.prefix(SheetSelection.maximumCharacters)),
            "title": request.courseTitle,
            "subject": request.subject ?? "",
            "context": String(request.courseContext.prefix(16_000)),
            "model": AppConfig.aiModel
        ]

        let envelope = try await post("explain-selection", payload: payload)
        let explanation = try decode(SelectionExplanation.self, from: envelope, key: "explanation")
        guard explanation.isUsable else { throw AIServiceError.invalidResponse }
        return explanation
    }

    // MARK: - Transport

    private func post(_ function: String, payload: [String: Any]) async throws -> [String: Any] {
        do {
            return try await functions.post(function, payload: payload)
        } catch let error as SupabaseFunctionError {
            throw AIServiceError(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from envelope: [String: Any], key: String) throws -> T {
        do {
            return try functions.decode(type, from: envelope, key: key)
        } catch {
            throw AIServiceError.invalidResponse
        }
    }
}

extension AIServiceError {
    /// Traduit une panne de transport dans les termes de l'IA. Les deux cas nommés,
    /// la clé fal manquante et la clé Supabase refusée, méritent une phrase à eux : ce
    /// sont des erreurs de configuration, et l'utilisateur peut les corriger lui-même.
    init(_ error: SupabaseFunctionError) {
        switch error {
        case .notConfigured:
            self = .notConfigured
        case .network(let detail):
            self = .network(detail)
        case .invalidResponse:
            self = .invalidResponse
        case .server(let status, let message, _):
            if message.localizedCaseInsensitiveContains("FAL_KEY") {
                self = .missingProviderKey
            } else if status == 401 || status == 403 {
                self = .server("Clé Supabase refusée (\(status)). Vérifie la clé publique dans Réglages.")
            } else if status == 404 {
                self = .server("Fonction Supabase introuvable. Déployez les Edge Functions du dossier supabase/functions.")
            } else if message.isEmpty {
                self = .server("Le serveur a répondu \(status).")
            } else {
                self = .server(message)
            }
        }
    }
}
