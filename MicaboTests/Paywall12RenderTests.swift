import SwiftUI
import XCTest
@testable import Micabo

/// **Le paywall, l'offre, la sortie et la bienvenue du lot 12, sur un vrai iPhone** : posés
/// dans une fenêtre avec les marges de l'iPhone 15 Pro (59/34) et de l'iPhone SE (20/0),
/// l'encoche et la barre d'accueil dessinées par-dessus (`RenderGallery.renderDevice`).
///
/// L'en-tête « essai » (la promesse, puis Mika, ce que l'élève a déclaré, le tableau, la
/// chronologie) ; une porte de l'app ; les états ; l'offre qui suit le paywall refusé (Mika
/// parle d'abord) ; la sortie propre ; la bienvenue d'un essai qui commence ; l'allemand et
/// l'arabe.
@MainActor
final class Paywall12RenderTests: XCTestCase {
    private var savedLocale: String?
    private var savedDisplay: PriceDisplay?
    private var savedName: String?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        savedLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
        savedDisplay = PriceDisplay.forced(in: .standard)
        savedName = OnboardingPreferences.displayName
        PriceDisplay.setOverride(.weekly)
        OnboardingPreferences.displayName = "Lina"
    }

    override func tearDown() {
        if let savedLocale {
            UserDefaults.standard.set(savedLocale, forKey: UiLocale.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UiLocale.storageKey)
        }
        PriceDisplay.setOverride(savedDisplay)
        OnboardingPreferences.displayName = savedName
        PaywallStorePrices.clear()
        super.tearDown()
    }

    private func use(_ locale: UiLocale) {
        UserDefaults.standard.set(locale.rawValue, forKey: UiLocale.storageKey)
    }

    /// Le 12 novembre 2026, dix heures : le rappel tombe le 14, la fin de l'essai le 15.
    private static let now: Date = {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10)) ?? Date()
    }()

    private static let examDay: Date = {
        Calendar.current.date(from: DateComponents(year: 2027, month: 6, day: 15)) ?? Date()
    }()

    private func context(
        name: String? = "Lina",
        exam: (name: String, id: String)? = ("Bac", "fr.bac"),
        subjects: [String] = ["Mathématiques", "Histoire", "SVT", "Philosophie"],
        reminder: Bool = true,
        topic: String? = "La guerre froide"
    ) -> PaywallContext {
        PaywallContext(
            profile: PaywallProfile(
                firstName: name,
                examName: exam?.name,
                examID: exam?.id,
                examDate: exam == nil ? nil : Self.examDay,
                subjects: subjects
            ),
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

    private func offer(remaining: Int = 86_382, rtl: Bool = false) -> some View {
        DiscountOfferScreen(
            clock: .fixed(remaining),
            isPurchasing: false,
            animatesArrival: false,
            onClose: {},
            onBuy: {},
            onRestore: {}
        )
        .environment(\.mikaStill, true)
        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
    }

    // MARK: - L'essai

    func testTrialOnDevice() throws {
        use(.fr)
        try RenderGallery.renderDevice("pay12-fr-trial", paywall(context: context()))
        try RenderGallery.renderDevice(
            "pay12-fr-trial-noreminder",
            devices: [.iPhone15Pro],
            paywall(context: context(reminder: false))
        )
        try RenderGallery.renderDevice(
            "pay12-fr-trial-plain",
            devices: [.iPhone15Pro],
            paywall(.upgrade, context: context(name: nil, exam: nil, subjects: [], reminder: false, topic: nil))
        )
    }

    /// L'essai déjà pris : ni chronologie, ni « gratuit », un bouton qui dit la somme.
    func testNoTrialOnDevice() throws {
        use(.fr)
        PaywallStorePrices.storeTrialEligibility([
            PaywallCatalog.yearly.productID: false,
            PaywallCatalog.weekly.productID: false,
        ])
        try RenderGallery.renderDevice("pay12-fr-notrial", devices: [.iPhone15Pro], paywall(context: context()))
        PaywallStorePrices.clear()
    }

    func testDoorAndStatesOnDevice() throws {
        use(.fr)
        try RenderGallery.renderDevice("pay12-fr-door-mika", devices: [.iPhone15Pro], paywall(.mika, context: context()))
        // L'aperçu d'un compte déjà Pro (constructions internes) : la mention sous le bouton.
        try RenderGallery.renderDevice(
            "pay12-fr-preview-pro",
            devices: [.iPhone15Pro],
            paywall(context: context(), notice: .info(L10n.t("ios.pay12.preview", locale: .fr)))
        )
        try RenderGallery.renderDevice("pay12-fr-loading", devices: [.iPhoneSE], paywall(context: context(), prices: .loading))
        // **Au toucher de « Voir ma leçon »** : le paywall parle de la leçon qui vient de s'écrire.
        var lesson = context()
        lesson.lessonTitle = "La guerre froide"
        try RenderGallery.renderDevice("pay12-fr-lesson", paywall(context: lesson))
        try RenderGallery.renderDevice("pay12-fr-buying", devices: [.iPhone15Pro], paywall(context: context(), purchasing: true))
    }

    // MARK: - L'offre, la sortie, la bienvenue

    func testOfferFarewellWelcomeOnDevice() throws {
        use(.fr)
        try RenderGallery.renderDevice("pay12-fr-offer", offer())
        try RenderGallery.renderDevice(
            "pay12-fr-farewell",
            PaywallFarewellScreen(name: "Lina", topic: "La guerre froide", onContinue: {}).environment(\.mikaStill, true)
        )
        let end = PaywallTimeline.endDate(from: Self.now, trialDays: 3)
        try RenderGallery.renderDevice(
            "pay12-fr-welcome",
            PaywallWelcomeScreen(name: "Lina", trialEnd: end, onContinue: {}).environment(\.mikaStill, true)
        )
    }

    // MARK: - L'allemand, l'arabe

    func testLanguagesOnDevice() throws {
        use(.de)
        OnboardingPreferences.displayName = "Mia"
        let german = context(name: "Mia", exam: ("Abitur", "de.abitur"), subjects: ["Mathématiques", "Physique", "Anglais"], topic: "Der Kalte Krieg")
        try RenderGallery.renderDevice("pay12-de-trial", paywall(context: german))
        try RenderGallery.renderDevice("pay12-de-offer", devices: [.iPhoneSE], offer())
        try RenderGallery.renderDevice(
            "pay12-de-welcome",
            devices: [.iPhoneSE],
            PaywallWelcomeScreen(name: "Mia", trialEnd: PaywallTimeline.endDate(from: Self.now, trialDays: 3), onContinue: {})
                .environment(\.mikaStill, true)
        )
        try RenderGallery.renderDevice(
            "pay12-de-farewell",
            devices: [.iPhoneSE],
            PaywallFarewellScreen(name: "Mia", topic: "Der Kalte Krieg", onContinue: {}).environment(\.mikaStill, true)
        )

        use(.ar)
        OnboardingPreferences.displayName = "لينا"
        let arabic = context(name: "لينا", exam: ("الثانوية العامة", "eg.thanawiya"), subjects: ["Mathématiques", "Physique"], topic: nil)
        try RenderGallery.renderDevice("pay12-ar-trial", devices: [.iPhone15Pro], paywall(context: arabic, rtl: true))
        try RenderGallery.renderDevice("pay12-ar-offer", devices: [.iPhone15Pro], offer(rtl: true))
        try RenderGallery.renderDevice(
            "pay12-ar-welcome",
            devices: [.iPhone15Pro],
            PaywallWelcomeScreen(name: "لينا", trialEnd: PaywallTimeline.endDate(from: Self.now, trialDays: 3), onContinue: {})
                .environment(\.mikaStill, true)
                .environment(\.layoutDirection, .rightToLeft)
        )
    }
}
