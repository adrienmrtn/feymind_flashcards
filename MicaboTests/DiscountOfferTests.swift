import XCTest
@testable import Micabo

/// Verrouille l'offre de réduction : sa fenêtre et son repos, le moment où elle remplace un
/// paywall refermé, la pastille de la Home, et son prix.
///
/// Les mêmes durées existent côté web dans `web/packages/core/src/discount.ts`, et
/// `freemium-parity.test.ts` relit `DiscountOffer.swift` pour qu'elles ne divergent pas d'un
/// client à l'autre.
final class DiscountOfferTests: XCTestCase {
    override func tearDown() {
        DiscountOffer.declinedThisSession = false
        PaywallStorePrices.clear()
        super.tearDown()
    }

    // MARK: - Le temps

    /// Vingt-quatre heures depuis le premier affichage de l'offre, et **une seule horloge** :
    /// l'écran de l'offre et la pastille de la Home lisent le même instant d'origine.
    func testTheWindowRunsFromTheMomentTheOfferShowed() {
        let start = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(DiscountOffer.windowSeconds, 86_400)
        XCTAssertEqual(DiscountOffer.windowRemaining(startedAt: start, now: start), 86_400)

        let tenMinutesLater = start.addingTimeInterval(600)
        XCTAssertEqual(DiscountOffer.windowRemaining(startedAt: start, now: tenMinutesLater), 85_800)
    }

    /// La fenêtre se retire à la fin des vingt-quatre heures, et la pastille avec elle.
    func testTheWindowExpiresAfterTwentyFourHours() {
        let start = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(DiscountOffer.windowRemaining(startedAt: start, now: Date(timeIntervalSince1970: 7200)), 79_200)
        XCTAssertTrue(DiscountOffer.isLive(startedAt: start, now: Date(timeIntervalSince1970: 7200)))

        XCTAssertEqual(DiscountOffer.windowRemaining(startedAt: start, now: Date(timeIntervalSince1970: 86_400)), 0)
        XCTAssertFalse(DiscountOffer.isLive(startedAt: start, now: Date(timeIntervalSince1970: 86_400)))
    }

    /// Le repos dure quarante-huit heures, comptées après la fin de la fenêtre.
    func testTheOfferRestsTwoDaysAfterItsWindow() {
        let start = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(DiscountOffer.restSeconds, 172_800)
        XCTAssertFalse(DiscountOffer.hasRested(startedAt: start, now: Date(timeIntervalSince1970: 86_400)))
        XCTAssertFalse(DiscountOffer.hasRested(startedAt: start, now: Date(timeIntervalSince1970: 259_199)))
        XCTAssertTrue(DiscountOffer.hasRested(startedAt: start, now: Date(timeIntervalSince1970: 259_200)))
    }

    /// Une horloge remise en arrière ne doit pas faire grandir le décompte.
    func testTheCountdownNeverGrows() {
        let start = Date(timeIntervalSince1970: 1000)
        let before = Date(timeIntervalSince1970: 0)

        XCTAssertEqual(DiscountOffer.windowRemaining(startedAt: start, now: before), 86_400)
    }

    /// L'horloge de l'écran compte depuis l'instant d'origine de la fenêtre ; une durée posée
    /// (les rendus) reste ce qu'elle est, jamais négative.
    func testTheScreenClockCountsFromTheOrigin() {
        let start = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(DiscountClock.since(start).remaining(now: start.addingTimeInterval(60)), 86_340)
        XCTAssertEqual(DiscountClock.since(start).remaining(now: start.addingTimeInterval(90_000)), 0)
        XCTAssertEqual(DiscountClock.fixed(90).remaining(), 90)
        XCTAssertEqual(DiscountClock.fixed(-5).remaining(), 0)
    }

    /// Deux chiffres partout : une pastille qui change de largeur à chaque seconde attire
    /// l'œil pour rien.
    func testTheCountdownKeepsItsWidth() {
        XCTAssertEqual(DiscountOffer.countdown(86_399), "23:59:59")
        XCTAssertEqual(DiscountOffer.countdown(3600), "01:00:00")
        XCTAssertEqual(DiscountOffer.countdown(3599), "59:59")
        XCTAssertEqual(DiscountOffer.countdown(65), "01:05")
        XCTAssertEqual(DiscountOffer.countdown(0), "00:00")
        XCTAssertEqual(DiscountOffer.countdown(-40), "00:00")
    }

