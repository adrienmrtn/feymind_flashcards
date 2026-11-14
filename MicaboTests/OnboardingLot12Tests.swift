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
        for isInternal in [false, true] {
            for forced in [false, true] {
                XCTAssertTrue(
                    PaywallTestMode.showsOnboardingPaywall(isPro: false, forcedByTest: forced, isInternal: isInternal),
                    "Un compte gratuit voit toujours le paywall"
                )
            }
        }
        XCTAssertTrue(PaywallStepView.keepsPaywall(shows: true, didShow: false))
    }

    /// **Aucune leçon ne s'écrit avant le paywall** (lot 13) : le sujet choisi part à la Home,
    /// qui le propose en grand ; le parcours passe par l'essai, puis le paywall titré sur le
    /// plan. Aucune vue du parcours ne lance d'écriture.
    func testNoLessonIsWrittenBeforeThePaywall() throws {
        let model = try lina()
        model.place(on: .firstLesson)
        model.firstLessonChoice = .topic
        model.firstLessonTopic = "La guerre froide"
        model.confirmFirstLesson()
        XCTAssertEqual(FirstLessonIntent.pending, .topic("La guerre froide"), "La Home le proposera")
        XCTAssertEqual(model.step, OnboardingTrial.isOffered ? .freeTrialIntro : .paywall)
        while model.step != .paywall, model.advance() {}
        XCTAssertEqual(model.step, .paywall)

        let steps = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo/Features/Onboarding", isDirectory: true)
        guard let files = FileManager.default.enumerator(at: steps, includingPropertiesForKeys: nil) else {
            throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
        }
        var read = 0
        for case let url as URL in files where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            read += 1
            for call in ["LessonGeneration(", "builder.create(", ".start(composer:"] {
                XCTAssertFalse(text.contains(call), "\(url.lastPathComponent) écrit une leçon avant le paywall (\(call))")
            }
        }
        guard read > 0 else { throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur") }
    }

    /// **« On veut que tu essaies Micabo Pro gratuitement »** : trois choses, tirées des
    /// réponses (sa leçon, sa matière la plus dure, son examen).
    func testTheTrialUnlocksAreMadeOfTheAnswers() throws {
        let model = try lina()
        model.firstLessonChoice = .topic
        model.firstLessonTopic = "La guerre froide"
        let unlocks = FreeTrialIntroStepView.unlocks(for: model, locale: .fr)
        XCTAssertEqual(unlocks.count, 3)
        XCTAssertTrue(unlocks[0].text.contains("La guerre froide"), unlocks[0].text)
        XCTAssertTrue(unlocks[1].text.contains("Mathématiques"), unlocks[1].text)
        XCTAssertFalse(unlocks[2].text.hasSuffix("pour Bac"), "L'examen prend son article : \(unlocks[2].text)")
        for unlock in FreeTrialIntroStepView.unlocks(for: OnboardingModel(), locale: .fr) {
            XCTAssertFalse(unlock.text.contains("{") || unlock.text.hasPrefix("ios."), unlock.text)
        }
        // Le rappel ne se promet qu'avec des notifications permises (ou à demander).
        XCTAssertTrue(TrialOfferStepView.promises(.ask, trialDays: 3))
        XCTAssertTrue(TrialOfferStepView.promises(.granted, trialDays: 3))
        XCTAssertFalse(TrialOfferStepView.promises(.denied, trialDays: 3))
        XCTAssertFalse(TrialOfferStepView.promises(.granted, trialDays: 1), "Un essai d'un jour n'a pas de veille")
    }

    /// **Le glissement vers le bas fait exactement comme la croix** (lot 13) : le paywall mène
    /// à l'offre (ou à la sortie), l'offre à la sortie, l'au revoir à l'app ; la bienvenue ne se
    /// referme que par son bouton. Un défilement ou un geste de côté ne ferme rien.
    func testSwipingDownDoesWhatTheCrossDoes() {
        XCTAssertEqual(PaywallFlowView.close(for: .paywall), .paywall)
        XCTAssertEqual(PaywallFlowView.close(for: .offer), .offer)
        XCTAssertEqual(PaywallFlowView.close(for: .farewell), .farewell)
        XCTAssertEqual(PaywallFlowView.close(for: .welcome), .none)
        XCTAssertTrue(PaywallFlowView.isDismissSwipe(translation: CGSize(width: 10, height: 180), startY: 120))
        XCTAssertFalse(PaywallFlowView.isDismissSwipe(translation: CGSize(width: 10, height: 60), startY: 120), "trop court")
        XCTAssertFalse(PaywallFlowView.isDismissSwipe(translation: CGSize(width: 200, height: 150), startY: 120), "de côté")
        XCTAssertFalse(PaywallFlowView.isDismissSwipe(translation: CGSize(width: 0, height: -200), startY: 120), "vers le haut")
        XCTAssertFalse(PaywallFlowView.isDismissSwipe(translation: CGSize(width: 0, height: 200), startY: 600), "un défilement plus bas")
    }

    /// **Après les refus, la Home propose la première leçon en grand**, avec le sujet choisi,
    /// et dit simplement qu'elle est offerte tant qu'elle l'est.
    func testTheHomeProposesTheFirstLesson() {
        var input = HomeBoardInput(day: HomeDay(hasCourses: false), name: "Lina")
        input.firstTopic = "La guerre froide"
        input.firstIsFree = true
        let board = HomeBoard.resolve(input, locale: .fr)
        XCTAssertEqual(board.moment, .newcomer)
        XCTAssertTrue(board.phrase.plain.contains("La guerre froide"), board.phrase.plain)
        XCTAssertEqual(board.phrase.keyword, "La guerre froide")
        XCTAssertEqual(board.action?.kind, .first)
        XCTAssertEqual(board.caption, "Ta première leçon est offerte.")

        input.firstIsFree = false
        XCTAssertNil(HomeBoard.resolve(input, locale: .fr).caption, "Une leçon gratuite déjà servie ne s'annonce plus")

        input.firstTopic = nil
        XCTAssertNotEqual(HomeBoard.resolve(input, locale: .fr).action?.title, L10n.t("ios.home13.cta.firstTopic", locale: .fr))
        XCTAssertNil(LessonAllowance.gate(isPro: false, source: .topic, courses: []), "La première leçon part, sans paywall")
    }

    /// **Rien n'annonce le gratuit avant le paywall** : ni « leçon offerte », ni essai, ni
    /// limite, sur le choix de la leçon, son écriture et « Ta leçon est prête ».
    func testNothingAnnouncesFreeBeforeThePaywall() {
        let keys = [
            "ios.onb10.q.lesson", "ios.onb12.say.lesson", "ios.onb10.lesson.topic", "ios.onb10.lesson.import",
            "ios.onb10.lesson.importHint", "ios.onb12.trial.unlock.lesson", "ios.onb12.trial.unlock.import",
        ]
        for key in keys {
            let text = L10n.t(key, locale: .fr).lowercased()
            // L'essai, lui, s'annonce (deux écrans) ; la leçon gratuite, jamais avant le paywall.
            for word in ["offert", "gratuit", "limite", "abonn"] {
                XCTAssertFalse(text.contains(word), "\(key) : « \(word) »")
            }
        }
    }

    /// **Un choix unique n'a pas de bouton** : il avance au toucher. Aucun « Continuer » ne
    /// reste au pied de ces écrans (retour testeur du build 179).
    func testSingleChoiceScreensHaveNoButton() throws {
        let steps = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo/Features/Onboarding/Steps", isDirectory: true)
        var read = 0
        for file in ["SchoolStepViews.swift", "GoalStepViews.swift", "HabitStepViews.swift", "SubjectsStepView.swift"] {
            guard let text = try? String(contentsOf: steps.appendingPathComponent(file), encoding: .utf8) else { continue }
            read += 1
            for answer in [
                "model.hasAnsweredCountry", "model.track != nil", "model.year != nil", "model.stage != nil",
                "model.mainGoal != nil", "model.weeklyStudy != nil", "model.studyMethod != nil",
                "model.dailyMinutes != nil", "model.hardestSubject != nil",
            ] {
                XCTAssertFalse(text.contains("isEnabled: \(answer)"), "\(file) : un bouton sur un choix unique (\(answer))")
            }
        }
        guard read > 0 else { throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur") }
    }

    /// **Un compte déjà Pro voit le paywall en aperçu dans les constructions internes**, et un
    /// vrai abonné de l'App Store finit sans paywall.
    func testAProAccountSeesThePaywallInInternalBuilds() {
        XCTAssertTrue(PaywallTestMode.showsOnboardingPaywall(isPro: true, forcedByTest: false, isInternal: true))
        XCTAssertFalse(PaywallTestMode.showsOnboardingPaywall(isPro: true, forcedByTest: false, isInternal: false))
        XCTAssertTrue(PaywallTestMode.showsOnboardingPaywall(isPro: true, forcedByTest: true, isInternal: false))
        XCTAssertFalse(L10n.t("ios.pay12.preview", locale: .fr).hasPrefix("ios."))
    }

    /// **Le paywall ne promet le rappel que s'il partira**, et ne dit « gratuitement » que si
    /// l'essai est offert. Le grand titre parle de son examen.
    func testThePaywallPromisesOnlyWhatIsKept() throws {
        let reminder = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 10)))
        let reminded = PaywallCopy.trialLine(reminder: reminder, locale: .fr)
        XCTAssertEqual(reminded, "Rien à payer aujourd'hui · je te préviens le 14 novembre")
        let refused = PaywallCopy.trialLine(reminder: nil, locale: .fr)
        XCTAssertEqual(refused, "Rien à payer aujourd'hui")

        XCTAssertEqual(PaywallCopy.promise(offersTrial: true, trialDays: 3, locale: .fr), "Essaie-le 3 jours, gratuitement.")
        XCTAssertFalse(PaywallCopy.promise(offersTrial: false, trialDays: 3, locale: .fr).contains("gratuit"))

        let lina = PaywallProfile(firstName: "Lina", examName: "Bac", examID: "fr.bac")
        let headline = PaywallCopy.headline(profile: lina, locale: .fr)
        XCTAssertEqual(headline.text, "Ton plan pour le Bac est prêt.")
        XCTAssertEqual(headline.highlight, "le Bac")
        XCTAssertNil(PaywallCopy.headline(profile: PaywallProfile(), locale: .fr).highlight)
        for locale in Self.languages {
            XCTAssertFalse(PaywallCopy.trialLine(reminder: reminder, locale: locale).contains("{"), locale.rawValue)
        }
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
