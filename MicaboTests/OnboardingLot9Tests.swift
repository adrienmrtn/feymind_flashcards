import XCTest
@testable import Micabo

/// **Lot 9**, ce qui en reste dans le parcours du lot 10 : l'objectif n°1 selon le niveau, et le
/// paywall qu'on ne voyait plus (« j'vois pas le paywall »), que « Refaire l'onboarding » montre
/// toujours. Les écrans que le lot 9 avait remis sont partis : voir `OnboardingFlowTests` et
/// `OnboardingContentTests`.
final class OnboardingLot9Tests: XCTestCase {
    // MARK: - Le paywall, visible en test

    /// **La section Test n'existe que sur un reçu de bac à sable** (TestFlight) ou dans une
    /// construction Xcode : jamais avec le reçu de l'App Store, jamais sans reçu, jamais pour le
    /// compte de relecture d'Apple.
    func testThePaywallTestsExistOnlyInSandboxBuilds() {
        XCTAssertTrue(PaywallTestMode.isAvailable(receiptName: "sandboxReceipt", isDebugBuild: false, email: nil))
        XCTAssertTrue(PaywallTestMode.isAvailable(receiptName: "sandboxReceipt", isDebugBuild: false, email: "adrien.not@gmail.com"))
        XCTAssertFalse(PaywallTestMode.isAvailable(receiptName: "receipt", isDebugBuild: false, email: nil), "L'App Store")
        XCTAssertFalse(PaywallTestMode.isAvailable(receiptName: "receipt", isDebugBuild: false, email: "adrien.not@gmail.com"),
                       "Même le compte développeur ne voit pas la section sur l'App Store")
        XCTAssertFalse(PaywallTestMode.isAvailable(receiptName: nil, isDebugBuild: false, email: nil), "Pas de reçu : pas de section")
        XCTAssertFalse(PaywallTestMode.isAvailable(receiptName: "sandboxReceipt", isDebugBuild: false, email: "review@apple.com"),
                       "La relecture d'Apple tourne aussi sur un reçu de bac à sable")
        XCTAssertFalse(PaywallTestMode.isAvailable(receiptName: "sandboxReceipt", isDebugBuild: false, email: "review2@apple.com"))
        XCTAssertTrue(PaywallTestMode.isAvailable(receiptName: nil, isDebugBuild: true, email: nil), "Une construction Xcode")
        XCTAssertEqual(PaywallTestMode.sandboxReceiptName, "sandboxReceipt")
    }

    /// **La cause du paywall invisible** : un abonné termine le parcours sans paywall. Le test
    /// le demande quand même ; un élève sans abonnement le voit toujours.
    func testTheOnboardingPaywallIsSkippedOnlyForASubscriberOutsideTests() {
        XCTAssertTrue(PaywallTestMode.showsOnboardingPaywall(isPro: false, forcedByTest: false))
        XCTAssertFalse(PaywallTestMode.showsOnboardingPaywall(isPro: true, forcedByTest: false),
                       "Un abonné ne se voit pas proposer l'essai qu'il paie déjà")
        XCTAssertTrue(PaywallTestMode.showsOnboardingPaywall(isPro: true, forcedByTest: true),
                      "« Refaire l'onboarding » montre le paywall même au compte Pro à vie")
        XCTAssertTrue(PaywallTestMode.showsOnboardingPaywall(isPro: false, forcedByTest: true))
    }

    /// Le compte développeur est Pro à vie : c'est lui qui ne voyait plus aucun paywall.
    func testTheDeveloperAccountIsProForLife() {
        XCTAssertTrue(LifetimePro.matches(" Adrien.Not@gmail.com "))
        XCTAssertFalse(LifetimePro.matches("eleve@example.com"))
    }

