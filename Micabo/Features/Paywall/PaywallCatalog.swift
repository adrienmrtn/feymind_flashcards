import Foundation

/// Rythme de facturation d'un abonnement.
enum PaywallPeriod {
    case week
    case year

    /// Le mot qui suit la barre oblique : « 7,99 € / semaine ».
    var unit: String {
        switch self {
        case .week: L10n.t("ios.unitWeek", locale: .resolved())
        case .year: L10n.t("ios.unitYear", locale: .resolved())
        }
    }

    /// Combien de fois par an la somme est prélevée. Sert à comparer deux offres qui ne
    /// se paient pas au même rythme : sans ce ramené à l'année, « 7,99 € » a l'air moins
    /// cher que « 69,99 € ».
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
    let price: Decimal
    let period: PaywallPeriod
    /// Jours d'essai. Zéro : rien n'est offert, et le bouton ne doit pas le dire.
    let trialDays: Int

    var id: Kind { kind }

    var title: String {
        switch kind {
        case .yearly: L10n.t("ios.planYearly", locale: .resolved())
        case .weekly: L10n.t("ios.planWeekly", locale: .resolved())
        }
    }

    var hasTrial: Bool { trialDays > 0 }

    /// « 69,99 € », ou ce que la boutique du pays annonce.
    ///
    /// **Le prix écrit n'est plus qu'un repli.** Il est celui de la France, et un étudiant
    /// turc à qui l'on annonce des euros pendant qu'Apple lui prélève des livres lit un
    /// chiffre faux — pas approximatif, faux. `PaywallStorePrices` garde ce que
    /// l'offering a répondu, dans la devise et le format du pays ; le nombre d'ici ne sert
    /// plus qu'avant la réponse du réseau, pour qu'un paywall ne s'ouvre jamais vide.
    var displayPrice: String {
        PaywallStorePrices.price(for: productID)?.localized ?? PaywallPrice.text(price)
    }

    /// Ce que l'offre coûte sur douze mois, quel que soit son rythme de prélèvement.
    ///
    /// Il reste calculé sur le prix **écrit**, et c'est voulu : `savingsPercent` compare
    /// l'annuel à l'hebdomadaire, et une remise qui changerait de quelques points selon le
    /// pays ferait mentir le sceau « −43 % » imprimé à côté.
    var annualCost: Decimal {
        price * period.occurrencesPerYear
    }

    /// Le prix ramené au mois, pour les offres qui se paient d'un bloc.
    ///
    /// C'est **le seul chiffre qu'un étudiant sait comparer**. Personne ne divise
    /// mentalement 69,99 par douze devant un paywall, et personne ne multiplie 7,99 par
    /// cinquante-deux : le mois est l'unité dans laquelle un budget se pense.
    ///
    /// Il se divise dans la même monnaie que l'annuel affiché juste à côté. Deux nombres
    /// sur une même carte doivent parler de la même somme : un mensuel en euros posé sous
    /// un annuel en livres turques est pire que pas de mensuel du tout.
    var monthlyEquivalent: String? {
        guard period == .year else { return nil }
        if let store = PaywallStorePrices.price(for: productID),
           let text = store.formatted(store.amount / 12) {
            return text
        }
        return PaywallPrice.text(price / 12)
    }

    /// **Le grand chiffre du paywall, et c'est le mois.**
    ///
    /// Les deux nombres d'une offre annuelle ne pèsent pas pareil : « 69,99 € » est la
    /// somme prélevée, « 5,83 € » est celle qu'on compare. Personne ne divise soixante-dix
    /// par douze devant un paywall, et une offre annoncée à son prix annuel se lit comme
    /// chère avant d'être lue comme avantageuse. Le mois passe donc en grand, et l'annuel
    /// descend dans `caption` — il n'est pas caché, il n'est plus ce qu'on lit en premier.
    ///
    /// Une offre qui n'a pas de mensuel — l'hebdomadaire — garde son propre prix : il est
    /// déjà dans l'unité où on le compare.
    var headlinePrice: String { monthlyEquivalent ?? displayPrice }

    /// L'unité du grand chiffre, qui doit toujours l'accompagner : « 5,83 € » posé sous un
    /// titre « Annuel » se lit comme le prix de l'année.
    var headlineUnit: String {
        switch period {
        case .year: L10n.t("app.paywall.perMonthSlash", locale: .resolved())
        case .week: L10n.t("app.paywall.perWeekSlash", locale: .resolved())
        }
    }

