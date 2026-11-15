import XCTest

/// **Le maintien pour s'engager, sur un vrai geste** (lot 15).
///
/// Au build 182, l'écran d'engagement ne validait jamais : le sceau changeait de vue au toucher,
/// ce qui annulait le geste. Deux correctifs n'avaient été vérifiés que sur la logique
/// (`CommitHold`), jamais sur un doigt. Ce test lance l'app directement sur l'écran
/// d'engagement (`-onboardingStep commitment`, en Debug seulement), puis :
///
/// 1. **un appui court (0,3 s) ne signe rien** : on reste sur l'engagement ;
/// 2. **un maintien de 2 s signe** : l'écran suivant (le plan qui se prépare) s'affiche.
final class CommitmentHoldUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        // Le premier lancement de l'app sur le simulateur de la CI peut être lent.
        executionTimeAllowance = 170
    }

    @MainActor
    func testAShortPressDoesNothingAndAFullHoldCommits() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-onboardingStep", "commitment",
            // Le parcours s'affiche même si une autre suite l'a marqué fini sur ce simulateur.
            "-micabo.onboarding.completed", "NO",
        ]
        app.launch()

        let commitment = app.descendants(matching: .any)["onboarding.step.commitment"]
        XCTAssertTrue(commitment.waitForExistence(timeout: 30), "Le parcours ne s'est pas ouvert sur l'engagement")
        let hold = app.descendants(matching: .any)["onboarding.commitment.hold"]
        XCTAssertTrue(hold.waitForExistence(timeout: 10), "Le bouton à maintenir est absent")
        let planBuilding = app.descendants(matching: .any)["onboarding.step.planBuilding"]
        let profileSummary = app.descendants(matching: .any)["onboarding.step.profileSummary"]

        // 1. Un appui court : rien n'est signé, on reste sur l'écran.
        hold.press(forDuration: 0.3)
        XCTAssertFalse(planBuilding.waitForExistence(timeout: 2.5), "Un appui de 0,3 s a validé l'engagement")
        XCTAssertTrue(commitment.exists, "L'écran d'engagement a disparu après un appui court")
        XCTAssertTrue(hold.exists)

        // 2. Un maintien de 2 s : l'engagement est pris, l'écran suivant arrive.
        hold.press(forDuration: 2.0)
        let advanced = planBuilding.waitForExistence(timeout: 8) || profileSummary.exists
        XCTAssertTrue(advanced, "Le maintien de 2 s n'a pas mené à l'écran suivant")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: commitment)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "L'écran d'engagement est resté après le maintien")
    }
}
