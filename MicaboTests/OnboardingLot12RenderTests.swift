import SwiftUI
import XCTest
@testable import Micabo

/// **Une page du parcours posée comme dans l'app** : le fond qui passe sous les marges, la
/// page de l'étape et la barre du haut fixe, exactement comme `OnboardingFlowView` les empile.
/// Rien n'est immobilisé (`onboardingStill` reste faux) : le gabarit est celui de l'iPhone,
/// avec son défilement. Les animations de l'arrivée sont jouées d'un coup (la courbe tracée,
/// le point posé) : le rendu montre l'état où la page se pose.
struct OnboardingLivePage<Content: View>: View {
    let step: OnboardingStep
    let model: OnboardingModel
    let content: Content
    /// Vrai pour une vue d'étape posée à la main : elle reçoit ici ce que
    /// `OnboardingStepScreen` donne à la sienne (la place de la barre du haut). Faux pour
    /// `OnboardingStepScreen`, qui la prend déjà : la compter deux fois descendait le titre de
    /// 44 pt dans les rendus.
    private let pads: Bool

    init(step: OnboardingStep, model: OnboardingModel, @ViewBuilder content: () -> Content) {
        self.step = step
        self.model = model
        self.content = content()
        self.pads = true
    }

    fileprivate init(step: OnboardingStep, model: OnboardingModel, screen: Content) {
        self.step = step
        self.model = model
        self.content = screen
        self.pads = false
    }

    var body: some View {
        let auth = AuthController()
        ZStack(alignment: .top) {
            V3Color.bg
                .ignoresSafeArea()
            content
                .padding(.top, pads && step.showsChrome ? OnboardingTopBar.height : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .modifier(OnbCompactReader(chrome: step.showsChrome))
                .background(V3Color.bg.ignoresSafeArea())
            OnboardingTopBar(model: model)
        }
        .ignoresSafeArea(.keyboard)
        .environment(model)
        .environment(auth)
        .environment(CloudSync(auth: auth))
        .environment(\.mikaStill, true)
        .environment(\.onbSettled, true)
        .transaction { $0.disablesAnimations = true }
    }
}

/// **Une page du parcours posée immobile**, sans fenêtre (`RenderGallery.render`) : gardée
/// pour les rendus d'autres lots (`PolishSystemRenderTests`).
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

extension OnboardingLivePage where Content == OnboardingStepScreen {
    init(step: OnboardingStep, model: OnboardingModel) {
        self.init(step: step, model: model, screen: OnboardingStepScreen(step: step))
    }
}

/// **Le parcours d'accueil du lot 12, écran par écran, sur un vrai iPhone** : chaque écran dans
/// une fenêtre aux marges de l'iPhone 15 Pro (59/34) et de l'iPhone SE (20/0), encoche et barre
/// d'accueil dessinées (`RenderGallery.renderDevice`), marine et clair. Les démonstrations sont
/// rendues jouées (et, sur 15 Pro, avant d'être jouées). L'allemand et l'arabe sur les écrans
/// qui portent le plus de texte ; le très grand texte sur un iPhone SE.
@MainActor
final class OnboardingLot12RenderTests: XCTestCase {
    private var savedLocale: String?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        savedLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
        use(.fr)
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

    private func student(
        name: String,
        region: String,
        track trackID: String,
        year yearID: String,
        subjects: [String],
        hardest: String?,
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
        model.hardestSubject = hardest
        model.goals = [.dreamSchool]
        for worry in [StudyWorry.forgetting, .examStress, .homework] {
            model.toggle(worry: worry)
        }
        model.weeklyStudy = .oneToThree
        model.studyMethod = .rereading
        model.currentScore = 12
        model.targetScore = 16
        model.dailyMinutes = 15
        model.studyHour = 18
        model.firstLessonChoice = .topic
        model.firstLessonTopic = topic
        return model
    }

    private func lina() -> OnboardingModel {
        student(name: "Lina", region: "FR", track: "fr.lyceeGeneral", year: "fr.terminale",
                subjects: ["Mathématiques", "Philosophie", "Physique-Chimie", "Histoire-Géographie"],
                hardest: "Mathématiques", topic: "La guerre froide")
    }

    private func mia() -> OnboardingModel {
        student(name: "Mia", region: "DE", track: "de.gymnasium", year: "de.klasse12",
                subjects: ["Mathematik", "Deutsch", "Englisch", "Biologie"], hardest: "Mathematik", topic: "Der Kalte Krieg")
    }

