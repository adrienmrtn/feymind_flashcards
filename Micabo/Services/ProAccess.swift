import Observation
import SwiftUI

/// **Ce que la version gratuite laisse faire**, et rien de plus.
///
/// Les trois nombres vivent ici parce qu'ils se répondent : un cours qu'on peut lire aux
/// sept dixièmes, cinq cartes par session, un seul import. Éparpillés dans les écrans, ils
/// auraient dérivé au premier ajustement, et le gratuit se serait mis à dire deux choses
/// différentes selon l'endroit où on l'a rencontré.
enum FreeTier {
    /// Un cours importé, et un seul. Le deuxième demande un abonnement.
    ///
    /// Ce n'est pas zéro, et c'est le point : un paywall posé avant le premier import
    /// demande de payer pour un produit qu'on n'a pas vu tourner sur ses propres cours.
    static let courses = 1

    /// La part de la fiche qui se lit sans payer.
    ///
    /// Sept dixièmes, pas la moitié : il faut que la fiche ait le temps d'être utile avant
    /// de s'arrêter. Une coupure au milieu se lit comme une démonstration, une coupure à la
    /// fin se lit comme un manque — et c'est le manque qui fait payer.
    static let readableSheetRatio = 0.7

    /// Le nombre de cartes qu'une session gratuite sert avant de s'arrêter.
    static let cardsPerSession = 5

    /// L'entraînement libre est réservé à Pro.
    ///
    /// C'est la seule limite qui ferme une porte entière plutôt que d'en entrouvrir une, et
    /// elle se tient : réviser ce qui est dû est le service que Micabo rend, s'entraîner à
    /// volonté sur tout un paquet est ce qu'on fait la veille d'un partiel.
    static let allowsPractice = false
}

/// **L'abonnement, tel que l'app le lit.**
///
/// Un seul objet répond à « est-ce que cette personne est abonnée ? », et tout ce qui se
/// ferme dans l'app lui pose la question. Deux écrans qui décideraient chacun de leur côté
/// finiraient par ne pas être d'accord, et un utilisateur qui vient de payer verrait encore
/// un cadenas quelque part.
///
/// **Rien n'est branché sur une boutique pour l'instant.** `PaywallPurchases` répond
/// `unavailable`, et `unlock()` est appelé quand même : sans ça, le bouton du paywall ne
/// ferait rien du tout et le parcours ne serait pas testable. Le jour où RevenueCat est en
/// place, `refresh()` lit l'entitlement `pro` et `unlock()` disparaît au profit de la
/// réponse du serveur — voir `docs/revenuecat.md`.
@Observable
@MainActor
final class ProAccess {
    enum Key {
        static let isPro = "micabo.pro.active"
    }

    private(set) var isPro: Bool

    /// Même règle que le web (`ASSUME_PRO_WITHOUT_ROW`) : sans ligne, on ouvre.
    /// Il n'y a pas encore de boutique branchée ; fermer maintenant enfermerait
    /// tout le monde sans porte de sortie.
    static let assumeProWithoutRow = true

    init(
        defaults: UserDefaults = .standard,
        accessToken: (() async -> String?)? = nil,
        userID: (() -> UUID?)? = nil
    ) {
        self.defaults = defaults
        self.accessToken = accessToken
        self.userID = userID
        self.isPro = defaults.bool(forKey: Key.isPro)
    }

    private let defaults: UserDefaults
    private let accessToken: (() async -> String?)?
    private let userID: (() -> UUID?)?

    /// Ouvre tout. Appelé après un achat, et après une restauration réussie.
    func unlock() {
        guard !isPro else { return }
        isPro = true
        defaults.set(true, forKey: Key.isPro)
    }

    /// Referme tout. N'existe que pour les réglages de test : c'est le seul moyen de
    /// revoir les écrans de blocage une fois qu'on les a franchis une fois.
    func lock() {
        guard isPro else { return }
        isPro = false
        defaults.set(false, forKey: Key.isPro)
    }

    func setPro(_ value: Bool) {
        value ? unlock() : lock()
    }

    /// Relit l'état de l'abonnement au lancement.
    ///
    /// La table `entitlements` fait foi, comme sur le web. Une échéance passée
    /// l'emporte sur le drapeau. Sans ligne, on ouvre — tant qu'on ne peut pas
    /// payer depuis l'app, fermer serait une porte sans poignée.
    func refresh() async {
        guard let token = await accessToken?(), let userID = userID?() else {
            isPro = defaults.bool(forKey: Key.isPro)
            return
        }

        do {
            let database = SupabaseDatabase(accessToken: { token })
            let rows = try await database.rows(
                EntitlementRecord.self,
                from: CloudTable.entitlements,
                filters: [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())")],
                limit: 1
            )
            if let row = rows.first {
                let expired = row.expires_at.map { $0 < Date() } ?? false
                setPro(row.is_pro && !expired)
            } else if Self.assumeProWithoutRow {
                setPro(true)
            } else {
                setPro(false)
            }
        } catch {
            isPro = defaults.bool(forKey: Key.isPro)
        }
    }

    // MARK: - Les portes

    /// Peut-on encore importer un cours ?
    ///
    /// Les cours repris dans la bibliothèque ne comptent pas : ils n'ont rien coûté à
    /// produire, et faire payer un import qu'on n'a pas fait serait incompréhensible.
    func canImportCourse(existingCourses courses: [Course]) -> Bool {
        guard !isPro else { return true }
        return courses.filter { !$0.isFromLibrary }.count < FreeTier.courses
    }

    var canPractice: Bool {
        isPro || FreeTier.allowsPractice
    }

    /// Vrai à partir de la carte qui doit rester derrière le paywall.
    func hasReachedSessionLimit(answered: Int) -> Bool {
        !isPro && answered >= FreeTier.cardsPerSession
    }
}

/// **Où s'arrête la lecture d'une fiche**, pour qui n'est pas abonné.
///
/// La coupure se compte en blocs et non en caractères : couper un paragraphe en deux au
/// septième dixième de son texte donnerait une phrase interrompue au milieu d'un mot, ce
/// qui ressemble à un bug d'affichage plutôt qu'à une limite assumée.
enum SheetGate {
    /// Indice du premier bloc flouté. Toujours au moins un bloc lisible, et au plus tous.
    static func lockIndex(blockCount: Int, ratio: Double = FreeTier.readableSheetRatio) -> Int {
        guard blockCount > 0 else { return 0 }
        let raw = Int((Double(blockCount) * ratio).rounded())
        return max(1, min(blockCount, raw))
    }

    /// Coupe la fiche en deux : ce qui se lit, ce qui se devine.
    static func split(
        _ blocks: [SheetBlock],
        isPro: Bool,
        ratio: Double = FreeTier.readableSheetRatio
    ) -> (readable: [SheetBlock], locked: [SheetBlock]) {
        guard !isPro, !blocks.isEmpty else { return (blocks, []) }
        let index = lockIndex(blockCount: blocks.count, ratio: ratio)
        return (Array(blocks[..<index]), Array(blocks[index...]))
    }
}
