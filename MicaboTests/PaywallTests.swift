import XCTest
@testable import Micabo

/// Verrouille ce qui est écrit sur les deux paywalls : les prix, la remise annoncée, et la
/// durée de l'essai, qui doit être la même que celle promise deux écrans plus tôt.
final class PaywallTests: XCTestCase {
    // MARK: - Les offres

    /// Deux offres, et l'annuelle d'abord : c'est celle qu'on recommande, et l'ordre de la
    /// liste est l'ordre d'affichage.
    func testTwoOffersAndTheYearlyComesFirst() {
        XCTAssertEqual(PaywallCatalog.all.map(\.kind), [.yearly, .weekly])
        XCTAssertEqual(PaywallCatalog.recommended.kind, .yearly)
    }

    func testThePricesAreTheOnesAnnounced() {
        XCTAssertEqual(PaywallCatalog.yearly.period, .year)
        XCTAssertEqual(PaywallCatalog.weekly.period, .week)

        XCTAssertTrue(
            PaywallCatalog.yearly.displayPrice.hasPrefix("49,99"),
            "L'annuel est à 49,99 €, pas \(PaywallCatalog.yearly.displayPrice)"
        )
        XCTAssertTrue(
            PaywallCatalog.weekly.displayPrice.hasPrefix("4,99"),
            "L'hebdomadaire est à 4,99 €, pas \(PaywallCatalog.weekly.displayPrice)"
        )
    }

    /// Le mois est la seule unité qu'on compare de tête. L'annuel doit donc dire
    /// son prix mensuel, et l'hebdomadaire ne doit pas en inventer un.
    func testOnlyTheYearlyIsRestatedPerMonth() throws {
        let monthly = try XCTUnwrap(PaywallCatalog.yearly.monthlyEquivalent)
        XCTAssertTrue(monthly.hasPrefix("4,17"), "49,99 € par an font 4,17 € par mois, pas \(monthly)")
        XCTAssertNil(PaywallCatalog.weekly.monthlyEquivalent)

        XCTAssertEqual(PaywallCatalog.weekly.caption, "facturé chaque semaine")
    }

    /// **Le grand chiffre est le mois, la petite ligne est ce qui part du compte.**
    ///
    /// L'inverse — l'annuel en gras, le mensuel en gris — faisait lire « 49,99 € » avant
    /// « 4,17 € », c'est-à-dire la somme qu'on ne compare pas avant celle qu'on compare.
    /// Les deux restent affichés : annoncer un mensuel sans dire qu'il est prélevé d'un
    /// bloc une fois l'an serait le maquiller.
    func testTheHeadlineIsTheMonthAndTheCaptionIsWhatIsCharged() {
        XCTAssertTrue(
            PaywallCatalog.yearly.headlinePrice.hasPrefix("4,17"),
            "L'annuel doit s'annoncer au mois, pas à l'année : \(PaywallCatalog.yearly.headlinePrice)"
        )
        XCTAssertEqual(PaywallCatalog.yearly.headlineUnit, "/ mois")
        XCTAssertTrue(
            PaywallCatalog.yearly.caption.contains(PaywallCatalog.yearly.displayPrice),
            "La petite ligne doit porter la somme prélevée : \(PaywallCatalog.yearly.caption)"
        )

        // L'hebdomadaire est déjà dans l'unité où on le compare : il garde son prix.
        XCTAssertTrue(PaywallCatalog.weekly.headlinePrice.hasPrefix("4,99"))
        XCTAssertEqual(PaywallCatalog.weekly.headlineUnit, "/ semaine")

        // Le tarif réduit suit la même règle, sinon les deux paywalls se contrediraient.
        XCTAssertNotEqual(PaywallCatalog.discount.headlinePrice, PaywallCatalog.discount.displayPrice)
        XCTAssertEqual(PaywallCatalog.discount.headlineUnit, "/ mois")
    }

    /// La remise est calculée, jamais écrite à la main : un pourcentage qui contredit les
    /// deux prix affichés juste en dessous ne se remarque qu'en production.
    func testTheSavingsComeFromTheTwoPrices() {
        let weeklyOverAYear = NSDecimalNumber(decimal: PaywallCatalog.weekly.annualCost).doubleValue
        XCTAssertEqual(weeklyOverAYear, 259.48, accuracy: 0.01, "4,99 € par semaine sur cinquante-deux semaines")

        XCTAssertEqual(PaywallCatalog.savingsPercent, 81)
    }

    /// **La remise se calcule sur les prix du pays**, pas sur ceux de la France.
    ///
    /// Aux États-Unis la grille met l'hebdomadaire à $7.99 et l'annuel à $59.99 : le sceau
    /// doit y dire −86 %, pas le −81 % français. Deux devises différentes — une réponse
    /// partielle — ne se comparent pas : on retombe alors sur les prix écrits.
    func testTheSavingsFollowTheStorePricesOfTheCountry() {
        defer { PaywallStorePrices.clear() }

        PaywallStorePrices.store([
            PaywallCatalog.weekly.productID: Self.storePrice(7.99, "USD"),
            PaywallCatalog.yearly.productID: Self.storePrice(59.99, "USD"),
        ])
        XCTAssertEqual(PaywallCatalog.savingsPercent, 86)

        PaywallStorePrices.store([PaywallCatalog.weekly.productID: Self.storePrice(149.99, "TRY")])
        XCTAssertEqual(PaywallCatalog.savingsPercent, 81, "Des livres contre des dollars ne font pas une remise")

        PaywallStorePrices.store([PaywallCatalog.yearly.productID: Self.storePrice(1499.99, "TRY")])
        XCTAssertEqual(PaywallCatalog.savingsPercent, 81)
    }

