import XCTest
@testable import Micabo

/// Verrouille les règles du parcours d'accueil : ce qui se saute, ce qui s'affiche,
/// et la jauge qui ne recule jamais.
final class OnboardingFlowTests: XCTestCase {
    private func model(advancingTo target: OnboardingStep) -> OnboardingModel {
        let model = OnboardingModel()
        var guardCounter = 0
        while model.step != target, guardCounter < OnboardingStep.allCases.count * 2 {
            model.advance()
            guardCounter += 1
        }
        XCTAssertEqual(model.step, target, "Le parcours n'atteint pas \(target)")
        return model
    }

    // MARK: - Ouverture

    func testMissionScreenComesRightAfterTheHook() {
        let model = OnboardingModel()
        XCTAssertEqual(model.step, .welcome)

        model.advance()
        XCTAssertEqual(model.step, .builtByStudents, "L'écran « conçu par des étudiants » suit l'accroche")

        model.advance()
        XCTAssertEqual(model.step, .language)
    }

    // MARK: - Fond des écrans

    func testShellKnowsWhichScreensLeaveTheCanvas() {
        XCTAssertEqual(OnboardingStep.welcome.surface, .ink)
        XCTAssertEqual(OnboardingStep.science.surface, .ink)
        XCTAssertEqual(OnboardingStep.personalizing.surface, .indigo)

        let dark = OnboardingStep.allCases.filter(\.surface.isDark)
        XCTAssertEqual(dark, [.welcome, .science, .personalizing], "Trois écrans seulement quittent le crème")

        for step in OnboardingStep.allCases where !dark.contains(step) {
            XCTAssertEqual(step.surface, .canvas, "\(step) devrait rester sur le crème")
        }
    }

    // MARK: - Preuve sociale

    func testCommunityStepIsSkippedWhenInstitutionWasTypedByHand() {
        let model = self.model(advancingTo: .school)
        model.institutionId = nil
        model.institutionName = "Lycée Lacordaire"

        model.advance()

        XCTAssertEqual(model.step, .dailyTime, "Sans établissement reconnu, l'écran communauté doit être sauté")
    }

    func testCommunityStepIsSkippedWhenNoInstitutionAtAll() {
        let model = self.model(advancingTo: .school)
        model.institutionId = nil
        model.institutionName = nil

        model.advance()

        XCTAssertEqual(model.step, .dailyTime)
    }

    func testCommunityStepIsShownOnlyForARecognizedInstitution() {
        let model = self.model(advancingTo: .school)
        model.institutionId = "fr-lycee-lacordaire"
        model.institutionName = "Lycée Lacordaire"

        XCTAssertTrue(model.hasRecognizedInstitution)
        model.advance()

        XCTAssertEqual(model.step, .schoolPeers)
        model.advance()
        XCTAssertEqual(model.step, .dailyTime)
    }

    func testBlankInstitutionIdCountsAsUnrecognized() {
        let model = self.model(advancingTo: .school)
        model.institutionId = "   "
        model.institutionName = "Quelque part"

        XCTAssertFalse(model.hasRecognizedInstitution)
        model.advance()
        XCTAssertEqual(model.step, .dailyTime)
    }

    func testPeerCountStaysBetweenOneAndTenAndDoesNotMove() {
        let identifiers = [
            "fr-lycee-lacordaire",
            "fr-univ-sorbonne",
            "fr-ge-polytechnique",
            "us-univ-stanford",
            "x",
            ""
        ]

        for id in identifiers {
            let value = SchoolPeers.count(forInstitutionId: id)
            XCTAssertGreaterThanOrEqual(value, 1, "Effectif trop bas pour \(id)")
            XCTAssertLessThanOrEqual(value, SchoolPeers.maximum, "Effectif trop haut pour \(id)")
            XCTAssertEqual(value, SchoolPeers.count(forInstitutionId: id), "Le même établissement doit donner le même chiffre")
        }
    }

    // MARK: - Intervalles

    func testSpacedRepetitionListReusesTheChartIntervals() {
        XCTAssertEqual(RetentionCurve.intervalLabels, ["1 j", "3 j", "7 j", "16 j"])
        XCTAssertEqual(
            RetentionCurve.intervalLabels.count,
            RetentionCurve.reviewDays.count,
            "La liste des intervalles doit couvrir toutes les révisions du graphe"
        )
    }

    // MARK: - Jauge

    func testProgressNeverGoesBackwardAndFillsAtTheEnd() {
        var previous = 0.0
        for step in OnboardingStep.allCases {
            XCTAssertGreaterThan(step.progress, 0, "La jauge ne doit jamais être vide")
            XCTAssertGreaterThanOrEqual(step.progress, previous, "La jauge recule sur \(step)")
            XCTAssertLessThanOrEqual(step.progress, 1)
            previous = step.progress
        }

        XCTAssertEqual(OnboardingStep.paywall.progress, 1, accuracy: 0.0001)
    }
}
