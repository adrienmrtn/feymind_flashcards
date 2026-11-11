import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus du lot 7 (`onb7-*`)** : chaque écran du parcours que le lot a touché — l'accroche
/// sans « 2x », les trois pages de Mika à la première personne, la question d'essai (avant et
/// après la réponse, juste ou fausse), l'écart des moyennes dans le barème de l'élève, la
/// demande de rappel à l'heure choisie, la révélation du plan et sa courbe, l'essai daté, le
/// paywall sans la ligne de recherche — en français de jour et de nuit, en allemand, en arabe,
/// et pour un élève américain, un collégien et un étudiant.
@MainActor
final class OnboardingLot7RenderTests: XCTestCase {
    private var savedLocale: String?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        savedLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
        OnboardingPreferences.reset()
    }

    override func tearDown() {
        if let savedLocale {
            UserDefaults.standard.set(savedLocale, forKey: UiLocale.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UiLocale.storageKey)
        }
        OnboardingPreferences.reset()
        super.tearDown()
    }

    private func use(_ locale: UiLocale) {
        UserDefaults.standard.set(locale.rawValue, forKey: UiLocale.storageKey)
    }

    // MARK: - Les élèves

    private func student(
        name: String,
        country: SchoolingCountry,
        custom: WorldCountry? = nil,
        track trackID: String,
        yearIndex: Int? = nil,
        subjects: [String],
        current: Int = 12,
        target: Int = 16
    ) -> OnboardingModel {
        let model = OnboardingModel()
        model.displayName = name
        model.select(country: country)
        if let custom { model.customCountry = custom }
        if let track = model.tracks.first(where: { $0.id == trackID }) {
            model.track = track
            model.year = yearIndex.map { track.years[$0] } ?? track.years.last
        }
        if let first = model.examChoices.first {
            model.choose(exam: first)
        }
        model.subjects = Set(subjects)
        model.worries = [.examStress, .forgetting]
        model.currentScore = current
        model.targetScore = target
        model.dailyMinutes = 15
        model.studyHour = 18

        OnboardingPreferences.displayName = name
        OnboardingPreferences.schoolingCountry = country
        OnboardingPreferences.customCountry = custom
        OnboardingPreferences.schoolTrackID = model.track?.id
        OnboardingPreferences.schoolYearID = model.year?.id
        OnboardingPreferences.subjects = subjects.sorted()
        OnboardingPreferences.currentScore = current
        OnboardingPreferences.targetScore = target
        OnboardingPreferences.dailyMinutes = 15
        OnboardingPreferences.examID = model.examChoice?.id
        OnboardingPreferences.examDate = model.examDate
        return model
    }

    /// Une page du parcours, avec sa barre du haut, à la taille d'un iPhone 15.
    private func page<V: View>(
        _ step: OnboardingStep,
        _ model: OnboardingModel,
        rtl: Bool = false,
        reaction: Bool = false,
        xxl: Bool = false,
        @ViewBuilder _ content: () -> V
    ) -> some View {
        ZStack(alignment: .top) {
            content()
                .environment(\.onboardingStep, step)
            OnboardingTopBar(progress: step.progress, showsBack: step.allowsReturn, isVisible: step.showsChrome, onBack: {})
        }
        .environment(model)
        .environment(\.onboardingStill, true)
        .environment(\.mikaStill, true)
        .environment(\.onboardingShowsReaction, reaction)
        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
        .environment(\.dynamicTypeSize, xxl ? .xxxLarge : .large)
    }

    private func paywall(rtl: Bool = false) -> some View {
        PaywallScreen(name: OnboardingPreferences.displayName, isPurchasing: false, onClose: {}, onSubscribe: { _ in }, onRestore: {})
            .environment(\.onboardingStill, true)
            .environment(\.mikaStill, true)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
    }

    /// Le premier écran : il lit le compte et la synchro, comme dans l'app.
    private func hook(_ model: OnboardingModel, rtl: Bool = false) -> some View {
        let auth = AuthController()
        return HookLogoStepView()
            .environment(model)
            .environment(auth)
            .environment(CloudSync(auth: auth))
            .environment(\.onboardingStill, true)
            .environment(\.mikaStill, true)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
    }

    /// Les écrans touchés par le lot, pour un élève, dans une langue.
    private func renderAll(_ prefix: String, _ model: OnboardingModel, rtl: Bool = false, night: Bool = false) throws {
        try RenderGallery.render("\(prefix)-hook", height: 852, night: night, hook(model, rtl: rtl))
        for mika in MikaPage.allCases {
            let step: OnboardingStep = switch mika {
            case .sources: .mikaSources
            case .paths: .mikaPaths
            case .tutor: .mikaTutor
            }
            try RenderGallery.render("\(prefix)-mika-\(mika.rawValue)", height: 852, night: night,
                                     page(step, model, rtl: rtl) { MikaStepView(page: mika) })
        }
        try RenderGallery.render("\(prefix)-card", height: 852, night: night,
                                 page(.sampleCard, model, rtl: rtl) { SampleCardStepView() })
        try RenderGallery.render("\(prefix)-card-right", height: 852, night: night,
                                 page(.sampleCard, model, rtl: rtl, reaction: true) { SampleCardStepView(previewAnswer: 0) })
        try RenderGallery.render("\(prefix)-target", height: 852, night: night,
                                 page(.targetAverage, model, rtl: rtl) { TargetAverageStepView() })
        try RenderGallery.render("\(prefix)-notif", height: 852, night: night,
                                 page(.notifications, model, rtl: rtl) { NotificationsStepView() })
        try RenderGallery.render("\(prefix)-planbuild", height: 852, night: night,
                                 page(.planBuilding, model, rtl: rtl) { PlanBuildingStepView() })
        try RenderGallery.render("\(prefix)-plan", height: 1_100, night: night,
                                 page(.profileSummary, model, rtl: rtl) { ProfileSummaryStepView() })
        try RenderGallery.render("\(prefix)-trial", height: 852, night: night,
                                 page(.trialOffer, model, rtl: rtl) { TrialOfferStepView() })
        try RenderGallery.render("\(prefix)-paywall", height: 1_150, night: night, paywall(rtl: rtl))
    }

    // MARK: - Français, lycée, jour et nuit

    func testFrenchHighSchool() throws {
        use(.fr)
        let lina = student(name: "Lina", country: .fr, track: "fr.lyceeGeneral",
                           subjects: ["Mathématiques", "Philosophie", "Physique-Chimie", "SVT"])
        try renderAll("onb7-fr", lina, night: true)

        // Une mauvaise réponse : la sienne en rouge, la bonne en vert, Mika qui rassure.
        try RenderGallery.render("onb7-fr-card-wrong", height: 852,
                                 page(.sampleCard, lina, reaction: true) { SampleCardStepView(previewAnswer: 1) })
        // Le plus grand texte, sur un iPhone SE.
        try RenderGallery.render("onb7-fr-card-xxl-se", width: 375, height: 667,
                                 page(.sampleCard, lina, reaction: true, xxl: true) { SampleCardStepView(previewAnswer: 0) })
        try RenderGallery.render("onb7-fr-plan-xxl-se", width: 375, height: 1_200,
                                 page(.profileSummary, lina, xxl: true) { ProfileSummaryStepView() })
    }

    // MARK: - Collège, université

    func testFrenchMiddleSchoolAndUniversity() throws {
        use(.fr)
        let tom = student(name: "Tom", country: .fr, track: "fr.college",
                          subjects: ["Histoire-Géographie", "Français"], current: 11, target: 14)
        try RenderGallery.render("onb7-fr-college-card", height: 852,
                                 page(.sampleCard, tom) { SampleCardStepView() })
        try RenderGallery.render("onb7-fr-college-plan", height: 1_100,
                                 page(.profileSummary, tom) { ProfileSummaryStepView() })

        let ines = student(name: "Inès", country: .fr, track: "fr.universite",
                           subjects: ["Psychologie", "Statistiques"], current: 13, target: 15)
        try RenderGallery.render("onb7-fr-fac-card", height: 852,
                                 page(.sampleCard, ines, reaction: true) { SampleCardStepView(previewAnswer: 0) })
        try RenderGallery.render("onb7-fr-fac-plan", height: 1_100,
                                 page(.profileSummary, ines) { ProfileSummaryStepView() })

        // Rien qui corresponde à une question (des langues) : de la culture générale, jamais
        // une matière qu'il n'a pas choisie.
        let lea = student(name: "Léa", country: .fr, track: "fr.lyceeGeneral",
                          subjects: ["Anglais", "Espagnol"])
        try RenderGallery.render("onb7-fr-langues-card", height: 852,
                                 page(.sampleCard, lea) { SampleCardStepView() })
    }

    // MARK: - Allemand, Gymnasium

    func testGermanGymnasium() throws {
        use(.de)
        let jonas = student(name: "Jonas", country: .de, track: "de.gymnasium",
                            subjects: ["Mathematik", "Deutsch", "Englisch", "Biologie"], current: 13, target: 17)
        try renderAll("onb7-de", jonas)
    }

    // MARK: - Anglais, États-Unis

    func testAmericanHighSchool() throws {
        use(.en)
        let maya = student(name: "Maya", country: .us, track: "us.high", yearIndex: 2,
                           subjects: ["Algebra", "Chemistry", "US History", "English"], current: 14, target: 18)
        try RenderGallery.render("onb7-en-target", height: 852,
                                 page(.targetAverage, maya) { TargetAverageStepView() })
        try RenderGallery.render("onb7-en-card", height: 852,
                                 page(.sampleCard, maya, reaction: true) { SampleCardStepView(previewAnswer: 0) })
        try RenderGallery.render("onb7-en-notif", height: 852,
                                 page(.notifications, maya) { NotificationsStepView() })
        try RenderGallery.render("onb7-en-plan", height: 1_100,
                                 page(.profileSummary, maya) { ProfileSummaryStepView() })
        try RenderGallery.render("onb7-en-trial", height: 852,
                                 page(.trialOffer, maya) { TrialOfferStepView() })
    }

    // MARK: - Arabe, de droite à gauche

    func testArabic() throws {
        use(.ar)
        let omar = student(name: "عمر", country: .other, custom: WorldCountry(code: "EG", name: "مصر"),
                           track: "eg.thanawi", subjects: ["الرياضيات", "الفيزياء", "اللغة العربية"])
        try renderAll("onb7-ar", omar, rtl: true)
    }
}
