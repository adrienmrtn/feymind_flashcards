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

/// **Le parcours d'accueil du lot 15 (rendus `onb15-…`), écran par écran, dans l'ordre, sur un vrai iPhone** :
/// chaque écran dans une fenêtre aux marges de l'iPhone 15 Pro (59/34) et de l'iPhone SE
/// (20/0), encoche et barre d'accueil dessinées (`RenderGallery.renderDevice`). Le français en
/// entier sur les deux iPhone ; l'anglais en entier sur le 15 Pro ; l'arabe et le japonais
/// sur les écrans qui portent le plus de texte ; le très grand texte sur un iPhone SE. Les
/// démonstrations sont rendues jouées ; quelques-unes aussi avant.
@MainActor
final class OnboardingLot14RenderTests: XCTestCase {
    private var savedLocale: String?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        // Chaque méthode rend une vingtaine d'écrans : sous le plafond de la CI (180 s).
        executionTimeAllowance = 170
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
        model.dailyMinutes = 45
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

    private func emma() -> OnboardingModel {
        student(name: "Emma", region: "US", track: "us.high", year: "us.hs12",
                subjects: ["Calculus", "US History", "Chemistry", "English"], hardest: "Calculus", topic: "The Cold War")
    }

    private func noura() -> OnboardingModel {
        student(name: "نورة", region: "SA", track: "sa.thanawi", year: "sa.t3",
                subjects: ["الرياضيات", "الفيزياء", "الكيمياء"], hardest: "الرياضيات", topic: "الحرب الباردة")
    }

    // MARK: - Poser une page

    /// La vue d'étape jouée, pour une démonstration ; `nil` : l'écran tel que le parcours le
    /// pose (`OnboardingStepScreen`).
    private func played(_ step: OnboardingStep) -> AnyView? {
        switch step {
        case .origin: AnyView(OriginStepView(previewTidy: true))
        case .lessonDemo: AnyView(LessonDemoStepView(previewPlayed: true))
        case .scanDemo: AnyView(ScanDemoStepView(previewStage: 3))
        case .planDemo: AnyView(PlanDemoStepView(previewDay: 1))
        case .focusDemo: AnyView(FocusDemoStepView(previewDone: true))
        case .commitment: AnyView(CommitmentStepView(previewCommitted: true))
        case .planBuilding: AnyView(PlanBuildingStepView(previewProgress: 0.62))
        case .trialOffer: AnyView(TrialOfferStepView(previewPermission: .ask, now: Self.now))
        default: nil
        }
    }

    /// Pose l'écran : la vue donnée (elle reçoit la place de la barre du haut), sinon l'écran
    /// du parcours, joué quand c'est une démonstration.
    private func render(
        _ name: String,
        _ step: OnboardingStep,
        _ model: OnboardingModel,
        devices: [RenderDevice] = [.iPhone15Pro, .iPhoneSE],
        rtl: Bool = false,
        xxl: Bool = false,
        view: AnyView? = nil,
        playsDemo: Bool = true
    ) throws {
        model.place(on: step)
        let custom = view ?? (playsDemo ? played(step) : nil)
        let page: AnyView = if let custom {
            AnyView(OnboardingLivePage(step: step, model: model) { custom })
        } else {
            AnyView(OnboardingLivePage(step: step, model: model))
        }
        try RenderGallery.renderDevice(
            name,
            devices: devices,
            page
                .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
                .environment(\.dynamicTypeSize, xxl ? .accessibility2 : .large)
        )
    }

