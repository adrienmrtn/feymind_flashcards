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
            PaywallCatalog.yearly.displayPrice.hasPrefix("69,99"),
            "L'annuel est à 69,99 €, pas \(PaywallCatalog.yearly.displayPrice)"
        )
        XCTAssertTrue(
            PaywallCatalog.weekly.displayPrice.hasPrefix("7,99"),
            "L'hebdomadaire est à 7,99 €, pas \(PaywallCatalog.weekly.displayPrice)"
        )
    }

    /// La ligne sous le nom de l'offre dit le **rythme**, jamais un second prix : le prix,
    /// la carte l'écrit déjà en face, et un mensuel équivalent posé à côté d'un prélèvement
    /// annuel faisait retenir un chiffre qui n'était pas celui qui part.
    func testTheCaptionSaysTheRhythmAndNotASecondPrice() {
        XCTAssertEqual(PaywallCatalog.yearly.caption, "facturé une fois par an")
        XCTAssertEqual(PaywallCatalog.weekly.caption, "facturé chaque semaine")

        for plan in PaywallCatalog.all + [PaywallCatalog.discount] {
            XCTAssertFalse(plan.caption.contains("/ mois"), "\(plan.caption) ramène encore au mois")
        }
    }

    /// La phrase du premier paywall dit **une** somme, celle qui sera prélevée. Elle en
    /// disait deux — le mensuel équivalent puis l'annuel entre parenthèses — et le plus gros
    /// des deux arrivait en second, ce qui se lit comme un rattrapage.
    ///
    /// L'espace avant l'euro n'est pas comparé : `Intl` et `NumberFormatter` rendent tantôt
    /// U+00A0 tantôt U+202F selon la version d'ICU.
    func testTheFirstPaywallAnnouncesTheChargedPrice() {
        let yearly = PaywallPitch.sentence(for: PaywallCatalog.yearly, locale: .fr)
        XCTAssertTrue(yearly.hasPrefix("puis 69,99"), yearly)
        XCTAssertTrue(yearly.hasSuffix("par an."), yearly)
        XCTAssertFalse(yearly.contains("mois"), "La phrase ramène encore au mois : \(yearly)")

        let weekly = PaywallPitch.sentence(for: PaywallCatalog.weekly, locale: .fr)
        XCTAssertTrue(weekly.hasPrefix("puis 7,99"), weekly)
        XCTAssertTrue(weekly.hasSuffix("par semaine."), weekly)
    }

    /// La remise est calculée, jamais écrite à la main : un pourcentage qui contredit les
    /// deux prix affichés juste en dessous ne se remarque qu'en production.
    func testTheSavingsComeFromTheTwoPrices() {
        let weeklyOverAYear = NSDecimalNumber(decimal: PaywallCatalog.weekly.annualCost).doubleValue
        XCTAssertEqual(weeklyOverAYear, 415.48, accuracy: 0.01, "7,99 € par semaine sur cinquante-deux semaines")

        XCTAssertEqual(PaywallCatalog.savingsPercent, 83)
    }

    /// Le discount existe pour plus tard, et il n'apparaît pas à côté des deux offres.
    func testTheDiscountExistsButIsNotOnThePaywall() {
        XCTAssertTrue(
            PaywallCatalog.discount.displayPrice.hasPrefix("39,99"),
            "Le discount est à 39,99 €, pas \(PaywallCatalog.discount.displayPrice)"
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
        XCTAssertFalse(PaywallCatalog.weekly.hasTrial)
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