    private func noura() -> OnboardingModel {
        student(name: "نورة", region: "SA", track: "sa.thanawi", year: "sa.t3",
                subjects: ["الرياضيات", "الفيزياء", "الكيمياء"], hardest: "الرياضيات", topic: "الحرب الباردة")
    }

    // MARK: - Poser une page

    private func render(
        _ name: String,
        _ step: OnboardingStep,
        _ model: OnboardingModel,
        devices: [RenderDevice] = [.iPhone15Pro, .iPhoneSE],
        rtl: Bool = false
    ) throws {
        model.place(on: step)
        try RenderGallery.renderDevice(
            name,
            devices: devices,
            OnboardingLivePage(step: step, model: model)
                .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
        )
    }

    private func render<V: View>(
        _ name: String,
        _ step: OnboardingStep,
        _ model: OnboardingModel,
        devices: [RenderDevice] = [.iPhone15Pro, .iPhoneSE],
        rtl: Bool = false,
        @ViewBuilder _ page: () -> V
    ) throws {
        model.place(on: step)
        try RenderGallery.renderDevice(
            name,
            devices: devices,
            OnboardingLivePage(step: step, model: model, content: page)
                .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
        )
    }

    private func id(_ step: OnboardingStep) -> String {
        String(format: "%02d-%@", step.rawValue, step.analyticsName)
    }

    // MARK: - Le parcours, acte par acte

    /// Acte 0 et 1 : les stories, Mika qui se présente, puis « toi ».
    func testActOneOnDevice() throws {
        let model = lina()
        for step in [OnboardingStep.hookLogo, .welcome, .country, .schoolType, .year, .exam, .subjects] {
            try render("onb12-\(id(step))", step, model)
        }
        // Le prénom : vide, puis tapé (Mika réagit).
        let fresh = OnboardingModel()
        try render("onb12-\(id(.name))-empty", .name, fresh, devices: [.iPhone15Pro])
        try render("onb12-\(id(.name))", .name, model)
        // L'examen, avant la réponse.
        let before = lina()
        before.examChoice = nil
        try render("onb12-\(id(.exam))-before", .exam, before, devices: [.iPhone15Pro])
    }

    /// Acte 2 : ce qui bloque, puis Mika reformule.
    func testActTwoOnDevice() throws {
        let model = lina()
        for step in [OnboardingStep.hardestSubject, .goal, .worries, .studyHours, .studyMethod, .solutionMap] {
            try render("onb12-\(id(step))", step, model)
        }
    }

    /// Acte 3 : les démonstrations, jouées.
    func testActThreePlayedOnDevice() throws {
        let model = lina()
        try render("onb12-\(id(.lessonDemo))", .lessonDemo, model) { LessonDemoStepView(previewPlayed: true) }
        try render("onb12-\(id(.cardsDemo))", .cardsDemo, model) { CardsDemoStepView(previewFlipped: true, previewKnew: true) }
        try render("onb12-\(id(.scanDemo))", .scanDemo, model) { ScanDemoStepView(previewStage: 3) }
        try render("onb12-\(id(.chatDemo))", .chatDemo, model) { ChatDemoStepView(previewAsked: 0) }
        try render("onb12-\(id(.examDemo))", .examDemo, model) { ExamDemoStepView(previewPlayed: true) }
    }

    /// Acte 3 : les démonstrations, telles qu'on les découvre.
    func testActThreeBeforeOnDevice() throws {
        let model = lina()
        let pro = [RenderDevice.iPhone15Pro]
        try render("onb12-\(id(.lessonDemo))-before", .lessonDemo, model, devices: pro)
        try render("onb12-\(id(.cardsDemo))-before", .cardsDemo, model, devices: pro)
        try render("onb12-\(id(.cardsDemo))-flipped", .cardsDemo, model, devices: pro) { CardsDemoStepView(previewFlipped: true) }
        try render("onb12-\(id(.scanDemo))-before", .scanDemo, model, devices: pro)
        try render("onb12-\(id(.scanDemo))-step", .scanDemo, model, devices: pro) { ScanDemoStepView(previewStage: 1) }
        try render("onb12-\(id(.chatDemo))-before", .chatDemo, model, devices: pro)
        try render("onb12-\(id(.examDemo))-before", .examDemo, model, devices: pro)
    }

