import SwiftUI
import XCTest
@testable import Micabo

/// **Le paywall et l'offre du lot 11, sur un vrai iPhone** : posés dans une fenêtre avec les
/// marges de l'iPhone 15 Pro (59/34) et de l'iPhone SE (20/0), l'encoche et la barre
/// d'accueil dessinées par-dessus (`RenderGallery.renderDevice`). C'est là que se voient une
/// croix sous l'encoche, un bouton ou des liens collés au bord bas.
///
/// L'en-tête « essai » (fin du parcours, « Passer en Pro ») avec ce que l'élève a déclaré ;
/// les portes de l'app, leur ligne du tableau en tête ; les états ; l'offre ; la bienvenue ;
/// l'allemand et l'arabe.
@MainActor
final class Paywall11RenderTests: XCTestCase {
    private var savedLocale: String?
    private var savedDisplay: PriceDisplay?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        savedLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
        savedDisplay = PriceDisplay.forced(in: .standard)
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
        try RenderGallery.renderDevice("pay11-fr-trial", paywall(context: context()))
        try RenderGallery.renderDevice(
            "pay11-fr-trial-plain",
            paywall(.upgrade, context: context(name: nil, exam: nil, subjects: [], reminder: false, topic: nil))
        )
        PriceDisplay.setOverride(.monthly)
        try RenderGallery.renderDevice("pay11-fr-trial-monthly", devices: [.iPhone15Pro], paywall(context: context()))
        PriceDisplay.setOverride(.weekly)
    }

    /// L'essai déjà pris : ni chronologie, ni « gratuit », un bouton qui dit la somme.
    func testNoTrialOnDevice() throws {
        use(.fr)
        PaywallStorePrices.storeTrialEligibility([
            PaywallCatalog.yearly.productID: false,
            PaywallCatalog.weekly.productID: false,
        ])
        try RenderGallery.renderDevice("pay11-fr-notrial", paywall(context: context()))
        try RenderGallery.renderDevice("pay11-fr-notrial-door", devices: [.iPhone15Pro], paywall(.mika, context: context()))
        PaywallStorePrices.clear()
    }

    // MARK: - Les portes

    func testDoorsOnDevice() throws {
        use(.fr)
        try RenderGallery.renderDevice("pay11-fr-door-lesson", paywall(.lessonReady, context: context()))
        try RenderGallery.renderDevice("pay11-fr-door-mika", paywall(.mika, context: context()))
        for trigger in [PaywallTrigger.mockExam, .generateCourse, .practice, .exportSheet, .secondCourse] {
            try RenderGallery.renderDevice("pay11-fr-door-\(trigger.rawValue)", devices: [.iPhone15Pro], paywall(trigger, context: context()))
        }
    }

    // MARK: - Les états

    func testStatesOnDevice() throws {
        use(.fr)
        try RenderGallery.renderDevice("pay11-fr-loading", devices: [.iPhoneSE], paywall(context: context(), prices: .loading))
        try RenderGallery.renderDevice(
            "pay11-fr-failed",
            devices: [.iPhoneSE],
            paywall(context: context(), prices: .failed(PaywallFailure.network.message))
        )
        try RenderGallery.renderDevice("pay11-fr-buying", devices: [.iPhone15Pro], paywall(context: context(), purchasing: true))
        try RenderGallery.renderDevice(
            "pay11-fr-error",
            devices: [.iPhone15Pro],
            paywall(.lessonReady, context: context(), notice: .error(PaywallFailure.store.message))
        )
    }

    // MARK: - L'offre, la bienvenue

    func testOfferOnDevice() throws {
        use(.fr)
        try RenderGallery.renderDevice("pay11-fr-offer", offer())
        try RenderGallery.renderDevice(
            "pay11-fr-welcome",
            PaywallWelcomeScreen(name: "Lina", onContinue: {}).environment(\.mikaStill, true)
        )
    }

    // MARK: - L'allemand, l'arabe

    func testLanguagesOnDevice() throws {
        use(.de)
        let german = context(exam: ("Abitur", "de.abitur"), subjects: ["Mathématiques", "Physique", "Anglais"], topic: "Der Kalte Krieg")
        try RenderGallery.renderDevice("pay11-de-trial", paywall(context: german))
        try RenderGallery.renderDevice("pay11-de-door-exam", paywall(.mockExam, context: german))
        try RenderGallery.renderDevice("pay11-de-offer", devices: [.iPhoneSE], offer())

        use(.ar)
        let arabic = context(name: "لينا", exam: ("الثانوية العامة", "eg.thanawiya"), subjects: ["Mathématiques", "Physique"], topic: nil)
        try RenderGallery.renderDevice("pay11-ar-trial", paywall(context: arabic, rtl: true))
        try RenderGallery.renderDevice("pay11-ar-door-mika", devices: [.iPhone15Pro], paywall(.mika, context: arabic, rtl: true))
    }
}