    private static func storePrice(_ amount: Decimal, _ currency: String) -> PaywallStorePrices.StorePrice {
        PaywallStorePrices.StorePrice(
            localized: "\(amount) \(currency)",
            amount: amount,
            currencyCode: currency,
            formatter: nil
        )
    }

    /// Le discount existe pour plus tard, et il n'apparaît pas à côté des deux offres.
    func testTheDiscountExistsButIsNotOnThePaywall() {
        XCTAssertTrue(
            PaywallCatalog.discount.displayPrice.hasPrefix("29,99"),
            "Le discount est à 29,99 €, pas \(PaywallCatalog.discount.displayPrice)"
        )
        XCTAssertEqual(PaywallCatalog.discount.productID, "com.micabo.app.pro.yearly.discount")
        XCTAssertFalse(PaywallCatalog.discount.hasTrial)
        XCTAssertFalse(PaywallCatalog.all.contains(PaywallCatalog.discount))
    }

    func testEveryOfferCarriesItsOwnProductIdentifier() {
        let identifiers = PaywallCatalog.all.map(\.productID)

        for identifier in identifiers {
            XCTAssertTrue(identifier.hasPrefix("com.micabo.app.pro."), "\(identifier) n'est pas un produit Micabo Pro")
        }

        XCTAssertEqual(Set(identifiers).count, identifiers.count, "Deux offres ne peuvent pas vendre le même produit")
        XCTAssertEqual(PaywallCatalog.plan(.weekly), PaywallCatalog.weekly)
    }

    /// Tant que rien n'est branché, la boutique répond « rien à vendre ». C'est cette
    /// réponse-là que le paywall traite comme une entrée dans l'app : sans elle, le dernier
    /// écran du parcours n'aurait pas de sortie.
    func testTheStoreIsNotWiredYetAndSaysSo() async {
        let purchase = await PaywallPurchases.buy(PaywallCatalog.yearly)
        XCTAssertEqual(purchase, .unavailable)

        let restore = await PaywallPurchases.restore()
        XCTAssertEqual(restore, .unavailable)
    }

    // MARK: - La chronologie de l'essai

    /// La durée de l'essai sort d'un seul endroit. L'écran qui annonce « trois jours » et
    /// le bouton qui les facture ne peuvent pas diverger s'ils lisent le même nombre.
    func testTheTrialLengthIsSharedWithTheTimeline() {
        XCTAssertEqual(TrialTimeline.freeDays, 3)
        XCTAssertEqual(PaywallCatalog.freeTrialDays, TrialTimeline.freeDays)
        XCTAssertEqual(PaywallCatalog.yearly.trialDays, TrialTimeline.freeDays)
        XCTAssertEqual(PaywallCatalog.weekly.trialDays, TrialTimeline.freeDays)
        XCTAssertTrue(PaywallCatalog.weekly.hasTrial)
    }

    /// **On ne promet pas un essai qu'Apple ne donnera pas.** Un seul essai par groupe :
    /// qui a pris les trois jours de l'hebdomadaire ne les retrouve pas sur l'annuel. Le
    /// badge, la phrase de prix et le bouton doivent alors tous parler d'abonnement.
    func testAnAccountThatUsedItsTrialIsNotPromisedAnother() {
        defer { PaywallStorePrices.clear() }

        PaywallStorePrices.storeTrialEligibility([PaywallCatalog.yearly.productID: false])
        XCTAssertFalse(PaywallCatalog.yearly.hasTrial)
        XCTAssertTrue(PaywallCatalog.weekly.hasTrial, "Rien n'a été dit de l'hebdomadaire")

        let sentence = PaywallPitch.sentence(for: PaywallCatalog.yearly, locale: .fr)
        XCTAssertFalse(sentence.hasPrefix("puis"), "Sans essai, la phrase commence par le prix : \(sentence)")
        XCTAssertTrue(sentence.contains(PaywallCatalog.yearly.displayPrice))

        // Une réponse « éligible » rend l'essai, sans attendre un redémarrage.
        PaywallStorePrices.storeTrialEligibility([PaywallCatalog.yearly.productID: true])
        XCTAssertTrue(PaywallCatalog.yearly.hasTrial)
    }

    /// Quatre étapes, et une seule est « aujourd'hui » : une chronologie qui aurait deux
    /// présents ne se lirait plus comme une chronologie.
    func testTheTimelineRunsFromTheAccountToTheFirstCharge() {
        let milestones = TrialTimeline.milestones()

        XCTAssertEqual(milestones.count, 4)
        XCTAssertEqual(milestones.map(\.tone), [.done, .current, .upcoming, .upcoming])
        XCTAssertEqual(Set(milestones.map(\.id)).count, milestones.count, "Deux étapes ne peuvent pas porter le même libellé")
    }

    /// La dernière étape dit la date du premier prélèvement, et elle la dit juste : c'est
    /// la seule information de cet écran qu'on peut vérifier avec un calendrier.
    func testTheLastStepNamesTheDayOfTheFirstCharge() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))

        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 25)))

        XCTAssertEqual(TrialTimeline.billingDateText(from: start, calendar: calendar), "28 août")

        let lastStep = try XCTUnwrap(TrialTimeline.milestones(from: start, calendar: calendar).last)
        XCTAssertTrue(lastStep.detail.contains("28 août"), "La date manque à l'étape qui l'annonce : \(lastStep.detail)")
    }
}
