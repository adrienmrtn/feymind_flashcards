import Foundation

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
/// Ce qui n'est *pas* conditionnel : le contrat. `buy` rend `purchased`, `cancelled` ou
/// `unavailable`, et les deux paywalls ne connaissent que ces trois cas.
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

    static func buy(_ plan: PaywallPlan) async -> PaywallOutcome {
        #if canImport(RevenueCat)
        guard PurchasesBridge.isConfigured else { return .unavailable }

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
            return result.customerInfo.hasPro ? .purchased : .unavailable
        } catch {
            return .unavailable
        }
        #else
        _ = plan
        return .unavailable
        #endif
    }

    static func restore() async -> PaywallOutcome {
        #if canImport(RevenueCat)
        guard PurchasesBridge.isConfigured else { return .unavailable }

        do {
            let info = try await Purchases.shared.restorePurchases()
            return info.hasPro ? .purchased : .unavailable
        } catch {
            return .unavailable
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

    /// Attache — ou détache — l'identifiant Supabase. Appelé à chaque changement de compte.
    static func identify(_ userID: UUID?) async {
        #if canImport(RevenueCat)
        guard isConfigured else { return }

        if let userID {
            let wanted = userID.uuidString.lowercased()
            guard Purchases.shared.appUserID != wanted else { return }
            _ = try? await Purchases.shared.logIn(wanted)
        } else if !Purchases.shared.isAnonymous {
            _ = try? await Purchases.shared.logOut()
        }
        #else
        _ = userID
        #endif
    }

    /// L'état du droit selon le SDK, ou `nil` quand il n'a rien à dire.
    ///
    /// `nil` n'est pas « pas abonné » : c'est « je ne sais pas », et `ProAccess` retombe alors
    /// sur la table `entitlements`. Confondre les deux fermerait la porte à chaque avion.
    static func isPro() async -> Bool? {
        #if canImport(RevenueCat)
        guard isConfigured else { return nil }
        guard let info = try? await Purchases.shared.customerInfo() else { return nil }
        return info.hasPro
        #else
        return nil
        #endif
    }

    /// Le flux qui fait qu'un abonnement résilié se referme **sans redémarrage**.
    ///
    /// Un `Bool` et non un `CustomerInfo` : le type traverse les frontières d'acteur sans
    /// question, et l'appelant n'a pas à connaître RevenueCat. Sans SDK, le flux se termine
    /// tout de suite — la boucle d'en face ne tourne donc pas dans le vide.
    static func proUpdates() -> AsyncStream<Bool> {
        #if canImport(RevenueCat)
        guard isConfigured else { return AsyncStream { $0.finish() } }

        return AsyncStream { continuation in
            let task = Task {
                for await info in Purchases.shared.customerInfoStream {
                    continuation.yield(info.hasPro)
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
}
#endif

/// Le nom de l'entitlement, écrit une fois. Il est aussi en dur dans le webhook et dans
/// `packages/core/src/entitlement.ts` : les trois doivent dire la même chaîne.
enum ProEntitlement {
    static let id = "pro"
}
