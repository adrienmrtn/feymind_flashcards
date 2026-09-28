import Foundation

/// Rythme de facturation d'un abonnement.
enum PaywallPeriod {
    case week
    case year

    /// Le mot qui suit la barre oblique : « 4,99 € / semaine ».
    var unit: String {
        switch self {
        case .week: L10n.t("ios.unitWeek", locale: .resolved())
        case .year: L10n.t("ios.unitYear", locale: .resolved())
        }
    }

    /// Combien de fois par an la somme est prélevée. Sert à comparer deux offres qui ne
    /// se paient pas au même rythme : sans ce ramené à l'année, « 4,99 € » a l'air moins
    /// cher que « 49,99 € ».
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

    /// **Un essai qu'on peut vraiment promettre.**
    ///
    /// Apple n'offre qu'un essai par groupe d'abonnements : qui a pris les trois jours de
    /// l'hebdomadaire ne les retrouve pas sur l'annuel, et qui a déjà été abonné ne les
    /// retrouve nulle part. Annoncer « 3 jours gratuits » à quelqu'un qu'Apple va prélever
    /// tout de suite est exactement ce que la relecture App Store sanctionne (3.1.2).
    ///
    /// Tant que la boutique n'a rien dit, on suit le catalogue : c'est le cas d'un premier
    /// lancement, et donc du plus grand nombre.
    var hasTrial: Bool {
        trialDays > 0 && !PaywallStorePrices.isIneligibleForTrial(productID)
    }

    /// « 49,99 € », ou ce que la boutique du pays annonce.
    ///
    /// **Le prix écrit n'est plus qu'un repli.** Il est celui de la France, et un étudiant
    /// turc à qui l'on annonce des euros pendant qu'Apple lui prélève des livres lit un
    /// chiffre faux — pas approximatif, faux. `PaywallStorePrices` garde ce que
    /// l'offering a répondu, dans la devise et le format du pays ; le nombre d'ici ne sert
    /// plus qu'avant la réponse du réseau, pour qu'un paywall ne s'ouvre jamais vide.
    var displayPrice: String {
        PaywallStorePrices.price(for: productID)?.localized ?? PaywallPrice.text(price)
    }

    /// Ce que l'offre coûte sur douze mois, quel que soit son rythme de prélèvement, au
    /// prix **écrit** — celui de la France.
    var annualCost: Decimal {
        price * period.occurrencesPerYear
    }

    /// La même somme au prix **de la boutique du pays**, dans sa devise.
    ///
    /// Les prix changent d'un pays à l'autre, et pas tous dans la même proportion : aux
    /// États-Unis l'annuel vaut 7,5 hebdomadaires, en France 10. Un pourcentage calculé sur
    /// les prix français dirait « −81 % » à un Américain qui lit $7.99 et $59.99 — soit
    /// −86 %. `nil` tant que la boutique n'a pas répondu.
    var storeAnnualCost: (amount: Decimal, currency: String?)? {
        guard let store = PaywallStorePrices.price(for: productID) else { return nil }
        return (store.amount * period.occurrencesPerYear, store.currencyCode)
    }

    /// Le prix ramené au mois, pour les offres qui se paient d'un bloc.
    ///
    /// C'est **le seul chiffre qu'un étudiant sait comparer**. Personne ne divise
    /// mentalement 49,99 par douze devant un paywall, et personne ne multiplie 4,99 par
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
    /// Les deux nombres d'une offre annuelle ne pèsent pas pareil : « 49,99 € » est la
    /// somme prélevée, « 4,17 € » est celle qu'on compare. Personne ne divise cinquante
    /// par douze devant un paywall, et une offre annoncée à son prix annuel se lit comme
    /// chère avant d'être lue comme avantageuse. Le mois passe donc en grand, et l'annuel
    /// descend dans `caption` — il n'est pas caché, il n'est plus ce qu'on lit en premier.
    ///
    /// Une offre qui n'a pas de mensuel — l'hebdomadaire — garde son propre prix : il est
    /// déjà dans l'unité où on le compare.
    var headlinePrice: String { monthlyEquivalent ?? displayPrice }

    /// L'unité du grand chiffre, qui doit toujours l'accompagner : « 4,17 € » posé sous un
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
///
/// **Les prix écrits ici sont ceux de la France**, et seulement un repli : chaque pays a
/// le sien, posé dans App Store Connect depuis `store/pricing.json` (voir
/// `docs/revenuecat.md`, §15). Les trois offres gardent partout le même rapport — l'annuel
/// vaut dix hebdomadaires, le tarif réduit 40 % de moins que l'annuel —, sauf aux
/// États-Unis, où l'annuel reste au prix du marché.
enum PaywallCatalog {
    /// La durée de l'essai vient de la chronologie affichée deux écrans plus tôt : la date
    /// annoncée et la date facturée ne peuvent pas diverger si elles sortent du même nombre.
    static let freeTrialDays = TrialTimeline.freeDays

