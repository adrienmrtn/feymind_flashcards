import XCTest
@testable import Micabo

/// **L'entonnoir du lot 12** : les phrases dans les six langues, rien d'inventé, Mika qui
/// reformule avec les réponses, l'engagement écrit avec elles, le plan qui les cite, le
/// paywall qui ne promet le rappel que s'il partira, l'offre qui parle en premier.
@MainActor
final class OnboardingLot12Tests: XCTestCase {
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

    private func lina() throws -> OnboardingModel {
        let model = OnboardingModel()
        model.displayName = "Lina"
        model.select(worldCountry: try XCTUnwrap(WorldCountries.country(code: "FR")))
        let track = try XCTUnwrap(model.tracks.first { $0.id == "fr.lyceeGeneral" })
        model.track = track
        model.year = track.years.first { $0.id == "fr.terminale" }
        if let first = model.examChoices.first { model.choose(exam: first) }
        model.subjects = ["Mathématiques", "Philosophie", "Physique-Chimie"]
        model.hardestSubject = "Mathématiques"
        model.toggle(worry: .forgetting)
        model.toggle(worry: .homework)
        model.toggle(worry: .examStress)
        model.weeklyStudy = .oneToThree
        model.studyMethod = .rereading
        model.currentScore = 12
        model.targetScore = 16
        model.dailyMinutes = 15
        model.studyHour = 18
        return model
    }

    // MARK: - Les phrases

    /// Chaque phrase du lot existe dans les six langues, avec ses mots-clés et ses variables.
    func testEveryPhraseExistsInTheSixLanguages() {
        let french = IosI18nCatalogs.table(for: "fr").filter { $0.key.hasPrefix("ios.onb12.") || $0.key.hasPrefix("ios.pay12.") }
        XCTAssertGreaterThanOrEqual(french.count, 170)
        for locale in Self.languages {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for (key, source) in french {
                let text = table[key] ?? ""
                XCTAssertFalse(text.isEmpty, "\(locale.rawValue) \(key)")
                XCTAssertEqual(text.components(separatedBy: "**").count % 2, 1, "\(locale.rawValue) \(key)")
                XCTAssertEqual(I18nTests.placeholders(in: text), I18nTests.placeholders(in: source), "\(locale.rawValue) \(key)")
            }
            for family in SampleCard.allCases {
                XCTAssertFalse(family.demoCardQuestion(locale: locale).hasPrefix("ios."), "\(locale.rawValue) \(family)")
                XCTAssertFalse(family.demoCardAnswer(locale: locale).hasPrefix("ios."), "\(locale.rawValue) \(family)")
            }
            for hours in WeeklyStudy.allCases {
                XCTAssertFalse(hours.title(locale: locale).hasPrefix("ios."))
                XCTAssertFalse(hours.reaction(locale: locale).hasPrefix("ios."))
            }
            for method in StudyMethod.allCases {
                XCTAssertFalse(method.title(locale: locale).hasPrefix("ios."))
                XCTAssertFalse(method.recap(locale: locale).hasPrefix("ios."))
            }
            for worry in StudyWorry.allCases {
                XCTAssertFalse(WorriesStepView.reaction(to: worry, locale: locale).hasPrefix("ios."))
            }
        }
    }

    /// **Rien d'inventé** : ni pourcentage, ni grand nombre, ni étude, ni chiffre
    /// d'utilisateurs dans les phrases du lot.
    func testNoFigureAndNoStudy() throws {
        let bigNumber = try NSRegularExpression(pattern: #"[0-9]{3,}"#)
        for locale in Self.languages {
            for (key, text) in IosI18nCatalogs.table(for: locale.rawValue) where key.hasPrefix("ios.onb12.") || key.hasPrefix("ios.pay12.") {
                XCTAssertFalse(text.contains("%") || text.contains("٪"), "\(locale.rawValue) \(key)")
                XCTAssertNil(bigNumber.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), "\(locale.rawValue) \(key)")
                for name in ["Karpicke", "Harvard", "000", "★"] {
                    XCTAssertFalse(text.contains(name), "\(locale.rawValue) \(key)")
                }
            }
        }
    }

