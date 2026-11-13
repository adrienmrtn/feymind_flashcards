import XCTest
@testable import Micabo

/// Verrouille ce qui est écrit sur le paywall : les prix, la remise annoncée, la durée de
/// l'essai et ses dates, et **aucune promesse d'essai à qui n'y a pas droit** — ni dans le
/// titre, ni sur le bouton, ni dans la mention.
final class PaywallTests: XCTestCase {
    override func tearDown() {
        PaywallStorePrices.clear()
        super.tearDown()
    }

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
    /// Aux États-Unis la grille met l'hebdomadaire à $7.99 et l'annuel à $59.99 : la pastille
    /// doit y dire −86 %, pas le −81 % français. Deux devises différentes — une réponse
    /// partielle — ne se comparent pas : on retombe alors sur les prix écrits.
    func testTheSavingsFollowTheStorePricesOfTheCountry() {
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

    /// Le tarif réduit existe, et il n'apparaît pas à côté des deux offres : on y entre par
    /// l'offre de réduction.
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

    /// Tant que rien n'est branché, la boutique répond « rien à vendre ». Ce n'est jamais un
    /// achat : le paywall le dit sous son bouton, et n'ouvre rien.
    func testTheStoreIsNotWiredYetAndSaysSo() async {
        let purchase = await PaywallPurchases.buy(PaywallCatalog.yearly)
        XCTAssertEqual(purchase, .unavailable)
        XCTAssertNotNil(purchase.failureMessage)

        let restore = await PaywallPurchases.restore()
        XCTAssertEqual(restore, .unavailable)
    }

    /// Sans boutique branchée (les tests, les aperçus), les prix sont là tout de suite : ceux
    /// du catalogue. Rien ne viendrait, et l'écran n'attend pas.
    func testWithoutAStoreThePricesAreReady() throws {
        try XCTSkipIf(PaywallPurchases.isReady, "La boutique est branchée sur cet hôte de test")
        let products = PaywallCatalog.all.map(\.productID)
        XCTAssertEqual(PaywallPriceLoading.state(for: products, failure: nil), .ready)
        XCTAssertEqual(PaywallPriceLoading.state(for: products, failure: "panne"), .ready)
    }

    // MARK: - L'essai

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
    /// titre, la ligne de l'offre, le bouton et la mention parlent alors d'abonnement — et la
    /// mention dit pourquoi.
    func testAnAccountThatUsedItsTrialIsNotPromisedAnother() {
        PaywallStorePrices.storeTrialEligibility([PaywallCatalog.yearly.productID: false])
        let yearly = PaywallCatalog.yearly
        XCTAssertFalse(yearly.hasTrial)
        XCTAssertTrue(PaywallCatalog.weekly.hasTrial, "Rien n'a été dit de l'hebdomadaire")

        let title = PaywallCopy.title(profile: PaywallProfile(), offersTrial: yearly.hasTrial, trialDays: yearly.trialDays, locale: .fr)
        XCTAssertFalse(title.text.lowercased().contains("gratuit"), title.text)
        XCTAssertFalse(title.text.contains("3"), title.text)

        XCTAssertEqual(PaywallCopy.callToAction(for: yearly, locale: .fr), "S'abonner")
        XCTAssertFalse(PaywallCopy.planDetail(for: yearly, locale: .fr).contains("gratuit"))

        let legal = PaywallCopy.legal(for: yearly, locale: .fr)
        XCTAssertTrue(legal.hasPrefix("Essai gratuit déjà utilisé."), legal)
        XCTAssertTrue(legal.contains("Payé aujourd'hui : \(yearly.displayPrice)"), legal)
        XCTAssertFalse(legal.contains("jours gratuits"), legal)
        XCTAssertFalse(legal.contains("jusqu'au"), "Sans essai, aucune date de gratuité : \(legal)")

        // Une réponse « éligible » rend l'essai, sans attendre un redémarrage.
        PaywallStorePrices.storeTrialEligibility([yearly.productID: true])
        XCTAssertTrue(PaywallCatalog.yearly.hasTrial)
        XCTAssertEqual(PaywallCopy.callToAction(for: PaywallCatalog.yearly, locale: .fr), "Commencer mes 3 jours gratuits")
    }

    /// Un pays où aucun essai n'est posé : la mention dit le prix, sans parler d'un essai
    /// « déjà utilisé » que personne n'a eu.
    func testACountryWithoutTrialOnlyStatesThePrice() {
        let yearly = PaywallCatalog.yearly
        PaywallStorePrices.storeTrialEligibility([yearly.productID: false], notOffered: [yearly.productID])

        let legal = PaywallCopy.legal(for: PaywallCatalog.yearly, locale: .fr)
        XCTAssertEqual(legal, "Payé aujourd'hui : \(yearly.displayPrice), puis chaque année. Annule quand tu veux.")
        XCTAssertEqual(PaywallCopy.callToAction(for: PaywallCatalog.yearly, locale: .fr), "S'abonner")
    }

    /// **Le tarif réduit n'a pas d'essai**, et rien sur son écran n'en promet : ni son
    /// bouton, ni sa mention, qui le dit en toutes lettres.
    func testTheDiscountNeverPromisesATrial() {
        let discount = PaywallCatalog.discount
        XCTAssertEqual(PaywallCopy.callToAction(for: discount, locale: .fr), "S'abonner", "Le bouton ne porte jamais de prix")
        XCTAssertFalse(PaywallCopy.legal(for: discount, locale: .fr).contains("gratuit"))

        let mention = L10n.t("ios.pay11.offer.legal", locale: .fr, vars: ["price": discount.displayPrice])
        XCTAssertEqual(mention, "Payé aujourd'hui : \(discount.displayPrice) pour un an, sans essai. Annule quand tu veux.")
        XCTAssertEqual(L10n.t("ios.pay10.offer.cta", locale: .fr, vars: ["percent": "−40 %"]), "Profiter de −40 %")
    }

    /// **Le rappel de fin d'essai part la veille de la fin**, à l'heure de l'achat ; un essai
    /// d'un jour n'a pas de veille.
    func testTheTrialReminderFiresTheDayBeforeTheEnd() throws {
        let start = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-11T18:30:00Z"))
        let fire = try XCTUnwrap(TrialEndReminder.fireDate(purchasedAt: start, trialDays: 3))
        XCTAssertEqual(fire.timeIntervalSince(start), 2 * 86_400, accuracy: 1)
        XCTAssertNil(TrialEndReminder.fireDate(purchasedAt: start, trialDays: 1))
        XCTAssertNil(TrialEndReminder.fireDate(purchasedAt: start, trialDays: 0))
        for locale in UiLocale.allCases {
            let text = TrialEndReminder.content(locale: locale)
            XCTAssertFalse(text.title.hasPrefix("ios."), locale.rawValue)
            XCTAssertFalse(text.body.hasPrefix("ios."), locale.rawValue)
        }
    }

    // MARK: - Les mots du paywall

    /// **Le titre dit le plan de l'élève, puis ce qu'on lui propose** : l'examen quand il en
    /// a choisi un, et l'essai — la phrase mise en avant — seulement quand il lui est offert.
    func testTheTitleNamesThePlanAndTheTrial() {
        let lina = PaywallProfile(firstName: "Lina", examName: "Bac", examID: "fr.bac")
        let french = PaywallCopy.title(profile: lina, offersTrial: true, trialDays: 3, locale: .fr)
        XCTAssertEqual(french.text, "Ton plan pour le Bac est prêt.\nEssaie-le 3 jours, gratuitement.")
        XCTAssertEqual(french.highlight, "Essaie-le 3 jours, gratuitement.")

        let sam = PaywallProfile(firstName: "Sam", examName: "SAT", examID: "us.sat")
        let english = PaywallCopy.title(profile: sam, offersTrial: true, trialDays: 3, locale: .en)
        XCTAssertEqual(english.text, "Your SAT plan is ready.\nTry it free for 3 days.")
        XCTAssertEqual(english.highlight, "Try it free for 3 days.")

        let german = PaywallCopy.title(
            profile: PaywallProfile(examName: "Abitur", examID: "de.abitur"),
            offersTrial: true,
            trialDays: 3,
            locale: .de
        )
        XCTAssertTrue(german.text.hasPrefix("Dein Abitur-Plan steht."), german.text)

        let anonymous = PaywallCopy.title(profile: PaywallProfile(), offersTrial: false, trialDays: 3, locale: .fr)
        XCTAssertEqual(anonymous.text, "Ton plan est prêt.\nDébloque-le avec Micabo\u{00a0}Pro.")
        XCTAssertEqual(anonymous.highlight, "Débloque-le avec Micabo\u{00a0}Pro.")

        let oneDay = PaywallCopy.title(profile: PaywallProfile(), offersTrial: true, trialDays: 1, locale: .fr)
        XCTAssertEqual(oneDay.highlight, "Essaie-le 1 jour, gratuitement.")
    }

    /// Le catalogue marque d'un `**…**` le groupe de mots à mettre en avant : on en tire le
    /// texte tel qu'il se lit, et ce groupe. Sans marque, ou avec une marque sans sa paire,
    /// rien n'est mis en avant et aucune étoile ne reste à l'écran.
    func testTheKeywordIsReadFromTheMarkedCopy() {
        let marked = PaywallEmphasis(marked: "Je réponds à **toutes tes questions** avec Pro.")
        XCTAssertEqual(marked.text, "Je réponds à toutes tes questions avec Pro.")
        XCTAssertEqual(marked.highlight, "toutes tes questions")

        let plain = PaywallEmphasis(marked: "Avec Pro, je t'aide sans limite.")
        XCTAssertEqual(plain.text, "Avec Pro, je t'aide sans limite.")
        XCTAssertNil(plain.highlight)

        let broken = PaywallEmphasis(marked: "Avec **Pro, je t'aide.")
        XCTAssertEqual(broken.text, "Avec Pro, je t'aide.")
        XCTAssertNil(broken.highlight)
    }

    /// **La mention sous le bouton dit ce qui sera prélevé, et quand** : la date de fin de
    /// l'essai, la même que celle de la chronologie, puis la somme et son rythme.
    func testTheLegalLineSaysWhatIsChargedAndWhen() throws {
        let calendar = try paris()
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10)))
        let yearly = PaywallCatalog.yearly
        let weekly = PaywallCatalog.weekly
        XCTAssertEqual(
            PaywallCopy.legal(for: yearly, now: now, locale: .fr, calendar: calendar),
            "Gratuit jusqu'au 15 novembre, puis \(yearly.displayPrice) par an. Annule quand tu veux."
        )
        XCTAssertEqual(
            PaywallCopy.legal(for: weekly, now: now, locale: .fr, calendar: calendar),
            "Gratuit jusqu'au 15 novembre, puis \(weekly.displayPrice) par semaine. Annule quand tu veux."
        )
        XCTAssertEqual(
            PaywallCopy.legal(for: yearly, now: now, locale: .en, calendar: calendar),
            "Free until November 15, then \(yearly.displayPrice) per year. Cancel anytime."
        )
        // Le bouton dit les jours gratuits, et rien d'autre.
        XCTAssertEqual(PaywallCopy.callToAction(for: yearly, locale: .fr), "Commencer mes 3 jours gratuits")
        XCTAssertEqual(PaywallCopy.callToAction(for: yearly, locale: .en), "Start my 3 free days")
    }

    /// La ligne sous le nom d'une offre : les jours gratuits quand ce compte y a droit, puis
    /// la somme prélevée et son rythme.
    func testThePlanDetailSaysTheTrialThenTheCharge() {
        let yearly = PaywallCatalog.yearly
        let weekly = PaywallCatalog.weekly
        XCTAssertEqual(PaywallCopy.planDetail(for: yearly, locale: .fr), "3 jours gratuits, puis \(yearly.displayPrice) par an")
        XCTAssertEqual(PaywallCopy.planDetail(for: weekly, locale: .fr), "3 jours gratuits, puis chaque semaine")

        PaywallStorePrices.storeTrialEligibility([yearly.productID: false, weekly.productID: false])
        XCTAssertEqual(PaywallCopy.planDetail(for: PaywallCatalog.yearly, locale: .fr), "\(yearly.displayPrice) par an")
        XCTAssertEqual(PaywallCopy.planDetail(for: PaywallCatalog.weekly, locale: .fr), weekly.caption)
    }

    private func paris() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        return calendar
    }

    /// **La chronologie écrit de vraies dates, et celle du rappel est celle du rappel
    /// réellement posé** (`TrialEndReminder`) : la veille de la fin, à l'heure de l'achat. La
    /// dernière étape dit la somme du premier paiement.
    func testTheTimelineUsesTheRealReminderDate() throws {
        let calendar = try paris()
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 18, minute: 30)))

        let steps = PaywallTimeline.steps(trialDays: 3, price: "49,99 €", now: start, reminderKept: true, locale: .fr, calendar: calendar)
        XCTAssertEqual(steps.map(\.kind), [.today, .reminder, .end])
        XCTAssertEqual(steps[0].title, "Aujourd'hui")
        XCTAssertEqual(steps[1].title, "14 novembre")
        XCTAssertEqual(steps[2].title, "15 novembre")
        XCTAssertEqual(steps[2].detail, "1er paiement : 49,99 €")
        XCTAssertEqual(Set(steps.map(\.id)).count, steps.count)

        let fire = try XCTUnwrap(TrialEndReminder.fireDate(purchasedAt: start, trialDays: 3))
        XCTAssertEqual(steps[1].title, PaywallTimeline.dayText(fire, locale: .fr, calendar: calendar))
        XCTAssertEqual(
            PaywallTimeline.endDate(from: start, trialDays: 3).timeIntervalSince(fire),
            86_400,
            accuracy: 1,
            "Le rappel part la veille de la fin"
        )

        let english = PaywallTimeline.steps(trialDays: 3, price: "$49.99", now: start, reminderKept: true, locale: .en, calendar: calendar)
        XCTAssertEqual(english[1].title, "November 14")
        XCTAssertEqual(english[2].title, "November 15")
    }

    /// **Le rappel ne s'écrit que s'il partira** : notifications refusées, ou essai sans
    /// veille, l'étape est retirée au lieu de promettre.
    func testTheTimelineDropsAReminderThatCannotBeKept() throws {
        let calendar = try paris()
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 9)))

        let refused = PaywallTimeline.steps(trialDays: 3, price: "49,99 €", now: start, reminderKept: false, locale: .fr, calendar: calendar)
        XCTAssertEqual(refused.map(\.kind), [.today, .end])
        XCTAssertEqual(refused[1].title, "15 novembre")

        let oneDay = PaywallTimeline.steps(trialDays: 1, price: "49,99 €", now: start, reminderKept: true, locale: .fr, calendar: calendar)
        XCTAssertEqual(oneDay.map(\.kind), [.today, .end])
        XCTAssertEqual(oneDay[1].title, "13 novembre")
    }

    /// **Ce que l'élève a déclaré revient en pastilles** : l'examen et le temps qui reste, trois
    /// matières puis « +n », la leçon demandée (abrégée si elle est longue). Rien d'absent ne
    /// s'invente.
    func testTheFactsAreWhatTheStudentDeclared() throws {
        let calendar = MicaboCalendar.shared
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10)))
        let exam = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 6, day: 15)))
        let lina = PaywallProfile(
            firstName: "Lina",
            examName: "Bac",
            examID: "fr.bac",
            examDate: exam,
            subjects: ["SVT", "Mathématiques", "Histoire", "Philosophie", "Physique"]
        )
        let facts = lina.facts(topic: " La guerre froide ", now: now, locale: .fr)
        XCTAssertEqual(facts.first?.id, "exam")
        XCTAssertTrue(facts[0].text.hasPrefix("Bac dans "), facts[0].text)
        XCTAssertEqual(facts.filter { $0.id.hasPrefix("subject.") }.count, PaywallProfile.shownSubjects)
        XCTAssertEqual(facts.first { $0.id == "more" }?.text, "+2")
        XCTAssertEqual(facts.last?.text, "La guerre froide")

        let long = String(repeating: "photosynthèse ", count: 8)
        XCTAssertTrue(lina.facts(topic: long, now: now, locale: .fr).last?.text.hasSuffix("…") == true)

        XCTAssertTrue(PaywallProfile().facts(topic: nil, now: now, locale: .fr).isEmpty)
        XCTAssertTrue(PaywallProfile().facts(topic: "   ", now: now, locale: .fr).isEmpty)
        XCTAssertEqual(PaywallProfile(examName: "Bac", examID: "fr.bac").facts(topic: nil, locale: .fr).map(\.text), ["Bac"])
    }

    // MARK: - Les portes

    /// Les six langues écrites dans ce lot ; les vingt autres suivent.
    private static let written: [UiLocale] = [.fr, .en, .de, .es, .tr, .ar]

    /// **Chaque porte a son accroche, dite par Mika** : courte, à la première personne (il
    /// ne se nomme pas), qui dit « Pro », avec un seul groupe de mots mis en avant.
    func testEveryDoorHasItsHook() throws {
        XCTAssertEqual(PaywallTrigger.allCases.count, 12)
        for locale in Self.written {
            let hooks = PaywallTrigger.allCases.map { $0.hook(locale: locale) }
            XCTAssertEqual(Set(hooks).count, hooks.count, "\(locale.rawValue) : deux portes disent la même phrase")
            for (trigger, hook) in zip(PaywallTrigger.allCases, hooks) {
                let name = "\(locale.rawValue) \(trigger.rawValue) : \(hook)"
                XCTAssertFalse(hook.hasPrefix("ios."), name)
                XCTAssertTrue(hook.contains("Pro"), name)
                XCTAssertFalse(hook.contains("Mika"), name)
                XCTAssertFalse(hook.contains("**"), name)
                XCTAssertLessThanOrEqual(hook.count, 80, name)

                let line = PaywallCopy.hook(for: trigger, locale: locale)
                XCTAssertEqual(line.text, hook)
                let keyword = try XCTUnwrap(line.highlight, name)
                XCTAssertEqual(hook.components(separatedBy: keyword).count, 2, "\(name) : le mot-clé doit s'y trouver une seule fois")
            }
        }
        // L'accroche dit ce qui vient de se passer, puis ce que Pro ouvre à cet endroit.
        XCTAssertEqual(PaywallTrigger.mika.hook(locale: .fr), "Ta question offerte est posée. Les suivantes, j'y réponds avec Pro.")
        XCTAssertEqual(PaywallTrigger.lessonReady.hook(locale: .fr), "J'ai lu tes documents. Ta leçon, je l'écris dès que tu passes Pro.")
        XCTAssertEqual(PaywallTrigger.mika.headline, PaywallTrigger.mika.hook())
    }

    /// L'en-tête « essai » est celui de qui n'a buté sur rien : la fin du parcours d'accueil
    /// et « Passer en Pro ». Toutes les autres portes ont l'accroche de Mika.
    func testOnlyTheDoorlessPaywallsShowTheTrialHeader() {
        XCTAssertTrue(PaywallTrigger.showsTrialHeader(nil))
        XCTAssertTrue(PaywallTrigger.showsTrialHeader(.upgrade))
        for trigger in PaywallTrigger.allCases where trigger != .upgrade {
            XCTAssertFalse(PaywallTrigger.showsTrialHeader(trigger), trigger.rawValue)
        }
    }

    /// **Le tableau dit les vraies limites du gratuit** — celles que l'app applique — et la
    /// ligne de la porte passe en tête.
    func testTheTableStatesTheRealFreeLimitsAndLeadsWithTheDoor() {
        XCTAssertEqual(PaywallFeature.mika.freeAllowance, MikaAllowance.freeQuestions)
        XCTAssertEqual(PaywallFeature.lessons.freeAllowance, 1)
        XCTAssertEqual(PaywallFeature.exams.freeAllowance, 1)
        XCTAssertEqual(PaywallFeature.practice.freeAllowance, 1)
        XCTAssertNil(PaywallFeature.pdf.freeAllowance, "La fiche PDF est réservée à Pro (RevisionModeAllowance)")
        XCTAssertNotNil(RevisionModeAllowance.gate(.export, isPro: false))

        XCTAssertEqual(PaywallFeature.shown(for: nil), [.lessons, .mika, .exams, .practice])
        XCTAssertEqual(PaywallFeature.shown(for: .mika), [.mika, .lessons, .exams, .practice])
        XCTAssertEqual(PaywallFeature.shown(for: .exportSheet), [.pdf, .lessons, .mika, .exams])
        XCTAssertEqual(PaywallFeature.shown(for: .mockExam, count: 2), [.exams, .lessons])

        for trigger in PaywallTrigger.allCases {
            let shown = PaywallFeature.shown(for: trigger)
            XCTAssertEqual(shown.count, 4, trigger.rawValue)
            XCTAssertEqual(Set(shown).count, 4, trigger.rawValue)
            XCTAssertEqual(shown.first, trigger.feature, trigger.rawValue)
        }
        for feature in PaywallFeature.allCases {
            for locale in Self.written {
                XCTAssertFalse(L10n.t(feature.titleKey, locale: locale).hasPrefix("ios."), feature.rawValue)
            }
        }
    }

    /// **Cinq serrages, du plus aéré au plus serré** : Mika et le titre rapetissent, l'air se
    /// resserre ; les trois bénéfices restent, et rien de ce qui est promis ne part.
    func testTheDensitiesShrinkTheHeroAndKeepThePromises() {
        XCTAssertEqual(PaywallDensity.allCases, [.regular, .comfortable, .compact, .tight, .tightest])
        XCTAssertEqual(PaywallDensity.benefitCount, 3)
        XCTAssertEqual(PaywallDensity.allCases.map(\.benefits), [3, 3, 3, 3, 2])
        let sizes = PaywallDensity.allCases.map(\.mikaSize)
        XCTAssertEqual(sizes, sizes.sorted(by: >))
        XCTAssertGreaterThan(PaywallDensity.tightest.mikaSize, 0, "Mika reste, même sur un iPhone SE")
        XCTAssertGreaterThan(PaywallDensity.regular.titleSize, PaywallDensity.compact.titleSize)
        XCTAssertGreaterThan(PaywallDensity.compact.titleSize, PaywallDensity.tight.titleSize)
        XCTAssertGreaterThan(PaywallDensity.regular.sectionGap, PaywallDensity.tight.sectionGap)
        for feature in PaywallFeature.allCases {
            for locale in Self.written {
                XCTAssertFalse(L10n.t(feature.benefitKey, locale: locale).hasPrefix("ios."), feature.rawValue)
            }
        }
    }

    /// Chaque phrase des lots 10 et 11 existe dans les six langues écrites.
    func testTheCopyExistsInTheWrittenLanguages() {
        let keys10 = IosI18nCatalogs.fr.keys.filter { $0.hasPrefix("ios.pay10.") }
        XCTAssertEqual(keys10.count, 55)
        let keys11 = IosI18nCatalogs.fr.keys.filter { $0.hasPrefix("ios.pay11.") }
        XCTAssertEqual(keys11.count, 36)
        for locale in Self.written {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in keys10 + keys11 {
                XCTAssertFalse((table[key] ?? "").isEmpty, "\(locale.rawValue) \(key)")
            }
        }
    }

    // MARK: - Le profil

    /// L'examen n'entre dans le titre que s'il a un nom propre, assez court, et qu'il est à
    /// venir : un contrôle, des partiels ou un examen passé laissent le titre de tout le monde.
    func testTheExamEntersTheTitleOnlyWhenItFits() {
        let bac = SchoolExams.choice(id: "fr.bac")
        XCTAssertEqual(PaywallProfile.examName(choice: bac, date: nil), "Bac")
        XCTAssertEqual(PaywallProfile.examName(choice: SchoolExams.choice(id: "es.pau"), date: nil), "PAU")
        XCTAssertNil(PaywallProfile.examName(choice: .test, date: nil))
        XCTAssertNil(PaywallProfile.examName(choice: .finals, date: nil))
        XCTAssertNil(PaywallProfile.examName(choice: .noExam, date: nil))
        XCTAssertNil(PaywallProfile.examName(choice: nil, date: nil))
        XCTAssertNil(PaywallProfile.examName(choice: SchoolExams.choice(id: "lu.examen"), date: nil), "Trop long pour un titre")

        XCTAssertNil(PaywallProfile.examName(choice: bac, date: Date(timeIntervalSinceNow: -5 * 86_400)), "Un examen passé")
        XCTAssertEqual(PaywallProfile.examName(choice: bac, date: Date(timeIntervalSinceNow: 30 * 86_400)), "Bac")

        for exam in SchoolExams.catalog.values {
            guard let name = PaywallProfile.examName(choice: .named(exam), date: nil) else { continue }
            XCTAssertLessThanOrEqual(name.count, PaywallProfile.longestExamName, exam.id)
            XCTAssertFalse(name.contains("("), exam.id)
        }
    }

    /// **En français, l'examen prend son article** — « le Bac », « l'Examen régional » — et
    /// seulement quand son nom est français : le genre d'un nom étranger ne se devine pas.
    func testFrenchExamsTakeTheirArticle() {
        XCTAssertEqual(PaywallProfile.frenchArticled("Bac"), "le Bac")
        XCTAssertEqual(PaywallProfile.frenchArticled("Brevet"), "le Brevet")
        XCTAssertEqual(PaywallProfile.frenchArticled("Bac de français"), "le Bac de français")
        XCTAssertEqual(PaywallProfile.frenchArticled("Examen régional"), "l'Examen régional")
        XCTAssertEqual(PaywallProfile.frenchArticled("Épreuves ministérielles"), "les Épreuves ministérielles")
        XCTAssertEqual(PaywallProfile.frenchArticled("Concours"), "le Concours")
        XCTAssertEqual(PaywallProfile.frenchArticled("CESS"), "le CESS")

        XCTAssertEqual(PaywallProfile(examName: "Bac", examID: "fr.bac").examPhrase(locale: .fr), "le Bac")
        XCTAssertEqual(PaywallProfile(examName: "Bac national", examID: "ma.bac").examPhrase(locale: .fr), "le Bac national")
        XCTAssertNil(PaywallProfile(examName: "Abitur", examID: "de.abitur").examPhrase(locale: .fr))
        XCTAssertEqual(PaywallProfile(examName: "Abitur", examID: "de.abitur").examPhrase(locale: .de), "Abitur")
        XCTAssertEqual(PaywallProfile(examName: "Bac", examID: "fr.bac").examPhrase(locale: .en), "Bac")
        XCTAssertNil(PaywallProfile().examPhrase(locale: .fr))
    }

    /// Le prénom : le premier mot de ce que l'élève a donné, rien s'il n'a rien donné.
    func testTheFirstNameIsTheFirstWord() {
        XCTAssertEqual(PaywallProfile.firstName("  Lina Martin "), "Lina")
        XCTAssertEqual(PaywallProfile.firstName("Léa"), "Léa")
        XCTAssertNil(PaywallProfile.firstName("   "))
        XCTAssertNil(PaywallProfile.firstName(nil))

        let welcome = PaywallCopy.welcome(name: "Lina", locale: .fr)
        XCTAssertEqual(welcome.text, "Bienvenue dans Micabo\u{00a0}Pro, Lina\u{00a0}!")
        XCTAssertEqual(welcome.highlight, "Micabo\u{00a0}Pro")
        XCTAssertEqual(PaywallCopy.welcome(name: nil, locale: .en).text, "Welcome to Micabo\u{00a0}Pro!")
        XCTAssertEqual(L10n.t("ios.pay10.brand.for", locale: .fr, vars: ["name": "Lina"]), "Pour Lina")
    }

    /// Le prix se range dans sa phrase là où la langue le veut : devant « par an » en
    /// français, derrière « Yıllık » en turc.
    func testThePriceTemplateSplitsAroundThePrice() {
        let french = PaywallPriceTemplate.split("ios.pay10.plan.perYear", locale: .fr)
        XCTAssertEqual(french.before, "")
        XCTAssertEqual(french.after, " par an")

        let turkish = PaywallPriceTemplate.split("ios.pay10.plan.perYear", locale: .tr)
        XCTAssertEqual(turkish.before, "Yıllık ")
        XCTAssertEqual(turkish.after, "")

        for locale in UiLocale.allCases {
            let parts = PaywallPriceTemplate.split("ios.pay10.plan.perYear", locale: locale)
            XCTAssertFalse((parts.before + parts.after).isEmpty, locale.rawValue)
            XCTAssertFalse((parts.before + parts.after).contains("{"), locale.rawValue)
        }
    }
}
