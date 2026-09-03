import Foundation

/// Le compte que les relecteurs d'Apple ouvrent depuis « Recevoir un lien ».
///
/// Ils n'ont pas la boîte `review@apple.com` : taper l'adresse et envoyer le lien
/// ouvre la session tout de suite, sans courriel. Le mot de passe n'est pas montré
/// dans les notes de relecture — l'écran de connexion reste celui du lien magique.
enum AppStoreReview {
    static let email = "review@apple.com"
    static let password = "Micabo-Review-2026-Kx9m"
    static let userID = UUID(uuidString: "C0DE0000-A11E-4E11-9E11-00000000F00D")!

    static func matches(_ raw: String?) -> Bool {
        guard let raw else { return false }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == email
    }

    /// Session locale si GoTrue ne répond pas : l'app reste ouverte, le droit Pro
    /// se lit sur l'adresse, pas sur un jeton.
    static func localSession() -> AuthSession {
        AuthSession(
            accessToken: "review-local",
            refreshToken: "review-local",
            expiresAt: .distantFuture,
            user: AuthUser(id: userID, email: email, displayName: "App Review")
        )
    }

    /// Le cadeau se pose sur le premier cours : on le marque vu pour qu'un instant
    /// sans droit (avant le `refresh`) ne l'ouvre pas quand même.
    static func silenceDiscount() {
        DiscountOffer.markSeen()
    }
}
