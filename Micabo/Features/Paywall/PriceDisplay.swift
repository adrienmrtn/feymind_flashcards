import Foundation

/// **Le test A/B de l'écriture du prix** : le même abonnement annuel, au même prix de la
/// boutique, annoncé ramené au mois (« 4,17 € / mois », variante A) ou à la semaine
/// (« 0,96 € / semaine », variante B). Rien d'autre ne change : ni produit, ni prix, ni essai,
/// ni offering. La somme prélevée reste écrite à côté (« facturé 49,99 € par an »).
///
/// **Le tirage** : une fois par installation, à pile ou face, gardé dans `UserDefaults`. Une
/// variante forcée (`setOverride`, depuis la section de test des Réglages) passe devant, sans
/// effacer le tirage.
///
/// **La lecture des résultats** : `price_display` (`monthly` ou `weekly`) voyage avec
/// `paywall_opened`, `paywall_plans_seen`, `paywall_purchase_started`, `paywall_purchased`,
/// `paywall_trial_started`, `paywall_purchase_cancelled` et `paywall_dismissed`.
enum PriceDisplay: String, CaseIterable, Sendable {
    /// Variante A, l'écriture d'avant : l'annuel ramené au mois.
    case monthly
    /// Variante B : l'annuel ramené à la semaine.
    case weekly

    static let assignmentKey = "micabo.ab.priceDisplay"
    static let overrideKey = "micabo.ab.priceDisplay.override"

    /// La variante de cette installation : la variante forcée s'il y en a une, sinon le tirage.
    static var current: PriceDisplay {
        forced(in: .standard) ?? assigned
    }

    /// Tiré une seule fois par lancement, et une seule fois par installation : un `static
    /// let` se calcule une fois, à l'abri des appels simultanés.
    private static let assigned: PriceDisplay = assignment(in: .standard)

    /// **Le tirage de l'installation**, et le seul endroit où il s'écrit. Une valeur gardée
    /// gagne ; sinon `coin` décide (vrai : la semaine) et la réponse est gardée.
    static func assignment(in defaults: UserDefaults, coin: () -> Bool = { Bool.random() }) -> PriceDisplay {
        if let raw = defaults.string(forKey: assignmentKey), let stored = PriceDisplay(rawValue: raw) {
            return stored
        }
        let drawn: PriceDisplay = coin() ? .weekly : .monthly
        defaults.set(drawn.rawValue, forKey: assignmentKey)
        return drawn
    }

    static func forced(in defaults: UserDefaults) -> PriceDisplay? {
        defaults.string(forKey: overrideKey).flatMap(PriceDisplay.init(rawValue:))
    }

    /// Force une variante (`nil` rend le tirage). Pour la relecture seulement.
    static func setOverride(_ value: PriceDisplay?, in defaults: UserDefaults = .standard) {
        if let value {
            defaults.set(value.rawValue, forKey: overrideKey)
        } else {
            defaults.removeObject(forKey: overrideKey)
        }
    }

    /// L'étiquette des statistiques.
    var analyticsValue: AnalyticsValue { .text(rawValue) }
}
