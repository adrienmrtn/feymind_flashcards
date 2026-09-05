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
/// **Deux sources, dans cet ordre : le SDK, puis la table.** RevenueCat répond depuis son
/// cache local, donc il sait même hors ligne, et il sait *avant* le webhook. La table
/// `entitlements` est le repli : elle vaut pour un achat fait sur le web, et pour un appareil
/// où le SDK n'est pas configuré.
///
/// Aucune des deux ne répond ? On ne devine pas : `assumeProWithoutRow` tranche, et il dit
/// non — comme le web.
@Observable
@MainActor
final class ProAccess {
    enum Key {
        static let isPro = "micabo.pro.active"
    }

    private(set) var isPro: Bool

    /// Même règle que le web (`ASSUME_PRO_WITHOUT_ROW`, à `false`) : pas de ligne, pas
    /// d'abonnement. Les deux clients doivent dire la même chose — un cours flouté sur le
    /// web et ouvert sur le téléphone, c'est le même produit qui dit deux choses.
    static let assumeProWithoutRow = false

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
    /// Une seule veille sur le flux du SDK : deux boucles se répondraient.
    private var purchaseWatch: Task<Void, Never>?

    /// Ouvre tout. Appelé quand le serveur confirme un achat ou une restauration — jamais
    /// sur un `unavailable`, qui veut dire « je n'ai pas pu vendre ».
    func unlock() {
        guard !isPro else { return }
        isPro = true
        defaults.set(true, forKey: Key.isPro)
    }

    /// Referme tout. La réponse du serveur passe par ici, et l'interrupteur de relecture
    /// des réglages aussi — il n'existe qu'en `DEBUG`.
    func lock() {
        guard isPro else { return }
        isPro = false
        defaults.set(false, forKey: Key.isPro)
    }

    func setPro(_ value: Bool) {
        value ? unlock() : lock()
    }

    /// Relit l'état de l'abonnement.
    ///
    /// **Le plus généreux des deux gagne.** Le SDK et la table doivent s'accorder ; quand ils
    /// divergent — le webhook a une seconde de retard, ou l'achat vient d'être fait sur le
    /// web — enfermer dehors quelqu'un qui paye est pire qu'une minute offerte.
    ///
    /// Une échéance passée l'emporte sur le drapeau de la table : un webhook peut se perdre,
    /// et un abonnement fini qui reste ouvert est une fuite qui ne se voit pas.
    func refresh() async {
        let fromSDK = await PurchasesBridge.isPro()
        let fromTable = await readEntitlementRow()

        // Personne ne sait rien : le réglage tranche, et il dit non.
        guard fromSDK != nil || fromTable != nil else {
            setPro(Self.assumeProWithoutRow)
            return
        }

        setPro(fromSDK == true || fromTable == true)
    }

    /// S'abonne au flux du SDK : un abonnement résilié se referme **sans redémarrage**.
    ///
    /// Le flux ne parle que d'Apple. Il ouvre tout seul ; il ne referme pas ce qu'un achat
    /// web a ouvert, et repasse donc par `refresh()` pour arbitrer les deux sources.
    func observePurchases() {
        guard purchaseWatch == nil else { return }
        purchaseWatch = Task { [weak self] in
            for await active in PurchasesBridge.proUpdates() {
                guard let self else { return }
                if active {
                    self.setPro(true)
                } else {
                    await self.refresh()
                }
            }
        }
    }

    /// La ligne `entitlements`, ou `nil` quand on n'a pas pu la lire. `nil` n'est pas « non ».
    private func readEntitlementRow() async -> Bool? {
        guard let token = await accessToken?(), let userID = userID?() else { return nil }

        do {
            let database = SupabaseDatabase(accessToken: { token })
            let rows = try await database.rows(
                EntitlementRecord.self,
                from: CloudTable.entitlements,
                filters: [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())")],
                limit: 1
            )
            guard let row = rows.first else { return false }
            let expired = row.expires_at.map { $0 < Date() } ?? false
            return row.is_pro && !expired
        } catch {
            return nil
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
