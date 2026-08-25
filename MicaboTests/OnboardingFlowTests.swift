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
        XCTAssertEqual(model.step, .language)
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
        XCTAssertEqual(model.step, .demoReview, "La fiche se découpe ensuite en révisions")

        model.advance()
        XCTAssertEqual(model.step, .examPromise, "Le mode examen vient après la démonstration")
    }

    // MARK: - Sortie du parcours

    /// La fin du parcours a un ordre, et il est délibéré : on construit le parcours sous les
    /// yeux, on montre que d'autres l'ont suivi, on passe la main à l'étudiant, et c'est
    /// seulement là qu'on lui demande un compte. Demander de se connecter plus tôt, c'est
    /// demander un compte pour une app qu'on n'a pas encore vue fonctionner.
    func testTheAccountIsAskedOnlyOnceTheJourneyIsBuilt() {
        let model = self.model(advancingTo: .personalizing)

        model.advance()
        XCTAssertEqual(model.step, .socialProof, "La preuve sociale arrive sur un parcours déjà construit")

        model.advance()
        XCTAssertEqual(model.step, .yourTurn, "Puis on passe la main à l'étudiant")

        model.advance()
        XCTAssertEqual(model.step, .signIn, "Le compte n'est demandé qu'à ce moment-là")

        model.advance()
        XCTAssertEqual(model.step, .trialOffer, "L'offre vient après la connexion")
    }

    /// L'écran de génération du parcours ne doit pas passer plus vite qu'on ne le lit : un
    /// chargement qui s'évapore en une seconde n'a rien généré aux yeux de personne.
    func testTheGenerationScreenLastsLongEnoughToBeRead() {
        XCTAssertGreaterThanOrEqual(PersonalizingStepView.duration, 3)
    }

    /// Les deux fournisseurs sont annoncés, même si les flux OAuth ne sont pas encore
    /// branchés : l'écran doit rester complet le jour où ils le seront.
    func testSignInOffersBothProviders() {
        XCTAssertEqual(OnboardingSignInProvider.allCases, [.apple, .google])

        for provider in OnboardingSignInProvider.allCases {
            XCTAssertTrue(provider.title.hasPrefix("Continuer avec"), "\(provider) doit dire ce qu'il fait")
        }
    }

    // MARK: - Rapport à l'oubli

    /// Quatre réponses, et non plus un oui et un non : les deux réponses du milieu sont
    /// celles où la plupart des étudiants se reconnaissent, et ce sont les plus utiles.
    func testForgettingHasFourAnswers() {
        XCTAssertEqual(ForgettingHabit.allCases, [.always, .withMethod, .sometimes, .never])

        for habit in ForgettingHabit.allCases {
            XCTAssertFalse(habit.title.isEmpty, "\(habit) doit avoir un libellé")
        }
    }

    /// Les quatre réponses se ramènent au oui ou non de la clé historique : les deux qui
    /// commencent par « oui » disent qu'on oublie, les deux autres non.
    func testForgettingAnswersFoldBackToTheLegacyYesOrNo() {
        XCTAssertTrue(ForgettingHabit.always.forgetsOften)
        XCTAssertTrue(ForgettingHabit.withMethod.forgetsOften)
        XCTAssertFalse(ForgettingHabit.sometimes.forgetsOften)
        XCTAssertFalse(ForgettingHabit.never.forgetsOften)
    }

    /// La réponse détaillée est écrite au changement d'écran, et la clé historique reste
    /// tenue à jour pour les appareils qui ont fait le parcours à deux réponses.
    func testForgettingIsPersistedOnAdvance() {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let model = self.model(advancingTo: .forgetting)
        model.forgetting = .withMethod
        model.advance()

        XCTAssertEqual(OnboardingPreferences.forgetting, .withMethod)
        XCTAssertEqual(OnboardingPreferences.forgetsOften, true)
    }

    // MARK: - Écrans retirés

    /// Ces écrans ont été retirés du parcours : la génération simulée, qui faisait patienter
    /// devant un travail invisible, la courbe de l'oubli prise à contre-pied, qui répétait
    /// l'écran précédent, et « on a fait Micabo pour nous », qui racontait d'où venait l'app
    /// à quelqu'un qui ne l'a pas encore vue fonctionner.
    func testRemovedScreensAreGoneFromTheFlow() {
        let names = OnboardingStep.allCases.map(String.init(describing:))

        XCTAssertFalse(names.contains("demoWrite"))
        XCTAssertFalse(names.contains("science"))
        XCTAssertFalse(names.contains("schoolPeers"))
        XCTAssertFalse(names.contains("builtByStudents"))
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

    /// Trois écrans seulement quittent le crème : la variété d'un parcours ne vient pas de
    /// ses fonds. L'encre est réservée aux deux moments où le parcours s'adresse
    /// directement à l'étudiant, l'accroche et le passage à son tour.
    func testOnlyThreeScreensLeaveTheCanvas() {
        XCTAssertEqual(OnboardingStep.welcome.surface, .ink)
        XCTAssertEqual(OnboardingStep.yourTurn.surface, .ink)
        XCTAssertEqual(OnboardingStep.personalizing.surface, .indigo)

        let dark = OnboardingStep.allCases.filter(\.surface.isDark)
        XCTAssertEqual(dark, [.welcome, .personalizing, .yourTurn])

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

    /// Le troisième écran montre les quatre formes que prend une fiche. Le schéma en fait
    /// partie : une démonstration qui n'aurait que des cartes laisserait croire que Micabo
    /// ne sait pas dessiner un cours.
    func testDemoOutputsCoverTheFourFormats() {
        XCTAssertEqual(OnboardingDemo.Output.allCases, [.schema, .flashcard, .quiz, .gap])

        for output in OnboardingDemo.Output.allCases {
            XCTAssertFalse(output.label.isEmpty, "\(output) doit avoir un libellé")
            XCTAssertFalse(output.systemImage.isEmpty, "\(output) doit avoir un symbole")
        }
    }

    /// Le texte à trou de la démonstration doit vraiment avoir un trou, et le mot qui le
    /// remplit doit être celui du cours déposé.
    func testTheGapExerciseComesFromTheRawCourse() {
        XCTAssertFalse(OnboardingDemo.gapBefore.isEmpty)
        XCTAssertFalse(OnboardingDemo.gapAnswer.isEmpty)

        let raw = OnboardingDemo.rawLines.joined(separator: " ").lowercased()
        XCTAssertTrue(raw.contains(OnboardingDemo.gapAnswer.lowercased()))
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
