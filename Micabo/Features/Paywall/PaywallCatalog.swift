import Foundation

/// Rythme de facturation d'un abonnement.
enum PaywallPeriod {
    case week
    case year

    /// Le mot qui suit la barre oblique : « 7,99 € / semaine ».
    var unit: String {
        switch self {
        case .week: "semaine"
        case .year: "an"
        }
    }

    /// Combien de fois par an la somme est prélevée. Sert à comparer deux offres qui ne
    /// se paient pas au même rythme : sans ce ramené à l'année, « 7,99 € » a l'air moins
    /// cher que « 59,99 € ».
    var occurrencesPerYear: Decimal {
        switch self {
        case .week: 52
        case .year: 1
        }
    }
}

/// Une offre d'abonnement, telle qu'elle s'affiche.
///
/// Les prix sont écrits ici et pas lus depuis la boutique : aucun produit n'est encore
/// publié, et un paywall qui n'affiche rien tant qu'App Store Connect n'a pas répondu est
/// un paywall qu'on ne peut ni relire ni faire relire. Quand RevenueCat sera branché, c'est
/// **ce type-là** qui se construira depuis un `Package` — voir `PaywallPurchases`.
struct PaywallPlan: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case yearly
        case weekly
    }

    let kind: Kind
    /// Identifiant App Store Connect, et identifiant du produit côté RevenueCat.
    let productID: String
    let title: String
    let price: Decimal
    let period: PaywallPeriod

    var id: Kind { kind }

    /// « 59,99 € »
    var displayPrice: String {
        PaywallPrice.text(price)
    }

    /// Ce que l'offre coûte sur douze mois, quel que soit son rythme de prélèvement.
    var annualCost: Decimal {
        price * period.occurrencesPerYear
    }

    /// Le prix ramené au mois, pour les offres qui se paient d'un bloc.
    ///
    /// C'est **le seul chiffre qu'un étudiant sait comparer**. Personne ne divise
    /// mentalement 59,99 par douze devant un paywall, et personne ne multiplie 7,99 par
    /// cinquante-deux : le mois est l'unité dans laquelle un budget se pense.
    var monthlyEquivalent: String? {
        guard period == .year else { return nil }
        return PaywallPrice.text(price / 12)
    }

    /// La ligne posée sous le nom de l'offre, dans la liste des plans.
    var caption: String {
        if let monthlyEquivalent {
            return "\(monthlyEquivalent) / mois"
        }
        return "facturé chaque \(period.unit)"
    }
}

/// Les offres de Micabo Pro, et rien d'autre.
///
/// **Deux offres, pas trois.** Un paywall à trois colonnes fait comparer des colonnes au
/// lieu de faire choisir : l'annuel est celui qu'on recommande, l'hebdomadaire existe pour
/// celui qui a un partiel dans dix jours et ne veut pas s'engager plus loin que ça.
enum PaywallCatalog {
    /// La durée de l'essai vient de la chronologie affichée deux écrans plus tôt : la date
    /// annoncée et la date facturée ne peuvent pas diverger si elles sortent du même nombre.
    static let freeTrialDays = TrialTimeline.freeDays

    static let yearly = PaywallPlan(
        kind: .yearly,
        productID: "com.micabo.app.pro.yearly",
        title: "Annuel",
        price: 59.99,
        period: .year
    )

    static let weekly = PaywallPlan(
        kind: .weekly,
        productID: "com.micabo.app.pro.weekly",
        title: "Hebdomadaire",
        price: 7.99,
        period: .week
    )

    /// L'ordre de la liste est l'ordre d'affichage : l'offre recommandée d'abord.
    static let all: [PaywallPlan] = [yearly, weekly]

    /// Celle qui est cochée d'avance, et la seule que le premier paywall met en avant.
    static let recommended = yearly

    /// Ce que l'annuel fait économiser par rapport à l'hebdomadaire, en pourcentage entier.
    ///
    /// Calculé, jamais écrit à la main : une remise annoncée à côté de deux prix qui la
    /// contredisent est le genre de détail qu'on ne remarque qu'une fois en production.
    static var savingsPercent: Int {
        let reference = NSDecimalNumber(decimal: weekly.annualCost).doubleValue
        let discounted = NSDecimalNumber(decimal: yearly.annualCost).doubleValue
        guard reference > 0 else { return 0 }
        return Int(((1 - discounted / reference) * 100).rounded())
    }

    static func plan(_ kind: PaywallPlan.Kind) -> PaywallPlan {
        all.first { $0.kind == kind } ?? recommended
    }
}

/// Écriture des sommes, dans la seule forme qu'on affiche : « 59,99 € ».
enum PaywallPrice {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.currencyCode = "EUR"
        return formatter
    }()

    static func text(_ amount: Decimal) -> String {
        formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) €"
    }
}

/// Issue d'un achat ou d'une restauration.
enum PaywallOutcome {
    case purchased
    case cancelled
    /// La boutique n'a rien à vendre : aucun produit publié, ou aucun SDK branché.
    case unavailable
}

/// **Le seul endroit par lequel un achat passe**, et le point de branchement de RevenueCat.
///
/// Il ne fait rien aujourd'hui, et c'est délibéré : aucun produit n'est publié sur App Store
/// Connect, donc un achat lancé maintenant échouerait sans que personne puisse distinguer
/// « le SDK n'est pas là » de « l'utilisateur a annulé ». Le paywall traite `unavailable`
/// comme une entrée dans l'app, faute de quoi le parcours n'aurait plus de sortie.
///
/// **Pour brancher RevenueCat**, il n'y a que ce fichier à toucher côté app :
///
/// 1. ajouter le paquet `purchases-ios` et configurer le SDK au lancement
///    (`Purchases.configure(withAPIKey:)` dans `MicaboApp`) ;
/// 2. remplacer le corps de `buy(_:)` par la récupération de l'offering courant, la
///    recherche du `Package` dont le `storeProduct.productIdentifier` vaut
///    `plan.productID`, puis `Purchases.shared.purchase(package:)` ;
/// 3. remplacer le corps de `restore()` par `Purchases.shared.restorePurchases()` ;
/// 4. rendre `PaywallCatalog` capable de se construire depuis l'offering, pour que les prix
///    affichés soient ceux de la boutique de l'utilisateur et non ceux écrits ici ;
/// 5. lire l'entitlement `pro` là où l'app devra fermer une porte.
enum PaywallPurchases {
    static func buy(_ plan: PaywallPlan) async -> PaywallOutcome {
        _ = plan
        return .unavailable
    }

    static func restore() async -> PaywallOutcome {
        .unavailable
    }
}

/// Les deux liens qu'Apple exige sur un écran d'abonnement.
enum PaywallLinks {
    /// Adresses à confirmer avant la première soumission : un paywall dont les deux liens
    /// ne mènent nulle part se fait refuser à la relecture.
    static let terms = "https://micabo.app/conditions"
    static let privacy = "https://micabo.app/confidentialite"
}
