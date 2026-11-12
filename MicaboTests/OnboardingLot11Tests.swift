import XCTest
@testable import Micabo

/// **Le parcours du lot 11** : les démos liées aux réponses, les trois écrans qui amènent à
/// l'offre, la bienvenue après l'achat, le pied au-dessus de la barre d'accueil.
@MainActor
final class OnboardingLot11Tests: XCTestCase {
    private static let languages: [UiLocale] = [.fr, .en, .de, .es, .tr, .ar]

    override func setUp() {
        super.setUp()
        OnboardingPreferences.reset()
        FirstLessonIntent.pending = nil
    }

    override func tearDown() {
        OnboardingPreferences.reset()
        FirstLessonIntent.pending = nil
        super.tearDown()
    }

    /// Chaque phrase du lot existe dans les six langues, avec ses mots-clés et ses variables.
    func testEveryPhraseExistsInTheSixLanguages() {
        let french = IosI18nCatalogs.table(for: "fr").filter { $0.key.hasPrefix("ios.onb11.") }
        XCTAssertGreaterThanOrEqual(french.count, 38)
        for locale in Self.languages {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for (key, source) in french {
                let text = table[key] ?? ""
                XCTAssertFalse(text.isEmpty, "\(locale.rawValue) \(key)")
                XCTAssertEqual(text.components(separatedBy: "**").count % 2, 1, "\(locale.rawValue) \(key)")
                XCTAssertEqual(I18nTests.placeholders(in: text), I18nTests.placeholders(in: source), "\(locale.rawValue) \(key)")
            }
        }
    }

    /// **Rien d'inventé** : ni pourcentage, ni grand nombre, ni étude dans les phrases du lot.
    func testNoFigureAndNoStudy() throws {
        let bigNumber = try NSRegularExpression(pattern: #"[0-9]{3,}"#)
        for locale in Self.languages {
            for (key, text) in IosI18nCatalogs.table(for: locale.rawValue) where key.hasPrefix("ios.onb11.") {
                XCTAssertFalse(text.contains("%") || text.contains("٪"), "\(locale.rawValue) \(key)")
                XCTAssertNil(bigNumber.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), "\(locale.rawValue) \(key)")
                for name in ["Karpicke", "Harvard", "000"] {
                    XCTAssertFalse(text.contains(name), "\(locale.rawValue) \(key)")
                }
            }
        }
    }

    /// Chaque démo suit la réponse qui la précède.
    func testEachDemoFollowsTheAnswerItIllustrates() {
        let order = OnboardingStep.allCases
        func after(_ demo: OnboardingStep, _ answer: OnboardingStep) {
            XCTAssertEqual(order.firstIndex(of: demo), order.firstIndex(of: answer).map { $0 + 1 }, "\(demo)")
        }
        after(.lessonDemo, .subjects)
        after(.scanDemo, .solutionMap)
        after(.planDemo, .dailyTime)
        after(.chatDemo, .sampleCard)
        // Les quatre écrans qui amènent à l'offre : le plan, ce que l'essai ouvre, la fin de
        // l'essai, pourquoi maintenant.
        XCTAssertEqual(Array(order.suffix(5)), [.profileSummary, .freeTrialIntro, .trialOffer, .whyNow, .paywall])
        XCTAssertTrue([OnboardingStep.lessonDemo, .scanDemo, .planDemo, .chatDemo, .whyNow].allSatisfy(\.showsChrome))
        XCTAssertTrue([OnboardingStep.lessonDemo, .scanDemo, .planDemo, .chatDemo, .whyNow].allSatisfy(\.allowsReturn))
    }

    /// La phrase du scanner reprend le blocage coché.
    func testTheScannerSpeaksToTheWorry() {
        XCTAssertEqual(ScanDemoStepView.askKey(worries: [.homework, .hardLessons]), "ios.onb11.scan.askHomework")
        XCTAssertEqual(ScanDemoStepView.askKey(worries: [.hardLessons]), "ios.onb11.scan.askHard")
        XCTAssertEqual(ScanDemoStepView.askKey(worries: [.forgetting]), "ios.onb11.scan.ask")
    }

    /// La démo de leçon parle de la matière cochée, jamais d'une matière qu'il n'a pas.
    func testTheLessonDemoUsesATickedSubject() {
        let model = OnboardingModel()
        model.subjects = ["Histoire"]
        XCTAssertEqual(OnbDemo.subject(for: model, locale: .fr), SubjectDisplay.subject("Histoire", locale: .fr))
        model.subjects = ["Anglais"]
        XCTAssertNil(OnbDemo.subject(for: model, locale: .fr), "Aucune famille connue : la phrase se dit sans matière")
        XCTAssertFalse(OnbDemo.topic(for: model, locale: .fr).hasPrefix("ios."))
    }

    /// Les séances d'ici l'examen : une par jour, à partir de deux jours (« 1 séances » ne se dit pas).
    func testSessionsLeftAreTheDaysLeft() {
        XCTAssertNil(WhyNowStepView.sessionsLeft(daysLeft: nil))
        XCTAssertNil(WhyNowStepView.sessionsLeft(daysLeft: 1))
        XCTAssertEqual(WhyNowStepView.sessionsLeft(daysLeft: 12), 12)
    }

    /// Ce que l'essai ouvre : la première leçon (offerte de toute façon) en tête, l'examen nommé.
    func testTheTrialUnlocksAreMadeOfTheAnswers() {
        let model = OnboardingModel()
        model.firstLessonChoice = .topic
        model.firstLessonTopic = "La guerre froide"
        let unlocks = FreeTrialIntroStepView.unlocks(for: model, locale: .fr)
        XCTAssertEqual(unlocks.count, 6)
        XCTAssertTrue(unlocks[0].isFree)
        XCTAssertTrue(unlocks[0].text.contains("La guerre froide"))
        XCTAssertEqual(unlocks.filter(\.isFree).count, 1)
    }

    /// **La bienvenue après l'achat** : une fois montré, le paywall reste monté même quand Pro
    /// s'ouvre ; un abonné qui arrive ne le voit pas.
    func testThePaywallStaysOnceShown() {
        XCTAssertTrue(PaywallStepView.keepsPaywall(shows: true, didShow: false))
        XCTAssertTrue(PaywallStepView.keepsPaywall(shows: false, didShow: true), "L'achat ne démonte pas la bienvenue")
        XCTAssertFalse(PaywallStepView.keepsPaywall(shows: false, didShow: false))
    }

    /// Le bouton du pied se pose au-dessus de la barre d'accueil, et loin du bord d'un SE.
    func testTheFooterSitsAboveTheHomeIndicator() {
        XCTAssertEqual(OnbLayout.footerGap(safeBottom: 34), 16)
        XCTAssertEqual(OnbLayout.footerGap(safeBottom: 0), 24)
    }
}
