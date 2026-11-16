import Foundation

/// **Le mode test des paywalls : TestFlight et les constructions Xcode, jamais l'App Store.**
///
/// « J'vois pas le paywall » (lot 9) : le compte de test du développeur est Pro à vie
/// (`LifetimePro`), et `ProAccess.refresh()` l'ouvre dès le lancement — la session survit à
/// la réinstallation, dans le trousseau. Pro ouvert, le parcours se termine sans paywall
/// (`PaywallStepView`), la leçon lue ne se verrouille pas (`LessonCreationFlow`), aucune porte
/// ne se ferme : le paywall ne se voyait plus nulle part. Un compte qui a pris l'essai en bac
/// à sable est dans le même cas.
///
/// La section « Test » des réglages le montre quand même — le paywall, l'offre de secours, le
/// parcours refait jusqu'au paywall — **seulement là où l'achat est en bac à sable** : un
/// reçu `sandboxReceipt` (TestFlight, et la relecture d'Apple) ou une construction Xcode.
/// Sur l'App Store, le reçu s'appelle `receipt` et la section n'existe pas. Le compte de
/// relecture d'Apple ne la voit pas non plus : sa relecture tourne sur un reçu de bac à sable,
/// et une section de test dans une app relue se lit comme une app inachevée.
enum PaywallTestMode {
    /// Le nom du reçu d'une app installée par TestFlight (et par la relecture d'Apple).
    static let sandboxReceiptName = "sandboxReceipt"

    /// **Où la section existe**, sans dépendre de la construction qui fait tourner les tests.
    ///
    /// - Construction Xcode (`DEBUG`) : toujours.
    /// - Reçu de bac à sable (TestFlight) : pour tout compte, sauf celui de la relecture.
    /// - Tout autre reçu (l'App Store), ou pas de reçu : jamais.
    static func isAvailable(receiptName: String?, isDebugBuild: Bool, email: String?) -> Bool {
        if isDebugBuild { return true }
        guard receiptName == sandboxReceiptName else { return false }
        return !AppStoreReview.matches(email)
    }

    /// La même décision, pour l'app qui tourne.
    static func isAvailable(email: String?) -> Bool {
        isAvailable(receiptName: receiptName, isDebugBuild: isDebugBuild, email: email)
    }

    /// Le nom du reçu de cette installation, `nil` quand il n'y en a pas.
    static var receiptName: String? {
        Bundle.main.appStoreReceiptURL?.lastPathComponent
    }

    static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Le parcours refait jusqu'au paywall

    /// Posé par « Refaire l'onboarding » : le paywall de la fin s'affiche même à un abonné.
    /// Effacé à la fin du parcours, pour que le suivant redevienne normal.
    static let onboardingPaywallKey = "micabo.test.onboardingPaywall"

    /// **Le parcours se termine-t-il sur le paywall ?** Toujours pour un élève sans
    /// abonnement. Pour un abonné : quand le test l'a demandé, et **dans toute construction
    /// interne** (Xcode, TestFlight : `BuildChannel.isInternal`, lot 12) — le compte du
    /// développeur est Pro à vie, et c'est là qu'on juge le parcours ; le paywall s'y montre
    /// en aperçu, sans achat possible (`PaywallFlowView.previewsPro`). Seul un vrai abonné de
    /// l'App Store finit le parcours sans paywall : on ne lui propose pas ce qu'il paie déjà.
    static func showsOnboardingPaywall(isPro: Bool, forcedByTest: Bool, isInternal: Bool = false) -> Bool {
        !isPro || forcedByTest || isInternal
    }

    /// Vrai quand « Refaire l'onboarding » a demandé le paywall. Ne vaut que là où la section
    /// existe : une valeur restée sur l'appareil ne change rien à une app de l'App Store.
    static func forcesOnboardingPaywall(defaults: UserDefaults = .standard) -> Bool {
        guard isAvailable(receiptName: receiptName, isDebugBuild: isDebugBuild, email: nil) else { return false }
        return defaults.bool(forKey: onboardingPaywallKey)
    }

    static func setForcesOnboardingPaywall(_ value: Bool, defaults: UserDefaults = .standard) {
        if value {
            defaults.set(true, forKey: onboardingPaywallKey)
        } else {
            defaults.removeObject(forKey: onboardingPaywallKey)
        }
    }
}