    /// Le drapeau posé par « Refaire l'onboarding » se lit, puis s'efface à la fin du parcours.
    func testTheReplayFlagIsReadThenCleared() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "lot9.paywall.\(UUID().uuidString)"))
        XCTAssertFalse(PaywallTestMode.forcesOnboardingPaywall(defaults: defaults))
        PaywallTestMode.setForcesOnboardingPaywall(true, defaults: defaults)
        // Les tests tournent dans une construction de développement : le mode test y existe.
        XCTAssertTrue(PaywallTestMode.forcesOnboardingPaywall(defaults: defaults))
        PaywallTestMode.setForcesOnboardingPaywall(false, defaults: defaults)
        XCTAssertFalse(PaywallTestMode.forcesOnboardingPaywall(defaults: defaults))
        XCTAssertNil(defaults.object(forKey: PaywallTestMode.onboardingPaywallKey))
    }

    /// Le drapeau survit à la remise à zéro du parcours : il est posé après elle, et c'est le
    /// paywall de la fin qui l'efface.
    func testTheReplayFlagIsNotAnOnboardingAnswer() {
        XCTAssertFalse(OnboardingPreferences.Key.all.contains(PaywallTestMode.onboardingPaywallKey))
    }

    /// Les trois rangées de la section : le paywall, l'offre de secours, le parcours refait.
    @MainActor
    func testTheTestSectionHasItsThreeRows() {
        for locale in UiLocale.allCases {
            let rows = SettingsView.paywallTestRows(locale: locale, showPaywall: {}, showDiscount: {}, replayOnboarding: {})
            XCTAssertEqual(rows.count, 3)
            for row in rows {
                XCTAssertFalse(row.title.hasPrefix("ios."), "\(locale) \(row.title)")
                XCTAssertFalse((row.subtitle ?? "").hasPrefix("ios."), "\(locale) \(row.subtitle ?? "")")
            }
        }
    }

    // MARK: - L'objectif n°1, selon le niveau

    /// Un collégien ne voit ni l'université ni le travail ; un étudiant ne voit pas « la
    /// formation de mes rêves » ; un concours voit son concours. L'examen n'y est jamais.
    func testTheGoalsAreAdaptedToTheLevel() {
        let middle = LearningGoal.offered(for: .lowerSecondary)
        XCTAssertFalse(middle.contains(.passYear))
        XCTAssertFalse(middle.contains(.profession))
        XCTAssertFalse(middle.contains(.dreamSchool))

        let high = LearningGoal.offered(for: .upperSecondary)
        XCTAssertTrue(high.contains(.dreamSchool))
        XCTAssertFalse(high.contains(.passYear))
        XCTAssertFalse(high.contains(.profession))

        let university = LearningGoal.offered(for: .undergraduate)
        XCTAssertTrue(university.contains(.passYear))
        XCTAssertFalse(university.contains(.dreamSchool))
        XCTAssertFalse(university.contains(.ahead))

        XCTAssertEqual(LearningGoal.offered(for: .health).first, .competition)
        XCTAssertEqual(LearningGoal.offered(for: .competitive).first, .competition)

        for tier in EducationTier.allCases.map(Optional.some) + [nil] {
            let offered = LearningGoal.offered(for: tier)
            XCTAssertGreaterThanOrEqual(offered.count, 4)
            XCTAssertLessThanOrEqual(offered.count, 6, "Pas plus de six réponses : elles tiennent sur un écran")
            XCTAssertFalse(offered.contains(.exam))
            XCTAssertEqual(Set(offered).count, offered.count)
            for goal in offered {
                for locale in UiLocale.allCases {
                    let title = goal.title(locale: locale)
                    XCTAssertFalse(title.hasPrefix("ios."), "\(goal) \(locale)")
                    XCTAssertFalse(title.isEmpty)
                }
            }
        }
    }

    /// L'objectif choisi est celui qu'on coche ; un objectif d'un autre niveau (l'élève est
    /// revenu changer de classe) ne s'affiche pas coché, et le rond attend une réponse.
    func testTheMainGoalIsOneOfTheOfferedOnes() throws {
        let model = OnboardingModel()
        model.select(country: .fr)
        let college = try XCTUnwrap(model.tracks.first { $0.id == "fr.college" })
        model.track = college
        XCTAssertNil(model.mainGoal)
        model.goals = [.ahead]
        XCTAssertEqual(model.mainGoal, .ahead)

        let university = try XCTUnwrap(model.tracks.first { $0.id == "fr.universite" })
        model.track = university
        XCTAssertNil(model.mainGoal, "« Prendre de l'avance » n'est pas proposé à l'université")
        model.goals = [.passYear]
        XCTAssertEqual(model.mainGoal, .passYear)
    }

    /// L'objectif est écrit au changement d'écran, avec ce que l'examen dit déjà.
    func testTheGoalIsPersisted() {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }
        let model = OnboardingModel()
        model.goals = [.grades]
        model.examChoice = .noExam
        model.advance()
        XCTAssertEqual(Set(OnboardingPreferences.goals), ["grades", "lectures"])
        XCTAssertEqual(Set(OnboardingPreferences.learningGoals), [.grades, .lectures])
    }

    // MARK: - Les phrases

    /// Chaque phrase du lot existe dans les 26 langues, garde ses variables et ses passages
    /// marqués.
    func testEveryLot9KeyExistsInEveryLanguage() {
        let french = IosI18nCatalogs.table(for: "fr").filter { $0.key.hasPrefix("ios.onb9.") }
        XCTAssertGreaterThanOrEqual(french.count, 29)
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for (key, source) in french {
                let text = table[key] ?? ""
                XCTAssertFalse(text.isEmpty, "\(locale.rawValue) \(key)")
                for variable in ["{name}", "{exam}", "{subject}"] where source.contains(variable) {
                    XCTAssertTrue(text.contains(variable), "\(locale.rawValue) \(key) perd \(variable)")
                }
                XCTAssertEqual(text.components(separatedBy: "**").count % 2, 1, "\(locale.rawValue) \(key) : ** impair")
            }
        }
    }

    /// **Une seule citation d'étude dans le parcours**, et aucun chiffre inventé : les écrans
    /// revenus ne citent ni Harvard ni Karpicke, et ne promettent aucun pourcentage.
    func testTheReturnedScreensCiteNoStudyAndNoFigure() {
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for (key, text) in table where key.hasPrefix("ios.onb9.") && !key.hasPrefix("ios.onb9.test.") {
                XCTAssertFalse(text.contains("%"), "\(locale.rawValue) \(key)")
                XCTAssertFalse(text.localizedCaseInsensitiveContains("Harvard"), "\(locale.rawValue) \(key)")
                XCTAssertFalse(text.localizedCaseInsensitiveContains("Karpicke"), "\(locale.rawValue) \(key)")
                XCTAssertFalse(text.contains("000"), "\(locale.rawValue) \(key) : pas de compteur d'élèves")
            }
        }
    }
}