    static let yearly = PaywallPlan(
        kind: .yearly,
        productID: "com.micabo.app.pro.yearly",
        price: 49.99,
        period: .year,
        trialDays: freeTrialDays
    )

    /// **Trois jours offerts, comme l'annuel.** L'hebdomadaire est l'offre de celui qui
    /// a un partiel dans dix jours : lui demander de payer avant d'avoir vu un seul cours
    /// transformé, c'était lui demander de parier. Apple ne donne qu'un essai par groupe,
    /// donc ces trois jours-là ne s'ajoutent jamais à ceux de l'annuel.
    static let weekly = PaywallPlan(
        kind: .weekly,
        productID: "com.micabo.app.pro.weekly",
        price: 4.99,
        period: .week,
        trialDays: freeTrialDays
    )

    /// Tarif réduit, hors paywall : on y entre par l'offre cadeau (`DiscountOffer`).
    static let discount = PaywallPlan(
        kind: .yearly,
        productID: "com.micabo.app.pro.yearly.discount",
        price: 29.99,
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
        savings(of: yearly, against: weekly)
    }

    /// **La remise que lit ce pays-ci.**
    ///
    /// Sur les prix de la boutique dès qu'elle a répondu pour les deux offres **dans la
    /// même devise** — c'est le seul calcul que les deux prix affichés juste en dessous ne
    /// peuvent pas contredire. Sinon, sur les prix écrits : la grille garde le même rapport
    /// dans presque tous les pays, et c'est le repli d'avant la réponse du réseau.
    static func savings(of discounted: PaywallPlan, against reference: PaywallPlan) -> Int {
        if let full = reference.storeAnnualCost,
           let cheaper = discounted.storeAnnualCost,
           full.currency == cheaper.currency {
            return percentOff(cheaper.amount, from: full.amount)
        }
        return percentOff(discounted.annualCost, from: reference.annualCost)
    }

    private static func percentOff(_ cheaper: Decimal, from reference: Decimal) -> Int {
        let full = NSDecimalNumber(decimal: reference).doubleValue
        let discounted = NSDecimalNumber(decimal: cheaper).doubleValue
        guard full > 0 else { return 0 }
        return Int(((1 - discounted / full) * 100).rounded())
    }

    static func plan(_ kind: PaywallPlan.Kind) -> PaywallPlan {
        all.first { $0.kind == kind } ?? recommended
    }
}

/// Écriture des sommes, dans la seule forme qu'on affiche : « 49,99 € ».
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

    /// Les produits dont on **sait** qu'ils n'ouvriront pas d'essai à ce compte : essai
    /// déjà consommé dans le groupe, ou aucun essai posé dans ce pays. Un produit absent
    /// d'ici n'est pas « éligible » : c'est « la boutique n'a rien dit ».
    private static var withoutTrial: Set<String> = []

    static func price(for productID: String) -> StorePrice? {
        byProduct[productID]
    }

    static func isIneligibleForTrial(_ productID: String) -> Bool {
        withoutTrial.contains(productID)
    }

    /// Remplace ce qu'on savait de l'essai, produit par produit. Un produit dont la
    /// boutique ne sait rien dire garde l'état précédent : une réponse perdue ne doit pas
    /// faire réapparaître un essai qu'on savait consommé.
    static func storeTrialEligibility(_ eligible: [String: Bool]) {
        for (productID, isEligible) in eligible {
            if isEligible {
                withoutTrial.remove(productID)
            } else {
                withoutTrial.insert(productID)
            }
        }
    }

    /// Vrai quand la boutique a répondu et qu'elle vend dans une autre monnaie que l'euro.
    /// Sert au seul endroit où un prix reste écrit à la main : le mensuel du cadeau.
    static func isForeignCurrency(_ productID: String) -> Bool {
        guard let code = byProduct[productID]?.currencyCode else { return false }
        return code.uppercased() != "EUR"
    }

    /// Oublie tout ce que la boutique a dit. Pour les tests, qui ne contactent aucune
    /// boutique et doivent retrouver le repli après avoir simulé une réponse.
    static func clear() {
        byProduct = [:]
        withoutTrial = []
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
