import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus du paywall et de l'offre de réduction** (lot 10) : le paywall d'essai et celui
/// des portes de l'app, leurs états (prix attendus, prix absents, achat en cours, erreur,
/// essai déjà pris), l'offre et ses états, la bienvenue, la pastille de la Home — de jour et
/// de nuit, en allemand, en arabe, sur un iPhone SE et en très grand texte.
///
/// Les écrans sont posés à la hauteur utile d'un téléphone (sans les zones sûres) : ce qui
/// ne tiendrait pas défilerait, et `ImageRenderer` ne dessine pas l'intérieur d'un
/// `ScrollView` — un milieu d'écran vide dit donc « ça ne tient pas ». Les rendus en très
/// grand texte sont posés à leur hauteur naturelle, pour voir que rien ne se coupe.
@MainActor
final class Paywall10RenderTests: XCTestCase {
    private var savedLocale: String?
    private var savedDisplay: PriceDisplay?

    /// La hauteur utile d'un iPhone 15 (852 moins les zones sûres) et d'un iPhone SE.
    private let tall: CGFloat = 759
    private let smallWidth: CGFloat = 375
    private let smallHeight: CGFloat = 647

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        savedLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
        savedDisplay = PriceDisplay.forced(in: .standard)
        // La variante « à la semaine » : celle des maquettes.
        PriceDisplay.setOverride(.weekly)
    }

    override func tearDown() {
        if let savedLocale {
            UserDefaults.standard.set(savedLocale, forKey: UiLocale.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UiLocale.storageKey)
        }
        PriceDisplay.setOverride(savedDisplay)
        PaywallStorePrices.clear()
        super.tearDown()
    }

    private func use(_ locale: UiLocale) {
        UserDefaults.standard.set(locale.rawValue, forKey: UiLocale.storageKey)
    }

    // MARK: - Ce que les écrans reçoivent

    /// Le 12 novembre 2026, dix heures : le rappel tombe le 14, la fin de l'essai le 15.
    private static let now: Date = {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10)) ?? Date()
    }()

    private func context(
        name: String? = "Lina",
        exam: (name: String, id: String)? = ("Bac", "fr.bac"),
        reminder: Bool = true,
        topic: String? = nil
    ) -> PaywallContext {
        PaywallContext(
            profile: PaywallProfile(firstName: name, examName: exam?.name, examID: exam?.id),
            now: Self.now,
            reminderKept: reminder,
            topic: topic
        )
    }

    private func paywall(
        _ trigger: PaywallTrigger? = nil,
        context: PaywallContext,
        prices: PaywallPriceState = .ready,
        purchasing: Bool = false,
        notice: PaywallNotice? = nil,
        rtl: Bool = false
    ) -> some View {
        PaywallScreen(
            trigger: trigger,
            name: context.profile.firstName,
            isPurchasing: purchasing,
            onClose: {},
            onSubscribe: { _ in },
            onRestore: {},
            prices: prices,
            notice: notice,
            context: context
        )
        .environment(\.mikaStill, true)
        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
    }

    private func offer(
        remaining: Int = 86_382,
        prices: PaywallPriceState = .ready,
        purchasing: Bool = false,
        notice: PaywallNotice? = nil,
        rtl: Bool = false
    ) -> some View {
        DiscountOfferScreen(
            remaining: remaining,
            isPurchasing: purchasing,
            prices: prices,
            notice: notice,
            animatesArrival: false,
            onClose: {},
            onBuy: {},
            onRestore: {}
        )
        .environment(\.mikaStill, true)
        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
    }

    // MARK: - Le paywall d'essai

    /// L'en-tête « essai » : avec l'examen, avec la leçon demandée dans le parcours, sans
    /// rappel possible, et dans la variante « au mois » du test de prix.
    func testTrialPaywall() throws {
        use(.fr)
        try RenderGallery.render("pay10-fr-trial", height: tall, night: true, paywall(context: context()))
        try RenderGallery.render(
            "pay10-fr-trial-topic",
            height: tall,
            paywall(context: context(exam: nil, topic: "La guerre froide"))
        )
        try RenderGallery.render(
            "pay10-fr-trial-noreminder",
            height: tall,
            paywall(.upgrade, context: context(name: nil, reminder: false))
        )

        PriceDisplay.setOverride(.monthly)
        try RenderGallery.render("pay10-fr-trial-monthly", height: tall, paywall(context: context()))
        PriceDisplay.setOverride(.weekly)
    }

    /// **L'élève a déjà pris son essai** : plus un « gratuit » à l'écran — ni dans le titre,
    /// ni sur le bouton, ni dans la mention, qui dit pourquoi.
    func testPaywallWithoutTrial() throws {
        use(.fr)
        PaywallStorePrices.storeTrialEligibility([
            PaywallCatalog.yearly.productID: false,
            PaywallCatalog.weekly.productID: false,
        ])
        try RenderGallery.render("pay10-fr-notrial", height: tall, night: true, paywall(context: context()))
        try RenderGallery.render("pay10-fr-notrial-door", height: tall, paywall(.mika, context: context()))
        PaywallStorePrices.clear()
    }

    // MARK: - Les portes de l'app

    /// L'en-tête « contexte » : Mika dit l'accroche de la porte, et son bénéfice vient d'abord.
    func testDoorPaywalls() throws {
        use(.fr)
        try RenderGallery.render("pay10-fr-door-lesson", height: tall, night: true, paywall(.lessonReady, context: context()))
        try RenderGallery.render("pay10-fr-door-mika", height: tall, paywall(.mika, context: context()))
        try RenderGallery.render("pay10-fr-door-exam", height: tall, paywall(.mockExam, context: context()))
        try RenderGallery.render("pay10-fr-door-voice", height: tall, paywall(.voiceRecall, context: context()))
        try RenderGallery.render("pay10-fr-door-import", height: tall, paywall(.generateCourse, context: context(name: nil)))
    }

    // MARK: - Les états

    /// Les prix attendus (les silhouettes des deux offres), les prix absents (la phrase et
    /// « Réessayer »), l'achat en cours (le bouton charge, la croix s'éteint), et la phrase
    /// d'un achat qui n'a pas abouti, sous le bouton.
    func testPaywallStates() throws {
        use(.fr)
        try RenderGallery.render("pay10-fr-loading", height: tall, night: true, paywall(context: context(), prices: .loading))
        try RenderGallery.render(
            "pay10-fr-failed",
            height: tall,
            paywall(context: context(), prices: .failed(PaywallFailure.network.message))
        )
        try RenderGallery.render("pay10-fr-buying", height: tall, paywall(context: context(), purchasing: true))
        try RenderGallery.render(
            "pay10-fr-error",
            height: tall,
            paywall(context: context(), notice: .error(PaywallFailure.store.message))
        )
        try RenderGallery.render(
            "pay10-fr-pending",
            height: tall,
            paywall(.lessonReady, context: context(), notice: .info(L10n.t("ios.paywallPending", locale: .fr)))
        )
    }

    // MARK: - L'offre de réduction

    /// L'offre et ses états : le tarif réduit, les prix attendus et absents, l'achat en
    /// cours, une erreur, et la fenêtre finie sous les yeux de l'élève.
    func testDiscountOffer() throws {
        use(.fr)
        try RenderGallery.render("pay10-fr-offer", height: tall, night: true, offer())
        try RenderGallery.render("pay10-fr-offer-loading", height: tall, offer(prices: .loading))
        try RenderGallery.render(
            "pay10-fr-offer-failed",
            height: tall,
            offer(prices: .failed(PaywallFailure.productUnavailable.message))
        )
        try RenderGallery.render("pay10-fr-offer-buying", height: tall, offer(purchasing: true))
        try RenderGallery.render(
            "pay10-fr-offer-error",
            height: tall,
            offer(remaining: 3_540, notice: .error(PaywallFailure.network.message))
        )
        try RenderGallery.render("pay10-fr-offer-ended", height: tall, offer(remaining: 0))

        PriceDisplay.setOverride(.monthly)
        try RenderGallery.render("pay10-fr-offer-monthly", height: tall, offer())
        PriceDisplay.setOverride(.weekly)
    }

    /// L'achat a abouti : Mika fête ça.
    func testWelcome() throws {
        use(.fr)
        try RenderGallery.render(
            "pay10-fr-welcome",
            height: tall,
            night: true,
            PaywallWelcomeScreen(name: "Lina", onContinue: {}).environment(\.mikaStill, true)
        )
        use(.de)
        try RenderGallery.render(
            "pay10-de-welcome",
            height: tall,
            PaywallWelcomeScreen(name: nil, onContinue: {}).environment(\.mikaStill, true)
        )
    }

    // MARK: - La pastille de la Home

    /// La pastille de l'offre, à côté de la marque dont elle prend la place : au-dessus et en
    /// dessous de l'heure, en allemand, en turc, en arabe, et en très grand texte.
    func testDiscountChip() throws {
        use(.fr)
        let board = VStack(alignment: .leading, spacing: 14) {
            PaywallBrand(name: "Lina")
            DiscountChipLabel(percent: 40, remaining: 85_270, locale: .fr)
            DiscountChipLabel(percent: 40, remaining: 582, locale: .fr)
            DiscountChipLabel(percent: 25, remaining: 3_600, locale: .de)
            DiscountChipLabel(percent: 40, remaining: 85_270, locale: .tr)
            DiscountChipLabel(percent: 40, remaining: 85_270, locale: .ar)
                .environment(\.layoutDirection, .rightToLeft)
            DiscountChipLabel(percent: 40, remaining: 85_270, locale: .fr)
                .environment(\.dynamicTypeSize, .xxxLarge)
            DiscountCountdownPill(remaining: 85_270)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V3Color.bg)
        try RenderGallery.render("pay10-chip", night: true, board)
    }

    // MARK: - Les langues longues, l'arabe, le petit écran

    func testGerman() throws {
        use(.de)
        let german = context(exam: ("Abitur", "de.abitur"))
        try RenderGallery.render("pay10-de-trial", height: tall, night: true, paywall(context: german))
        try RenderGallery.render("pay10-de-door-exam", height: tall, paywall(.mockExam, context: german))
        try RenderGallery.render("pay10-de-door-import", height: tall, paywall(.generateCourse, context: german))
        try RenderGallery.render("pay10-de-offer", height: tall, offer())

        // Sur un iPhone SE, au texte normal puis en très grand texte.
        try RenderGallery.render("pay10-de-se-trial", width: smallWidth, height: smallHeight, paywall(context: german))
        try RenderGallery.render("pay10-de-se-offer", width: smallWidth, height: smallHeight, offer())
        try RenderGallery.render(
            "pay10-de-se-xl-trial",
            width: smallWidth,
            paywall(context: german).environment(\.dynamicTypeSize, .xxxLarge)
        )
        try RenderGallery.render(
            "pay10-de-se-xl-door",
            width: smallWidth,
            paywall(.lockedSheet, context: german).environment(\.dynamicTypeSize, .xxxLarge)
        )
        try RenderGallery.render(
            "pay10-de-se-xl-offer",
            width: smallWidth,
            offer().environment(\.dynamicTypeSize, .xxxLarge)
        )
    }

    func testArabic() throws {
        use(.ar)
        let arabic = context(name: "لينا", exam: ("الثانوية العامة", "eg.thanawiya"))
        try RenderGallery.render("pay10-ar-trial", height: tall, night: true, paywall(context: arabic, rtl: true))
        try RenderGallery.render("pay10-ar-door-mika", height: tall, paywall(.mika, context: arabic, rtl: true))
        try RenderGallery.render("pay10-ar-offer", height: tall, offer(rtl: true))
        try RenderGallery.render("pay10-ar-se-trial", width: smallWidth, height: smallHeight, paywall(context: arabic, rtl: true))
    }

    /// L'iPhone SE, en français : ce qui doit tenir sans défiler.
    func testSmallPhone() throws {
        use(.fr)
        try RenderGallery.render("pay10-fr-se-trial", width: smallWidth, height: smallHeight, night: true, paywall(context: context()))
        try RenderGallery.render("pay10-fr-se-door", width: smallWidth, height: smallHeight, paywall(.lessonReady, context: context()))
        try RenderGallery.render("pay10-fr-se-offer", width: smallWidth, height: smallHeight, night: true, offer())
        try RenderGallery.render(
            "pay10-fr-se-xl-trial",
            width: smallWidth,
            paywall(context: context()).environment(\.dynamicTypeSize, .xxxLarge)
        )
        try RenderGallery.render(
            "pay10-fr-se-xl-offer",
            width: smallWidth,
            offer().environment(\.dynamicTypeSize, .xxxLarge)
        )
    }
}
