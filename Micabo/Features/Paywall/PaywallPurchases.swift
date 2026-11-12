import Foundation
import OSLog
import StoreKit

#if canImport(RevenueCat)
import RevenueCat
#endif

/// **Le seul endroit par lequel un achat passe.**
///
/// Le corps est compilé conditionnellement — `#if canImport(RevenueCat)`. Ce n'est pas une
/// précaution de style : le paquet `purchases-ios` s'ajoute dans Xcode, et sans ce garde-fou
/// le dépôt ne compilerait plus entre le moment où ce fichier est écrit et celui où quelqu'un
/// ouvre Xcode. Avec, les deux états sont valides et **le second s'allume tout seul**.
///
/// Ce qui n'est *pas* conditionnel : le contrat. `buy` rend `purchased`, `cancelled`,
/// `unavailable` ou `pending`, et les deux paywalls ne connaissent que ces quatre cas.
enum PaywallPurchases {
    /// Vrai quand le SDK est là **et** configuré. Les écrans s'en servent pour ne pas
    /// promettre un achat qu'aucune boutique ne peut honorer.
    static var isReady: Bool {
        #if canImport(RevenueCat)
        return PurchasesBridge.isConfigured
        #else
        return false
        #endif
    }

    /// **Qui achète**, posé au lancement (`MicaboApp`) : le compte, sinon l'invité, ouvert à
    /// la demande (`AuthController.ensureBillingIdentity`). Sans fermeture posée (les tests),
    /// l'achat part sous l'identité que RevenueCat a déjà.
    static var billingIdentity: (() async -> (userID: UUID?, guestID: UUID?))?

    /// **Relit les prix de la boutique** et les pose dans `PaywallStorePrices`.
    ///
    /// Appelée au lancement et à l'ouverture de chaque paywall. Elle ne rend rien et
    /// n'échoue jamais bruyamment ; c'est le paywall qui attend les prix du pays et retente
    /// (`PaywallFlowView.loadPrices`, avec `fetchPrices`).
    @MainActor
    static func refreshPrices() async {
        _ = await fetchPrices()
    }

    /// **Relit les prix, et dit pourquoi ils ne sont pas venus.** `nil` quand la boutique a
    /// répondu ; les produits qu'elle a rendus sont dans `PaywallStorePrices`.
    ///
    /// C'est le même parcours d'offerings que `buy` — l'offering courant puis tous les
    /// autres — pour que le tarif du cadeau, qui vit dans son propre offering, soit lu
    /// comme les deux offres ordinaires.
    @MainActor
    static func fetchPrices() async -> PaywallFailure? {
        #if canImport(RevenueCat)
        guard PurchasesBridge.isConfigured else { return .productUnavailable }

        do {
            let offerings = try await Purchases.shared.offerings()
            let packages = (offerings.current?.availablePackages ?? [])
                + offerings.all.values.flatMap(\.availablePackages)

            var prices: [String: PaywallStorePrices.StorePrice] = [:]
            for package in packages {
                let product = package.storeProduct
                let formatter = product.priceFormatter
                prices[product.productIdentifier] = PaywallStorePrices.StorePrice(
                    localized: product.localizedPriceString,
                    amount: product.price,
                    // La devise se lit sur le formateur du produit, celui d'Apple pour ce
                    // pays : c'est la même information que sur le produit, par une porte de
                    // Foundation plutôt qu'une de plus du SDK.
                    currencyCode: formatter?.currencyCode,
                    formatter: formatter
                )
            }
            PaywallStorePrices.store(prices)

            // **L'essai, compte par compte.** Apple n'en donne qu'un par groupe : qui a pris
            // les trois jours de l'hebdomadaire ne les retrouve pas sur l'annuel. `unknown`
            // ne tranche rien et laisse le catalogue parler ; `noIntroOfferExists` veut dire
            // qu'aucun essai n'est posé dans ce pays, et ne se promet donc pas non plus.
            let withTrial = PaywallCatalog.all.filter { $0.trialDays > 0 }.map(\.productID)
            let eligibility = await Purchases.shared
                .checkTrialOrIntroDiscountEligibility(productIdentifiers: withTrial)
            var known: [String: Bool] = [:]
            var notOffered: Set<String> = []
            var statuses: [String: AnalyticsValue] = [:]
            for (productID, answer) in eligibility {
                switch answer.status {
                case .eligible:
                    known[productID] = true
                case .ineligible:
                    known[productID] = false
                case .noIntroOfferExists:
                    known[productID] = false
                    notOffered.insert(productID)
                case .unknown: break
                @unknown default: break
                }
                statuses[Self.analyticsKey(productID)] = .text(Self.statusName(answer.status))
            }
            PaywallStorePrices.storeTrialEligibility(known, notOffered: notOffered)
            // **Ce que la boutique a répondu, tel quel.** « Sans essai » sur un téléphone de
            // test ne dit pas si l'essai manque dans App Store Connect ou si ce compte l'a
            // déjà pris ; cette ligne-là le dit, pays compris.
            let storefront = await StoreKit.Storefront.current
            statuses["storefront"] = .text(storefront?.countryCode ?? "inconnu")
            Analytics.track(.paywallTrialStatus, statuses)
            return nil
        } catch {
            return failure(for: error)
        }
        #else
        return .productUnavailable
        #endif
    }

