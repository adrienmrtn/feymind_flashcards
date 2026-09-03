import Foundation

/// Le compte que les relecteurs d'Apple ouvrent depuis « Recevoir un lien ».
///
/// Ils n'ont pas la boîte `review@apple.com` : taper l'adresse et appuyer ouvre la
/// session tout de suite, par mot de passe, sans courriel. L'écran ne change pas —
/// c'est le même champ, et le mot de passe n'est pas dans les notes de relecture.
///
/// **Pas de session fabriquée en repli.** Une session locale sans jeton valable
/// donnerait une app qui *paraît* connectée : aucun cours ne descendrait, aucun
/// import ne partirait. Un refus se dit, comme pour n'importe quelle connexion.
enum AppStoreReview {
    static let email = "review@apple.com"
    static let password = "Micabo-Review-2026-Kx9m"

    static func matches(_ raw: String?) -> Bool {
        guard let raw else { return false }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == email
    }

    /// Le cadeau se pose sur la fiche du premier cours. Il est marqué vu d'avance : le
    /// droit Pro le referme déjà, mais il se présente pendant les quelques centaines de
    /// millisecondes qui séparent la session du premier `refresh()`.
    static func silenceDiscount() {
        DiscountOffer.markSeen()
    }
}
