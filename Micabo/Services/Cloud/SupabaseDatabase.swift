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
        case server(status: Int, message: String, code: String? = nil)

        var errorDescription: String? {
            switch self {
            case .notConfigured: "L'accès au cloud n'est pas configuré."
            case .notSignedIn: "Aucun compte connecté."
            case .network(let detail): "Connexion impossible. \(detail)"
            case .server(_, let message, _): message
            }
        }

        /// Vrai quand une contrainte d'unicité a refusé l'écriture : un nom d'utilisateur déjà
        /// pris, une demande d'amitié déjà envoyée. `23505` est le code de Postgres, et c'est
        /// lui qu'on lit plutôt que la phrase, qui change avec les versions.
        var isDuplicate: Bool {
            guard case .server(let status, _, let code) = self else { return false }
            return code == "23505" || status == 409
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

    /// Envoie des lignes **sans** écraser celles qui existent.
    ///
    /// C'est le contraire de `upsert`, et c'est voulu là où le doublon est l'information : une
    /// demande d'amitié déjà envoyée doit se signaler, pas s'écrire une seconde fois.
    func insert<T: Encodable>(_ rows: [T], into table: String) async throws {
        guard !rows.isEmpty else { return }
        _ = try await send(
            method: "POST",
            path: table,
            query: [],
            body: try encoder.encode(rows),
            prefer: "return=minimal"
        )
    }

    /// Modifie les lignes que le filtre désigne. Le cloisonnement décide du reste : un filtre
    /// qui viserait la ligne de quelqu'un d'autre ne trouve rien.
    func patch<T: Encodable>(_ values: T, in table: String, matching filters: [URLQueryItem]) async throws {
        _ = try await send(
            method: "PATCH",
            path: table,
            query: filters,
            body: try encoder.encode(values),
            prefer: "return=minimal"
        )
    }

    func remove(from table: String, matching filters: [URLQueryItem]) async throws {
        _ = try await send(
            method: "DELETE",
            path: table,
            query: filters,
            body: nil,
            prefer: "return=minimal"
        )
    }

    /// Lit une table avec les filtres qu'on lui donne, sans ordre ni fenêtre imposés.
    ///
    /// `fetch` ci-dessous sert la synchro, qui demande toujours la même chose : tout, par ordre
    /// de modification. La bibliothèque et les amis, eux, filtrent, trient et paginent
    /// autrement à chaque écran.
    func rows<T: Decodable>(
        _ type: T.Type,
        from table: String,
        select: String = "*",
        filters: [URLQueryItem] = [],
        order: String? = nil,
        limit: Int? = nil
    ) async throws -> [T] {
        var query = [URLQueryItem(name: "select", value: select)]
        query.append(contentsOf: filters)
        if let order { query.append(URLQueryItem(name: "order", value: order)) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }

        let data = try await send(method: "GET", path: table, query: query, body: nil, prefer: nil)
        do {
            return try decoder.decode([T].self, from: data)
        } catch {
            throw Failure.server(status: 200, message: "Réponse illisible pour \(table).")
        }
    }

    /// Relit une table, éventuellement en ne demandant que ce qui a changé depuis une date.
    func fetch<T: Decodable>(
        _ type: T.Type,
        from table: String,
        select: String = "*",
        updatedSince: Date? = nil,
        sinceColumn: String = "updated_at",
        filters: [URLQueryItem] = [],
        limit: Int = 1_000
    ) async throws -> [T] {
        var collected: [T] = []
        var offset = 0
        let page = max(1, limit)

        while true {
            var query = [
                URLQueryItem(name: "select", value: select),
                URLQueryItem(name: "limit", value: String(page)),
                URLQueryItem(name: "offset", value: String(offset)),
                URLQueryItem(name: "order", value: "\(sinceColumn).asc")
            ]
            query.append(contentsOf: filters)
            if let updatedSince {
                query.append(URLQueryItem(name: sinceColumn, value: "gt." + isoFormatter.string(from: updatedSince)))
            }

            let data = try await send(method: "GET", path: table, query: query, body: nil, prefer: nil)
            let batch: [T]
            do {
                batch = try decoder.decode([T].self, from: data)
            } catch {
                throw Failure.server(status: 200, message: "Réponse illisible pour \(table).")
            }

            collected.append(contentsOf: batch)
            // Ne jamais prendre une limite de sécurité pour une fin de table. La synchro
            // avancerait ensuite son repère et les lignes après la coupure seraient perdues
            // pour toujours. Les appels d'écran utilisent `rows(limit:)`; `fetch` est réservé
            // à la copie complète/incrémentale du compte.
            if batch.count < page { break }
            offset += batch.count
        }

        return collected
    }

    /// Appelle une fonction PostgREST (`/rpc/…`). Le corps porte les arguments
    /// sous leurs noms SQL.
    func rpc(_ name: String, arguments: [String: String] = [:]) async throws {
        _ = try await invokeRPC(name, arguments: arguments, prefer: "return=minimal")
    }

    /// Même appel, en lisant la réponse. C'est ce dont a besoin un RPC qui rend
    /// des lignes (`week_review_ranking`), et pas seulement un accusé de réception.
    func rpc<T: Decodable>(
        _ type: T.Type,
        _ name: String,
        arguments: [String: String] = [:]
    ) async throws -> T {
        let data = try await invokeRPC(name, arguments: arguments, prefer: nil)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw Failure.server(status: 200, message: "Réponse illisible pour \(name).")
        }
    }

    private func invokeRPC(
        _ name: String,
        arguments: [String: String],
        prefer: String?
    ) async throws -> Data {
        let body = try JSONSerialization.data(withJSONObject: arguments)
        return try await send(
            method: "POST",
            path: "rpc/\(name)",
            query: [],
            body: body,
            prefer: prefer
        )
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
            // Le code de Postgres passe avec l'erreur : c'est lui qui distingue « ce nom est
            // déjà pris » de « le serveur est tombé », et l'écran n'a pas à deviner en lisant
            // une phrase anglaise.
            throw Failure.server(
                status: http.statusCode,
                message: (payload?["message"] as? String) ?? "Le serveur a répondu \(http.statusCode).",
                code: payload?["code"] as? String
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
