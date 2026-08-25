import SwiftUI
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

    /// **Le pays passe avant le niveau.** Ce sont les paliers du pays choisi qui deviennent
    /// les réponses de « tu en es où ? » : dans l'autre sens, il fallait proposer les mêmes
    /// sept réponses françaises à un Américain, qui n'en avait aucune de juste.
    func testTheCountryIsAskedBeforeTheLevel() {
        let model = OnboardingModel()
        XCTAssertEqual(model.step, .welcome)

        model.advance()
        XCTAssertEqual(model.step, .country, "Le pays vient d'abord : il commande les réponses du niveau")

        model.advance()
        XCTAssertEqual(model.step, .level)

        model.advance()
        XCTAssertEqual(model.step, .personalizeIntro)
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
        XCTAssertGreaterThanOrEqual(PersonalizingStepView.duration, 5)
    }

    /// Les deux fournisseurs sont proposés, et ils disent tous les deux ce qu'ils font.
    func testSignInOffersBothProviders() {
        XCTAssertEqual(OnboardingSignInProvider.allCases, [.apple, .google])

        for provider in OnboardingSignInProvider.allCases {
            XCTAssertTrue(provider.title.hasPrefix("Continuer avec"), "\(provider) doit dire ce qu'il fait")
        }
    }

    /// Passer la connexion referme la porte du compte : sans la clé partagée, l'app
    /// reposait la question juste après le parcours, sur un second écran de connexion.
    func testSkippingTheAccountUsesTheKeyReadByTheRoot() {
        XCTAssertEqual(AccountGate.skippedKey, "micabo.auth.skipped")
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
        // L'écran de la langue annonçait « Micabo parle français » avec une seule réponse,
        // cochée d'avance : la langue se déduit du pays de scolarisation.
        XCTAssertFalse(names.contains("language"))
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
    ///
    /// L'écran de génération, lui, est passé du vert plein au vert pastel : un aplat saturé
    /// tenu cinq secondes derrière du texte blanc fatigue, et c'est celui où l'on demande
    /// justement de patienter. Il ne compte donc plus parmi les fonds sombres.
    func testOnlyThreeScreensLeaveTheCanvas() {
        XCTAssertEqual(OnboardingStep.welcome.surface, .ink)
        XCTAssertEqual(OnboardingStep.yourTurn.surface, .ink)
        XCTAssertEqual(OnboardingStep.personalizing.surface, .accentSoft)

        let dark = OnboardingStep.allCases.filter(\.surface.isDark)
        XCTAssertEqual(dark, [.welcome, .yourTurn], "Seuls les deux écrans d'encre s'inversent")

        let coloured = OnboardingStep.allCases.filter { $0.surface != .canvas }
        XCTAssertEqual(coloured, [.welcome, .personalizing, .yourTurn])
    }

    // MARK: - Niveau

    /// Le palier est écrit dès le changement d'écran, et il écrit son registre avec lui :
    /// c'est ce registre que la fonction reçoit et que le cloud synchronise.
    func testStageIsPersistedOnAdvanceWithItsWritingRegister() throws {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let model = self.model(advancingTo: .level)
        let sante = try XCTUnwrap(model.country.stages.first { $0.level == .sante })
        model.stage = sante
        model.advance()

        XCTAssertEqual(OnboardingPreferences.educationStageId, "fr.sante")
        XCTAssertEqual(OnboardingPreferences.level, "sante")
        XCTAssertEqual(OnboardingPreferences.studyLevel, .sante)
        XCTAssertEqual(OnboardingPreferences.educationStage, sante)
    }

    /// Chaque pays propose les paliers qui existent chez lui, et rien d'autre : « PASS » et
    /// « Prépa » n'ont pas cours aux États-Unis, « A-Levels » n'en a pas en France.
    func testEachCountryOffersItsOwnStages() {
        for country in SchoolingCountry.allCases {
            let stages = country.stages
            XCTAssertGreaterThanOrEqual(stages.count, 4, "\(country) doit proposer un vrai parcours")

            for stage in stages {
                XCTAssertFalse(stage.title.isEmpty, "\(stage.id) doit avoir un libellé")
                XCTAssertFalse(stage.emoji.isEmpty, "\(stage.id) doit porter un emoji")
            }

            let ids = stages.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "\(country) répète un identifiant de palier")
        }

        XCTAssertEqual(SchoolingCountry.fr.stages.map(\.title).first, "Lycée")
        XCTAssertTrue(SchoolingCountry.us.stages.contains { $0.title == "High school" })
        XCTAssertTrue(SchoolingCountry.uk.stages.contains { $0.title == "A-Levels" })
        XCTAssertFalse(SchoolingCountry.us.stages.contains { $0.title.contains("PASS") })
        XCTAssertFalse(SchoolingCountry.uk.stages.contains { $0.title == "Prépa" })
    }

    /// Un pays qu'on ne connaît pas retombe sur l'échelle générique, en anglais : inventer
    /// des paliers pour un système scolaire qu'on ignore donnerait des réponses fausses, et
    /// une réponse fausse est pire qu'une réponse large.
    func testAnUnknownCountryFallsBackToTheGenericLadder() {
        XCTAssertEqual(SchoolingCountry.other.stages, SchoolingCountry.genericStages)
        XCTAssertEqual(
            SchoolingCountry.genericStages.map(\.title),
            ["Middle school", "High school", "College", "University", "Other"]
        )
    }

    /// La langue vient du pays, et de nulle part ailleurs : c'est ce qui a permis de retirer
    /// l'écran qui la demandait.
    func testTheLanguageComesFromTheCountry() {
        XCTAssertEqual(SchoolingCountry.fr.language, .fr)
        XCTAssertEqual(SchoolingCountry.ca.language, .fr)
        XCTAssertEqual(SchoolingCountry.us.language, .en)
        XCTAssertEqual(SchoolingCountry.uk.language, .en)
        XCTAssertEqual(SchoolingCountry.other.language, .en)

        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        OnboardingPreferences.schoolingCountry = .uk
        XCTAssertEqual(OnboardingPreferences.contentLanguage, .en)
    }

    /// Changer de pays ne perd pas la réponse déjà donnée quand le nouveau pays a un palier
    /// du même registre : un étudiant en licence en France arrive en « Undergraduate » au
    /// Royaume-Uni, parce que les deux demandent la même écriture.
    func testChangingCountryCarriesTheStageOverWhenItCan() {
        let model = OnboardingModel()
        model.stage = SchoolingCountry.fr.stages.first { $0.level == .licence }
        XCTAssertEqual(model.stage?.id, "fr.licence")

        model.select(country: .uk)

        XCTAssertEqual(model.stage?.id, "uk.undergraduate")
        XCTAssertEqual(model.level, .licence)
        XCTAssertEqual(model.language, .en)
    }

    /// Le palier abandonné plutôt que gardé de travers : la Suisse n'a pas de concours, donc
    /// la réponse ne se reporte sur rien et l'écran redemande.
    func testChangingCountryDropsAStageThatHasNoEquivalent() {
        let model = OnboardingModel()
        model.stage = SchoolingCountry.fr.stages.first { $0.level == .prepa }

        model.select(country: .ch)

        XCTAssertNil(model.stage, "La Suisse ne propose pas de classe préparatoire")
    }

    func testEveryLevelHasALabel() {
        for level in StudyLevel.allCases {
            XCTAssertFalse(level.title.isEmpty, "\(level) doit avoir un libellé")
        }
        XCTAssertEqual(StudyLevel.allCases.count, 7)
    }

    /// Chaque réponse porte son emoji : c'est ce qui fait retrouver sa réponse d'un regard
    /// au lieu de relire sept lignes qui commencent toutes pareil.
    func testEveryAnswerCarriesAnEmoji() {
        for level in StudyLevel.allCases {
            XCTAssertFalse(level.emoji.isEmpty, "\(level) doit porter un emoji")
        }
        for goal in LearningGoal.allCases {
            XCTAssertFalse(goal.emoji.isEmpty, "\(goal) doit porter un emoji")
        }
        for country in SchoolingCountry.allCases {
            XCTAssertFalse(country.flag.isEmpty, "\(country) doit porter son drapeau")
        }
        for habit in ForgettingHabit.allCases {
            XCTAssertFalse(habit.emoji.isEmpty, "\(habit) doit porter un emoji")
        }
    }

    // MARK: - Pays de scolarisation

    /// « Les attendus du bac » ne veut rien dire pour un lycéen belge : le pays est écrit
    /// comme le niveau, et il commande les mêmes consignes de rédaction.
    func testCountryIsPersistedOnAdvance() {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let model = self.model(advancingTo: .country)
        model.select(country: .be)
        model.advance()

        XCTAssertEqual(OnboardingPreferences.schoolingCountry, .be)
        XCTAssertTrue(OnboardingPreferences.hasChosenCountry)
    }

    /// Sans réponse, on suppose la France : c'est ce que l'app faisait implicitement avant
    /// que la question existe, et les fiches déjà écrites ne doivent pas changer de sens.
    func testFranceIsAssumedWhenTheQuestionWasNeverAsked() {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        XCTAssertFalse(OnboardingPreferences.hasChosenCountry)
        XCTAssertEqual(OnboardingPreferences.schoolingCountry, .fr)
    }

    func testEveryCountryDescribesItsSchoolSystem() {
        for country in SchoolingCountry.allCases {
            XCTAssertFalse(country.name.isEmpty, "\(country) doit avoir un nom")
            XCTAssertFalse(country.systemHint.isEmpty, "\(country) doit dire son système scolaire")
        }
        // Le brut est envoyé à la fonction : le renommer changerait la consigne de rédaction.
        XCTAssertEqual(SchoolingCountry.fr.rawValue, "fr")
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
