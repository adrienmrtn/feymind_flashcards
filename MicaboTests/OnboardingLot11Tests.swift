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
        XCTAssertGreaterThanOrEqual(french.count, 39)
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

    /// **Les démonstrations suivent la reformulation** (lot 12) : Mika dit « je t'ai compris »,
    /// puis montre une réponse jouable par blocage ; le calendrier et la concentration suivent
    /// le temps par jour.
    func testEachDemoFollowsTheAnswerItIllustrates() {
        let order = OnboardingStep.allCases
        func after(_ demo: OnboardingStep, _ answer: OnboardingStep) {
            XCTAssertEqual(order.firstIndex(of: demo), order.firstIndex(of: answer).map { $0 + 1 }, "\(demo)")
        }
        after(.lessonDemo, .solutionMap)
        after(.cardsDemo, .lessonDemo)
        after(.scanDemo, .cardsDemo)
        after(.chatDemo, .scanDemo)
        after(.examDemo, .chatDemo)
        after(.planDemo, .dailyTime)
        after(.focusDemo, .planDemo)
        // Les écrans qui amènent au paywall : le plan, la leçon choisie, écrite, prête — et
        // rien qui annonce l'essai avant lui (retour testeur du build 179).
        XCTAssertEqual(Array(order.suffix(5)), [.profileSummary, .firstLesson, .lessonBuilding, .lessonReady, .paywall])
        let demos = OnboardingStep.allCases.filter { $0.kind == .demo }
        XCTAssertTrue((demos + [.commitment]).allSatisfy(\.showsChrome))
        XCTAssertTrue((demos + [.commitment]).allSatisfy(\.allowsReturn))
    }

    /// La démo de leçon parle de la matière cochée, jamais d'une matière qu'il n'a pas.
    func testTheLessonDemoUsesATickedSubject() {
        let model = OnboardingModel()
        model.subjects = ["Histoire"]
        XCTAssertEqual(OnbDemo.subject(for: model, locale: .fr), SubjectDisplay.subject("Histoire", locale: .fr))
        model.subjects = ["Anglais"]
        XCTAssertEqual(OnbDemo.subject(for: model, locale: .fr), SubjectDisplay.subject("Anglais", locale: .fr), "Sa seule matière, même sans question d'exemple")
        model.subjects = ["Anglais", "Espagnol"]
        XCTAssertNil(OnbDemo.subject(for: model, locale: .fr), "Aucune famille connue ni matière la plus dure : la phrase se dit sans matière")
        XCTAssertFalse(OnbDemo.topic(for: model, locale: .fr).hasPrefix("ios."))
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