    /// La jauge en actes : les actes finis pleins, celui en cours à son avancée, la suite vide.
    func testTheActGaugeFillsItsSegments() {
        let gauge = V3ActProgress(acts: 7, act: 2, fraction: 0.5)
        XCTAssertEqual(gauge.fill(of: 0), 1)
        XCTAssertEqual(gauge.fill(of: 2), 0.5)
        XCTAssertEqual(gauge.fill(of: 5), 0)
    }

    // MARK: - Mika reformule

    /// **« Je t'ai compris »** : chaque ligne vient d'une réponse, quatre au plus ; une
    /// réponse absente retire sa ligne.
    func testTheRecapIsMadeOfTheAnswers() throws {
        let model = try lina()
        let lines = SolutionMapStepView.lines(for: model, locale: .fr).map(\.text)
        XCTAssertEqual(lines.count, 4)
        XCTAssertTrue(lines[0].contains("Mathématiques"), lines[0])
        XCTAssertTrue(lines[1].contains(StudyWorry.forgetting.title(locale: .fr)), "Le premier blocage coché d'abord")

        let empty = OnboardingModel()
        XCTAssertTrue(SolutionMapStepView.lines(for: empty, locale: .fr).isEmpty)
    }

    /// **Le plan qui se construit cite les réponses**, la matière la plus dure et l'objectif
    /// compris.
    func testThePlanLinesCiteTheNewAnswers() throws {
        let lines = try lina().planLines(locale: .fr)
        XCTAssertTrue(lines.contains("Mathématiques en premier"), "\(lines)")
        XCTAssertTrue(lines.contains { $0.hasPrefix("Ton objectif : 12/20") }, "\(lines)")
        for line in lines { XCTAssertFalse(line.contains("{") || line.contains("ios."), line) }
    }

    // MARK: - L'engagement

    /// **La promesse est écrite avec les réponses** : le prénom, le temps, le jour de l'examen ;
    /// sans examen, sans date ; sans prénom, sans prénom.
    func testThePromiseIsWrittenWithTheAnswers() throws {
        let model = try lina()
        let promise = CommitmentStepView.studentPromise(for: model, locale: .fr)
        XCTAssertTrue(promise.contains("Lina") && promise.contains("15\u{00A0}min"), promise)
        XCTAssertTrue(promise.contains("juin"), promise)

        model.examChoice = .noExam
        let open = CommitmentStepView.studentPromise(for: model, locale: .fr)
        XCTAssertFalse(open.contains("d'ici"), open)

        model.displayName = ""
        XCTAssertFalse(CommitmentStepView.studentPromise(for: model, locale: .fr).contains("{"))
        XCTAssertGreaterThanOrEqual(CommitmentStepView.holdSeconds, 1, "Un geste qu'on tient, pas un appui")
    }

    // MARK: - Les démonstrations

    /// Les démonstrations prennent la matière la plus dure ; la carte n'est pas la question
    /// d'essai qui suit.
    func testTheDemosUseTheHardestSubject() throws {
        let model = try lina()
        XCTAssertEqual(OnbDemo.subject(for: model, locale: .fr), "Mathématiques")
        XCTAssertEqual(OnbDemo.family(for: model), .math)
        XCTAssertEqual(OnbDemo.sessionSubjects(for: model, locale: .fr).first, "Mathématiques")
        XCTAssertNotEqual(SampleCard.math.demoCardQuestion(locale: .fr), L10n.t(SampleCard.math.questionKey, locale: .fr))
        XCTAssertEqual(ExamDemoStepView.marks.filter { $0 }.count, 2)
    }

    // MARK: - Le paywall et l'offre

