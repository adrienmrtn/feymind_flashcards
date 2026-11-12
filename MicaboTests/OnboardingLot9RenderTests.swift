import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus du lot 9 (`onb9-*`)** : chaque écran remis dans le parcours — l'objectif n°1,
/// le point de départ, l'annonce de la démonstration, les quatre pages de Mika revenues, ce que
/// ça change concrètement, l'essai offert — en français de jour et de nuit, en allemand, en
/// arabe ; l'objectif pour un collégien, un étudiant et un lycéen américain ; le plus grand
/// texte sur un iPhone SE ; et la section Test des réglages.
@MainActor
final class OnboardingLot9RenderTests: XCTestCase {
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
        goal: LearningGoal? = nil
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
        if let goal { model.goals = [goal] }
        model.currentScore = 12
        model.targetScore = 16
        model.dailyMinutes = 15
        model.studyHour = 18
        OnboardingPreferences.displayName = name
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

    /// Les écrans remis, pour un élève, dans une langue.
    private func renderAll(_ prefix: String, _ model: OnboardingModel, rtl: Bool = false, night: Bool = false) throws {
        try RenderGallery.render("\(prefix)-goal", height: 852, night: night,
                                 page(.goal, model, rtl: rtl, reaction: model.mainGoal != nil) { GoalStepView() })
        try RenderGallery.render("\(prefix)-start", height: 852, night: night,
                                 page(.startingPoint, model, rtl: rtl) { StartingPointStepView() })
        try RenderGallery.render("\(prefix)-features", height: 852, night: night,
                                 page(.featuresIntro, model, rtl: rtl) { FeaturesIntroStepView() })
        for mika in [MikaPage.mission, .design, .solution, .relief] {
            try RenderGallery.render("\(prefix)-mika-\(mika.rawValue)", height: 852, night: night,
                                     page(mika.step, model, rtl: rtl) { MikaStepView(page: mika) })
        }
        try RenderGallery.render("\(prefix)-proof", height: 852, night: night,
                                 page(.socialProof, model, rtl: rtl) { SocialProofStepView() })
        try RenderGallery.render("\(prefix)-freetrial", height: 852, night: night,
                                 page(.freeTrialIntro, model, rtl: rtl) { FreeTrialIntroStepView() })
    }

    // MARK: - Français, lycée, jour et nuit

    func testFrenchHighSchool() throws {
        use(.fr)
        let lina = student(name: "Lina", country: .fr, track: "fr.lyceeGeneral",
                           subjects: ["Mathématiques", "Philosophie", "Physique-Chimie", "SVT"], goal: .dreamSchool)
        try renderAll("onb9-fr", lina, night: true)

        // Avant la réponse : le rond attend.
        let noGoal = student(name: "Lina", country: .fr, track: "fr.lyceeGeneral", subjects: ["SVT"])
        try RenderGallery.render("onb9-fr-goal-open", height: 852, page(.goal, noGoal) { GoalStepView() })

        // Le plus grand texte, sur un iPhone SE.
        try RenderGallery.render("onb9-fr-goal-xxl-se", width: 375, height: 667,
                                 page(.goal, lina, reaction: true, xxl: true) { GoalStepView() })
        try RenderGallery.render("onb9-fr-proof-xxl-se", width: 375, height: 667,
                                 page(.socialProof, lina, xxl: true) { SocialProofStepView() })
        try RenderGallery.render("onb9-fr-start-se", width: 375, height: 667,
                                 page(.startingPoint, lina) { StartingPointStepView() })
        try RenderGallery.render("onb9-fr-mika-design-se", width: 375, height: 667,
                                 page(.mikaDesign, lina) { MikaStepView(page: .design) })
    }

    // MARK: - Collège, université, États-Unis

    func testGoalsByLevel() throws {
        use(.fr)
        let tom = student(name: "Tom", country: .fr, track: "fr.college", subjects: ["Histoire-Géographie"], goal: .grades)
        try RenderGallery.render("onb9-fr-college-goal", height: 852, page(.goal, tom, reaction: true) { GoalStepView() })
        try RenderGallery.render("onb9-fr-college-start", height: 852, page(.startingPoint, tom) { StartingPointStepView() })

        let ines = student(name: "Inès", country: .fr, track: "fr.universite", subjects: ["Psychologie"], goal: .passYear)
        try RenderGallery.render("onb9-fr-fac-goal", height: 852, page(.goal, ines, reaction: true) { GoalStepView() })
        try RenderGallery.render("onb9-fr-fac-proof", height: 852, page(.socialProof, ines) { SocialProofStepView() })

        use(.en)
        let maya = student(name: "Maya", country: .us, track: "us.high", yearIndex: 2,
                           subjects: ["Algebra", "Chemistry"], goal: .dreamSchool)
        try RenderGallery.render("onb9-en-goal", height: 852, page(.goal, maya, reaction: true) { GoalStepView() })
        try RenderGallery.render("onb9-en-start", height: 852, page(.startingPoint, maya) { StartingPointStepView() })
    }

    // MARK: - Allemand, Gymnasium

    func testGermanGymnasium() throws {
        use(.de)
        let jonas = student(name: "Jonas", country: .de, track: "de.gymnasium",
                            subjects: ["Mathematik", "Deutsch", "Englisch", "Biologie"], goal: .understand)
        try renderAll("onb9-de", jonas)
    }

    // MARK: - Arabe, de droite à gauche

    func testArabic() throws {
        use(.ar)
        let omar = student(name: "عمر", country: .other, custom: WorldCountry(code: "EG", name: "مصر"),
                           track: "eg.thanawi", subjects: ["الرياضيات", "الفيزياء", "اللغة العربية"], goal: .grades)
        try renderAll("onb9-ar", omar, rtl: true)
    }

    // MARK: - La section Test des réglages

    func testSettingsTestSection() throws {
        for (locale, rtl, night) in [(UiLocale.fr, false, true), (.de, false, false), (.ar, true, false)] {
            use(locale)
            let section = MicaboSettingsSection(
                caption: L10n.t("ios.debug.test", locale: locale),
                rows: SettingsView.paywallTestRows(locale: locale, showPaywall: {}, showDiscount: {}, replayOnboarding: {}),
                footnote: L10n.t("ios.onb9.test.footnote", locale: locale)
            )
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.vertical, MicaboSpacing.lg)
            .frame(maxHeight: .infinity, alignment: .top)
            .micaboScreenBackground()
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
            try RenderGallery.render("onb9-\(locale.rawValue)-settings-test", height: 520, night: night, section)
        }
    }
}