    /// « 1 heure restantes » se lirait comme une faute : la phrase commence donc par
    /// « il reste ».
    func testVoiceOverReadsAFrenchSentence() {
        XCTAssertEqual(DiscountOffer.countdownLabel(0, locale: .fr), "offre terminée")
        XCTAssertEqual(DiscountOffer.countdownLabel(30, locale: .fr), "il reste moins d'une minute")
        XCTAssertEqual(DiscountOffer.countdownLabel(90, locale: .fr), "il reste 1 minute")
        XCTAssertEqual(DiscountOffer.countdownLabel(3600, locale: .fr), "il reste 1 heure")
        XCTAssertEqual(DiscountOffer.countdownLabel(3720, locale: .fr), "il reste 1 heure et 2 minutes")
        XCTAssertEqual(DiscountOffer.countdownLabel(86_400, locale: .fr), "il reste 24 heures")
    }

    // MARK: - Quand l'offre remplace un paywall refermé

    /// **Un paywall refermé sans achat laisse la place à l'offre**, sans attendre de cours ni
    /// rien d'autre : jamais affichée ici, elle se présente.
    func testAClosedPaywallMakesWayForTheOffer() {
        XCTAssertEqual(DiscountOffer.giftAfterCourses, 0)
        XCTAssertTrue(DiscountOffer.paywallClosed(isPro: false, startedAt: nil, declined: false))
    }

    /// **Jamais à un abonné**, quel que soit l'état de la fenêtre.
    func testASubscriberNeverSeesTheOffer() {
        let start = Date(timeIntervalSince1970: 0)
        let moments: [Date?] = [nil, start]
        for startedAt in moments {
            for elapsed in [0.0, 3600, 100_000, 400_000] {
                XCTAssertFalse(
                    DiscountOffer.paywallClosed(
                        isPro: true,
                        startedAt: startedAt,
                        declined: false,
                        now: start.addingTimeInterval(elapsed)
                    )
                )
            }
        }
        XCTAssertFalse(DiscountOffer.isReachable(isPro: true, courseCount: 3))
        XCTAssertFalse(DiscountOffer.isChipLive(isPro: true, startedAt: start, now: start.addingTimeInterval(60)))
    }

    /// **Tant que la fenêtre court, refermer un paywall remontre l'offre**, avec le temps
    /// qu'il lui reste : la fenêtre ne repart pas de zéro.
    func testARunningWindowShowsTheOfferAgain() {
        let start = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(
            DiscountOffer.paywallClosed(isPro: false, startedAt: start, declined: false, now: start.addingTimeInterval(1))
        )
        XCTAssertTrue(
            DiscountOffer.paywallClosed(isPro: false, startedAt: start, declined: false, now: start.addingTimeInterval(86_399))
        )
    }

    /// **Fenêtre finie : rien pendant le repos, puis l'offre de nouveau.** Elle revient, elle
    /// ne meurt pas — et elle ne revient pas le lendemain matin.
    func testTheOfferComesBackOnlyAfterTheRest() {
        let start = Date(timeIntervalSince1970: 0)
        func closed(after seconds: TimeInterval) -> Bool {
            DiscountOffer.paywallClosed(isPro: false, startedAt: start, declined: false, now: start.addingTimeInterval(seconds))
        }
        XCTAssertFalse(closed(after: 86_400), "La fenêtre vient de finir")
        XCTAssertFalse(closed(after: 200_000), "Au milieu du repos")
        XCTAssertFalse(closed(after: 259_199))
        XCTAssertTrue(closed(after: 259_200), "Le repos est passé")
        XCTAssertTrue(closed(after: 1_000_000))
    }

    /// **Refusée, l'offre n'insiste pas** : pas deux fois dans la même session, que sa
    /// fenêtre coure ou qu'elle soit reposée.
    func testARefusedOfferDoesNotComeBackInTheSameSession() {
        let start = Date(timeIntervalSince1970: 0)
        XCTAssertFalse(DiscountOffer.paywallClosed(isPro: false, startedAt: nil, declined: true))
        XCTAssertFalse(
            DiscountOffer.paywallClosed(isPro: false, startedAt: start, declined: true, now: start.addingTimeInterval(60))
        )
        XCTAssertFalse(
            DiscountOffer.paywallClosed(isPro: false, startedAt: start, declined: true, now: start.addingTimeInterval(500_000))
        )
    }

