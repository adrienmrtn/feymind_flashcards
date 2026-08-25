import Foundation

/// Transport vers la base, en PostgREST.
///
/// Le jeton de l'utilisateur remplace la clé publique dans l'en-tête `Authorization` : c'est
/// lui qui porte `auth.uid()`, et donc lui que les règles de sécurité lisent. Sans lui, la
/// requête part en anonyme et ne voit rien, ce qui est exactement le comportement voulu — un
/// bug de session ne peut pas faire fuiter les cours de quelqu'un d'autre, il ne peut que
/// rendre une liste vide.
struct SupabaseDatabase {
    enum Failure: LocalizedError {
        case notConfigured
        case notSignedIn
        case network(String)
        case server(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: "L'accès au cloud n'est pas configuré."
            case .notSignedIn: "Aucun compte connecté."
            case .network(let detail): "Connexion impossible. \(detail)"
            case .server(_, let message): message
            }
        }
    }

    var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 45
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    /// Rend le jeton d'accès courant. C'est une fermeture, et pas une valeur : une synchro
    /// dure plusieurs requêtes, et le jeton peut expirer au milieu.
    let accessToken: () async -> String?

    // MARK: - Écriture

    /// Envoie des lignes en écrasant celles qui existent déjà.
    ///
    /// `resolution=merge-duplicates` est le cœur de la synchro : l'app envoie la même ligne
    /// autant de fois qu'elle veut, avec l'identifiant qu'elle a créé localement, et la base
    /// la met à jour au lieu de refuser un doublon. C'est ce qui permet de tout renvoyer après
    /// trois jours hors ligne sans tenir un journal de ce qui a changé.
    func upsert<T: Encodable>(_ rows: [T], into table: String) async throws {
        guard !rows.isEmpty else { return }
        _ = try await send(
            method: "POST",
            path: table,
            query: [],
            body: try encoder.encode(rows),
            prefer: "resolution=merge-duplicates,return=minimal"
        )
    }

    // MARK: - Lecture

    /// Relit une table, éventuellement en ne demandant que ce qui a changé depuis une date.
    func fetch<T: Decodable>(
        _ type: T.Type,
        from table: String,
        select: String = "*",
        updatedSince: Date? = nil,
        limit: Int = 1_000
    ) async throws -> [T] {
        var query = [
            URLQueryItem(name: "select", value: select),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "order", value: "updated_at.asc")
        ]
        if let updatedSince {
            query.append(URLQueryItem(name: "updated_at", value: "gt." + isoFormatter.string(from: updatedSince)))
        }

        let data = try await send(method: "GET", path: table, query: query, body: nil, prefer: nil)
        do {
            return try decoder.decode([T].self, from: data)
        } catch {
            throw Failure.server(status: 200, message: "Réponse illisible pour \(table).")
        }
    }

    // MARK: - Transport

    private func send(
        method: String,
        path: String,
        query: [URLQueryItem],
        body: Data?,
        prefer: String?
    ) async throws -> Data {
        guard AppConfig.isConfigured else { throw Failure.notConfigured }
        guard let token = await accessToken() else { throw Failure.notSignedIn }

        let root = AppConfig.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let base = URL(string: root + "/rest/v1/" + path),
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw Failure.notConfigured
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw Failure.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Failure.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw Failure.server(status: 0, message: "Réponse inattendue.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw Failure.server(
                status: http.statusCode,
                message: (payload?["message"] as? String) ?? "Le serveur a répondu \(http.statusCode)."
            )
        }
        return data
    }

    // MARK: - Formats

    /// Postgres attend de l'ISO 8601 avec fractions de seconde, et le décodeur doit accepter
    /// les deux formes qu'il renvoie : avec et sans fractions.
    private var isoFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        let formatter = isoFormatter
        encoder.dateEncodingStrategy = .custom { date, container in
            var container = container.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let withFractions = isoFormatter
        let plain = ISO8601DateFormatter()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = withFractions.date(from: text) { return date }
            if let date = plain.date(from: text) { return date }
            // Une date en date nue (`2026-08-25`) pour les colonnes `date` d'examen.
            let dayOnly = DateFormatter()
            dayOnly.dateFormat = "yyyy-MM-dd"
            dayOnly.timeZone = TimeZone(identifier: "UTC")
            if let date = dayOnly.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Date illisible : \(text)"
            )
        }
        return decoder
    }
}
