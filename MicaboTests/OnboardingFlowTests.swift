import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// Verrouille les règles du parcours d'accueil (V3.3, lot 10) : son ordre, ce que chaque pays
/// en voit, ses noms dans les statistiques, le retour, la reprise, la première leçon, et la
/// jauge qui ne recule jamais.
final class OnboardingFlowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Self.clean()
    }

    override func tearDown() {
        Self.clean()
        super.tearDown()
    }

    /// Le parcours écrit ses réponses au fil de l'eau : chaque test part d'un téléphone neuf.
    private static func clean() {
        OnboardingPreferences.reset()
        FirstLessonIntent.pending = nil
        UserDefaults.standard.removeObject(forKey: AccountGate.skippedKey)
    }

    private func model(advancingTo target: OnboardingStep) -> OnboardingModel {
        let model = OnboardingModel()
        var guardCounter = 0
        while model.step != target, guardCounter < OnboardingStep.allCases.count * 2 {
            if model.isAccountSheetPresented {
                model.finishAccountSheet()
            } else {
                model.advance()
            }
            guardCounter += 1
        }
        XCTAssertEqual(model.step, target, "Le parcours n'atteint pas \(target)")
        return model
    }

    /// Tous les écrans traversés, de celui où l'on est jusqu'au paywall.
    private func walk(_ model: OnboardingModel) -> [OnboardingStep] {
        var seen = [model.step]
        var guardCounter = 0
        while model.step != .paywall, guardCounter < OnboardingStep.allCases.count * 2 {
            if model.isAccountSheetPresented {
                model.finishAccountSheet()
            } else {
                model.advance()
            }
            if seen.last != model.step { seen.append(model.step) }
            guardCounter += 1
        }
        return seen
    }

    /// Les deux écrans de l'essai ne se montrent que si la boutique le propose encore.
    private var trialScreens: Int {
        OnboardingTrial.isOffered ? 2 : 0
    }

    // MARK: - L'ordre

    /// **Le parcours de la spécification, écran par écran** : les stories, puis vingt-trois
    /// étapes. Les noms sont ceux des statistiques : en changer un coupe sa courbe.
    func testTheFlowIsTheSpecInOrder() {
        XCTAssertEqual(OnboardingStep.allCases.map(\.analyticsName), [
            "hookLogo",
            "welcome", "name", "country", "level", "schoolType", "year", "exam", "subjects",
            "lessonDemo",
            "goal", "worries", "solutionMap", "scanDemo", "currentAverage", "targetAverage", "startingPoint",
            "dailyTime", "planDemo", "sampleCard", "chatDemo", "notifications", "firstLesson",
            "planBuilding", "profileSummary",
            "freeTrialIntro", "trialOffer", "whyNow", "paywall",
        ])
        XCTAssertEqual(OnboardingStep.allCases.count, 29, "Un écran de stories et vingt-huit étapes (lot 11)")
        XCTAssertEqual(OnboardingStep.allCases.filter { $0.kind == .stories }, [.hookLogo])
        XCTAssertEqual(OnboardingStep.allCases.last, .paywall)
    }

    /// **Les stories, Mika qui se présente, le prénom, puis le pays.** Le prénom vient avant
    /// tout ce qui trie, parce que tout ce qui suit s'adresse à quelqu'un ; le pays commande
    /// les réponses de tout le reste.
    func testMikaIntroducesHimselfBeforeTheFirstQuestion() {
        let model = OnboardingModel()
        XCTAssertEqual(model.step, .hookLogo)

        model.advance()
        XCTAssertEqual(model.step, .welcome, "Mika se présente avant de demander quoi que ce soit")

        model.advance()
        XCTAssertEqual(model.step, .name, "Le prénom, en premier")

        model.advance()
        XCTAssertEqual(model.step, .country, "Le pays commande les réponses de tout le reste")
    }

    /// Chaque pays ne voit qu'une des deux questions de niveau, et c'est le pays qui
    /// décide : la filière puis l'année pour ceux qu'on décrit en détail, le palier large
    /// pour les autres.
    func testEachCountrySeesExactlyOneLevelQuestion() {
        let detailed = self.model(advancingTo: .country)
        detailed.select(country: .fr)
        detailed.advance()
        XCTAssertEqual(detailed.step, .schoolType, "La France demande la filière")
        detailed.advance()
        XCTAssertEqual(detailed.step, .year)
        detailed.advance()
        XCTAssertEqual(detailed.step, .exam, "Ce qui arrive en premier, une fois l'année connue")
        detailed.advance()
        XCTAssertEqual(detailed.step, .subjects)

        let generic = self.model(advancingTo: .country)
        generic.select(country: .other)
        generic.advance()
        XCTAssertEqual(generic.step, .level, "Un pays générique demande le palier large")
        generic.advance()
        XCTAssertEqual(generic.step, .exam)
        generic.advance()
        XCTAssertEqual(generic.step, .subjects)

        XCTAssertEqual(OnboardingStep.allCases.filter { $0.isSkipped(for: .fr) }, [.level])
        XCTAssertEqual(OnboardingStep.allCases.filter { $0.isSkipped(for: .other) }, [.schoolType, .year])
    }

    /// **Le parcours d'un lycéen français, écran par écran.**
    func testAFrenchStudentWalksTheWholeFlow() {
        let model = OnboardingModel()
        model.select(country: .fr)
        var expected: [OnboardingStep] = [
            .hookLogo, .welcome, .name, .country, .schoolType, .year, .exam, .subjects, .lessonDemo,
            .goal, .worries, .solutionMap, .scanDemo, .currentAverage, .targetAverage, .startingPoint,
            .dailyTime, .planDemo, .sampleCard, .chatDemo, .notifications, .firstLesson, .planBuilding, .profileSummary,
        ]
        if OnboardingTrial.isOffered { expected += [.freeTrialIntro, .trialOffer] }
        expected += [.whyNow, .paywall]
        XCTAssertEqual(walk(model), expected)
    }

    /// **La longueur du parcours, pays par pays** : un écran de moins que la liste (l'autre
    /// question de niveau) pour un pays décrit, deux de moins ailleurs.
    func testTheLengthOfTheFlowFollowsTheCountry() throws {
        for country in [SchoolingCountry.fr, .de, .us, .es, .it, .ma] {
            let model = OnboardingModel()
            model.select(country: country)
            let seen = walk(model)
            XCTAssertEqual(seen.count, 26 + trialScreens, "\(country)")
            XCTAssertFalse(seen.contains(.level), "\(country) : la filière et l'année, pas le palier")
            XCTAssertEqual(seen.last, .paywall)
        }

        let elsewhere = OnboardingModel()
        elsewhere.select(country: .other)
        let seen = walk(elsewhere)
        XCTAssertEqual(seen.count, 25 + trialScreens)
        XCTAssertFalse(seen.contains(.schoolType) || seen.contains(.year))
        XCTAssertTrue(seen.contains(.level))

        // Un pays trouvé par la recherche, dont on connaît l'école : l'Arabie saoudite a ses
        // filières, ses années et ses examens.
        let saudi = OnboardingModel()
        saudi.select(worldCountry: try XCTUnwrap(WorldCountries.country(code: "SA")))
        XCTAssertEqual(saudi.country, .other)
        XCTAssertEqual(saudi.regionCode, "SA")
        XCTAssertEqual(walk(saudi).count, 26 + trialScreens)

        // Un pays de la liste retrouvé par la recherche se range sous son nom de la liste.
        let morocco = OnboardingModel()
        morocco.select(worldCountry: try XCTUnwrap(WorldCountries.country(code: "MA")))
        XCTAssertEqual(morocco.country, .ma)
        XCTAssertNil(morocco.customCountry)
    }

    // MARK: - Les formes d'écran

    /// Les questions sont celles que Mika pose dans sa bulle, et rien d'autre ne l'est.
    func testTheQuestionsAreExactlyTheScreensThatAsk() {
        XCTAssertEqual(OnboardingStep.allCases.filter(\.isQuestion), [
            .name, .country, .level, .schoolType, .year, .exam, .subjects, .goal, .worries,
            .currentAverage, .targetAverage, .dailyTime, .sampleCard, .firstLesson,
        ])
        XCTAssertEqual(
            OnboardingStep.allCases.filter { $0.kind == .moment },
            [.welcome, .planBuilding, .profileSummary, .freeTrialIntro]
        )
    }

    /// **Un choix unique avance tout seul** : ces écrans n'ont pas de bouton.
    func testASingleChoiceAdvancesOnItsOwn() {
        let advancing = OnboardingStep.allCases.filter(\.advancesOnChoice)
        XCTAssertEqual(advancing, [.country, .level, .schoolType, .year, .goal, .dailyTime])
        XCTAssertTrue(advancing.allSatisfy(\.isQuestion))
    }

    /// La barre du haut (le retour et la jauge) reste sur tous les écrans du parcours, sauf
    /// ceux qui sont un moment à eux seuls.
    func testTheChromeHidesOnlyOnTheScreensThatStandAlone() {
        XCTAssertEqual(
            OnboardingStep.allCases.filter { !$0.showsChrome },
            [.hookLogo, .planBuilding, .profileSummary, .paywall]
        )
        XCTAssertEqual(OnboardingStep.allCases.filter(\.isSkippable), [.currentAverage])
        XCTAssertEqual(OnboardingStep.allCases.filter(\.isLoading), [.planBuilding])
    }

    // MARK: - Les réponses

    /// Les réponses sont écrites au changement d'écran, et le temps choisi devient le rythme
    /// que `DailyLoad` lit.
    func testTheAnswersArePersistedOnAdvance() {
        let model = OnboardingModel()
        model.displayName = "Léa"
        model.worries = [.homework, .examStress]
        model.dailyMinutes = 10
        model.studyHour = 20
        model.advance()

        XCTAssertEqual(OnboardingPreferences.displayName, "Léa")
        XCTAssertEqual(OnboardingPreferences.worries, ["examStress", "homework"], "Dans l'ordre de la liste")
        XCTAssertEqual(OnboardingPreferences.dailyMinutes, 10)
        XCTAssertEqual(OnboardingPreferences.studyHour, 20)
        XCTAssertEqual(model.cardsPerDay, DailyLoad.newCardsPerDay(dailyMinutes: 10))
        XCTAssertEqual(model.minutesPerDay, 10)
    }

    /// **Mika répond aux trois premiers blocages cochés, dans l'ordre où ils l'ont été** :
    /// c'est l'ordre des cartes de « Voilà comment je t'aide ».
    func testTheSolutionsFollowTheOrderTheWorriesWereTicked() {
        let model = OnboardingModel()
        XCTAssertEqual(model.answeredWorries, [])

        model.toggle(worry: .motivation)
        model.toggle(worry: .examStress)
        model.toggle(worry: .forgetting)
        model.toggle(worry: .homework)
        XCTAssertEqual(model.answeredWorries, [.motivation, .examStress, .forgetting], "Trois au plus")

        model.toggle(worry: .examStress)
        XCTAssertEqual(model.answeredWorries, [.motivation, .forgetting, .homework], "Décocher fait remonter le suivant")

        for worry in StudyWorry.allCases {
            XCTAssertFalse(worry.title(locale: .fr).hasPrefix("ios."), "\(worry)")
            XCTAssertFalse(worry.solutionTitle(locale: .fr).hasPrefix("ios."), "\(worry)")
            XCTAssertFalse(worry.solutionBody(locale: .fr).hasPrefix("ios."), "\(worry)")
        }
        XCTAssertEqual(StudyWorry.examStress.solutionTitle(locale: .fr), "Examens blancs")
        XCTAssertEqual(StudyWorry.homework.solutionTitle(locale: .fr), "Scanner d'exos")
    }

    /// **« Passer » la moyenne saute aussi la moyenne visée**, et rien n'est gardé ; y revenir
    /// et répondre la redemande.
    func testSkippingTheAverageSkipsTheTargetToo() {
        let model = self.model(advancingTo: .currentAverage)
        model.currentScore = 12
        model.skipAverages()

        XCTAssertEqual(model.step, .startingPoint, "La projection se dessine sans chiffres")
        XCTAssertNil(model.currentScore)
        XCTAssertNil(model.targetScore)
        XCTAssertTrue(model.didSkipAverages)
        XCTAssertTrue(model.isSkipped(.targetAverage))

        model.goBack()
        XCTAssertEqual(model.step, .currentAverage, "Le retour enjambe la question qu'on n'a pas posée")
        model.currentScore = 12
        model.answerCurrentAverage()
        model.advance()
        XCTAssertEqual(model.step, .targetAverage)
    }

    /// On vise sa note d'aujourd'hui (« tenir ») ou plus haut : jamais en dessous.
    func testTheTargetIsNeverBelowTheCurrentAverage() {
        let model = OnboardingModel()
        model.select(country: .fr)
        model.currentScore = 14
        XCTAssertEqual(model.targetChoices.first?.score, 14, "Tenir sa note est un objectif")
        XCTAssertTrue(model.targetChoices.allSatisfy { $0.score >= 14 })
        XCTAssertEqual(model.targetChoices.last?.score, TargetScore.max)
    }

    // MARK: - Le compte, puis l'offre

    /// **Le compte se propose en quittant le plan révélé**, dans une languette : l'écran ne
    /// change pas tant qu'elle n'a pas de réponse.
    func testTheAccountSheetRisesWhenLeavingThePlan() {
        let model = self.model(advancingTo: .profileSummary)
        XCTAssertFalse(model.isAccountSheetPresented)

        XCTAssertTrue(model.advance(), "L'appui est pris : la languette monte")
        XCTAssertTrue(model.isAccountSheetPresented)
        XCTAssertEqual(model.step, .profileSummary)

        model.finishAccountSheet()
        XCTAssertFalse(model.isAccountSheetPresented)
        XCTAssertEqual(model.step, OnboardingTrial.isOffered ? .freeTrialIntro : .paywall)
    }

    /// Qui a déjà un compte ne voit pas la languette.
    func testASignedInStudentSkipsTheAccountSheet() {
        let model = self.model(advancingTo: .profileSummary)
        model.hasAccount = true
        model.advance()
        XCTAssertFalse(model.isAccountSheetPresented)
        XCTAssertNotEqual(model.step, .profileSummary)
    }

    /// Apple et Google restent les deux fournisseurs OAuth. Le courriel n'est pas un
    /// quatrième fournisseur : c'est le formulaire que son bouton ouvre.
    func testSignInOffersBothProviders() {
        XCTAssertEqual(SignInProvider.allCases, [.apple, .google])

        for provider in SignInProvider.allCases {
            let title = provider.title(t: { L10n.t($0, locale: .fr) })
            XCTAssertTrue(title.hasPrefix("Continuer avec"), "\(provider) doit dire ce qu'il fait")
        }

        XCTAssertEqual(L10n.t("onboarding.connexionTitle", locale: .fr), "Content de te revoir.")
        XCTAssertEqual(L10n.t("ios.onb10.account.title", locale: .fr), "Garde ton plan **en lieu sûr**")
        XCTAssertFalse(PaywallLinks.terms.isEmpty)
        XCTAssertFalse(PaywallLinks.privacy.isEmpty)
    }

    /// Passer la connexion ici la passe pour de bon : c'est la clé que la racine relit.
    func testSkippingTheAccountUsesTheKeyReadByTheRoot() {
        XCTAssertEqual(AccountGate.skippedKey, "micabo.auth.skipped")
    }

    /// **L'essai ne s'annonce que s'il peut être tenu** : ses deux écrans suivent l'offre de la
    /// boutique, et sa durée est celle du produit.
    func testTheTrialScreensFollowTheStore() {
        let model = OnboardingModel()
        XCTAssertEqual(model.isSkipped(.freeTrialIntro), !OnboardingTrial.isOffered)
        XCTAssertEqual(model.isSkipped(.trialOffer), !OnboardingTrial.isOffered)
        XCTAssertEqual(OnboardingTrial.days, PaywallCatalog.yearly.trialDays)
        XCTAssertEqual(OnboardingTrial.days, TrialTimeline.freeDays)
    }

    /// Le parcours se termine sur le paywall, et il n'y a rien après.
    func testTheFlowEndsOnThePaywall() {
        let model = self.model(advancingTo: .paywall)
        XCTAssertFalse(model.advance())
        XCTAssertEqual(model.step, .paywall)
    }

    // MARK: - Revenir

    /// **On revient de partout, sauf du premier écran, du chargement, du plan révélé et du
    /// paywall.** Le retour enjambe le chargement : y revenir renverrait aussitôt en avant.
    func testGoingBackWorksEverywhereExceptLoadingAndPaywall() {
        XCTAssertEqual(
            OnboardingStep.allCases.filter { !$0.allowsReturn },
            [.hookLogo, .planBuilding, .profileSummary, .paywall]
        )

        let model = self.model(advancingTo: .name)
        XCTAssertTrue(model.canGoBack)
        model.goBack()
        XCTAssertEqual(model.step, .welcome)
        model.goBack()
        XCTAssertEqual(model.step, .hookLogo, "Revenir jusqu'aux stories rend le choix de la langue")
        XCTAssertFalse(model.canGoBack)

        let revealed = self.model(advancingTo: .profileSummary)
        XCTAssertFalse(revealed.canGoBack, "Le plan révélé est un aboutissement")

        let loading = self.model(advancingTo: .planBuilding)
        XCTAssertFalse(loading.canGoBack)

        if OnboardingTrial.isOffered {
            let offer = self.model(advancingTo: .freeTrialIntro)
            offer.goBack()
            XCTAssertEqual(offer.step, .profileSummary, "Le retour ne s'arrête pas sur le chargement")
        }

        let paywall = self.model(advancingTo: .paywall)
        XCTAssertFalse(paywall.canGoBack, "Le paywall porte sa propre croix")
    }

    /// Le retour ne fait pas apparaître une question qu'on n'a pas posée à l'aller.
    func testGoingBackKeepsSkippedScreensSkipped() {
        let detailed = self.model(advancingTo: .country)
        detailed.select(country: .fr)
        while detailed.step != .exam { detailed.advance() }
        detailed.goBack()
        XCTAssertEqual(detailed.step, .year)
        detailed.goBack()
        XCTAssertEqual(detailed.step, .schoolType)
        detailed.goBack()
        XCTAssertEqual(detailed.step, .country, "Le palier large n'a jamais été posé à un Français")

        let generic = self.model(advancingTo: .country)
        generic.select(country: .other)
        while generic.step != .exam { generic.advance() }
        generic.goBack()
        XCTAssertEqual(generic.step, .level)
        generic.goBack()
        XCTAssertEqual(generic.step, .country)
    }

    /// Le sens du mouvement suit le geste : il décide du bord par lequel la page arrive.
    func testTheDirectionFollowsTheMove() {
        let model = OnboardingModel()
        model.advance()
        XCTAssertTrue(model.isMovingForward)
        model.advance()
        model.goBack()
        XCTAssertFalse(model.isMovingForward)
        model.advance()
        XCTAssertTrue(model.isMovingForward)
    }

    // MARK: - Les statistiques

    /// **Les écrans gardés portent le nom qu'ils avaient** ; deux sont nouveaux.
    func testKeptScreensKeepTheirAnalyticsNames() {
        let names = Set(OnboardingStep.allCases.map(\.analyticsName))
        let kept = [
            "hookLogo", "name", "welcome", "country", "level", "schoolType", "year", "exam",
            "subjects", "goal", "worries", "startingPoint", "currentAverage", "targetAverage",
            "dailyTime", "sampleCard", "notifications", "planBuilding", "profileSummary",
            "freeTrialIntro", "trialOffer", "paywall",
        ]
        for name in kept {
            XCTAssertTrue(names.contains(name), "\(name) a disparu des statistiques")
        }
        XCTAssertEqual(
            names.subtracting(kept),
            ["solutionMap", "firstLesson", "lessonDemo", "scanDemo", "planDemo", "chatDemo", "whyNow"]
        )
        XCTAssertEqual(AnalyticsEvent.onboardingStoryViewed.rawValue, "onboarding_story_viewed")
        XCTAssertEqual(AnalyticsEvent.onboardingFirstLesson.rawValue, "onboarding_first_lesson")
    }

    /// Les écrans retirés ne sont plus dans le parcours : ce qu'ils disaient est dit une fois,
    /// par les stories et par « Voilà comment je t'aide ».
    func testRemovedScreensAreGoneFromTheFlow() {
        let names = Set(OnboardingStep.allCases.map(\.analyticsName))
        let retired = [
            "building", "featuresIntro", "mikaMission", "mikaSources", "mikaPaths", "mikaDesign",
            "mikaTutor", "mikaSolution", "mikaRelief", "socialProof", "studyTime",
        ]
        for name in retired {
            XCTAssertFalse(names.contains(name), "\(name) devait partir")
            XCTAssertNotNil(OnboardingStep.replacement(forRetired: name), "\(name) doit se reprendre quelque part")
        }
    }

    /// **Un parcours laissé sur un écran retiré continue sur le suivant qui existe.**
    func testARetiredScreenResumesOnTheNextOneThatExists() {
        XCTAssertEqual(OnboardingStep.replacement(forRetired: "studyTime"), .notifications, "L'heure du rappel se règle là")
        for name in ["building", "featuresIntro", "mikaMission", "mikaSources", "mikaPaths"] {
            XCTAssertEqual(OnboardingStep.replacement(forRetired: name), .sampleCard, name)
        }
        for name in ["mikaDesign", "mikaTutor", "mikaSolution", "mikaRelief", "socialProof"] {
            XCTAssertEqual(OnboardingStep.replacement(forRetired: name), .planBuilding, name)
        }
        XCTAssertEqual(OnboardingStep.replacement(forRetired: "trialReminder"), .trialOffer)
        XCTAssertNil(OnboardingStep.replacement(forRetired: "trainCards"))

        OnboardingPreferences.displayName = "Lina"
        UserDefaults.standard.set("mikaTutor", forKey: OnboardingPreferences.Key.resumeStep)
        XCTAssertEqual(OnboardingPreferences.resumeStep, .planBuilding)
        XCTAssertEqual(OnboardingModel.resuming(in: nil).step, .planBuilding)

        UserDefaults.standard.set("studyTime", forKey: OnboardingPreferences.Key.resumeStep)
        XCTAssertEqual(OnboardingModel.resuming(in: nil).step, .notifications)
    }

    /// Les clés des écrans retirés avant ce lot s'effacent toujours avec le reste.
    func testTheResumeKeysAreErasedWithTheAnswers() {
        OnboardingPreferences.displayName = "Lina"
        OnboardingPreferences.resumeStep = .subjects
        OnboardingPreferences.reset()
        XCTAssertNil(OnboardingPreferences.resumeStep)
        XCTAssertNil(OnboardingPreferences.displayName)
    }

    // MARK: - La première leçon

    /// **« Par quel cours on commence ? »** n'a de réponse qu'avec un sujet écrit, ou l'import
    /// choisi.
    func testTheFirstLessonNeedsATopicOrAnImport() {
        let model = self.model(advancingTo: .firstLesson)
        XCTAssertFalse(model.hasAnsweredFirstLesson)

        model.firstLessonChoice = .topic
        XCTAssertFalse(model.hasAnsweredFirstLesson, "Choisir d'écrire n'est pas avoir écrit")
        model.firstLessonTopic = "   "
        XCTAssertFalse(model.hasAnsweredFirstLesson)
        XCTAssertNil(model.firstLessonSubject)
        model.confirmFirstLesson()
        XCTAssertEqual(model.step, .firstLesson, "Sans réponse, le bouton ne fait rien")

        model.firstLessonTopic = "  La guerre froide "
        XCTAssertTrue(model.hasAnsweredFirstLesson)
        XCTAssertEqual(model.firstLessonSubject, "La guerre froide")

        model.firstLessonChoice = .importSource
        XCTAssertTrue(model.hasAnsweredFirstLesson)
        XCTAssertNil(model.firstLessonSubject, "Le sujet tapé ne compte plus quand on importe")
    }

    /// Le sujet écrit part à la Home (`FirstLessonIntent`), qui lancera la leçon.
    func testAWrittenTopicIsHandedToTheHome() {
        let model = self.model(advancingTo: .firstLesson)
        model.firstLessonChoice = .topic
        model.firstLessonTopic = "La guerre froide"
        model.confirmFirstLesson()

        XCTAssertEqual(FirstLessonIntent.pending, .topic("La guerre froide"))
        XCTAssertEqual(model.step, .planBuilding)
        XCTAssertEqual(model.firstLessonLine(locale: .fr), "La guerre froide")
    }

    func testAnImportIsHandedToTheHome() {
        let model = self.model(advancingTo: .firstLesson)
        model.firstLessonChoice = .importSource
        model.confirmFirstLesson()

        XCTAssertEqual(FirstLessonIntent.pending, .importSource)
        XCTAssertEqual(model.step, .planBuilding)
        XCTAssertEqual(model.firstLessonLine(locale: .fr), "Ton cours à importer")
    }

    /// **« Plus tard »** : rien n'attend la Home, et le plan n'annonce pas de première leçon.
    func testLaterLeavesNothingForTheHome() {
        FirstLessonIntent.pending = .topic("Un vieux sujet")
        let model = self.model(advancingTo: .firstLesson)
        model.firstLessonChoice = .topic
        model.firstLessonTopic = "La guerre froide"
        model.skipFirstLesson()

        XCTAssertNil(FirstLessonIntent.pending)
        XCTAssertNil(model.firstLessonChoice)
        XCTAssertEqual(model.step, .planBuilding)
        XCTAssertNil(model.firstLessonLine(locale: .fr))
        XCTAssertFalse(model.planSummary(locale: .fr).contains { $0.id == "lesson" })
    }

    // MARK: - Le pays détecté

    /// **Le pays présélectionné est celui que l'appareil désigne** : ses langues d'abord ;
    /// quand elles ne désignent aucun pays de la liste, sa région, et plus la France par défaut.
    func testThePreselectedCountryIsTheOneTheDeviceNames() {
        XCTAssertEqual(SchoolingCountry.detected(languages: ["fr-FR"], chosen: nil), .fr)
        XCTAssertEqual(SchoolingCountry.detected(languages: ["ar-MA"], chosen: nil), .ma)
        XCTAssertNil(SchoolingCountry.detected(languages: ["ar-SA"], chosen: nil))
        XCTAssertNil(SchoolingCountry.detected(languages: ["ja-JP"], chosen: nil))
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["ja-JP"], chosen: nil), .fr, "Le repli des réglages ne change pas")

        let saudi = OnboardingModel.deviceCountry(languages: ["ar-SA"], chosen: nil, region: "SA", locale: .ar)
        XCTAssertEqual(saudi?.code, "SA")
        XCTAssertFalse(SchoolSystem.tracks(region: saudi?.code).isEmpty, "L'Arabie saoudite a ses filières")

        XCTAssertEqual(OnboardingModel.deviceCountry(languages: ["ja-JP"], chosen: nil, region: "JP", locale: .en)?.code, "JP")
        XCTAssertNil(OnboardingModel.deviceCountry(languages: ["fr-FR"], chosen: nil, region: "SA", locale: .fr),
                     "Un téléphone en français garde la France : la langue décide avant la région")
        XCTAssertNil(OnboardingModel.deviceCountry(languages: ["ar-MA"], chosen: nil, region: "MA", locale: .ar),
                     "Le Maroc est dans la liste")
        XCTAssertNil(OnboardingModel.deviceCountry(languages: ["ja-JP"], chosen: nil, region: nil, locale: .en))
    }

    // MARK: - Niveau

    /// Le palier est écrit dès le changement d'écran, et il écrit son registre avec lui :
    /// c'est ce registre que la fonction reçoit et que le cloud synchronise.
    func testStageIsPersistedOnAdvanceWithItsWritingRegister() throws {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let model = self.model(advancingTo: .country)
        model.select(country: .fr)
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

    /// Le pays garde sa langue (le système scolaire), mais Micabo écrit dans la langue de
    /// l'app : un élève scolarisé au Royaume-Uni qui lit l'app en turc reçoit du turc.
    func testTheLanguageComesFromTheApp() {
        XCTAssertEqual(SchoolingCountry.fr.language, .fr)
        XCTAssertEqual(SchoolingCountry.ca.language, .fr)
        XCTAssertEqual(SchoolingCountry.us.language, .en)
        XCTAssertEqual(SchoolingCountry.uk.language, .en)
        XCTAssertEqual(SchoolingCountry.other.language, UiLocale.resolved().contentLanguage, "Hors liste : la langue de l'app")

        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        OnboardingPreferences.schoolingCountry = .uk
        XCTAssertEqual(OnboardingPreferences.contentLanguage, UiLocale.resolved().contentLanguage)
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
        XCTAssertEqual(model.language, UiLocale.resolved().contentLanguage, "La langue reste celle de l'app")

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

        XCTAssertEqual(SchoolingCountry.guessed(languages: ["en-US"], chosen: nil), .us)
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["en-GB"], chosen: nil), .uk)
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["en"], chosen: nil), .us)
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["de-DE"], chosen: nil), .de)
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["fr-FR"], chosen: nil), .fr)
        // La langue décide avant la région : un iPhone en français réglé sur les États-Unis
        // reçoit ses cours en français, un Belge francophone garde la Belgique.
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["fr-US"], chosen: nil), .fr)
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["fr-BE"], chosen: nil), .be)
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["nl-BE"], chosen: nil), .nl)
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["ar-MA"], chosen: nil), .ma)
        // La langue choisie dans l'app passe avant celle du téléphone.
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["en-US"], chosen: "fr"), .fr)
        XCTAssertEqual(SchoolingCountry.guessed(languages: ["en-US", "fr-CA"], chosen: "fr"), .ca)
        XCTAssertEqual(SchoolingCountry.fr.institutionSearchIso(uiLocale: nil), "FR")
        XCTAssertEqual(SchoolingCountry.fr.institutionSearchIso(uiLocale: .de), "DE")
        XCTAssertEqual(SchoolingCountry.us.institutionSearchIso(uiLocale: .de), "US")
        // « EN » n'est pas un pays : l'annuaire aurait filtré sur rien.
        XCTAssertEqual(SchoolingCountry.fr.institutionSearchIso(uiLocale: .en), "US")
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
        XCTAssertTrue(model.hasAnsweredCountry, "Un pays est coché d'avance")

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
        XCTAssertGreaterThan(WorldCountries.all().count, 150, "Le catalogue doit couvrir le monde")

        let france = try XCTUnwrap(WorldCountries.country(code: "fr"))
        XCTAssertEqual(france.flag, "🇫🇷", "Le drapeau se déduit du code, il ne s'écrit pas")

        for country in WorldCountries.all().prefix(20) {
            XCTAssertEqual(country.code.count, 2, "\(country.code) n'est pas un code ISO à deux lettres")
            XCTAssertFalse(country.name.isEmpty)
        }
    }

    /// Un pays dont le nom **commence** par la recherche passe devant un pays qui la contient
    /// au milieu, et les accents ne comptent pas : personne ne tape « Émirats » accentué.
    ///
    /// Les noms viennent de la langue de l'app : le test les prend donc **dans le
    /// catalogue lui-même** plutôt que de les écrire, sans quoi il tomberait le jour où on
    /// le lance avec l'app en anglais.
    func testTheSearchPutsThePrefixMatchFirstAndIgnoresAccents() throws {
        let brazil = try XCTUnwrap(WorldCountries.country(code: "BR"))
        XCTAssertEqual(WorldCountries.matches(brazil.name).first?.code, "BR")

        let accented = WorldCountries.all().first { $0.name != $0.name.unaccented }
        if let accented {
            XCTAssertTrue(
                WorldCountries.matches(accented.name.unaccented).contains { $0.code == accented.code },
                "\(accented.name) doit se retrouver sans son accent"
            )
        }

        XCTAssertTrue(WorldCountries.matches("   ").isEmpty, "Une recherche vide ne propose rien")
        XCTAssertLessThanOrEqual(WorldCountries.matches("a").count, 6, "La liste reste courte")
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

    // MARK: - La reprise

    /// **Seule l'accroche se refait** : les stories, Mika qui se présente, le prénom. Le reste
    /// reprend sur l'écran quitté.
    func testOnlyTheHookIsReplayed() {
        XCTAssertEqual(OnboardingStep.welcome.resumePoint(hasName: true), .hookLogo)
        XCTAssertEqual(OnboardingStep.name.resumePoint(hasName: true), .hookLogo)
        XCTAssertEqual(OnboardingStep.subjects.resumePoint(hasName: true), .subjects)
        XCTAssertEqual(OnboardingStep.subjects.resumePoint(hasName: false), .hookLogo,
                       "Sans prénom, tout ce qui suit s'adresserait à personne")
        XCTAssertEqual(OnboardingStep.firstLesson.resumePoint(hasName: true), .firstLesson)
        XCTAssertEqual(OnboardingStep.paywall.resumePoint(hasName: true), .paywall)
    }

    /// **Un parcours interrompu reprend sur la question quittée**, avec les réponses déjà
    /// données.
    func testAnInterruptedFlowResumesOnTheScreenItLeft() {
        let first = OnboardingModel()
        first.displayName = "Lina"
        first.select(country: .fr)
        first.currentScore = 12
        first.targetScore = 16
        first.worries = [.forgetting, .examStress]
        while first.step != .dailyTime { first.advance() }

        let resumed = OnboardingModel.resuming(in: nil)
        XCTAssertTrue(resumed.isResumed)
        XCTAssertEqual(resumed.step, .dailyTime)
        XCTAssertEqual(resumed.displayName, "Lina")
        XCTAssertEqual(resumed.country, .fr)
        XCTAssertEqual(resumed.currentScore, 12)
        XCTAssertEqual(resumed.targetScore, 16)
        XCTAssertEqual(resumed.worries, [.forgetting, .examStress])
        XCTAssertFalse(resumed.didSkipAverages)
    }

    /// Une moyenne passée reste passée à la reprise : la moyenne visée ne revient pas, et la
    /// projection reste sans chiffres.
    func testSkippedAveragesStaySkippedOnResume() {
        let first = self.model(advancingTo: .currentAverage)
        first.displayName = "Lina"
        first.skipAverages()
        first.advance()
        XCTAssertEqual(first.step, .dailyTime)

        let resumed = OnboardingModel.resuming(in: nil)
        XCTAssertEqual(resumed.step, .dailyTime)
        XCTAssertTrue(resumed.didSkipAverages)
        resumed.goBack()
        resumed.goBack()
        XCTAssertEqual(resumed.step, .currentAverage, "Le retour enjambe toujours la moyenne visée")
    }

    /// La première leçon choisie se retrouve à la reprise.
    func testTheFirstLessonIsRestoredOnResume() {
        let first = self.model(advancingTo: .firstLesson)
        first.displayName = "Lina"
        first.firstLessonChoice = .topic
        first.firstLessonTopic = "La photosynthèse"
        first.confirmFirstLesson()

        let resumed = OnboardingModel.resuming(in: nil)
        XCTAssertEqual(resumed.step, .planBuilding)
        XCTAssertEqual(resumed.firstLessonChoice, .topic)
        XCTAssertEqual(resumed.firstLessonSubject, "La photosynthèse")
    }

    /// Sans prénom enregistré, il n'y a rien à reprendre : le parcours repart des stories.
    func testAFlowWithoutANameStartsOver() {
        let first = OnboardingModel()
        while first.step != .subjects { first.advance() }

        let resumed = OnboardingModel.resuming(in: nil)
        XCTAssertEqual(resumed.step, .hookLogo)
        XCTAssertFalse(resumed.isResumed)
    }

    /// **Un écran inconnu ne se reprend pas** : un parcours laissé sur un écran d'une version
    /// trop ancienne repart des stories plutôt que d'un écran qui n'existe plus.
    func testAnUnknownScreenIsNotResumed() {
        OnboardingPreferences.displayName = "Lina"
        UserDefaults.standard.set("trainCards", forKey: OnboardingPreferences.Key.resumeStep)
        XCTAssertNil(OnboardingPreferences.resumeStep)
        XCTAssertEqual(OnboardingModel.resuming(in: nil).step, .hookLogo)
    }

    /// Qui a passé la connexion ne revoit pas la languette en reprenant juste avant elle.
    func testASkippedAccountIsNotAskedAgainOnResume() {
        UserDefaults.standard.set(true, forKey: AccountGate.skippedKey)
        OnboardingPreferences.displayName = "Lina"
        OnboardingPreferences.resumeStep = .profileSummary

        let resumed = OnboardingModel.resuming(in: nil)
        XCTAssertEqual(resumed.step, .profileSummary)
        resumed.advance()
        XCTAssertFalse(resumed.isAccountSheetPresented)
        XCTAssertEqual(resumed.step, OnboardingTrial.isOffered ? .freeTrialIntro : .paywall)
    }

    /// Seule la vue du parcours reprend, et un parcours fini ne laisse rien à reprendre.
    func testAFinishedFlowLeavesNothingToResume() {
        OnboardingPreferences.displayName = "Lina"
        OnboardingPreferences.resumeStep = .paywall
        XCTAssertEqual(OnboardingModel().step, .hookLogo)
        XCTAssertEqual(OnboardingModel.resuming(in: nil).step, .paywall)

        OnboardingPreferences.markCompleted()
        XCTAssertNil(OnboardingPreferences.resumeStep)
        XCTAssertEqual(OnboardingModel.resuming(in: nil).step, .hookLogo)
    }
}

private extension String {
    var unaccented: String {
        folding(options: .diacriticInsensitive, locale: .current)
    }
}