    /// **Le 12 novembre 2026, dix heures** : l'instant des rendus du paywall.
    private static let now: Date = {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10)) ?? Date()
    }()

    private func id(_ step: OnboardingStep) -> String {
        String(format: "%02d-%@", step.rawValue, step.analyticsName)
    }

    /// Les écrans que cet élève voit, dans l'ordre, sans le paywall (rendu à part).
    private func seen(by model: OnboardingModel) -> [OnboardingStep] {
        OnboardingStep.allCases.filter { !model.isSkipped($0) && $0 != .paywall }
    }

    // MARK: - Le parcours entier

    /// **Le parcours français, dans l'ordre**, sur les deux iPhone, chapitre par chapitre (une
    /// méthode tient sous le plafond de temps de la CI).
    private func french(chapters: ClosedRange<Int>) throws {
        let model = lina()
        for step in seen(by: model) where chapters.contains(step.chapter) {
            try render("onb15-fr-\(id(step))", step, model)
        }
    }

    func testFrenchChaptersOneAndTwo() throws { try french(chapters: 0 ... 1) }
    func testFrenchChapterThree() throws { try french(chapters: 2 ... 2) }
    func testFrenchChaptersFourAndFive() throws { try french(chapters: 3 ... 4) }
    func testFrenchChaptersSixAndSeven() throws { try french(chapters: 5 ... 6) }

    /// **Le parcours anglais, dans l'ordre**, sur le 15 Pro.
    private func english(chapters: ClosedRange<Int>) throws {
        use(.en)
        let model = emma()
        for step in seen(by: model) where chapters.contains(step.chapter) {
            try render("onb15-en-\(id(step))", step, model, devices: [.iPhone15Pro])
        }
    }

    func testEnglishChaptersOneToThree() throws { try english(chapters: 0 ... 2) }
    func testEnglishChaptersFourToSeven() throws { try english(chapters: 3 ... 6) }

    /// **Avant d'être jouées** : les démonstrations, le curseur, le maintien en cours.
    func testBeforeAndDuring() throws {
        let model = lina()
        let pro = [RenderDevice.iPhone15Pro]
        for step in [OnboardingStep.origin, .lessonDemo, .scanDemo, .commitment] {
            try render("onb15-fr-\(id(step))-before", step, model, devices: pro, playsDemo: false)
        }
        // Lot 15 : le bouton à maintenir, doigt posé à 62 %, puis lâché trop tôt.
        try render("onb15-fr-\(id(.commitment))-holding", .commitment, model, view: AnyView(CommitmentStepView(previewHold: 0.62)))
        try render("onb15-fr-\(id(.commitment))-early", .commitment, model, devices: pro, view: AnyView(CommitmentStepView(previewEarly: true)))
        // Le scanner à chaque niveau : l'étape 2, puis le résultat au collège et après le bac.
        try render("onb15-fr-\(id(.scanDemo))-step2", .scanDemo, model, devices: pro, view: AnyView(ScanDemoStepView(previewStage: 2)))
        try render("onb15-fr-\(id(.scanDemo))-college", .scanDemo, model, view: AnyView(ScanDemoStepView(previewStage: 3, previewExercise: .pythagoras)))
        try render("onb15-fr-\(id(.scanDemo))-sup", .scanDemo, model, devices: pro, view: AnyView(ScanDemoStepView(previewStage: 3, previewExercise: .integral)))
        let short = lina()
        short.dailyMinutes = 10
        try render("onb15-fr-\(id(.dailyTime))-10", .dailyTime, short, devices: pro)
        let long = lina()
        long.dailyMinutes = 120
        try render("onb15-fr-\(id(.dailyTime))-120", .dailyTime, long, devices: pro)
    }

    // MARK: - Les écritures

    /// **L'arabe** (droite à gauche) et **le japonais** (sans la police condensée) sur les écrans
    /// qui portent le plus de texte.
    private static let scriptSteps: [OnboardingStep] = [
        .welcome, .studyIntro, .helpIntro, .origin, .lessonDemo, .scanDemo, .notJustChat, .research,
        .currentAverage, .dailyTime, .organizeIntro, .commitment, .firstLesson,
        .storyCreate, .storyPath, .storyPractice, .storyAsk, .storyClose, .freeTrialIntro, .trialOffer,
    ]

    func testArabic() throws {
        use(.ar)
        let arabic = noura()
        for step in Self.scriptSteps {
            try render("onb15-ar-\(id(step))", step, arabic, devices: [.iPhone15Pro], rtl: true)
        }
    }

    func testJapanese() throws {
        use(.ja)
        let japanese = lina()
        japanese.displayName = "ユイ"
        for step in Self.scriptSteps {
            try render("onb15-ja-\(id(step))", step, japanese, devices: [.iPhone15Pro])
        }
    }

    /// **Très grand texte, sur le plus petit iPhone** : rien ne se coupe, le contenu défile.
    func testLargeTextOnSmallPhone() throws {
        let model = lina()
        for step in [OnboardingStep.helpIntro, .solutionMap, .notJustChat, .research, .scanDemo, .currentAverage, .storyPath, .storyAsk, .commitment, .trialOffer] {
            try render("onb15-xxl-\(id(step))", step, model, devices: [.iPhoneSE], xxl: true)
        }
    }
}