    /// La même règle, lue sur l'appareil : le refus tient en mémoire, le temps de la session,
    /// et « oublier » (la section Test) remet tout à zéro.
    func testTheSessionRemembersTheRefusal() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "micabo.tests.discount.session"))
        defaults.removePersistentDomain(forName: "micabo.tests.discount.session")
        DiscountOffer.declinedThisSession = false

        XCTAssertTrue(DiscountOffer.paywallClosed(isPro: false, in: defaults))

        DiscountOffer.declinedThisSession = true
        XCTAssertFalse(DiscountOffer.paywallClosed(isPro: false, in: defaults))

        DiscountOffer.forget(in: defaults)
        XCTAssertFalse(DiscountOffer.declinedThisSession)
        XCTAssertTrue(DiscountOffer.paywallClosed(isPro: false, in: defaults))

        // L'offre affichée : sa fenêtre court, fermer un autre paywall la remontre — sauf à
        // un abonné.
        DiscountOffer.begin(in: defaults)
        XCTAssertTrue(DiscountOffer.paywallClosed(isPro: false, in: defaults))
        XCTAssertFalse(DiscountOffer.paywallClosed(isPro: true, in: defaults))
    }

    /// **Plus rien à déballer** : l'offre arrive ouverte, sans appui à compter.
    func testTheOfferAsksForNoTap() {
        XCTAssertEqual(DiscountOffer.taps, 0)
    }

    // MARK: - La pastille de la Home

    /// **La pastille vit le temps de la fenêtre** : dès le premier affichage de l'offre,
    /// jusqu'à la dernière seconde, jamais avant, jamais après.
    func testTheChipLivesAsLongAsTheWindow() {
        let start = Date(timeIntervalSince1970: 0)

        XCTAssertFalse(DiscountOffer.isChipLive(isPro: false, startedAt: nil), "Offre jamais affichée")
        XCTAssertTrue(DiscountOffer.isChipLive(isPro: false, startedAt: start, now: start))
        XCTAssertTrue(DiscountOffer.isChipLive(isPro: false, startedAt: start, now: Date(timeIntervalSince1970: 86_399)))
        XCTAssertFalse(DiscountOffer.isChipLive(isPro: false, startedAt: start, now: Date(timeIntervalSince1970: 86_400)))
        XCTAssertFalse(DiscountOffer.isChipLive(isPro: false, startedAt: start, now: Date(timeIntervalSince1970: 300_000)))
    }

    /// La fenêtre observable relit les réglages de l'appareil : l'offre affichée l'allume, un
    /// abonnement l'éteint, « oublier » aussi.
    @MainActor
    func testTheObservableWindowFollowsTheDevice() throws {
        let suite = "micabo.tests.discount.window"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let window = DiscountWindow(defaults: defaults)
        XCTAssertFalse(window.isLive)
        XCTAssertNil(window.startedAt)

        let opened = DiscountOffer.begin(in: defaults)
        window.refresh()
        XCTAssertTrue(window.isLive)
        XCTAssertEqual(window.startedAt?.timeIntervalSince1970 ?? 0, opened.timeIntervalSince1970, accuracy: 0.001)

        // La fenêtre finie, vue par l'horloge de la pastille. Une seconde de marge : l'instant
        // relu des réglages n'est celui qu'on y a écrit qu'à une fraction de milliseconde près.
        window.refresh(now: opened.addingTimeInterval(86_401))
        XCTAssertFalse(window.isLive)
        window.refresh()
        XCTAssertTrue(window.isLive)

        defaults.set(true, forKey: ProAccess.Key.isPro)
        window.refresh()
        XCTAssertFalse(window.isLive, "Un abonné ne voit pas la pastille")

        // L'offre ouverte depuis la pastille la tient en place : l'achat qu'on y fait, ou
        // la fenêtre qui finit, ne la retire qu'une fois l'écran refermé.
        window.hold(true)
        XCTAssertTrue(window.isLive)
        window.refresh(now: opened.addingTimeInterval(90_000))
        XCTAssertTrue(window.isLive)
        window.hold(false)
        XCTAssertFalse(window.isLive, "Refermée, la pastille d'un abonné s'en va")

        defaults.set(false, forKey: ProAccess.Key.isPro)
        DiscountOffer.forget(in: defaults)
        window.refresh()
        XCTAssertFalse(window.isLive)
        XCTAssertNil(window.startedAt)
    }

    // MARK: - Ce que l'appareil retient

    /// L'instant s'écrit **une seule fois** par fenêtre. Sans ce garde, chaque ouverture
    /// repousserait la fin des vingt-quatre heures et le décompte ne descendrait plus. Une
    /// fenêtre finie, elle, ouvre la suivante.
    func testTheStartIsWrittenOncePerWindow() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "micabo.tests.discount"))
        DiscountOffer.forget(in: defaults)

        XCTAssertNil(DiscountOffer.start(in: defaults))

        let first = Date(timeIntervalSince1970: 500)
        let kept = DiscountOffer.begin(now: first, in: defaults)
        XCTAssertEqual(kept.timeIntervalSince1970, 500, accuracy: 0.001)

        let later = DiscountOffer.begin(now: Date(timeIntervalSince1970: 9000), in: defaults)
        XCTAssertEqual(later.timeIntervalSince1970, 500, accuracy: 0.001)

        let next = DiscountOffer.begin(now: Date(timeIntervalSince1970: 500 + 86_400), in: defaults)
        XCTAssertEqual(next.timeIntervalSince1970, 500 + 86_400, accuracy: 0.001, "Une fenêtre finie ouvre la suivante")

        DiscountOffer.forget(in: defaults)
        XCTAssertNil(DiscountOffer.start(in: defaults))
    }

    /// Les deux clés d'avant le lot 10 (le « déjà vu », la demande en attente) ne servent
    /// plus : « oublier » les efface, pour qu'elles ne traînent pas sur l'appareil.
    func testForgettingAlsoClearsTheLegacyKeys() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "micabo.tests.discount.legacy"))
        defaults.set(true, forKey: DiscountOffer.Key.seen)
        defaults.set(true, forKey: DiscountOffer.Key.pending)

        DiscountOffer.forget(in: defaults)

        XCTAssertNil(defaults.object(forKey: DiscountOffer.Key.seen))
        XCTAssertNil(defaults.object(forKey: DiscountOffer.Key.pending))
    }

    // MARK: - Le prix

    /// 29,99 € par an, et l'annuel plein barré à côté. **L'offre écrit la somme prélevée** en
    /// grand ; ce qu'elle fait par mois n'est qu'un rappel à côté.
    func testTheOfferShowsTheChargedYearAgainstTheFullYear() {
        XCTAssertTrue(
            DiscountOffer.plan.displayPrice.hasPrefix("29,99"),
            "L'offre s'annonce à 29,99 € par an, pas \(DiscountOffer.plan.displayPrice)"
        )
        XCTAssertEqual(DiscountOffer.plan, PaywallCatalog.discount)
        XCTAssertEqual(DiscountOffer.reference, PaywallCatalog.yearly)
        XCTAssertTrue(DiscountOffer.reference.displayPrice.hasPrefix("49,99"))
        XCTAssertFalse(DiscountOffer.plan.hasTrial, "Le tarif réduit n'a pas d'essai, et l'écran le dit")
    }

    /// La remise est calculée depuis les deux prix, jamais écrite : 29,99 contre 49,99.
    /// La grille garde −40 % dans tous les pays.
    func testTheSavingsComeFromTheTwoYearlyPrices() {
        XCTAssertEqual(DiscountOffer.savingsPercent, 40)
    }

    /// **Le pourcentage suit les prix de la boutique du pays** : posé à côté de deux prix, il
    /// ne peut pas en dire un troisième.
    func testTheSavingsFollowTheStorePrices() {
        PaywallStorePrices.store([
            PaywallCatalog.yearly.productID: Self.storePrice(59.99, "USD"),
            PaywallCatalog.discount.productID: Self.storePrice(44.99, "USD"),
        ])
        XCTAssertEqual(DiscountOffer.savingsPercent, 25)

        // Deux devises ne font pas une remise : on retombe sur la grille.
        PaywallStorePrices.store([PaywallCatalog.discount.productID: Self.storePrice(899.99, "TRY")])
        XCTAssertEqual(DiscountOffer.savingsPercent, 40)
    }

    /// « −40 % », écrit comme la langue l'écrit, avec un vrai signe moins.
    func testTheSavingsLabelFollowsTheLocale() {
        XCTAssertEqual(DiscountOffer.savingsLabel(40, locale: .en), "−40%")
        XCTAssertEqual(DiscountOffer.savingsLabel(40, locale: .tr), "−%40")
        for locale in UiLocale.allCases {
            let label = DiscountOffer.savingsLabel(40, locale: locale)
            XCTAssertTrue(label.contains("−"), "\(locale.rawValue) : \(label)")
            XCTAssertFalse(label.contains("-"), "\(locale.rawValue) : \(label)")
            XCTAssertTrue(label.contains("40") || label.contains("٤٠"), "\(locale.rawValue) : \(label)")
        }
        // Sans remise, pas de signe.
        XCTAssertFalse(DiscountOffer.savingsLabel(0, locale: .fr).contains("−"))
    }

    private static func storePrice(_ amount: Decimal, _ currency: String) -> PaywallStorePrices.StorePrice {
        PaywallStorePrices.StorePrice(
            localized: "\(amount) \(currency)",
            amount: amount,
            currencyCode: currency,
            formatter: nil
        )
    }
}
