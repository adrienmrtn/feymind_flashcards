import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Une page du parcours telle qu'elle s'affiche** : l'écran de l'étape, sous la barre du haut
/// quand l'étape la montre, dans les zones sûres d'un vrai téléphone (le rendu n'a ni barre
/// d'état ni indicateur d'accueil : on leur garde leur place, pour que l'air soit le même).
///
/// L'écran est posé immobile (`onboardingStill`, `mikaStill`) : ni horloge, ni champ du
/// système, ni défilement.
struct OnboardingRenderPage<Content: View>: View {
    let step: OnboardingStep
    let model: OnboardingModel
    var rtl = false
    var xxl = false
    var safeTop: CGFloat = 59
    var safeBottom: CGFloat = 34
    private let content: Content

    init(
        step: OnboardingStep,
        model: OnboardingModel,
        rtl: Bool = false,
        xxl: Bool = false,
        safeTop: CGFloat = 59,
        safeBottom: CGFloat = 34,
        @ViewBuilder content: () -> Content
    ) {
        self.step = step
        self.model = model
        self.rtl = rtl
        self.xxl = xxl
        self.safeTop = safeTop
        self.safeBottom = safeBottom
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .top) {
            content
                .padding(.top, step.showsChrome ? OnboardingTopBar.height : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            OnboardingTopBar(model: model)
        }
        .padding(.top, safeTop)
        .padding(.bottom, safeBottom)
        .background(V3Color.bg)
        .environment(model)
        .environment(\.onboardingStill, true)
        .environment(\.mikaStill, true)
        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
        .environment(\.dynamicTypeSize, xxl ? .xxxLarge : .large)
    }
}

/// **Les rendus du parcours d'accueil du lot 10 (`onb10-*`)** : chaque écran en français, dans
/// l'ordre du parcours (le marine, thème de référence, et le clair) ; les mêmes pour une élève
/// allemande et une élève saoudienne (en arabe, de droite à gauche) ; les écrans denses en très
/// grand texte sur un iPhone SE ; les quatre stories.
///
/// Les noms portent le rang de l'écran (`onb10-fr-07-exam`) : les planches se montent dans
/// l'ordre du parcours.
@MainActor
final class OnboardingRenderTests: XCTestCase {
    private var savedLocale: String?

