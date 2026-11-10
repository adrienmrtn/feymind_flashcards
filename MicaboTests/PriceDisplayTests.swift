import XCTest
@testable import Micabo

/// **Le test A/B de l'écriture du prix** (`PriceDisplay`) : le tirage, sa persistance, la
/// variante forcée, et l'équivalent hebdomadaire calculé sur le vrai prix de la boutique.
/// Le prix, le produit et l'essai ne changent jamais : seule la phrase change.
final class PriceDisplayTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "micabo.tests.priceDisplay"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        PaywallStorePrices.clear()
        super.tearDown()
    }

    // MARK: - Le tirage

    func testTheCoinDecidesOnceAndIsKept() {
        XCTAssertEqual(PriceDisplay.assignment(in: defaults, coin: { true }), .weekly)
        // Gardé : une autre pièce ne change plus rien.
        XCTAssertEqual(PriceDisplay.assignment(in: defaults, coin: { false }), .weekly)
        XCTAssertEqual(defaults.string(forKey: PriceDisplay.assignmentKey), "weekly")

        defaults.removePersistentDomain(forName: suite)
        XCTAssertEqual(PriceDisplay.assignment(in: defaults, coin: { false }), .monthly)
        XCTAssertEqual(PriceDisplay.assignment(in: defaults, coin: { true }), .monthly)
    }

    /// Une valeur illisible (une ancienne version, une faute) est retirée au sort à nouveau.
    func testAnUnknownStoredValueIsRedrawn() {
        defaults.set("daily", forKey: PriceDisplay.assignmentKey)
        XCTAssertEqual(PriceDisplay.assignment(in: defaults, coin: { true }), .weekly)
        XCTAssertEqual(defaults.string(forKey: PriceDisplay.assignmentKey), "weekly")
    }

    /// À peu près moitié-moitié avec la vraie pièce.
    func testTheRealCoinSplitsRoughlyInHalf() {
        var weekly = 0
        for _ in 0..<2_000 {
            // Une installation neuve à chaque tour.
            defaults.removeObject(forKey: PriceDisplay.assignmentKey)
            if PriceDisplay.assignment(in: defaults) == .weekly { weekly += 1 }
        }
        XCTAssertGreaterThan(weekly, 850)
        XCTAssertLessThan(weekly, 1_150)
    }

    /// La variante forcée (Réglages, section de test) passe devant, et rend la main au tirage.
    func testTheOverrideWinsAndCanBeCleared() {
        XCTAssertNil(PriceDisplay.forced(in: defaults))
        PriceDisplay.setOverride(.weekly, in: defaults)
        XCTAssertEqual(PriceDisplay.forced(in: defaults), .weekly)
        PriceDisplay.setOverride(.monthly, in: defaults)
        XCTAssertEqual(PriceDisplay.forced(in: defaults), .monthly)
        PriceDisplay.setOverride(nil, in: defaults)
        XCTAssertNil(PriceDisplay.forced(in: defaults))
    }

    func testTheAnalyticsLabels() {
        XCTAssertEqual(PriceDisplay.allCases.map(\.rawValue), ["monthly", "weekly"])
        guard case .text("weekly") = PriceDisplay.weekly.analyticsValue else {
            return XCTFail("price_display doit valoir « weekly »")
        }
    }

    // MARK: - Le prix à la semaine

    /// Sans réponse de la boutique : le prix écrit, divisé par cinquante-deux, arrondi au
    /// centime comme le mois l'est par douze.
    func testTheWeeklyEquivalentOfTheCataloguePrice() throws {
        let weekly = try XCTUnwrap(PaywallCatalog.yearly.weeklyEquivalent)
        XCTAssertTrue(weekly.hasPrefix("0,96"), "49,99 € par an font 0,96 € par semaine, pas \(weekly)")
        let discount = try XCTUnwrap(PaywallCatalog.discount.weeklyEquivalent)
        XCTAssertTrue(discount.hasPrefix("0,58"), "29,99 € par an font 0,58 € par semaine, pas \(discount)")
        XCTAssertNil(PaywallCatalog.weekly.weeklyEquivalent, "L'hebdomadaire est déjà à la semaine")

        // Le produit et son prix ne bougent pas.
        XCTAssertEqual(PaywallCatalog.yearly.price, 49.99)
        XCTAssertEqual(PaywallCatalog.yearly.productID, "com.micabo.app.pro.yearly")
    }

    /// **Le vrai prix du pays** : la somme de la boutique, divisée dans sa devise et écrite par
    /// le formateur d'Apple, exactement comme le mois.
    func testTheWeeklyEquivalentFollowsTheStorePrice() throws {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencyCode = "USD"
        PaywallStorePrices.store([
            PaywallCatalog.yearly.productID: PaywallStorePrices.StorePrice(
                localized: "$59.99",
                amount: 59.99,
                currencyCode: "USD",
                formatter: formatter
            ),
        ])

        XCTAssertEqual(PaywallCatalog.yearly.weeklyEquivalent, "$1.15")
        XCTAssertEqual(PaywallCatalog.yearly.monthlyEquivalent, "$5.00")
        XCTAssertEqual(PaywallCatalog.yearly.equivalent(for: .weekly), "$1.15")
        XCTAssertEqual(PaywallCatalog.yearly.equivalent(for: .monthly), "$5.00")
        XCTAssertEqual(PaywallCatalog.yearly.priceHeadline(for: .weekly), "$1.15")
        // L'hebdomadaire garde son propre prix dans les deux variantes.
        XCTAssertEqual(
            PaywallCatalog.weekly.priceHeadline(for: .weekly),
            PaywallCatalog.weekly.priceHeadline(for: .monthly)
        )
    }

    func testTheUnitFollowsTheVariant() {
        XCTAssertEqual(PaywallCatalog.yearly.priceHeadlineUnit(for: .monthly), PaywallCatalog.yearly.headlineUnit)
        XCTAssertEqual(PaywallCatalog.yearly.priceHeadlineUnit(for: .weekly), PaywallCatalog.weekly.headlineUnit)
        XCTAssertEqual(PaywallCatalog.weekly.priceHeadlineUnit(for: .monthly), PaywallCatalog.weekly.headlineUnit)
    }

    /// **La phrase du paywall, dans les deux variantes**, avec la somme prélevée d'un bloc.
    func testThePitchSaysTheWeekAndStillTheYearlyCharge() throws {
        let weekly = try XCTUnwrap(PaywallCatalog.yearly.weeklyEquivalent)
        let monthly = try XCTUnwrap(PaywallCatalog.yearly.monthlyEquivalent)

        let b = PaywallPitch.sentence(for: PaywallCatalog.yearly, locale: .fr, display: .weekly)
        XCTAssertTrue(b.contains(weekly), b)
        XCTAssertTrue(b.contains("semaine"), b)
        XCTAssertTrue(b.contains(PaywallCatalog.yearly.displayPrice), "La somme prélevée reste écrite : \(b)")
        XCTAssertFalse(b.contains(monthly), b)

        let a = PaywallPitch.sentence(for: PaywallCatalog.yearly, locale: .fr, display: .monthly)
        XCTAssertTrue(a.contains(monthly), a)
        XCTAssertTrue(a.contains("mois"), a)

        XCTAssertTrue(PaywallPitch.headlineSentence(for: PaywallCatalog.yearly, locale: .en, display: .weekly).contains("week"))
        XCTAssertTrue(PaywallPitch.headlineSentence(for: PaywallCatalog.yearly, locale: .en, display: .monthly).contains("month"))
    }

    /// Chaque phrase de la variante B existe dans chaque langue de l'app.
    func testTheWeeklyCopyExistsInEveryLanguage() {
        let keys = [
            "ios.conv.paywallThenYearWeekly", "ios.conv.paywallPriceYearWeekly",
            "ios.conv.paywallThenOnlyWeekly", "ios.conv.paywallOnlyWeekly", "ios.conv.paywallTryThenWeekly",
        ]
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in keys {
                let value = table[key]
                XCTAssertNotNil(value, "\(locale.rawValue) \(key)")
                XCTAssertTrue(value?.contains("{weekly}") == true, "\(locale.rawValue) \(key)")
            }
        }
    }
}
