import Foundation

/// L'utilisateur connecté, réduit à ce dont l'app se sert.
///
/// Le reste de ce que renvoie Supabase (métadonnées du fournisseur, liste des identités,
/// horodatages internes) n'est pas recopié : une structure qui suit un format tiers champ pour
/// champ casse au premier champ ajouté en face.
struct AuthUser: Codable, Equatable, Identifiable {
    let id: UUID
    var email: String?
    var displayName: String?

    /// Ce qu'on affiche pour désigner quelqu'un : son nom s'il en a donné un, sinon la partie
    /// gauche de son adresse, sinon « Étudiant ». Jamais l'identifiant : personne ne se
    /// reconnaît dans un UUID.
    var label: String {
        if let name = displayName?.nilIfBlank { return name }
        if let email = email?.nilIfBlank {
            return email.split(separator: "@").first.map(String.init) ?? email
        }
        return "Étudiant"
    }

    private enum CodingKeys: String, CodingKey {
        case id, email, userMetadata = "user_metadata"
    }

    init(id: UUID, email: String?, displayName: String?) {
        self.id = id
        self.email = email
        self.displayName = displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawID = try container.decode(String.self, forKey: .id)
        guard let id = UUID(uuidString: rawID) else {
            throw AuthError.invalidResponse
        }
        self.id = id
        email = try? container.decodeIfPresent(String.self, forKey: .email)

        // Le nom arrive sous trois clés selon le fournisseur : Apple envoie `full_name`,
        // Google `name`, et une inscription par courriel n'envoie rien du tout.
        let metadata = (try? container.decodeIfPresent([String: JSONValue].self, forKey: .userMetadata)) ?? [:]
        displayName = ["full_name", "name", "display_name"]
            .compactMap { metadata[$0]?.stringValue?.nilIfBlank }
            .first
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
    }
}

/// Une session ouverte : les deux jetons, et la date à laquelle le premier expire.
///
/// `expiresAt` est calculée à la réception plutôt que relue du jeton : décoder un JWT pour
/// connaître sa date d'expiration demande de faire confiance à un contenu qu'on n'a pas
/// vérifié, alors que la réponse le donne en clair.
struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var user: AuthUser

    /// On renouvelle une minute avant l'échéance : un jeton qui expire pendant l'appel qu'il
    /// autorise produit une erreur que l'utilisateur ne peut pas comprendre.
    static let renewalMargin: TimeInterval = 60

    var isExpired: Bool {
        Date().addingTimeInterval(Self.renewalMargin) >= expiresAt
    }
}

/// Ce que Supabase renvoie quand une session s'ouvre.
struct AuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Double
    let user: AuthUser

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }

    func session(now: Date = Date()) -> AuthSession {
        AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: now.addingTimeInterval(expiresIn),
            user: user
        )
    }
}

/// Les pannes d'authentification, dites à l'étudiant et pas au développeur.
///
/// Deux cas méritent leur phrase parce que l'utilisateur peut agir : le courriel à confirmer,
/// et le fournisseur qui n'est pas branché côté Supabase. Les autres retombent sur le message
/// du serveur, qui est déjà en français dans les cas courants.
enum AuthError: LocalizedError, Equatable {
    case notConfigured
    case network(String)
    case invalidResponse
    case invalidCredentials
    case emailNotConfirmed
    case providerNotEnabled(String)
    case cancelled
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "La connexion n'est pas configurée. Renseigne l'URL Supabase dans Profil, Réglages."
        case .network(let detail):
            "Connexion impossible. \(detail)"
        case .invalidResponse:
            "La réponse du serveur n'a pas pu être lue. Réessaie."
        case .invalidCredentials:
            "Adresse ou mot de passe incorrect."
        case .emailNotConfirmed:
            "Ton adresse n'est pas encore confirmée. Ouvre le lien qu'on vient de t'envoyer."
        case .providerNotEnabled(let provider):
            "La connexion avec \(provider) n'est pas encore activée sur ce projet Supabase."
        case .cancelled:
            // Annuler n'est pas une erreur : l'écran ne doit rien afficher.
            nil
        case .server(let message):
            message
        }
    }
}

/// Une adresse assez crédible pour envoyer un lien, pas une RFC.
enum EmailAddress {
    static func isPlausible(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = value.firstIndex(of: "@") else { return false }
        let local = value[..<at]
        let domain = value[value.index(after: at)...]
        return !local.isEmpty
            && domain.contains(".")
            && !domain.hasPrefix(".")
            && !domain.hasSuffix(".")
    }
}
