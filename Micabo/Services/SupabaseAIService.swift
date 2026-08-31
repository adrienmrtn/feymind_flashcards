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

        // Le stade d'étude et la longueur partent en clair : c'est la fonction qui sait les
        // traduire en consignes. Deux formulations, une ici et une là, finiraient par se
        // contredire, et celle du serveur est la seule qu'on peut corriger sans mise à jour.
        let payload: [String: Any] = [
            "text": String(trimmed.prefix(60_000)),
            "images": request.pageImages.map { "data:image/jpeg;base64," + $0.base64EncodedString() },
            "hintTitle": request.hintTitle ?? "",
            "sourceName": request.sourceName ?? "",
            "level": request.studyLevel?.rawValue ?? "",
            "country": request.country?.rawValue ?? "",
            "language": request.language?.rawValue ?? "source",
            "length": request.sheetLength.rawValue,
            "blocks": request.sheetBlocks,
            "subject": request.subject ?? "",
            "source": request.sourceKind?.rawValue ?? ""
        ]

        let envelope = try await post("generate-course", payload: payload)
        return try decode(GeneratedCourse.self, from: envelope, key: "course")
    }

    // MARK: - Flashcards

    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] {
        // `count` et `kinds` restent envoyés en plus du quota : une fonction déployée avant
        // les quotas les comprend encore, et produira le bon volume à défaut du bon détail.
        let payload: [String: Any] = [
            "title": request.courseTitle,
            "context": String(request.courseContext.prefix(40_000)),
            "count": request.quota.total,
            "quota": request.quota.wireCounts,
            "existing": request.existingFronts,
            "kinds": request.quota.wireKinds,
            "subject": request.subject ?? "",
            "language": request.language.rawValue
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
            "language": request.language.rawValue
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
            } else if Self.isParserJargon(message) {
                self = .server("L'écriture a échoué. Réessaie, rien n'a été perdu.")
            } else {
                self = .server(message)
            }
        }
    }

    /// Le parseur JSON parle à un développeur. L'étudiant n'a pas à lire
    /// « after array element at position 25458 ».
    private static func isParserJargon(_ message: String) -> Bool {
        let lower = message.lowercased()
        if lower.contains("json") { return true }
        if lower.contains("after property") || lower.contains("after array") { return true }
        if lower.contains("unexpected token") || lower.contains("unexpected non-whitespace") { return true }
        if lower.contains("expected") && (lower.contains("position") || lower.contains("column")) {
            return true
        }
        return false
    }
}
