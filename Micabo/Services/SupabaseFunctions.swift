import Foundation

/// Panne rencontrée en appelant une Edge Function.
///
/// Le `code` est ce qui distingue ce transport d'un simple appel HTTP : les fonctions de
/// Micabo renvoient, à côté du message lisible, un code stable que l'appelant traduit dans
/// ses propres termes. Sans lui, l'application devrait reconnaître un refus à la forme de
/// sa phrase, ce qui casse au premier mot changé côté serveur.
enum SupabaseFunctionError: Error {
    case notConfigured
    case network(String)
    case server(status: Int, message: String, code: String?)
    case invalidResponse
}

/// Transport vers les Edge Functions Supabase.
///
/// Un seul endroit connaît l'URL, les en-têtes et la forme des réponses, parce que trois
/// clients qui la connaîtraient chacun de leur côté finiraient par ne plus traiter les
/// pannes de la même façon.
struct SupabaseFunctions {
    static let shared = SupabaseFunctions()

    /// Jeton de l'utilisateur, posé au lancement. Sans lui, l'appel part en anonyme :
    /// les fonctions qui regardent `auth.uid()` refusent, et c'est voulu.
    ///
    /// Statique : `SupabaseAIService` recopie `shared` à la construction, et une
    /// fermeture posée après coup sur l'instance copiée n'arriverait jamais.
    static var accessToken: (() async -> String?)?

    /// Les délais sont longs à dessein : une transcription puis une génération se comptent
    /// en dizaines de secondes, et couper à trente ferait échouer les appels qui allaient
    /// aboutir.
    var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    /// Appelle une fonction et rend l'enveloppe JSON de la réponse.
    func post(_ function: String, payload: [String: Any]) async throws -> [String: Any] {
        guard AppConfig.isConfigured, let url = AppConfig.functionURL(function) else {
            throw SupabaseFunctionError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let token = await Self.accessToken?() ?? AppConfig.supabaseAnonKey
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SupabaseFunctionError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SupabaseFunctionError.invalidResponse
        }

        let envelope = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseFunctionError.server(
                status: http.statusCode,
                message: (envelope?["error"] as? String) ?? String(data: data, encoding: .utf8) ?? "",
                code: envelope?["code"] as? String
            )
        }

        guard let envelope else {
            throw SupabaseFunctionError.invalidResponse
        }

        // Une fonction peut répondre 200 en signalant un refus dans le corps.
        if let message = envelope["error"] as? String {
            throw SupabaseFunctionError.server(
                status: http.statusCode,
                message: message,
                code: envelope["code"] as? String
            )
        }

        return envelope
    }

    /// Décode un objet de l'enveloppe. Une réponse illisible n'est pas une réponse.
    func decode<T: Decodable>(_ type: T.Type, from envelope: [String: Any], key: String) throws -> T {
        guard let object = envelope[key],
              let data = try? JSONSerialization.data(withJSONObject: object),
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            throw SupabaseFunctionError.invalidResponse
        }
        return decoded
    }
}