    /// Acte 4 et 5 : la vraie question, la projection, l'engagement.
    func testActFourAndFiveOnDevice() throws {
        let model = lina()
        try render("onb12-\(id(.sampleCard))", .sampleCard, model) { SampleCardStepView(previewAnswer: 0) }
        try render("onb12-\(id(.sampleCard))-before", .sampleCard, model, devices: [.iPhone15Pro])
        for step in [OnboardingStep.currentAverage, .targetAverage, .startingPoint, .dailyTime] {
            try render("onb12-\(id(step))", step, model)
        }
        try render("onb12-\(id(.planDemo))", .planDemo, model) { PlanDemoStepView(previewDay: 1) }
        try render("onb12-\(id(.focusDemo))", .focusDemo, model) { FocusDemoStepView(previewDone: true) }
        try render("onb12-\(id(.focusDemo))-before", .focusDemo, model, devices: [.iPhone15Pro])
        try render("onb12-\(id(.notifications))", .notifications, model)
        try render("onb12-\(id(.commitment))-before", .commitment, model)
        try render("onb12-\(id(.commitment))", .commitment, model) { CommitmentStepView(previewCommitted: true) }
    }

    /// Acte 6 et 7 : la première leçon, le plan, puis la montée vers l'offre.
    func testActSixAndSevenOnDevice() throws {
        let model = lina()
        try render("onb12-\(id(.firstLesson))", .firstLesson, model)
        try render("onb12-\(id(.planBuilding))", .planBuilding, model) { PlanBuildingStepView(previewProgress: 0.62) }
        for step in [OnboardingStep.profileSummary, .freeTrialIntro, .trialOffer, .whyNow] {
            try render("onb12-\(id(step))", step, model)
        }
    }

    // MARK: - Les langues

    func testGermanOnDevice() throws {
        use(.de)
        let model = mia()
        let pro = [RenderDevice.iPhone15Pro]
        for step in [OnboardingStep.welcome, .exam, .worries, .solutionMap, .notifications, .profileSummary, .trialOffer, .whyNow] {
            try render("onb12-de-\(id(step))", step, model, devices: pro)
        }
        try render("onb12-de-\(id(.lessonDemo))", .lessonDemo, model, devices: pro) { LessonDemoStepView(previewPlayed: true) }
        try render("onb12-de-\(id(.cardsDemo))", .cardsDemo, model, devices: [.iPhoneSE]) { CardsDemoStepView(previewFlipped: true, previewKnew: false) }
        try render("onb12-de-\(id(.commitment))", .commitment, model, devices: [.iPhoneSE]) { CommitmentStepView(previewCommitted: true) }
    }

    func testArabicOnDevice() throws {
        use(.ar)
        let model = noura()
        let pro = [RenderDevice.iPhone15Pro]
        for step in [OnboardingStep.welcome, .name, .worries, .solutionMap, .startingPoint, .profileSummary, .trialOffer] {
            try render("onb12-ar-\(id(step))", step, model, devices: pro, rtl: true)
        }
        try render("onb12-ar-\(id(.chatDemo))", .chatDemo, model, devices: pro, rtl: true) { ChatDemoStepView(previewAsked: 1) }
        try render("onb12-ar-\(id(.planDemo))", .planDemo, model, devices: pro, rtl: true) { PlanDemoStepView(previewDay: 2) }
        try render("onb12-ar-\(id(.commitment))", .commitment, model, devices: pro, rtl: true) { CommitmentStepView(previewCommitted: true) }
    }

    /// **Très grand texte, sur le plus petit iPhone** : le titre, Mika et les réponses
    /// passent à la ligne et défilent ; rien ne se coupe.
    func testLargeTextOnSmallPhone() throws {
        let model = lina()
        for step in [OnboardingStep.worries, .solutionMap, .commitment] {
            model.place(on: step)
            try RenderGallery.renderDevice(
                "onb12-xxl-\(id(step))",
                devices: [.iPhoneSE],
                OnboardingLivePage(step: step, model: model)
                    .environment(\.dynamicTypeSize, .accessibility2)
            )
        }
        model.place(on: .cardsDemo)
        try RenderGallery.renderDevice(
            "onb12-xxl-\(id(.cardsDemo))",
            devices: [.iPhoneSE],
            OnboardingLivePage(step: .cardsDemo, model: model) { CardsDemoStepView(previewFlipped: true) }
                .environment(\.dynamicTypeSize, .accessibility2)
        )
    }
}