    /// **Le parcours d'un compte gratuit finit toujours sur le paywall** : quel que soit le
    /// pays, que la boutique propose l'essai ou non (les deux écrans de l'essai se sautent, le
    /// paywall jamais), et sans aucune réponse donnée.
    func testAFreeAccountAlwaysEndsOnThePaywall() throws {
        for country in [SchoolingCountry.fr, .de, .us, .other] {
            let model = OnboardingModel()
            model.select(country: country)
            XCTAssertFalse(model.isSkipped(.paywall), "\(country)")
            var guardCounter = 0
            while model.step != .paywall, guardCounter < OnboardingStep.allCases.count * 2 {
                if model.isAccountSheetPresented { model.finishAccountSheet() } else { model.advance() }
                guardCounter += 1
            }
            XCTAssertEqual(model.step, .paywall, "\(country) : le parcours doit finir sur le paywall")
            XCTAssertFalse(model.advance(), "Rien après le paywall")
        }
        XCTAssertEqual(OnboardingStep.allCases.last, .paywall)
        for internal in [false, true] {
            for forced in [false, true] {
                XCTAssertTrue(
                    PaywallTestMode.showsOnboardingPaywall(isPro: false, forcedByTest: forced, isInternal: internal),
                    "Un compte gratuit voit toujours le paywall"
                )
            }
        }
        XCTAssertTrue(PaywallStepView.keepsPaywall(shows: true, didShow: false))
    }

    /// **Un compte déjà Pro voit le paywall en aperçu dans les constructions internes**, et un
    /// vrai abonné de l'App Store finit sans paywall.
    func testAProAccountSeesThePaywallInInternalBuilds() {
        XCTAssertTrue(PaywallTestMode.showsOnboardingPaywall(isPro: true, forcedByTest: false, isInternal: true))
        XCTAssertFalse(PaywallTestMode.showsOnboardingPaywall(isPro: true, forcedByTest: false, isInternal: false))
        XCTAssertTrue(PaywallTestMode.showsOnboardingPaywall(isPro: true, forcedByTest: true, isInternal: false))
        XCTAssertFalse(L10n.t("ios.pay12.preview", locale: .fr).hasPrefix("ios."))
    }

    /// **Mika ne promet le rappel que s'il partira** ; sans essai, il parle d'annulation.
    func testThePaywallMikaPromisesOnlyWhatIsKept() {
        let reminded = PaywallCopy.trialMika(name: "Lina", remindsBeforeEnd: true, offersTrial: true, locale: .fr)
        XCTAssertTrue(reminded.text.contains("préviens"), reminded.text)
        XCTAssertTrue(reminded.text.contains("Lina"))
        let refused = PaywallCopy.trialMika(name: "Lina", remindsBeforeEnd: false, offersTrial: true, locale: .fr)
        XCTAssertFalse(refused.text.contains("préviens"), refused.text)
        let noTrial = PaywallCopy.trialMika(name: nil, remindsBeforeEnd: true, offersTrial: false, locale: .fr)
        XCTAssertFalse(noTrial.text.contains("préviens"), noTrial.text)
        XCTAssertFalse(noTrial.text.contains("{"))
        XCTAssertNotNil(PaywallDensity.regular.mikaSize)
        XCTAssertNil(PaywallDensity.bare.mikaSize, "Sur un petit écran, Mika laisse la place à ce qui est promis")
    }

    /// **L'offre parle en premier**, avec le prénom quand il est connu, et sans reproche.
    func testTheOfferOpensWithMika() {
        let named = DiscountOfferScreen.mikaLine(name: "Lina", locale: .fr)
        XCTAssertTrue(named.text.hasPrefix("Attends, Lina"), named.text)
        XCTAssertNotNil(named.highlight)
        let anonymous = DiscountOfferScreen.mikaLine(name: nil, locale: .fr)
        XCTAssertFalse(anonymous.text.contains("{"))
    }
}
