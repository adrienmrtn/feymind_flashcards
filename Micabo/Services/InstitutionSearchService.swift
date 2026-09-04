import Foundation

/// Recherche hybride : catalogue embarqué pour l'instantané, Supabase pour le reste du monde.
actor InstitutionSearchService {
    static let shared = InstitutionSearchService()

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 8
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    private lazy var localCatalog: [Institution] = Self.loadLocalCatalog()

    func suggestions(matching query: String, country: String? = nil, limit: Int = 12) async -> [Institution] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else { return [] }

        let iso = Self.normalizedCountry(country)
        let local = Self.filter(localCatalog, matching: needle, country: iso, limit: limit)
        let remote = await searchRemote(matching: needle, country: iso, limit: limit)
        return Self.merge(local: local, remote: remote, limit: limit)
    }

    // MARK: - Local

    private static func loadLocalCatalog() -> [Institution] {
        let urls = [
            Bundle.main.url(forResource: "LocalInstitutions", withExtension: "json"),
            Bundle.main.url(forResource: "LocalInstitutions", withExtension: "json", subdirectory: "Institutions"),
            Bundle.main.url(forResource: "LocalInstitutions", withExtension: "json", subdirectory: "Resources/Institutions")
        ].compactMap { $0 }

        guard let url = urls.first,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Institution].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func normalizedCountry(_ country: String?) -> String? {
        guard let trimmed = country?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        let upper = trimmed.uppercased()
        return upper == "UK" ? "GB" : upper
    }

    private static func filter(
        _ catalog: [Institution],
        matching needle: String,
        country: String?,
        limit: Int
    ) -> [Institution] {
        let query = needle.lowercased()
        let scoped = country.map { iso in catalog.filter { $0.countryCode == iso } } ?? catalog
        let scored: [(Institution, Double)] = scoped.compactMap { institution in
            let score = matchScore(institution, query: query)
            return score > 0 ? (institution, score) : nil
        }
        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.name.count < rhs.0.name.count
            }
            .prefix(limit)
            .map(\.0)
    }

    private static func matchScore(_ institution: Institution, query: String) -> Double {
        let name = institution.name.lowercased()
        if name == query { return 1 }
        if name.hasPrefix(query) { return 0.92 }
        if name.contains(query) { return 0.7 }

        var best = 0.0
        for alias in institution.aliases {
            let value = alias.lowercased()
            if value == query { best = max(best, 0.95) }
            else if value.hasPrefix(query) { best = max(best, 0.88) }
            else if value.contains(query) { best = max(best, 0.6) }
        }
        return best
    }

    // MARK: - Remote

    private func searchRemote(matching query: String, country: String?, limit: Int) async -> [Institution] {
        guard AppConfig.isConfigured,
              let base = URL(string: AppConfig.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) else {
            return []
        }

        let url = base.appending(path: "rest/v1/rpc/search_institutions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        var payload: [String: Any] = [
            "query": query,
            "result_limit": limit
        ]
        if let country {
            payload["country"] = country
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return []
            }
            return try JSONDecoder().decode([Institution].self, from: data)
        } catch {
            return []
        }
    }

    private static func merge(local: [Institution], remote: [Institution], limit: Int) -> [Institution] {
        var seen = Set<String>()
        var merged: [Institution] = []

        for institution in local + remote {
            let key = institution.id
            let fuzzy = institution.name.lowercased()
            if seen.contains(key) || seen.contains(fuzzy) { continue }
            seen.insert(key)
            seen.insert(fuzzy)
            merged.append(institution)
            if merged.count >= limit { break }
        }
        return merged
    }
}
