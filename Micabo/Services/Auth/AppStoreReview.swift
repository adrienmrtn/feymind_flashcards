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

    private static let domain = "apple.com"

    /// Vrai pour **toute** adresse en `@apple.com`, et pas seulement pour celle des notes.
    ///
    /// Ça a l'air trop large, et c'est le contraire : c'est la largeur qui manquait. Le
    /// 5 septembre, un relecteur a demandé un lien pour `review2@apple.com` - l'adresse des
    /// notes, avec un chiffre en plus. L'égalité stricte ne l'a pas reconnue, le lien est
    /// parti pour de bon, et `apple.com` refuse les boîtes qu'il n'a pas : rebond dur. Les
    /// journaux gardent la trace du reste de la séance, cinq refus de format en quatre
    /// minutes depuis un appareil d'Apple, pendant que quelqu'un cherchait la bonne formule.
    ///
    /// Personne chez Apple ne relève une boîte pour essayer une app. Aucune adresse de ce
    /// domaine n'a donc de raison de recevoir un lien, et toutes ont une raison d'ouvrir la
    /// session de relecture : c'est ce qu'on leur promet dans les notes.
    static func matches(_ raw: String?) -> Bool {
        guard let raw else { return false }
        let address = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let at = address.lastIndex(of: "@"), at != address.startIndex else { return false }
        return String(address[address.index(after: at)...]) == domain
    }
}
