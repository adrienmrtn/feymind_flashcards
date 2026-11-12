import XCTest
@testable import Micabo

/// **Le parcours du lot 7 : cohérent, et honnête.** Ce qui se vérifie sans écran : la question
/// d'essai porte sur une matière de l'élève (ou de la culture générale, jamais une matière
/// qu'il n'a pas choisie), la bonne réponse n'est jamais en tête, chaque phrase existe dans les
/// 26 langues ; l'étude n'est citée qu'une fois ; les objectifs se déduisent de l'examen au
/// lieu d'être redemandés ; l'essai annonce de vraies dates.
final class OnboardingLot7Tests: XCTestCase {
    // MARK: - La question d'essai

    func testTheSampleCardFollowsTheStudentsSubjects() {
        XCTAssertEqual(SampleCard.pick(for: ["Mathématiques"]).card, .math)
        XCTAssertEqual(SampleCard.pick(for: ["Mathematik", "Deutsch"]).card, .math, "Dans l'ordre alphabétique : Deutsch se lit d'abord, sans question")
        XCTAssertEqual(SampleCard.pick(for: ["SVT"]).card, .biology)
        XCTAssertEqual(SampleCard.pick(for: ["Chemistry"]).card, .chemistry)
        XCTAssertEqual(SampleCard.pick(for: ["Physique-Chimie"]).card, .chemistry)
        XCTAssertEqual(SampleCard.pick(for: ["Histoire-Géographie"]).card, .history)
        XCTAssertEqual(SampleCard.pick(for: ["Philosophie"]).card, .philosophy)

        // La pastille montre la matière cochée, pas celle de la question.
        XCTAssertEqual(SampleCard.pick(for: ["Statistiques"]).subject, "Statistiques")
    }

    /// Des langues vivantes seulement : la question devient de la culture générale. Proposer
    /// « Mathématiques » à qui ne l'a pas cochée serait l'incohérence qu'on retire.
    func testNoSubjectTheStudentDidNotPick() {
        let pick = SampleCard.pick(for: ["Anglais", "Espagnol"])
        XCTAssertEqual(pick.subject, "Culture générale")
        XCTAssertFalse(["Anglais", "Espagnol"].contains(pick.card.catalogSubject))
        XCTAssertEqual(SampleCard.pick(for: []).subject, "Culture générale")
    }

    func testTheRightAnswerIsNeverShownFirst() {
        for card in SampleCard.allCases {
            XCTAssertEqual(Set(card.displayOrder), [0, 1, 2], "\(card)")
            XCTAssertNotEqual(card.displayOrder.first, 0, "\(card) : la bonne réponse en tête se devine")
            XCTAssertTrue(card.isRight(0))
            XCTAssertFalse(card.isRight(1))
        }
    }