    /// Un iPhone 15, et un iPhone SE.
    private let tall: CGFloat = 852
    private let small = CGSize(width: 375, height: 667)

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        savedLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
        OnboardingPreferences.reset()
        FirstLessonIntent.pending = nil
    }

    override func tearDown() {
        if let savedLocale {
            UserDefaults.standard.set(savedLocale, forKey: UiLocale.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UiLocale.storageKey)
        }
        OnboardingPreferences.reset()
        FirstLessonIntent.pending = nil
        super.tearDown()
    }

    private func use(_ locale: UiLocale) {
        UserDefaults.standard.set(locale.rawValue, forKey: UiLocale.storageKey)
    }

    // MARK: - Les élèves

    /// Un élève arrivé au bout des questions.
    private func student(
        name: String,
        region: String,
        track trackID: String,
        year yearID: String? = nil,
        subjects: [String],
        worries: [StudyWorry] = [.forgetting, .examStress, .homework],
        goal: LearningGoal = .dreamSchool,
        current: Int = 12,
        target: Int = 16,
        topic: String
    ) -> OnboardingModel {
        let model = OnboardingModel()
        model.displayName = name
        if let country = WorldCountries.country(code: region) {
            model.select(worldCountry: country)
        }
        if let track = model.tracks.first(where: { $0.id == trackID }) {
            model.track = track
            model.year = track.years.first { $0.id == yearID } ?? track.years.last
        }
        if let first = model.examChoices.first {
            model.choose(exam: first)
        }
        model.subjects = Set(subjects)
        for worry in worries {
            model.toggle(worry: worry)
        }
        model.goals = [goal]
        model.currentScore = current
        model.targetScore = target
        model.dailyMinutes = 15
        model.studyHour = 18
        model.firstLessonChoice = .topic
        model.firstLessonTopic = topic
        return model
    }

    private func lina() -> OnboardingModel {
        student(name: "Lina", region: "FR", track: "fr.lyceeGeneral", year: "fr.terminale",
                subjects: ["Mathématiques", "Philosophie", "Physique-Chimie"], topic: "La guerre froide")
    }

    /// Le même élève, avant d'avoir répondu : pour les écrans tels qu'on les découvre.
    private func newcomer(name: String = "Lina", region: String = "FR") -> OnboardingModel {
        let model = OnboardingModel()
        model.displayName = name
        if let country = WorldCountries.country(code: region) {
            model.select(worldCountry: country)
        }
        if let track = model.tracks.first(where: { $0.tier == .upperSecondary }) {
            model.track = track
            model.year = track.years.last
        }
        return model
    }

    // MARK: - Poser une page

    private func render<V: View>(
        _ name: String,
        _ step: OnboardingStep,
        _ model: OnboardingModel,
        rtl: Bool = false,
        @ViewBuilder _ content: () -> V
    ) throws {
        model.place(on: step)
        try RenderGallery.render(
            name, height: tall,
            OnboardingRenderPage(step: step, model: model, rtl: rtl, content: content)
        )
    }

    /// La même page en très grand texte, sur un iPhone SE : rien ne doit se couper.
    private func renderSmall<V: View>(
        _ name: String,
        _ step: OnboardingStep,
        _ model: OnboardingModel,
        @ViewBuilder _ content: () -> V
    ) throws {
        model.place(on: step)
        try RenderGallery.render(
            name, width: small.width, height: small.height,
            OnboardingRenderPage(step: step, model: model, xxl: true, safeTop: 20, safeBottom: 0, content: content)
        )
    }

    private func story(_ page: OnboardingStory) -> some View {
        let auth = AuthController()
        return StoriesStepView(previewPage: page)
            .environment(auth)
            .environment(CloudSync(auth: auth))
    }

    // MARK: - Le parcours entier, pour un élève

    /// Tous les écrans, dans l'ordre du parcours, pour un élève qui a répondu.
    private func renderFlow(_ prefix: String, _ model: OnboardingModel, rtl: Bool = false) throws {
        for page in OnboardingStory.allCases {
            try render("\(prefix)-00-story\(page.index)", .hookLogo, model, rtl: rtl) { story(page) }
        }
        try render("\(prefix)-01-welcome", .welcome, model, rtl: rtl) { WelcomeStepView() }
        try render("\(prefix)-02-name", .name, model, rtl: rtl) { NameStepView() }
        try render("\(prefix)-03-country", .country, model, rtl: rtl) { CountryStepView() }
        try render("\(prefix)-04-schooltype", .schoolType, model, rtl: rtl) { SchoolTypeStepView() }
        try render("\(prefix)-05-year", .year, model, rtl: rtl) { SchoolYearStepView() }
        try render("\(prefix)-06-exam", .exam, model, rtl: rtl) { ExamStepView() }
        try render("\(prefix)-07-subjects", .subjects, model, rtl: rtl) { SubjectsStepView() }
        try render("\(prefix)-08-goal", .goal, model, rtl: rtl) { GoalStepView() }
        try render("\(prefix)-09-worries", .worries, model, rtl: rtl) { WorriesStepView() }
        try render("\(prefix)-10-solutions", .solutionMap, model, rtl: rtl) { SolutionMapStepView() }
        try render("\(prefix)-11-current", .currentAverage, model, rtl: rtl) { CurrentAverageStepView() }
        try render("\(prefix)-12-target", .targetAverage, model, rtl: rtl) { TargetAverageStepView() }
        try render("\(prefix)-13-projection", .startingPoint, model, rtl: rtl) { StartingPointStepView() }
        try render("\(prefix)-14-time", .dailyTime, model, rtl: rtl) { DailyTimeStepView() }
        try render("\(prefix)-15-card", .sampleCard, model, rtl: rtl) { SampleCardStepView(previewAnswer: 0) }
        try render("\(prefix)-16-reminder", .notifications, model, rtl: rtl) { NotificationsStepView() }
        try render("\(prefix)-17-lesson", .firstLesson, model, rtl: rtl) { FirstLessonStepView() }
        try render("\(prefix)-18-building", .planBuilding, model, rtl: rtl) { PlanBuildingStepView(previewProgress: 0.62) }
        try render("\(prefix)-19-plan", .profileSummary, model, rtl: rtl) { ProfileSummaryStepView() }
        try render("\(prefix)-20-trial", .freeTrialIntro, model, rtl: rtl) { FreeTrialIntroStepView() }
        try render("\(prefix)-21-promise", .trialOffer, model, rtl: rtl) { TrialOfferStepView(previewDenied: false) }
    }

    // MARK: - Français

    /// Chaque écran du parcours, en français, pour une lycéenne de terminale.
    func testFrenchFlow() throws {
        use(.fr)
        try renderFlow("onb10-fr", lina())
    }

    /// Les mêmes écrans avant la réponse, et leurs autres états : la question posée, la
    /// mauvaise réponse, l'import, le rappel refusé, la moyenne passée, la languette du compte.
    func testFrenchStates() throws {
        use(.fr)
        let fresh = newcomer()
        try render("onb10-fr-06-exam-open", .exam, fresh) { ExamStepView() }
        try render("onb10-fr-07-subjects-open", .subjects, fresh) { SubjectsStepView() }
        try render("onb10-fr-08-goal-open", .goal, fresh) { GoalStepView() }
        try render("onb10-fr-09-worries-open", .worries, fresh) { WorriesStepView() }
        try render("onb10-fr-15-card-open", .sampleCard, lina()) { SampleCardStepView() }
        try render("onb10-fr-15-card-wrong", .sampleCard, lina()) { SampleCardStepView(previewAnswer: 1) }
        try render("onb10-fr-17-lesson-open", .firstLesson, fresh) { FirstLessonStepView() }

        let importing = lina()
        importing.firstLessonChoice = .importSource
        try render("onb10-fr-17-lesson-import", .firstLesson, importing) { FirstLessonStepView() }
        try render("onb10-fr-19-plan-import", .profileSummary, importing) { ProfileSummaryStepView() }

        try render("onb10-fr-21-promise-refused", .trialOffer, lina()) { TrialOfferStepView(previewDenied: true) }

        // La moyenne passée : la projection sans chiffres, le plan sans objectif.
        let skipped = lina()
        skipped.currentScore = nil
        skipped.targetScore = nil
        try render("onb10-fr-13-projection-skipped", .startingPoint, skipped) { StartingPointStepView() }
        try render("onb10-fr-19-plan-skipped", .profileSummary, skipped) { ProfileSummaryStepView() }

        // Un contrôle dans deux semaines : la réaction « on s'y met ».
        let test = lina()
        test.choose(exam: .test)
        try render("onb10-fr-06-exam-test", .exam, test) { ExamStepView() }
        try render("onb10-fr-16-reminder-test", .notifications, test) { NotificationsStepView() }

        // La languette du compte, à sa hauteur de languette.
        let auth = AuthController()
        try RenderGallery.render(
            "onb10-fr-19-account", height: 470,
            OnboardingAccountSheet(onFinish: {})
                .environment(auth)
                .environment(\.onboardingStill, true)
        )
    }

    /// Un collégien, une étudiante, un pays qu'on ne décrit pas : ce que le niveau change.
    func testFrenchLevels() throws {
        use(.fr)
        let tom = student(name: "Tom", region: "FR", track: "fr.college", year: "fr.3e",
                          subjects: ["Histoire-Géographie", "Mathématiques"], goal: .grades, topic: "La Révolution française")
        try render("onb10-fr-college-06-exam", .exam, tom) { ExamStepView() }
        try render("onb10-fr-college-08-goal", .goal, tom) { GoalStepView() }
        // Le champ vide montre l'exemple de son niveau.
        tom.firstLessonTopic = ""
        try render("onb10-fr-college-17-lesson-open", .firstLesson, tom) { FirstLessonStepView() }

        let ines = student(name: "Inès", region: "FR", track: "fr.universite", year: "fr.l1",
                           subjects: ["Mathématiques"], goal: .passYear, topic: "Les matrices")
        try render("onb10-fr-fac-05-year", .year, ines) { SchoolYearStepView() }
        try render("onb10-fr-fac-06-exam", .exam, ines) { ExamStepView() }
        try render("onb10-fr-fac-08-goal", .goal, ines) { GoalStepView() }
        try render("onb10-fr-fac-19-plan", .profileSummary, ines) { ProfileSummaryStepView() }

        let elsewhere = OnboardingModel()
        elsewhere.displayName = "Aiko"
        if let japan = WorldCountries.country(code: "JP") {
            elsewhere.select(worldCountry: japan)
        }
        try render("onb10-fr-other-03-country", .country, elsewhere) { CountryStepView() }
        try render("onb10-fr-other-04-level", .level, elsewhere) { LevelStepView() }
    }

    // MARK: - Allemand, anglais, arabe

    func testGermanFlow() throws {
        use(.de)
        let mia = student(name: "Mia", region: "DE", track: "de.gymnasium", year: "de.klasse12",
                          subjects: ["Mathematik", "Deutsch", "Englisch", "Biologie"], topic: "Der Kalte Krieg")
        try renderFlow("onb10-de", mia)
    }

    func testAmericanScreens() throws {
        use(.en)
        let sam = student(name: "Sam", region: "US", track: "us.high", year: "us.hs12",
                          subjects: ["Chemistry", "US History", "English"], current: 14, target: 17, topic: "The Cold War")
        try render("onb10-us-00-story4", .hookLogo, sam) { story(.plan) }
        try render("onb10-us-06-exam", .exam, sam) { ExamStepView() }
        try render("onb10-us-12-target", .targetAverage, sam) { TargetAverageStepView() }
        try render("onb10-us-13-projection", .startingPoint, sam) { StartingPointStepView() }
        try render("onb10-us-19-plan", .profileSummary, sam) { ProfileSummaryStepView() }
    }

    func testArabicFlow() throws {
        use(.ar)
        let noura = student(name: "نورة", region: "SA", track: "sa.thanawi", year: "sa.t3",
                            subjects: ["الرياضيات", "الفيزياء", "الكيمياء"], topic: "الحرب الباردة")
        try renderFlow("onb10-ar", noura, rtl: true)
    }

    // MARK: - Très grand texte, petit téléphone

    /// Les écrans denses, en très grand texte sur un iPhone SE, en français et en allemand.
    func testDenseScreensOnASmallPhoneWithLargeText() throws {
        use(.fr)
        let fr = lina()
        try renderSmall("onb10-se-fr-00-story3", .hookLogo, fr) { story(.scan) }
        try renderSmall("onb10-se-fr-06-exam", .exam, fr) { ExamStepView() }
        try renderSmall("onb10-se-fr-09-worries", .worries, fr) { WorriesStepView() }
        try renderSmall("onb10-se-fr-10-solutions", .solutionMap, fr) { SolutionMapStepView() }
        try renderSmall("onb10-se-fr-12-target", .targetAverage, fr) { TargetAverageStepView() }
        try renderSmall("onb10-se-fr-13-projection", .startingPoint, fr) { StartingPointStepView() }
        try renderSmall("onb10-se-fr-15-card", .sampleCard, fr) { SampleCardStepView(previewAnswer: 0) }
        try renderSmall("onb10-se-fr-16-reminder", .notifications, fr) { NotificationsStepView() }
        try renderSmall("onb10-se-fr-17-lesson", .firstLesson, fr) { FirstLessonStepView() }
        try renderSmall("onb10-se-fr-18-building", .planBuilding, fr) { PlanBuildingStepView(previewProgress: 0.62) }
        try renderSmall("onb10-se-fr-19-plan", .profileSummary, fr) { ProfileSummaryStepView() }

        use(.de)
        let de = student(name: "Mia", region: "DE", track: "de.gymnasium", year: "de.klasse12",
                         subjects: ["Mathematik", "Deutsch", "Englisch", "Biologie"], topic: "Der Kalte Krieg")
        try renderSmall("onb10-se-de-00-story1", .hookLogo, de) { story(.lesson) }
        try renderSmall("onb10-se-de-07-subjects", .subjects, de) { SubjectsStepView() }
        try renderSmall("onb10-se-de-10-solutions", .solutionMap, de) { SolutionMapStepView() }
        try renderSmall("onb10-se-de-16-reminder", .notifications, de) { NotificationsStepView() }
        try renderSmall("onb10-se-de-21-promise", .trialOffer, de) { TrialOfferStepView(previewDenied: false) }
    }
}