    #if canImport(RevenueCat)
    /// « yearly », « weekly » : la fin de l'identifiant produit, assez pour une colonne.
    private static func analyticsKey(_ productID: String) -> String {
        productID.split(separator: ".").last.map(String.init) ?? productID
    }

    private static func statusName(_ status: IntroEligibilityStatus) -> String {
        switch status {
        case .eligible: "eligible"
        case .ineligible: "deja_utilise"
        case .noIntroOfferExists: "aucun_essai"
        case .unknown: "inconnu"
        @unknown default: "inconnu"
        }
    }
    #endif

    /// **L'acheteur, identifié avant l'achat.** Un achat parti sous `$RCAnonymousID` n'a pas de
    /// propriétaire côté serveur (le webhook le refuse) : l'élève paie, et Pro ne s'ouvre
    /// nulle part ailleurs. On ouvre donc l'invité s'il n'existe pas encore, on passe
    /// RevenueCat sous son identifiant, et on n'achète que si c'est fait.
    private static func prepareIdentity() async -> Bool {
        guard let billingIdentity else { return true }
        let identity = await billingIdentity()
        guard let userID = identity.userID else { return false }
        return await PurchasesBridge.identify(userID, guestID: identity.guestID)
    }

    static func buy(_ plan: PaywallPlan) async -> PaywallOutcome {
        #if canImport(RevenueCat)
        guard PurchasesBridge.isConfigured else { return .unavailable }
        guard await prepareIdentity() else { return .failed(.identity) }

        do {
            let offerings = try await Purchases.shared.offerings()

            // L'offering courant d'abord, puis tous les autres : c'est ce qui permet au
            // discount de s'acheter par son propre offering sans code particulier ici.
            let packages = (offerings.current?.availablePackages ?? [])
                + offerings.all.values.flatMap(\.availablePackages)

            guard let package = packages.first(where: {
                $0.storeProduct.productIdentifier == plan.productID
            }) else {
                return .unavailable
            }

            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .cancelled }
            if result.customerInfo.hasPro { return .purchased }
            // **Acheté, mais le droit ne se voit pas encore** : la boutique a encaissé, et le
            // reçu n'est pas encore passé par RevenueCat. Ce n'est pas un échec - le dire
            // faisait racheter. On relit une fois le serveur ; sinon, l'achat est en attente,
            // et `ProAccess.observePurchases` ouvrira Pro quand le flux le confirmera.
            if let fresh = try? await Purchases.shared.customerInfo(fetchPolicy: .fetchCurrent), fresh.hasPro {
                return .purchased
            }
            return .pending
        } catch {
            return outcome(for: error)
        }
        #else
        _ = plan
        return .unavailable
        #endif
    }

    #if canImport(RevenueCat)
    /// **Ce qu'une erreur d'achat veut dire.** RevenueCat rend `paymentPendingError` quand
    /// l'achat attend une validation (partage familial, banque) : ce n'est pas un échec, et
    /// le paywall ne doit pas dire « l'achat n'a pas abouti » à quelqu'un qui vient d'acheter.
    ///
    /// Un produit que la boutique ne vend pas n'est pas une panne : l'offre n'est pas ouverte
    /// (`unavailable`). Le reste se dit selon sa cause (`failure(for:)`).
    static func outcome(for error: Error) -> PaywallOutcome {
        if let code = error as? RevenueCat.ErrorCode {
            switch code {
            case .paymentPendingError: return .pending
            case .purchaseCancelledError: return .cancelled
            case .productNotAvailableForPurchaseError, .configurationError: return .unavailable
            default: break
            }
        }
        return .failed(failure(for: error))
    }

    /// **Le réseau, ou la boutique.** Les deux ne se disent pas pareil : « vérifie ta
    /// connexion » à qui a du réseau et un achat refusé par l'App Store le fait chercher au
    /// mauvais endroit.
    static func failure(for error: Error) -> PaywallFailure {
        if let code = error as? RevenueCat.ErrorCode {
            switch code {
            case .networkError, .offlineConnectionError, .productRequestTimedOut:
                return .network
            case .productNotAvailableForPurchaseError, .configurationError:
                return .productUnavailable
            default:
                return .store
            }
        }
        if error is URLError { return .network }
        return .store
    }
    #endif

    static func restore() async -> PaywallOutcome {
        #if canImport(RevenueCat)
        guard PurchasesBridge.isConfigured else { return .unavailable }
        // Une restauration sous l'identifiant anonyme rattacherait l'abonnement retrouvé à
        // personne : même règle que l'achat.
        guard await prepareIdentity() else { return .failed(.identity) }

        do {
            let info = try await Purchases.shared.restorePurchases()
            return info.hasPro ? .purchased : .unavailable
        } catch {
            return .failed(failure(for: error))
        }
        #else
        return .unavailable
        #endif
    }
}

