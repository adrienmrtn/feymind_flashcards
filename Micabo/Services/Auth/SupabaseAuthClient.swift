import Foundation

/// Le client d'authentification : GoTrue, en HTTP direct.
///
/// Pas de SDK. Micabo parle déjà à Supabase en HTTP pour ses Edge Functions
/// (`SupabaseFunctions`), et l'authentification tient maintenant en quatre appels : ouvrir
/// une session depuis un jeton Apple, en ouvrir une depuis un code OAuth, la rafraîchir, la
/// fermer. Ajouter une dépendance externe pour ça coûterait un gestionnaire de paquets, une
/// surface de mise à jour et un binaire, pour du code qu'on relit en une fois.
struct SupabaseAuthClient {
    static let shared = SupabaseAuthClient()

    var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    // MARK: - Fournisseurs

    /// Ouvre une session depuis un jeton d'identité déjà obtenu. C'est le chemin d'Apple sur
    /// iOS : le système rend un JWT signé, on n'a aucune page web à ouvrir.
    func signIn(idToken: String, provider: String, nonce: String?) async throws -> AuthSession {
        var body: [String: Any] = ["provider": provider, "id_token": idToken]
        if let nonce { body["nonce"] = nonce }

        let payload = try await post("token", query: ["grant_type": "id_token"], body: body)
        return try decodeSession(payload)
    }

    /// Échange le code d'un retour OAuth contre une session. C'est la seconde moitié du flux
    /// PKCE : le vérificateur n'a jamais quitté l'appareil, donc un code intercepté ne sert à
    /// rien.
    func exchange(code: String, verifier: String) async throws -> AuthSession {
        let payload = try await post("token", query: ["grant_type": "pkce"], body: [
            "auth_code": code,
            "code_verifier": verifier
        ])
        return try decodeSession(payload)
    }

    /// Envoie un lien de connexion. Le retour ouvre `micabo://auth-callback` : sans
    /// `redirect_to` dans la liste du tableau de bord, le courriel part et le lien refuse.
    func sendMagicLink(email: String, redirectTo: URL, challenge: String) async throws {
        _ = try await post(
            "otp",
            query: ["redirect_to": redirectTo.absoluteString],
            body: [
                "email": email,
                "create_user": true,
                "code_challenge": challenge,
                "code_challenge_method": "s256",
            ]
        )
    }

    /// Échange le `token_hash` d'un lien de courriel contre une session. C'est l'autre
    /// forme que GoTrue sait renvoyer, quand le flux n'est pas PKCE.
    func verify(tokenHash: String, type: String) async throws -> AuthSession {
        let payload = try await post("verify", body: [
            "token_hash": tokenHash,
            "type": type,
        ])
        return try decodeSession(payload)
    }

    /// L'URL de la page d'autorisation d'un fournisseur, telle que Supabase l'attend.
    func authorizeURL(provider: String, redirectTo: URL, challenge: String) -> URL? {
        guard var components = base().flatMap({ URLComponents(url: $0.appending(path: "authorize"), resolvingAgainstBaseURL: false) }) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: redirectTo.absoluteString),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256")
        ]
        return components.url
    }

    // MARK: - Session

    func refresh(refreshToken: String) async throws -> AuthSession {
        let payload = try await post("token", query: ["grant_type": "refresh_token"], body: [
            "refresh_token": refreshToken
        ])
        return try decodeSession(payload)
    }

    func signOut(accessToken: String) async throws {
        _ = try? await post("logout", body: [:], accessToken: accessToken)
    }

    // MARK: - Transport

    private func base() -> URL? {
        guard AppConfig.isConfigured else { return nil }
        let trimmed = AppConfig.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: trimmed + "/auth/v1")
    }

    private func post(
        _ path: String,
        query: [String: String] = [:],
        body: [String: Any],
        accessToken: String? = nil
    ) async throws -> [String: Any] {
        guard let base = base() else { throw AuthError.notConfigured }

        var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw AuthError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken ?? AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

        guard (200..<300).contains(http.statusCode) else {
            throw Self.error(status: http.statusCode, payload: payload)
        }
        return payload
    }

    private func decodeSession(_ payload: [String: Any]) throws -> AuthSession {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let response = try? JSONDecoder().decode(AuthTokenResponse.self, from: data) else {
            throw AuthError.invalidResponse
        }
        return response.session()
    }

    /// GoTrue nomme ses refus : c'est le code qu'on lit, pas la phrase, qui peut changer.
    private static func error(status: Int, payload: [String: Any]) -> AuthError {
        let code = (payload["error_code"] as? String) ?? (payload["error"] as? String) ?? ""
        let message = (payload["msg"] as? String)
            ?? (payload["error_description"] as? String)
            ?? (payload["message"] as? String)
            ?? "Le serveur a répondu \(status)."

        switch code {
        case "invalid_credentials", "invalid_grant":
            return .invalidCredentials
        case "email_not_confirmed":
            return .emailNotConfirmed
        case "validation_failed" where message.localizedCaseInsensitiveContains("provider"):
            return .providerNotEnabled("ce fournisseur")
        default:
            if status == 400, message.localizedCaseInsensitiveContains("provider is not enabled") {
                return .providerNotEnabled("ce fournisseur")
            }
            return .server(message)
        }
    }
}
