import Foundation

/// Appelle les Edge Functions Supabase, qui relaient vers fal.ai.
/// La clé fal reste côté serveur : l'application n'envoie que la clé publique Supabase.
struct SupabaseAIService: AIService {
    var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        // Les podcasts enchaînent plusieurs appels TTS : laisser une marge confortable.
        configuration.timeoutIntervalForRequest = 240
        configuration.timeoutIntervalForResource = 420
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

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

        let data = try await post(function: "generate-course", payload: payload)
        let envelope = try decodeEnvelope(data)

        guard let courseObject = envelope["course"] else {
            throw AIServiceError.invalidResponse
        }
        let courseData = try JSONSerialization.data(withJSONObject: courseObject)
        guard let course = try? JSONDecoder().decode(GeneratedCourse.self, from: courseData) else {
            throw AIServiceError.invalidResponse
        }
        return course
    }

    // MARK: - Flashcards

    func generateFlashcards(_ request: FlashcardGenerationRequest) async throws -> [GeneratedFlashcard] {
        let payload: [String: Any] = [
            "title": request.courseTitle,
            "context": String(request.courseContext.prefix(40_000)),
            "count": request.desiredCount,
            "existing": request.existingFronts,
            "model": AppConfig.aiModel
        ]

        let data = try await post(function: "generate-flashcards", payload: payload)
        let envelope = try decodeEnvelope(data)

        guard let cardsObject = envelope["cards"] else {
            throw AIServiceError.invalidResponse
        }
        let cardsData = try JSONSerialization.data(withJSONObject: cardsObject)
        guard let cards = try? JSONDecoder().decode([GeneratedFlashcard].self, from: cardsData) else {
            throw AIServiceError.invalidResponse
        }
        return cards
    }

    // MARK: - Explication d'un passage

    func explain(_ request: ExplainRequest) async throws -> String {
        let payload: [String: Any] = [
            "selection": String(request.selection.prefix(4_000)),
            "title": request.courseTitle,
            "context": String(request.courseContext.prefix(20_000)),
            "angle": request.angle.rawValue,
            "model": AppConfig.aiModel
        ]

        let data = try await post(function: "explain-passage", payload: payload)
        let envelope = try decodeEnvelope(data)

        guard let answer = envelope["answer"] as? String, !answer.isEmpty else {
            throw AIServiceError.invalidResponse
        }
        return answer
    }

    // MARK: - Podcast

    func generatePodcast(_ request: PodcastGenerationRequest) async throws -> GeneratedPodcast {
        let context = request.courseContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard context.count >= 80 else { throw AIServiceError.emptySource }

        let payload: [String: Any] = [
            "title": request.courseTitle,
            "context": String(context.prefix(18_000)),
            "hostVoiceId": request.hostVoiceId,
            "guestVoiceId": request.guestVoiceId,
            "targetMinutes": min(max(request.targetMinutes, 3), 8),
            "model": AppConfig.aiModel
        ]

        let data = try await post(function: "generate-podcast", payload: payload)
        let envelope = try decodeEnvelope(data)

        guard let podcastObject = envelope["podcast"] else {
            throw AIServiceError.invalidResponse
        }
        let podcastData = try JSONSerialization.data(withJSONObject: podcastObject)
        guard let podcast = try? JSONDecoder().decode(GeneratedPodcast.self, from: podcastData),
              !podcast.segments.isEmpty else {
            throw AIServiceError.invalidResponse
        }
        return podcast
    }

    // MARK: - Transport

    private func post(function: String, payload: [String: Any]) async throws -> Data {
        guard AppConfig.isConfigured, let url = AppConfig.functionURL(function) else {
            throw AIServiceError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIServiceError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw mapServerError(status: http.statusCode, data: data)
        }
        return data
    }

    private func decodeEnvelope(_ data: Data) throws -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.invalidResponse
        }
        if let message = object["error"] as? String {
            throw AIServiceError.server(message)
        }
        return object
    }

    private func mapServerError(status: Int, data: Data) -> AIServiceError {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = (object?["error"] as? String) ?? String(data: data, encoding: .utf8) ?? ""

        if message.localizedCaseInsensitiveContains("FAL_KEY") {
            return .missingProviderKey
        }
        if status == 401 || status == 403 {
            return .server("Clé Supabase refusée (\(status)). Vérifiez la clé publique dans Réglages.")
        }
        if status == 404 {
            return .server("Fonction Supabase introuvable. Déployez les Edge Functions du dossier supabase/functions.")
        }
        if message.isEmpty {
            return .server("Le serveur a répondu \(status).")
        }
        return .server(message)
    }
}
