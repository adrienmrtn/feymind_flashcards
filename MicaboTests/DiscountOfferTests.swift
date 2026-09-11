import XCTest
@testable import Micabo

/// Verrouille l'offre cadeau : la fenêtre, les règles d'affichage, et le prix.
///
/// Les mêmes vérifications existent côté web dans `web/lib/discount.test.ts`, et
/// `freemium-parity.test.ts` relit `DiscountOffer.swift` pour que les constantes ne
/// divergent pas d'un client à l'autre.
final class DiscountOfferTests: XCTestCase {
    // MARK: - Le temps

    /// Vingt-quatre heures depuis l'ouverture du cadeau, comptées sans être montrées.
    func testTheWindowRunsForTwentyFourHours() {
        let start = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(DiscountOffer.windowSeconds, 86_400)
        XCTAssertEqual(DiscountOffer.windowRemaining(startedAt: start, now: start), 86_400)

        let tenMinutesLater = start.addingTimeInterval(600)
        XCTAssertEqual(DiscountOffer.windowRemaining(startedAt: start, now: tenMinutesLater), 85_800)
    }

    /// L'offre se retire à la fin des vingt-quatre heures.
    func testTheOfferExpiresWithItsWindow() {
        let start = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(DiscountOffer.windowRemaining(startedAt: start, now: Date(timeIntervalSince1970: 7200)), 79_200)
        XCTAssertTrue(DiscountOffer.isLive(startedAt: start, now: Date(timeIntervalSince1970: 7200)))

        XCTAssertEqual(DiscountOffer.windowRemaining(startedAt: start, now: Date(timeIntervalSince1970: 86_400)), 0)
        XCTAssertFalse(DiscountOffer.isLive(startedAt: start, now: Date(timeIntervalSince1970: 86_400)))
    }

    /// Une horloge remise en arrière ne doit pas faire grandir la fenêtre.
    func testTheWindowNeverGrows() {
        let start = Date(timeIntervalSince1970: 1000)
        let before = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(DiscountOffer.windowRemaining(startedAt: start, now: before), 86_400)
    }

    // MARK: - Quand l'offre se montre

    func testTheGiftWaitsForTheFirstCourse() {
        XCTAssertTrue(
            DiscountOffer.shouldPresentGift(isPro: false, courseCount: 1, seen: false, startedAt: nil)
        )
        XCTAssertFalse(
            DiscountOffer.shouldPresentGift(isPro: false, courseCount: 0, seen: false, startedAt: nil)
        )
    }

    /// On ne vend rien à quelqu'un qui paye déjà, et on ne déballe pas deux fois.
    func testTheGiftShowsOnlyOnce() {
        XCTAssertFalse(
            DiscountOffer.shouldPresentGift(isPro: true, courseCount: 1, seen: false, startedAt: nil)
        )
        XCTAssertFalse(
            DiscountOffer.shouldPresentGift(isPro: false, courseCount: 1, seen: true, startedAt: nil)
        )
    }

    /// La pastille prend le relais de la grande carte, et disparaît avec l'offre.
    func testTheBadgeTakesOverThenExpires() {
        let start = Date(timeIntervalSince1970: 0)

        XCTAssertTrue(
            DiscountOffer.shouldShowBadge(
                isPro: false,
                courseCount: 1,
                seen: true,
                startedAt: start,
                now: Date(timeIntervalSince1970: 3600)
            )
        )

        // Pas encore vue : c'est la grande carte qui parle, pas la pastille.
        XCTAssertFalse(
            DiscountOffer.shouldShowBadge(
                isPro: false,
                courseCount: 1,
                seen: false,
                startedAt: start,
                now: Date(timeIntervalSince1970: 3600)
            )
        )

        XCTAssertFalse(
            DiscountOffer.shouldShowBadge(
                isPro: false,
                courseCount: 1,
                seen: true,
                startedAt: start,
                now: Date(timeIntervalSince1970: 86_400)
            )
        )
    }

    // MARK: - Ce que l'appareil retient

    /// L'instant s'écrit **une seule fois**. Sans ce garde, chaque affichage repousserait la
    /// fin des vingt-quatre heures et l'offre ne se retirerait jamais.
    func testTheStartIsWrittenOnce() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "micabo.tests.discount"))
        DiscountOffer.forget(in: defaults)

        XCTAssertNil(DiscountOffer.start(in: defaults))

        let first = Date(timeIntervalSince1970: 500)
        let kept = DiscountOffer.begin(now: first, in: defaults)
        XCTAssertEqual(kept.timeIntervalSince1970, 500, accuracy: 0.001)

        let later = DiscountOffer.begin(now: Date(timeIntervalSince1970: 9000), in: defaults)
        XCTAssertEqual(later.timeIntervalSince1970, 500, accuracy: 0.001)

        XCTAssertFalse(DiscountOffer.isSeen(in: defaults))
        DiscountOffer.markSeen(in: defaults)
        XCTAssertTrue(DiscountOffer.isSeen(in: defaults))

        DiscountOffer.forget(in: defaults)
        XCTAssertNil(DiscountOffer.start(in: defaults))
        XCTAssertFalse(DiscountOffer.isSeen(in: defaults))
    }

    // MARK: - Le prix

    /// 39,99 € par an, et l'annuel plein barré à côté. Le prix affiché est celui qui est
    /// prélevé : plus de mensuel équivalent écrit à la main pour éviter que 39,99 ÷ 12
    /// s'affiche « 3,33 € ».
    func testTheOfferShowsItsYearlyPriceAgainstTheFullYear() {
        XCTAssertTrue(
            DiscountOffer.plan.displayPrice.hasPrefix("39,99"),
            "Le cadeau s'annonce à 39,99 € par an, pas \(DiscountOffer.plan.displayPrice)"
        )
        XCTAssertEqual(DiscountOffer.plan, PaywallCatalog.discount)
        XCTAssertEqual(DiscountOffer.reference, PaywallCatalog.yearly)
        XCTAssertTrue(DiscountOffer.reference.displayPrice.hasPrefix("69,99"))
    }

    /// La remise est calculée depuis les deux prix, jamais écrite : 39,99 contre 69,99.
    func testTheSavingsComeFromTheTwoYearlyPrices() {
        XCTAssertEqual(DiscountOffer.savingsPercent, 43)
    }

    /// Trois appuis. Un de plus lasse, un de moins n'est pas un geste.
    func testTheGiftAsksForThreeTaps() {
        XCTAssertEqual(DiscountOffer.taps, 3)
    }
}
