import Observation
import SwiftUI

/// **Le gratuit d'avant la refonte**, tenu à l'identique de celui du site.
///
/// L'app iOS n'en lit plus les portes : depuis la refonte « parcours », le gratuit est une
/// leçon offerte depuis un sujet ou un texte collé (`LessonAllowance`, et `begin_lesson`
/// côté serveur), et la fiche coupée, la carte par jour et l'entraînement verrouillé ont
/// disparu de l'interface. Les valeurs restent parce que le site les applique encore, et que
/// `web/packages/core/test/freemium-parity.test.ts` vérifie qu'elles disent la même chose.
enum FreeTier {
    /// **Aucun cours ne se génère sans abonnement.** Le cours du parcours d'accueil se
    /// construit à part, c'est la démonstration ; dans l'app, les questions d'un deck se
    /// posent à tout le monde et c'est « générer mon cours » qui ouvre le paywall — voir
    /// `DeckSetupFlowView.advance` et `PaywallTrigger.generateCourse`. La page d'un deck se
    /// rouvre librement, ses chapitres sont dans Pro (`PaywallTrigger.openChapter`).
    static let courses = 0

    /// La part d'un chapitre qui se lit sans payer, passé le premier.
    ///
    /// **Le premier chapitre de chaque deck se lit en entier** — sur le site — et
    /// c'est lui qui montre ce que vaut une fiche. Les suivants s'ouvrent, se lisent sur
    /// trois dixièmes, et le reste se devine derrière le flou : assez pour savoir que la
    /// fiche continue, pas assez pour s'en passer.
    static let readableSheetRatio = 0.3

    /// Le nombre de cartes qu'on révise par jour sans payer, toutes sessions confondues.
    ///
    /// **Une seule.** La carte qui montre le geste — lire, retourner, noter — et le paywall
    /// tout de suite après : c'est la démonstration, pas un service. Par jour et non par
    /// session : une limite par session se contournait en relançant la session.
    static let cardsPerDay = 1

    /// L'entraînement libre est réservé à Pro.
    ///
    /// C'est la seule limite qui ferme une porte entière plutôt que d'en entrouvrir une, et
    /// elle se tient : réviser ce qui est dû est le service que Micabo rend, s'entraîner à
    /// volonté sur tout un paquet est ce qu'on fait la veille d'un partiel.
    static let allowsPractice = false
}

/// **Ce que Mika laisse demander.**
///
/// Une question offerte, une seule, pour toujours : c'est la démonstration, comme le
/// premier cours. Et pour un abonné, un plafond par jour — un fusible de coût, pas un
/// palier commercial : il ne s'écrit nulle part tant qu'on ne l'atteint pas. Le serveur
/// tient les mêmes nombres (`_shared/mika.ts`) ; l'app les applique en premier, pour que
/// le refus arrive avant l'appel, pas après.
enum MikaAllowance {
    static let freeQuestions = 1
    static let proMessagesPerDay = 30
}

/// Comptes développeur : Pro à vie, sans abonnement.
///
/// La table `entitlements` ne suffit pas : le compte peut ne pas encore
/// exister, et un webhook RevenueCat peut refermer une ligne offerte. La
/// liste vit donc ici, et dans `entitlement.ts` — `freemium-parity.test.ts`
/// relit ces adresses.
enum LifetimePro {
    static let emails: Set<String> = [
        "adrien.not@gmail.com"
    ]

