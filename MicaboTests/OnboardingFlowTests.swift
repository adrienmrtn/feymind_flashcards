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

    /// Apple et Google restent les deux fournisseurs OAuth. Le courriel n'est pas un
    /// quatrième bouton : c'est le formulaire sous le séparateur.
    func testSignInOffersBothProviders() {
        XCTAssertEqual(SignInProvider.allCases, [.apple, .google])

        for provider in SignInProvider.allCases {
            let title = provider.title(t: { L10n.t($0, locale: .fr) })
            XCTAssertTrue(title.hasPrefix("Continuer avec"), "\(provider) doit dire ce qu'il fait")
        }

        XCTAssertEqual(L10n.t("onboarding.connexionTitle", locale: .fr), "Content de te revoir.")
        XCTAssertEqual(L10n.t("onboarding.or", locale: .fr), "ou")
        XCTAssertEqual(L10n.t("onboarding.sendLink", locale: .fr), "Recevoir un lien")
        XCTAssertFalse(PaywallLinks.terms.isEmpty)
        XCTAssertFalse(PaywallLinks.privacy.isEmpty)
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
        // « On te rappelle au bon moment » ne demandait rien au système : il notait une
        // intention que personne ne lisait, juste avant l'écran qui construit le parcours.
        XCTAssertFalse(names.contains("notifications"))
        // Le rythme quotidien et la projection sur un an : deux écrans pour une seule idée,
        // et une idée bâtie sur une réponse que personne ne peut donner avant d'avoir
        // essayé. Le plafond de cartes neuves garde sa valeur par défaut.
        XCTAssertFalse(names.contains("dailyTime"))
        XCTAssertFalse(names.contains("projection"))
    }

    /// Le rythme et la projection partis, l'établissement mène directement à la
    /// construction du parcours : c'est la dernière question, et la suite est le résultat.
    func testTheLastQuestionLeadsStraightToTheBuild() {
        let model = self.model(advancingTo: .school)

        model.advance()
        XCTAssertEqual(model.step, .personalizing)
    }

    /// La note ne se demande qu'une fois. Le système plafonne déjà les demandes à trois par
    /// an, mais il les compte même quand il ne les affiche pas : les dépenser deux fois sur
    /// le même écran, c'est n'en avoir plus aucune le jour où l'app a vraiment rendu service.
    func testTheRatingIsOnlyEverAskedOnce() {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        XCTAssertFalse(OnboardingPreferences.ratingAsked)

        OnboardingPreferences.ratingAsked = true
        XCTAssertTrue(OnboardingPreferences.ratingAsked)

        OnboardingPreferences.reset()
        XCTAssertFalse(OnboardingPreferences.ratingAsked, "Refaire le parcours repart de zéro")
    }

    /// La clé de l'écran retiré reste listée : sur un appareil qui a fait l'ancien parcours,
    /// la remise à zéro doit encore savoir l'effacer.
    func testTheRetiredNotificationKeyIsStillErased() {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let key = OnboardingPreferences.Key.retiredNotificationsOptIn
        UserDefaults.standard.set(true, forKey: key)

        OnboardingPreferences.reset()

        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))
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
    /// ses fonds.
    ///
    /// **Le noir ne sert plus qu'une fois**, au passage de relais. Ouvrir l'app sur un écran
    /// entièrement noir posait le contraste maximal du parcours avant d'avoir rien à lire :
    /// l'accroche est sur la sauge, un crème teinté de vert, et l'écran de génération sur le
    /// menthe. Aucun des deux ne s'inverse — l'encre s'y lit mieux que le blanc.
    func testOnlyOneScreenIsDarkAndItIsTheHandover() {
        XCTAssertEqual(OnboardingStep.welcome.surface, .sage, "L'accroche n'est plus noire")
        XCTAssertEqual(OnboardingStep.yourTurn.surface, .ink)
        XCTAssertEqual(OnboardingStep.personalizing.surface, .accentSoft)

        let dark = OnboardingStep.allCases.filter(\.surface.isDark)
        XCTAssertEqual(dark, [.yourTurn], "Le passage de relais est le seul écran d'encre")

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

    /// Changer de pays reporte la réponse sur le palier **équivalent**, pas sur le premier
    /// de la liste qui écrit pareil.
    ///
    /// C'est tout l'intérêt de l'échelle : un lycéen et un collégien partagent le registre
    /// « lycée », donc chercher par registre ramenait un lycéen français en « Middle
    /// school » dès qu'il passait aux États-Unis.
    func testChangingCountryCarriesTheStageOverToItsRealEquivalent() throws {
        let model = OnboardingModel()

        model.stage = try XCTUnwrap(SchoolingCountry.fr.stages.first { $0.id == "fr.lycee" })
        model.select(country: .us)
        XCTAssertEqual(model.stage?.id, "us.high", "Un lycéen n'est pas un collégien")
        XCTAssertEqual(model.language, .en)

        model.select(country: .uk)
        XCTAssertEqual(model.stage?.id, "uk.alevels", "A-Levels, pas GCSE")

        model.select(country: .fr)
        XCTAssertEqual(model.stage?.id, "fr.lycee", "L'aller-retour revient au point de départ")
    }

    /// Une filière santé se retrouve dans l'autre pays, et elle ne se convertit jamais en
    /// marche d'échelle : un étudiant en santé n'est pas un « undergraduate » parce que son
    /// pays d'accueil n'a pas de filière nommée.
    func testHealthAndCompetitiveTracksAreNotLadderRungs() throws {
        let model = OnboardingModel()

        model.stage = try XCTUnwrap(SchoolingCountry.fr.stages.first { $0.id == "fr.sante" })
        model.select(country: .uk)
        XCTAssertEqual(model.stage?.id, "uk.medicine")

        model.stage = try XCTUnwrap(SchoolingCountry.fr.stages.first { $0.id == "fr.concours" })
        model.select(country: .us)
        XCTAssertNil(model.stage, "Les États-Unis n'ont pas de concours : l'écran redemande")
    }

    /// Sans équivalent exact, on prend la marche la plus proche, et on monte à égalité de
    /// distance : la Suisse n'a pas de prépa, et « Bachelor » sert mieux un préparationnaire
    /// qu'une fiche écrite pour le secondaire.
    func testAStageWithoutAnEquivalentLandsOnTheNearestRungAbove() throws {
        let model = OnboardingModel()
        model.stage = try XCTUnwrap(SchoolingCountry.fr.stages.first { $0.id == "fr.prepa" })

        model.select(country: .ch)

        XCTAssertEqual(model.stage?.id, "ch.bachelor")
        XCTAssertEqual(model.level, .licence)
    }

    /// Le cégep québécois est un palier pré-universitaire : il retrouve la prépa française,
    /// et pas le lycée, même si les deux partagent le registre du secondaire.
    func testThePreUniversityRungTravels() throws {
        let model = OnboardingModel()
        model.select(country: .ca)
        model.stage = try XCTUnwrap(SchoolingCountry.ca.stages.first { $0.id == "ca.cegep" })

        model.select(country: .fr)

        XCTAssertEqual(model.stage?.id, "fr.prepa")
    }

    /// L'échelle se déduit de l'ordre de déclaration : une marche ajoutée au milieu se place
    /// à sa vraie hauteur, et aucune liste écrite à la main ne peut l'oublier.
    func testTheLadderIsTheDeclarationOrderOfItsRungs() {
        XCTAssertEqual(
            EducationTier.ladder,
            [.lowerSecondary, .upperSecondary, .preUniversity, .undergraduate, .graduate]
        )

        for tier in EducationTier.allCases {
            XCTAssertEqual(
                tier.isRung,
                tier.ladderIndex != nil,
                "\(tier) doit être sur l'échelle si et seulement si c'est une marche"
            )
        }

        // Une voie n'a pas de hauteur : la convertir en marche donnerait une réponse fausse.
        XCTAssertNil(EducationTier.health.ladderIndex)
        XCTAssertNil(EducationTier.competitive.ladderIndex)
        XCTAssertNil(EducationTier.other.ladderIndex)
    }

    /// La marche est écrite à côté du palier, et c'est elle qui le retrouve à la relecture.
    /// Sans elle, le chemin de lecture retombait sur le registre, qui ne distingue pas un
    /// collégien d'un lycéen.
    func testTheTierIsPersistedBesideTheStage() throws {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        OnboardingPreferences.schoolingCountry = .us
        OnboardingPreferences.educationStage = try XCTUnwrap(
            SchoolingCountry.us.stages.first { $0.id == "us.high" }
        )

        XCTAssertEqual(OnboardingPreferences.educationTier, .upperSecondary)
        XCTAssertEqual(OnboardingPreferences.educationStage?.id, "us.high")
    }

    /// Le profil que le cloud renvoie ne transporte que le registre : il n'y a pas de colonne
    /// pour la marche, et il n'en faut pas. Le registre désigne alors sa marche de référence,
    /// et c'est le palier qui s'y trouve qu'on retient.
    ///
    /// Prendre le premier de la liste ramenait un « lycee » américain sur « Middle school » ;
    /// prendre le plus haut ramenait un « lycee » québécois sur « Cégep », qui est
    /// post-secondaire. La marche de référence donne les deux bonnes réponses.
    func testALevelWithoutATierResolvesToItsReferenceRung() {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        OnboardingPreferences.schoolingCountry = .us
        OnboardingPreferences.level = "lycee"

        XCTAssertNil(OnboardingPreferences.educationTier)
        XCTAssertEqual(OnboardingPreferences.educationStage?.id, "us.high")

        OnboardingPreferences.schoolingCountry = .uk
        XCTAssertEqual(OnboardingPreferences.educationStage?.id, "uk.alevels")

        OnboardingPreferences.schoolingCountry = .ca
        XCTAssertEqual(OnboardingPreferences.educationStage?.id, "ca.secondaire", "Le cégep est post-secondaire")

        OnboardingPreferences.schoolingCountry = .other
        XCTAssertEqual(OnboardingPreferences.educationStage?.id, "generic.high")
    }

    /// Chaque registre désigne une marche, et chaque pays a bien un palier à cette marche
    /// pour les registres qu'il propose : sans quoi le repli du cloud tomberait à côté.
    func testEveryLevelPointsAtARungItsCountriesActuallyHave() {
        for country in SchoolingCountry.allCases {
            let tiers = country.stages.map(\.tier)
            XCTAssertEqual(
                Set(tiers).count,
                tiers.count,
                "\(country) place deux paliers sur la même marche : la résolution deviendrait arbitraire"
            )

            for stage in country.stages where country.stages.filter({ $0.level == stage.level }).count > 1 {
                XCTAssertTrue(
                    country.stages.contains { $0.level == stage.level && $0.tier == stage.level.canonicalTier },
                    "\(country) partage le registre \(stage.level) sans palier à sa marche de référence"
                )
            }
        }
    }

    /// Le profil distant est autoritaire sur le registre et le pays, et il ne transporte pas
    /// le palier : les traces du palier local doivent donc partir avec, sinon elles gagnent
    /// contre lui et le réécrivent au premier passage dans les réglages.
    func testApplyingARemoteProfileDropsTheLocalStage() throws {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        OnboardingPreferences.schoolingCountry = .fr
        OnboardingPreferences.educationStage = try XCTUnwrap(
            SchoolingCountry.fr.stages.first { $0.id == "fr.lycee" }
        )

        let remote = ProfileRecord(
            id: UUID(),
            display_name: nil,
            study_level: "master",
            country_code: "us",
            learning_goals: [],
            subjects: [],
            institution_id: nil,
            institution_name: nil,
            daily_minutes: 15,
            sheet_length: SheetLength.standard.rawValue,
            sheet_language: nil,
            onboarding_completed_at: nil
        )
        remote.applyToLocalPreferences()

        XCTAssertEqual(OnboardingPreferences.educationStage?.id, "us.graduate")
        XCTAssertEqual(OnboardingPreferences.studyLevel, .master)
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

    // MARK: - Matières

    /// **Une matière, un emoji.** Trente-huit pastilles s'enroulent sur cet écran : deux qui
    /// portent le même dessin obligent à lire les libellés un par un, et c'est justement le
    /// travail que l'emoji devait éviter. La table en servait un pour six matières voisines —
    /// quatre matières de santé pour un seul stéthoscope, dix langues pour une seule bouche.
    func testEverySubjectOfTheCatalogueHasItsOwnEmoji() {
        var seen: [String: String] = [:]

        for subject in SubjectCatalog.allSubjects {
            let emoji = SubjectCatalog.emoji(for: subject)

            XCTAssertNotEqual(
                emoji,
                CourseEmoji.fallback,
                "\(subject) retombe sur le livre générique : la table ne la connaît pas"
            )

            if let other = seen[emoji] {
                XCTFail("\(subject) et \(other) portent le même emoji \(emoji)")
            }
            seen[emoji] = subject
        }

        XCTAssertEqual(seen.count, SubjectCatalog.allSubjects.count)
    }

    /// Un drapeau se reconnaît sans lire, et c'est tout ce qu'on demande à un emoji posé sur
    /// une pastille. Les langues anciennes n'en ont pas : le drapeau d'un pays qui n'existait
    /// pas ne dirait rien.
    func testEachLivingLanguageCarriesItsFlag() {
        XCTAssertEqual(SubjectCatalog.emoji(for: "Espagnol"), "🇪🇸")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Anglais"), "🇬🇧")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Allemand"), "🇩🇪")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Japonais"), "🇯🇵")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Latin & grec"), "🏺")

        // Le repli des langues attrape ce qui parle de langue sans nommer laquelle.
        XCTAssertEqual(CourseEmoji.derive(subject: "LV2", title: "Thème grammatical"), "🗣️")
    }

    /// L'ordre de la table est sa règle : une entrée large ne passe jamais avant une entrée
    /// précise. « Code de la route » contenait « code » et sortait un ordinateur portable.
    func testAPreciseSubjectWinsOverAWideOne() {
        XCTAssertEqual(SubjectCatalog.emoji(for: "Code de la route"), "🚗")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Statistiques"), "📊")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Mécanique"), "⚙️")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Algorithmique"), "🧩")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Génie civil"), "🏗️")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Kinésithérapie"), "🦴")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Théâtre"), "🎭")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Photographie"), "📷")
        XCTAssertEqual(SubjectCatalog.emoji(for: "Français"), "📖")
    }

    /// L'emoji d'une matière et celui d'un cours de cette matière viennent de la même table :
    /// deux listes tenues en parallèle finiraient par ne plus dire la même chose.
    func testACourseAndItsSubjectShareTheSameTable() {
        XCTAssertEqual(
            CourseEmoji.derive(subject: "Espagnol", title: "Le subjonctif imparfait"),
            SubjectCatalog.emoji(for: "Espagnol")
        )
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

    func testEveryCountryHasANameAndAFlag() {
        for country in SchoolingCountry.allCases {
            XCTAssertFalse(country.name.isEmpty, "\(country) doit avoir un nom")
            XCTAssertFalse(country.flag.isEmpty, "\(country) doit porter un drapeau")
        }
        // Le brut est envoyé à la fonction : le renommer changerait la consigne de rédaction.
        XCTAssertEqual(SchoolingCountry.fr.rawValue, "fr")
    }

    /// **L'ordre des pastilles est celui des marchés visés**, et il est verrouillé : c'est un
    /// ordre commercial, pas alphabétique, donc rien dans le code ne le rappelle.
    func testTheTargetedCountriesComeFirstAndInOrder() {
        let expected: [SchoolingCountry] = [
            .fr, .uk, .de, .it, .es, .pt, .cz, .nl, .gr, .hu, .pl, .ro, .se, .tr
        ]
        XCTAssertEqual(Array(SchoolingCountry.allCases.prefix(expected.count)), expected)
        XCTAssertEqual(SchoolingCountry.allCases.last, .other, "La sortie de secours ferme la liste")
    }

    // MARK: - « Autre pays »

    /// La sortie de secours n'est plus une impasse : elle rendait un « ailleurs » qui ne
    /// disait rien de plus que le silence. Le parcours attend maintenant qu'un pays ait été
    /// nommé, faute de quoi la question n'a pas de réponse.
    func testElsewhereIsOnlyAnAnswerOnceACountryIsNamed() throws {
        let model = OnboardingModel()
        XCTAssertTrue(model.hasAnsweredCountry, "La France est cochée d'avance")

        model.select(country: .other)
        XCTAssertFalse(model.hasAnsweredCountry, "« Autre pays » seul ne dit rien")

        model.customCountry = try XCTUnwrap(WorldCountries.country(code: "BR"))
        XCTAssertTrue(model.hasAnsweredCountry)
    }

    /// Repartir sur une pastille efface le pays tapé à la main : le garder ferait dire à
    /// l'écran « France » et « Brésil » en même temps.
    func testGoingBackToAChipForgetsTheTypedCountry() throws {
        let model = OnboardingModel()
        model.select(country: .other)
        model.customCountry = try XCTUnwrap(WorldCountries.country(code: "JP"))

        model.select(country: .de)

        XCTAssertNil(model.customCountry)
        XCTAssertEqual(model.country, .de)
    }

    /// Le catalogue vient des régions du système, pas d'une liste recopiée : il doit couvrir
    /// le monde, et chaque entrée doit porter son drapeau.
    func testTheWorldCatalogueIsBuiltFromTheSystem() throws {
        XCTAssertGreaterThan(WorldCountries.all.count, 150, "Le catalogue doit couvrir le monde")

        let france = try XCTUnwrap(WorldCountries.country(code: "fr"))
        XCTAssertEqual(france.flag, "🇫🇷", "Le drapeau se déduit du code, il ne s'écrit pas")

        for country in WorldCountries.all.prefix(20) {
            XCTAssertEqual(country.code.count, 2, "\(country.code) n'est pas un code ISO à deux lettres")
            XCTAssertFalse(country.name.isEmpty)
        }
    }

    /// Un pays dont le nom **commence** par la recherche passe devant un pays qui la contient
    /// au milieu, et les accents ne comptent pas : personne ne tape « Émirats » accentué.
    ///
    /// Les noms viennent de la langue de l'appareil : le test les prend donc **dans le
    /// catalogue lui-même** plutôt que de les écrire, sans quoi il tomberait le jour où on
    /// le lance sur un simulateur en anglais.
    func testTheSearchPutsThePrefixMatchFirstAndIgnoresAccents() throws {
        let brazil = try XCTUnwrap(WorldCountries.country(code: "BR"))
        XCTAssertEqual(WorldCountries.matches(brazil.name).first?.code, "BR")

        let accented = WorldCountries.all.first { $0.name != $0.name.unaccented }
        if let accented {
            XCTAssertTrue(
                WorldCountries.matches(accented.name.unaccented).contains { $0.code == accented.code },
                "\(accented.name) doit se retrouver sans son accent"
            )
        }

        XCTAssertTrue(WorldCountries.matches("   ").isEmpty, "Une recherche vide ne propose rien")
        XCTAssertLessThanOrEqual(WorldCountries.matches("a").count, 6, "La liste reste courte")
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


private extension String {
    var unaccented: String {
        folding(options: .diacriticInsensitive, locale: .current)
    }
}