    /// La ligne posée sous le nom de l'offre : **ce qui part vraiment du compte**, et à
    /// quel rythme. C'est la contrepartie du mois affiché en grand — annoncer un mensuel
    /// sans dire qu'il est prélevé d'un bloc une fois l'an serait le maquiller.
    var caption: String {
        guard period == .year else {
            return L10n.t("ios.billedEach", locale: .resolved(), vars: ["unit": period.unit])
        }
        return L10n.t("ios.billedYearly", locale: .resolved(), vars: ["price": displayPrice])
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
        price: 69.99,
        period: .year,
        trialDays: 3
    )

    static let weekly = PaywallPlan(
        kind: .weekly,
        productID: "com.micabo.app.pro.weekly",
        price: 7.99,
        period: .week,
        trialDays: 0
    )

    /// Tarif réduit, hors paywall. Le chemin pour y accéder n'est pas encore ouvert.
    static let discount = PaywallPlan(
        kind: .yearly,
        productID: "com.micabo.app.pro.yearly.discount",
        price: 39.99,
        period: .year,
        trialDays: 0
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

/// Écriture des sommes, dans la seule forme qu'on affiche : « 69,99 € ».
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

/// **Ce que la boutique a répondu**, et la seule source d'un prix affiché dès qu'elle a
/// répondu.
///
/// Les six prix du catalogue sont ceux de la France. Tant qu'ils étaient les seuls, un
/// étudiant turc lisait « 39,99 € » pendant qu'Apple lui prélevait des livres turques :
/// un prix faux affiché à côté d'un bouton d'achat, ce qui se refuse à la relecture
/// App Store autant que ça se mérite.
///
/// Le cache est rempli une fois par lancement et à l'ouverture de chaque paywall, jamais
/// pendant le rendu : une vue qui déclencherait un appel réseau pour s'afficher clignoterait
/// à chaque image. Tant qu'il est vide, tout retombe sur les prix écrits — c'est ce qui
/// évite un paywall aux prix manquants pendant la seconde d'attente du réseau.
///
/// **Il n'est pas isolé sur l'acteur principal**, et c'est délibéré : `displayPrice` est lu
/// par les tests hors de tout acteur, et l'isoler obligerait à faire remonter `@MainActor`
/// jusqu'à `PaywallPitch`. Les écritures viennent toutes de `PaywallPurchases.refreshPrices()`,
/// qui est `@MainActor`.
enum PaywallStorePrices {
    /// Un prix tel que la boutique le donne : la somme, sa mise en forme locale, et de quoi
    /// en dériver un mensuel dans la même monnaie.
    struct StorePrice {
        let localized: String
        let amount: Decimal
        let currencyCode: String?
        /// Le formateur du produit, celui d'Apple pour ce pays. Absent sur certains
        /// produits : on retombe alors sur la somme telle quelle.
        let formatter: NumberFormatter?

        func formatted(_ value: Decimal) -> String? {
            formatter?.string(from: value as NSDecimalNumber)
        }
    }

    private static var byProduct: [String: StorePrice] = [:]

    static func price(for productID: String) -> StorePrice? {
        byProduct[productID]
    }

    /// Vrai quand la boutique a répondu et qu'elle vend dans une autre monnaie que l'euro.
    /// Sert au seul endroit où un prix reste écrit à la main : le mensuel du cadeau.
    static func isForeignCurrency(_ productID: String) -> Bool {
        guard let code = byProduct[productID]?.currencyCode else { return false }
        return code.uppercased() != "EUR"
    }

    static func store(_ prices: [String: StorePrice]) {
        guard !prices.isEmpty else { return }
        byProduct.merge(prices) { _, fresh in fresh }
    }
}

/// Issue d'un achat ou d'une restauration.
enum PaywallOutcome: Equatable {
    case purchased
    case cancelled
    /// **La boutique n'a pas pu vendre** : aucun produit publié, aucun SDK branché, ou le
    /// réseau est tombé. Ce n'est jamais un achat, et les paywalls ne l'ouvrent pas.
    case unavailable
}

/// Les deux liens qu'Apple exige sur un écran d'abonnement.
enum PaywallLinks {
    /// Adresses à confirmer avant la première soumission : un paywall dont les deux liens
    /// ne mènent nulle part se fait refuser à la relecture.
    static let terms = "https://micabo.app/conditions"
    static let privacy = "https://micabo.app/confidentialite"
}
