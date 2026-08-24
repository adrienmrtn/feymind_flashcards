import XCTest
@testable import Micabo

/// Verrouille les règles du parcours d'accueil : son ordre, ses fonds, et la jauge qui ne
/// recule jamais.
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

    /// La question du niveau vient juste après l'accroche : c'est elle qui situe tout le
    /// reste du parcours.
    func testLevelQuestionComesRightAfterTheHook() {
        let model = OnboardingModel()
        XCTAssertEqual(model.step, .welcome)

        model.advance()
        XCTAssertEqual(model.step, .level)

        model.advance()
        XCTAssertEqual(model.step, .builtByStudents)
    }

    // MARK: - Démonstration

    /// Les trois écrans de démonstration suivent le parcours réel de l'app : on dépose, le
    /// cours est fiché, la fiche se décompose en cartes. Une démonstration qui montrerait
    /// autre chose que le produit serait une promesse à tenir deux fois.
    func testDemoFollowsTheRealPipeline() {
        let model = self.model(advancingTo: .demoImport)

        model.advance()
        XCTAssertEqual(model.step, .demoSheet, "Le cours déposé est d'abord mis en fiche")

        model.advance()
        XCTAssertEqual(model.step, .demoReview, "La fiche se décompose ensuite en cartes")

        model.advance()
        XCTAssertEqual(model.step, .examPromise, "Le mode examen vient après la démonstration")
    }

    // MARK: - Écrans retirés

    /// Ces trois écrans ont été retirés du parcours : la génération simulée, qui faisait
    /// patienter devant un travail invisible, la courbe de l'oubli prise à contre-pied, qui
    /// répétait l'écran précédent, et la preuve sociale.
    func testRemovedScreensAreGoneFromTheFlow() {
        let names = OnboardingStep.allCases.map(String.init(describing:))

        XCTAssertFalse(names.contains("demoWrite"))
        XCTAssertFalse(names.contains("science"))
        XCTAssertFalse(names.contains("schoolPeers"))
    }

    /// Le parcours est une file droite : aucun écran ne se saute, donc avancer depuis
    /// n'importe quelle étape mène toujours à la suivante.
    func testNoStepIsEverSkipped() {
        for step in OnboardingStep.allCases.dropLast() {
            let model = self.model(advancingTo: step)
            model.advance()
            XCTAssertEqual(model.step, step.next, "\(step) doit mener directement à son suivant")
        }
    }

    func testTheFlowEndsOnThePaywall() {
        let model = self.model(advancingTo: .paywall)

        model.advance()
        XCTAssertEqual(model.step, .paywall, "Le dernier écran ne mène nulle part")
    }

    // MARK: - Fond des écrans

    /// Deux écrans seulement quittent le crème, et c'est un de moins qu'avant : la variété
    /// d'un parcours ne vient pas de ses fonds.
    func testOnlyTwoScreensLeaveTheCanvas() {
        XCTAssertEqual(OnboardingStep.welcome.surface, .ink)
        XCTAssertEqual(OnboardingStep.personalizing.surface, .indigo)

        let dark = OnboardingStep.allCases.filter(\.surface.isDark)
        XCTAssertEqual(dark, [.welcome, .personalizing])

        for step in OnboardingStep.allCases where !dark.contains(step) {
            XCTAssertEqual(step.surface, .canvas, "\(step) devrait rester sur le crème")
        }
    }

    // MARK: - Niveau

    /// Le niveau est écrit dès le changement d'écran : une sortie en cours de route ne perd
    /// que la question en cours.
    func testLevelIsPersistedOnAdvance() {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let model = self.model(advancingTo: .level)
        model.level = .sante
        model.advance()

        XCTAssertEqual(OnboardingPreferences.level, "sante")
        XCTAssertEqual(OnboardingPreferences.studyLevel, .sante)
    }

    func testEveryLevelHasALabel() {
        for level in StudyLevel.allCases {
            XCTAssertFalse(level.title.isEmpty, "\(level) doit avoir un libellé")
        }
        XCTAssertEqual(StudyLevel.allCases.count, 7)
    }

    // MARK: - Intervalles

    /// Le graphe de rétention garde ses intervalles réels : ce sont eux qu'annoncent les
    /// étiquettes au-dessus de chaque révision.
    func testRetentionChartKeepsItsRealIntervals() {
        XCTAssertEqual(RetentionCurve.intervalLabels, ["1 j", "3 j", "7 j", "16 j"])
        XCTAssertEqual(
            RetentionCurve.intervalLabels.count,
            RetentionCurve.reviewDays.count,
            "La liste des intervalles doit couvrir toutes les révisions du graphe"
        )
    }

    // MARK: - Démonstration

    /// Les cartes de la démonstration montrent les trois formats. Une démonstration qui
    /// n'aurait que du recto verso laisserait croire que Micabo ne sait faire que ça.
    func testDemoCardsCoverTheThreeFormats() {
        let kinds = OnboardingDemo.cards.map(\.kind)

        XCTAssertTrue(kinds.contains(.basic))
        XCTAssertTrue(kinds.contains(.choice))
        XCTAssertTrue(kinds.contains(.gap))
    }

    /// Le document déposé doit être plus dense que la fiche qui en sort, sinon l'écran de
    /// transformation ne transforme rien.
    func testTheRawDocumentIsDenserThanTheSheet() {
        let raw = OnboardingDemo.rawLines.joined(separator: " ")
        let sheet = [
            OnboardingDemo.sheetHeading,
            OnboardingDemo.sheetParagraph,
            OnboardingDemo.sheetDefinition,
            OnboardingDemo.sheetHighlight
        ].joined(separator: " ")

        XCTAssertGreaterThan(raw.count, sheet.count)
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