    static func matches(_ raw: String?) -> Bool {
        guard let raw else { return false }
        return emails.contains(raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

/// **D'où vient l'abonnement**, donc où il se gère. Les valeurs sont celles de la colonne
/// `entitlements.store`, que le webhook normalise.
enum SubscriptionStore: String, Equatable, Sendable {
    case appStore = "app_store"
    case playStore = "play_store"
    case stripe
    case promotional

    /// La page où l'on gère cet abonnement, chez celui qui l'encaisse. `nil` pour un accès
    /// offert : il n'y a rien à gérer, et un bouton qui ouvrirait l'App Store vide mentirait.
    var manageURL: URL? {
        switch self {
        case .appStore:
            URL(string: "https://apps.apple.com/account/subscriptions")
        case .playStore:
            URL(string: "https://play.google.com/store/account/subscriptions?package=com.micabo.app")
        case .stripe:
            // Le portail Stripe s'ouvre depuis le profil du site, connecté au même compte.
            URL(string: "https://www.micabo.app/app/profil")
        case .promotional:
            nil
        }
    }
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

    /// **La fin de l'essai gratuit en cours**, `nil` hors essai : jamais commencé, fini, ou
    /// déjà payé. Le rappel du jour (`DailyReminder`) ne commence qu'après.
    private(set) var trialEndsAt: Date?

    /// **D'où vient l'abonnement ouvert**, `nil` quand on ne le sait pas : « Gérer
    /// l'abonnement » ouvre alors l'App Store, comme avant.
    private(set) var store: SubscriptionStore?

    /// Même règle que le web (`ASSUME_PRO_WITHOUT_ROW`, à `false`) : pas de ligne, pas
    /// d'abonnement. Les deux clients doivent dire la même chose — un cours flouté sur le
    /// web et ouvert sur le téléphone, c'est le même produit qui dit deux choses.
    static let assumeProWithoutRow = false

    init(
        defaults: UserDefaults = .standard,
        accessToken: (() async -> String?)? = nil,
        userID: (() -> UUID?)? = nil,
        email: (() -> String?)? = nil
    ) {
        self.defaults = defaults
        self.accessToken = accessToken
        self.userID = userID
        self.email = email
        self.isPro = defaults.bool(forKey: Key.isPro)
    }

    private let defaults: UserDefaults
    private let accessToken: (() async -> String?)?
    private let userID: (() -> UUID?)?
    private let email: (() -> String?)?
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
        #if DEBUG
        // Un forçage tient contre tout le reste. Sans ce passage obligé, l'interrupteur des
        // réglages se défaisait tout seul : `refresh()` relit le SDK et la table à chaque
        // lancement et à chaque retour au premier plan, et remettait l'abonnement réel.
        if let forced = debugProOverride {
            forced ? unlock() : lock()
            return
        }
        #endif
        value ? unlock() : lock()
    }

    #if DEBUG
    /// **L'interrupteur Pro des constructions de développement.**
    ///
    /// Un mur d'abonnement se règle en le regardant : la moitié floutée d'une fiche, le
    /// cadenas sur l'entraînement libre, le cadeau du premier cours. Les voir demandait de
    /// se connecter à un compte gratuit, puis à un compte payant, et de croiser les doigts
    /// pour que le webhook suive.
    ///
    /// `nil` veut dire « rien n'est forcé » : l'abonnement réel décide, comme partout
    /// ailleurs. C'est bien un triple état, et pas un booléen, sans quoi on ne pourrait
    /// plus revenir à la vérité du compte une fois l'interrupteur touché.
    static let debugProOverrideKey = "micabo.debug.proOverride"

    var debugProOverride: Bool? {
        get { defaults.object(forKey: Self.debugProOverrideKey) as? Bool }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.debugProOverrideKey)
                newValue ? unlock() : lock()
            } else {
                defaults.removeObject(forKey: Self.debugProOverrideKey)
            }
        }
    }
    #endif

    /// Relit l'état de l'abonnement.
    ///
    /// **Le plus généreux des deux gagne.** Le SDK et la table doivent s'accorder ; quand ils
    /// divergent — le webhook a une seconde de retard, ou l'achat vient d'être fait sur le
    /// web — enfermer dehors quelqu'un qui paye est pire qu'une minute offerte.
    ///
    /// Une échéance passée l'emporte sur le drapeau de la table : un webhook peut se perdre,
    /// et un abonnement fini qui reste ouvert est une fuite qui ne se voit pas.
    func refresh() async {
        // Un compte développeur reste Pro même sans ligne, et même si un
        // webhook a refermé la sienne : l'adresse l'emporte sur le SDK et
        // sur la table.
        if LifetimePro.matches(email?()) {
            trialEndsAt = nil
            store = .promotional
            setPro(true)
            return
        }

        let fromSDK = await PurchasesBridge.entitlement()
        let fromTable = await readEntitlementRow()
        // L'essai selon le SDK quand il répond : il sait avant le webhook qu'un essai est
        // devenu un abonnement. La table sinon, pour un achat fait ailleurs.
        trialEndsAt = fromSDK.map(\.trialEndsAt) ?? fromTable?.trialEndsAt
        // Le magasin du droit ouvert : le SDK d'abord, la table pour un achat fait ailleurs.
        store = (fromSDK?.isPro == true ? fromSDK?.store : nil)
            ?? (fromTable?.isPro == true ? fromTable?.store : nil)

        // Personne ne sait rien : le réglage tranche, et il dit non.
        guard fromSDK != nil || fromTable != nil else {
            setPro(Self.assumeProWithoutRow)
            return
        }

        setPro(fromSDK?.isPro == true || fromTable?.isPro == true)
    }

    /// S'abonne au flux du SDK : un abonnement résilié se referme **sans redémarrage**.
    ///
    /// Le flux ne parle que d'Apple. Il ouvre tout seul ; il ne referme pas ce qu'un achat
    /// web a ouvert, et repasse donc par `refresh()` pour arbitrer les deux sources.
    func observePurchases() {
        guard purchaseWatch == nil else { return }
        purchaseWatch = Task { [weak self] in
            for await state in PurchasesBridge.proUpdates() {
                guard let self else { return }
                if state.isPro {
                    // Un essai qui commence, ou qui devient un abonnement, se lit ici.
                    self.trialEndsAt = state.trialEndsAt
                    if let store = state.store { self.store = store }
                    self.setPro(true)
                } else {
                    await self.refresh()
                }
            }
        }
    }

    /// La ligne `entitlements`, ou `nil` quand on n'a pas pu la lire. `nil` n'est pas « non ».
    private func readEntitlementRow() async -> (isPro: Bool, trialEndsAt: Date?, store: SubscriptionStore?)? {
        guard let token = await accessToken?(), let userID = userID?() else { return nil }

        do {
            let database = SupabaseDatabase(accessToken: { token })
            let rows = try await database.rows(
                EntitlementRecord.self,
                from: CloudTable.entitlements,
                filters: [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())")],
                limit: 1
            )
            guard let row = rows.first else { return (false, nil, nil) }
            let expired = row.expires_at.map { $0 < Date() } ?? false
            let active = row.is_pro && !expired
            let inTrial = active && row.period_type?.lowercased() == "trial"
            return (
                active,
                inTrial ? (row.expires_at ?? .distantFuture) : nil,
                row.store.flatMap { SubscriptionStore(rawValue: $0.lowercased()) }
            )
        } catch {
            return nil
        }
    }

    // MARK: - Les portes

    /// Peut-on encore importer un cours ?
    ///
    /// Les cours repris dans la bibliothèque ne comptent pas : ils n'ont rien coûté à
    /// produire, et faire payer un import qu'on n'a pas fait serait incompréhensible. Le
    /// cours de démonstration du parcours d'accueil (`sample`) ne compte pas non plus : il
    /// n'est pas le cours de l'élève, et il ne doit pas consommer le seul import offert.
    func canImportCourse(existingCourses courses: [Course]) -> Bool {
        canImportCourse(ownedCourses: courses.filter { !$0.isFromLibrary && $0.source != .sample }.count)
    }

    /// La même porte, à partir du seul nombre qui l'ouvre ou la ferme.
    ///
    /// Les écrans qui la posent n'ont pas besoin de tenir la liste des cours pour ça : un
    /// `CourseRepository.ownedCount(in:)` leur donne l'entier sans matérialiser une ligne.
    /// La version au-dessus reste pour les appels qui ont déjà la liste sous la main.
    func canImportCourse(ownedCourses count: Int) -> Bool {
        guard !isPro else { return true }
        return count < FreeTier.courses
    }

    var canPractice: Bool {
        isPro || FreeTier.allowsPractice
    }

    /// Vrai à partir de la carte qui doit rester derrière le paywall, en comptant tout ce
    /// qui a déjà été révisé dans la journée.
    func hasReachedDailyLimit(reviewedToday: Int) -> Bool {
        !isPro && reviewedToday >= FreeTier.cardsPerDay
    }
}