/// **Le pont d'identité, et c'est la ligne qui fait tenir le droit multiplateforme.**
///
/// `app_user_id` chez RevenueCat **est** l'`auth.users.id` de Supabase. Un achat parti sous un
/// `$RCAnonymousID` se fait refuser par le webhook (422) : l'iPhone est Pro, le web ne le sait
/// pas, et c'est le bug qu'on ne voit que le lendemain sur l'autre appareil.
///
/// On n'aliase donc pas après coup. On identifie **avant** le premier achat.
enum PurchasesBridge {
    /// La clé publique iOS de RevenueCat (`appl_…`).
    ///
    /// Ce n'est pas un secret : elle est lisible dans n'importe quel binaire d'App Store. Elle
    /// se lit dans `Info.plist` sous `RevenueCatPublicKey`, ce qui évite de la coller dans le
    /// code et permet de la changer sans recompiler le fichier.
    static var publicKey: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "RevenueCatPublicKey") as? String
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              // Le gabarit non remplacé ne compte pas pour une clé.
              !value.hasPrefix("$("),
              value.hasPrefix("appl_")
        else { return nil }
        return value
    }

    private(set) static var isConfigured = false

    /// Configure le SDK une fois, au lancement. Sans clé, on ne configure pas : un SDK
    /// configuré avec une chaîne vide journalise à chaque appel sans rien vendre.
    static func configureIfPossible() {
        #if canImport(RevenueCat)
        guard !isConfigured, let key = publicKey else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)
        isConfigured = true
        #endif
    }

    /// Attache — ou détache — l'identifiant Supabase. Appelé à chaque changement de compte,
    /// et avant chaque achat (`PaywallPurchases.buy`).
    ///
    /// `guestID` est le compte invité de qui a passé la connexion. **Un abonnement pris sous
    /// lui doit suivre l'élève quand il se connecte** : passer de l'invité au vrai compte
    /// renvoie donc les achats de l'appareil à RevenueCat, qui les transfère au compte.
    ///
    /// Rend vrai quand RevenueCat est bien sous l'identifiant demandé. Un `logIn` qui échouait
    /// se taisait (`try?`), et l'achat qui suivait partait sous l'identifiant anonyme : il est
    /// maintenant retenté une fois, et journalisé.
    @discardableResult
    static func identify(_ userID: UUID?, guestID: UUID? = nil) async -> Bool {
        #if canImport(RevenueCat)
        guard isConfigured else { return false }

        if let userID {
            let wanted = userID.uuidString.lowercased()
            let previous = Purchases.shared.appUserID
            guard previous != wanted else { return true }
            guard let customerInfo = await logIn(wanted) else { return false }
            let leftGuest = guestID.map { previous == $0.uuidString.lowercased() } ?? false
            if leftGuest, customerInfo.entitlements[ProEntitlement.id]?.isActive != true {
                _ = try? await Purchases.shared.syncPurchases()
            }
            return Purchases.shared.appUserID == wanted
        } else if !Purchases.shared.isAnonymous {
            _ = try? await Purchases.shared.logOut()
        }
        return true
        #else
        _ = userID
        _ = guestID
        return false
        #endif
    }

    private static let log = Logger(subsystem: "app.micabo", category: "store")

    #if canImport(RevenueCat)
    /// `logIn`, retenté une fois après une seconde : un réseau qui se réveille ne doit pas
    /// laisser l'achat suivant sous l'identifiant anonyme.
    private static func logIn(_ appUserID: String) async -> CustomerInfo? {
        for attempt in 1...2 {
            do {
                return try await Purchases.shared.logIn(appUserID).customerInfo
            } catch {
                log.error("RevenueCat logIn, essai \(attempt, privacy: .public) : \(error.localizedDescription, privacy: .public)")
                if attempt == 1 { try? await Task.sleep(for: .seconds(1)) }
            }
        }
        return nil
    }
    #endif

    /// Ce que le SDK sait du droit : ouvert ou non, et la fin de l'essai quand c'en est un.
    struct EntitlementState: Equatable, Sendable {
        var isPro: Bool
        /// La fin de l'essai gratuit en cours, `nil` hors essai. Un essai dont la date
        /// manque vaut `.distantFuture` : il reste un essai.
        var trialEndsAt: Date?
        /// Vrai dès qu'un essai ou un abonnement Pro a existé sur ce compte, fini ou non.
        var everHadPro: Bool = false
        /// D'où vient le droit ouvert, `nil` quand il est fermé ou que le SDK ne le dit pas.
        var store: SubscriptionStore? = nil
    }

    /// L'état du droit selon le SDK, ou `nil` quand il n'a rien à dire.
    ///
    /// `nil` n'est pas « pas abonné » : c'est « je ne sais pas », et `ProAccess` retombe alors
    /// sur la table `entitlements`. Confondre les deux fermerait la porte à chaque avion.
    static func entitlement() async -> EntitlementState? {
        #if canImport(RevenueCat)
        guard isConfigured else { return nil }
        guard let info = try? await Purchases.shared.customerInfo() else { return nil }
        return info.entitlementState
        #else
        return nil
        #endif
    }

    /// Le flux qui fait qu'un abonnement résilié se referme **sans redémarrage**.
    ///
    /// Un `EntitlementState` et non un `CustomerInfo` : le type traverse les frontières
    /// d'acteur sans question, et l'appelant n'a pas à connaître RevenueCat. Sans SDK, le flux se termine
    /// tout de suite — la boucle d'en face ne tourne donc pas dans le vide.
    static func proUpdates() -> AsyncStream<EntitlementState> {
        #if canImport(RevenueCat)
        guard isConfigured else { return AsyncStream { $0.finish() } }

        return AsyncStream { continuation in
            let task = Task {
                for await info in Purchases.shared.customerInfoStream {
                    continuation.yield(info.entitlementState)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        #else
        return AsyncStream { $0.finish() }
        #endif
    }
}

#if canImport(RevenueCat)
private extension CustomerInfo {
    /// Le nom de l'entitlement est fixé par `docs/revenuecat.md`, et les six produits —
    /// trois App Store, trois Stripe, discount compris — l'ouvrent tous.
    var hasPro: Bool {
        entitlements[ProEntitlement.id]?.isActive == true
    }

    var entitlementState: PurchasesBridge.EntitlementState {
        let pro = entitlements[ProEntitlement.id]
        let inTrial = pro?.isActive == true && pro?.periodType == .trial
        return .init(
            isPro: hasPro,
            trialEndsAt: inTrial ? (pro?.expirationDate ?? .distantFuture) : nil,
            everHadPro: hasPro || entitlements.all[ProEntitlement.id] != nil,
            store: hasPro ? pro.flatMap { SubscriptionStore(revenueCat: $0.store) } : nil
        )
    }
}

private extension SubscriptionStore {
    /// Les magasins que RevenueCat nomme, ramenés aux quatre que la table connaît. Un magasin
    /// qu'on ne vend pas (Amazon, Paddle…) ne dit pas où gérer : `nil`.
    init?(revenueCat store: Store) {
        switch store {
        case .appStore, .macAppStore: self = .appStore
        case .playStore: self = .playStore
        case .stripe, .rcBilling: self = .stripe
        case .promotional: self = .promotional
        default: return nil
        }
    }
}
#endif

/// Le nom de l'entitlement, écrit une fois. Il est aussi en dur dans le webhook et dans
/// `packages/core/src/entitlement.ts` : les trois doivent dire la même chaîne.
enum ProEntitlement {
    static let id = "pro"
}