    func testEverySampleCardSpeaksEveryLanguage() {
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for card in SampleCard.allCases {
                XCTAssertFalse((table[card.questionKey] ?? "").isEmpty, "\(locale.rawValue) \(card.questionKey)")
                for option in 0..<3 {
                    let text = card.option(option, locale: locale)
                    XCTAssertFalse(text.hasPrefix("ios."), "\(locale.rawValue) \(card) \(option)")
                }
            }
            for key in ["ios.onb7.card.ask", "ios.onb7.card.right", "ios.onb7.card.wrong",
                        "ios.onb7.card.proof", "ios.journey.source"] {
                XCTAssertFalse((table[key] ?? "").isEmpty, "\(locale.rawValue) \(key)")
            }
            XCTAssertTrue((table["ios.onb7.card.proof"] ?? "").contains("{testing}"), locale.rawValue)
            XCTAssertTrue((table["ios.onb7.card.proof"] ?? "").contains("{reread}"), locale.rawValue)
        }
    }

    // MARK: - Une étude, une fois

    /// **L'accroche ne dit plus « 2x »**, et la page « c'est prouvé » est partie : la seule
    /// étude du parcours est celle de la question d'essai.
    func testTheResearchIsCitedOnce() {
        let names = OnboardingStep.allCases.map(\.analyticsName)
        XCTAssertTrue(names.contains("sampleCard"))
        // Lot 9 : `socialProof` revient, sans étude (`OnboardingLot9Tests`).
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for (key, text) in table where key.hasPrefix("ios.onb9.proof.") {
                XCTAssertFalse(text.contains("Karpicke") || text.contains("Harvard"), "\(locale.rawValue) \(key)")
            }
        }
        for locale in UiLocale.allCases {
            let hook = L10n.t("ios.onb7.hook.title", locale: locale)
            XCTAssertFalse(hook.contains("2"), "\(locale.rawValue) : un chiffre sans source sur le premier écran")
            XCTAssertTrue(hook.contains("**"), locale.rawValue)
        }
    }

    // MARK: - Une question, une fois

    /// « Et pourquoi tu apprends ? » est parti : l'examen dit déjà pourquoi.
    func testTheGoalIsReadFromTheExamInsteadOfAskedTwice() {
        // Lot 9 : la question revient, mais jamais avec l'examen dans ses réponses.
        for tier in EducationTier.allCases.map(Optional.some) + [nil] {
            XCTAssertFalse(LearningGoal.offered(for: tier).contains(.exam), "\(String(describing: tier))")
            XCTAssertFalse(LearningGoal.offered(for: tier).contains(.lectures), "\(String(describing: tier))")
        }

        let model = OnboardingModel()
        XCTAssertEqual(model.learningGoals, [])
        model.examChoice = .noExam
        XCTAssertEqual(model.learningGoals, [.lectures])
        let dated = SchoolExams.choices(track: nil, year: nil, tier: nil).first { $0.hasDate }
        if let dated {
            model.examChoice = dated
            XCTAssertEqual(model.learningGoals, [.exam])
        }
        // L'objectif n°1 s'ajoute à ce que l'examen dit déjà.
        model.goals = [.grades]
        XCTAssertEqual(model.learningGoals, dated == nil ? [.grades, .lectures] : [.grades, .exam])
    }

    /// Mika dit « je » partout : plus de « il prend tes documents » trois écrans après « moi
    /// c'est Mika ».
    func testMikaSpeaksInTheFirstPerson() {
        for page in MikaPage.allCases {
            XCTAssertTrue(page.titleKey.hasPrefix("ios.onb7.") || page.titleKey.hasPrefix("ios.onb9."), "\(page)")
            let french = L10n.t(page.titleKey, locale: .fr)
            XCTAssertFalse(french.hasPrefix("Il "), french)
            XCTAssertFalse(french.contains("Mika,"), french)
        }
    }

    // MARK: - L'essai, daté

    func testTheTrialTimelineNamesRealDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 18)))
        let steps = TrialTimeline.milestones(from: start, calendar: calendar, locale: .fr)
        XCTAssertEqual(steps[1].title, "13 novembre : un rappel", "Le rappel part la veille de la fin, comme TrialEndReminder")
        XCTAssertEqual(steps[2].title, "14 novembre : ton abonnement commence")

        let fire = try XCTUnwrap(TrialEndReminder.fireDate(purchasedAt: start, trialDays: TrialTimeline.freeDays))
        XCTAssertEqual(calendar.component(.day, from: fire), 13, "La date affichée et celle du rappel sont la même")
    }

    // MARK: - Les phrases du lot, partout

    func testEveryLot7KeyExistsInEveryLanguage() {
        let french = IosI18nCatalogs.table(for: "fr").keys.filter { $0.hasPrefix("ios.onb7.") }
        XCTAssertGreaterThanOrEqual(french.count, 32)
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in french {
                XCTAssertFalse((table[key] ?? "").isEmpty, "\(locale.rawValue) \(key)")
            }
        }
        // La promesse de rappel ne cite plus de multiplicateur inventé.
        XCTAssertFalse(L10n.t("ios.onb7.notif.one", locale: .fr).contains("×"))
    }
}
