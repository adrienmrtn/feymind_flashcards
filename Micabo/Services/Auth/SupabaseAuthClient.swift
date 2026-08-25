import Foundation

/// Les fournisseurs de connexion que le projet Supabase a réellement activés.
///
/// C'est lu au lancement, et ça décide de ce que l'écran de connexion affiche. Micabo
/// n'écrit donc pas en dur « bouton Apple, bouton Google » : les boutons **apparaissent d'eux
/// mêmes** le jour où les fournisseurs sont configurés dans le tableau de bord, sans mise à
/// jour de l'app. C'est le contraire d'un détail : un bouton « Continuer avec Google » qui
/// mène à une page d'erreur coûte plus cher qu'un bouton absent.
struct AuthProviders: Equatable {
    var email: Bool = true
    var apple: Bool = false
    var google: Bool = false
    /// Vrai quand le projet accepte les inscriptions. À faux, l'écran ne propose que la
    /// connexion.
    var allowsSignUp: Bool = true
    /// Vrai quand une adresse doit être confirmée avant la première connexion. Ça change ce
    /// qu'on affiche après une inscription : « vérifie ta boîte » plutôt que l'app.
    var requiresEmailConfirmation: Bool = true

    static let emailOnly = AuthProviders()
}

/// Le client d'authentification : GoTrue, en HTTP direct.
///
/// Pas de SDK. Micabo parle déjà à Supabase en HTTP pour ses Edge Functions
/// (`SupabaseFunctions`), et l'authentification tient en six appels : ouvrir une session,
/// la rafraîchir, la fermer, en ouvrir une depuis un jeton Apple, en ouvrir une depuis un code
/// OAuth, et lire ce que le projet autorise. Ajouter une dépendance externe pour ça
/// coûterait un gestionnaire de paquets, une surface de mise à jour et un binaire, pour du
/// code qu'on relit en une fois.
struct SupabaseAuthClient {
    static let shared = SupabaseAuthClient()

    var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    // MARK: - Courriel

    /// Crée un compte. Rend `nil` quand le projet demande une confirmation par courriel : il
    /// n'y a alors pas encore de session, et l'écran doit le dire au lieu d'attendre.
    func signUp(email: String, password: String, displayName: String?) async throws -> AuthSession? {
        var body: [String: Any] = ["email": email, "password": password]
        if let displayName = displayName?.nilIfBlank {
            body["data"] = ["full_name": displayName]
        }

        let payload = try await post("signup", body: body)

        guard payload["access_token"] is String else { return nil }
        return try decodeSession(payload)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let payload = try await post("token", query: ["grant_type": "password"], body: [
            "email": email,
            "password": password
        ])
        return try decodeSession(payload)
    }

    /// Envoie un lien de connexion. C'est le chemin sans mot de passe, et celui qui répare
    /// tout : adresse confirmée trop tard, mot de passe oublié, compte créé sur un autre
    /// appareil.
    func sendMagicLink(email: String, redirectTo: URL) async throws {
        _ = try await post(
            "otp",
            query: ["redirect_to": redirectTo.absoluteString],
            body: ["email": email, "create_user": true]
        )
    }

    func sendPasswordReset(email: String, redirectTo: URL) async throws {
        _ = try await post(
            "recover",
            query: ["redirect_to": redirectTo.absoluteString],
            body: ["email": email]
        )
    }

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

    /// Ce que le projet autorise. Une panne réseau ne doit pas bloquer l'écran : on retombe
    /// sur « courriel seulement », qui est toujours vrai.
    func providers() async -> AuthProviders {
        guard let base = base() else { return .emailOnly }

        var request = URLRequest(url: base.appending(path: "settings"))
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")

        guard let (data, _) = try? await session.data(for: request),
              let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .emailOnly
        }

        let external = payload["external"] as? [String: Any] ?? [:]
        return AuthProviders(
            email: external["email"] as? Bool ?? true,
            apple: external["apple"] as? Bool ?? false,
            google: external["google"] as? Bool ?? false,
            allowsSignUp: !((payload["disable_signup"] as? Bool) ?? false),
            requiresEmailConfirmation: !((payload["mailer_autoconfirm"] as? Bool) ?? false)
        )
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
