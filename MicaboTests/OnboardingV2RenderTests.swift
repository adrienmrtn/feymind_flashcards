import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus du parcours v2** : Mika qui pose les questions, l'examen du pays, la
/// révélation du plan, l'essai et le paywall — en français de jour et de nuit, en allemand,
/// en anglais (États-Unis), en arabe, et une question propre à l'Italie et à l'Espagne.
///
/// Les écrans sont posés immobiles (`onboardingStill`) : ni frappe de la bulle, ni défilement
/// (`ImageRenderer` ne dessine pas l'intérieur d'un `ScrollView`).
@MainActor
final class OnboardingV2RenderTests: XCTestCase {
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

    /// Un élève décrit, de l'accroche à l'examen : pays, filière, année, examen, matières,
    /// moyennes, temps. Les réponses sont aussi écrites dans les préférences, que le paywall
    /// relit.
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
        OnboardingPreferences.subjects = subjects
        OnboardingPreferences.currentScore = current
        OnboardingPreferences.targetScore = target
        OnboardingPreferences.dailyMinutes = 15
        OnboardingPreferences.examID = model.examChoice?.id
        OnboardingPreferences.examDate = model.examDate
        return model
    }

    /// Une page du parcours, avec sa barre du haut, à la taille d'un iPhone 15.
    private func page<V: View>(_ step: OnboardingStep, _ model: OnboardingModel, rtl: Bool = false, reaction: Bool = false, @ViewBuilder _ content: () -> V) -> some View {
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
    }

    private func paywall(rtl: Bool = false) -> some View {
        PaywallScreen(name: OnboardingPreferences.displayName, isPurchasing: false, onClose: {}, onSubscribe: { _ in }, onRestore: {})
            .environment(\.onboardingStill, true)
            .environment(\.mikaStill, true)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
    }

    // MARK: - Français, jour et nuit

    func testFrenchOnboarding() throws {
        use(.fr)
        let lina = student(name: "Lina", country: .fr, track: "fr.lyceeGeneral",
                           subjects: ["Mathématiques", "Philosophie", "Physique-Chimie", "SVT"])

        try RenderGallery.render("onb5-fr-name", height: 852, night: true,
                                 page(.name, lina) { NameStepView() })
        try RenderGallery.render("onb5-fr-welcome", height: 852, night: true,
                                 page(.welcome, lina) { WelcomeStepView() })
        try RenderGallery.render("onb5-fr-country", height: 852, night: true,
                                 page(.country, lina, reaction: true) { CountryStepView() })
        try RenderGallery.render("onb5-fr-year", height: 852,
                                 page(.year, lina) { SchoolYearStepView() })
        try RenderGallery.render("onb5-fr-exam", height: 852, night: true,
                                 page(.exam, lina, reaction: true) { ExamStepView() })
        try RenderGallery.render("onb5-fr-subjects", height: 852,
                                 page(.subjects, lina, reaction: true) { SubjectsStepView() })
        try RenderGallery.render("onb5-fr-worries", height: 852,
                                 page(.worries, lina, reaction: true) { WorriesStepView() })
        try RenderGallery.render("onb5-fr-target", height: 852, night: true,
                                 page(.targetAverage, lina) { TargetAverageStepView() })
        try RenderGallery.render("onb5-fr-proof", height: 1_000,
                                 page(.socialProof, lina) { SocialProofStepView() })
        try RenderGallery.render("onb5-fr-plan", height: 1_120, night: true,
                                 page(.profileSummary, lina) { ProfileSummaryStepView() })
        try RenderGallery.render("onb5-fr-trial", height: 852, night: true,
                                 page(.trialOffer, lina) { TrialOfferStepView() })
        try RenderGallery.render("onb5-fr-paywall", height: 1_250, night: true, paywall())

        // Un collégien : le brevet, et Mika qui le dit.
        let tom = student(name: "Tom", country: .fr, track: "fr.college",
                          subjects: ["Mathématiques", "Français", "Histoire-Géographie"])
        try RenderGallery.render("onb5-fr-exam-brevet", height: 852,
                                 page(.exam, tom, reaction: true) { ExamStepView() })
    }

    // MARK: - Allemand

    func testGermanOnboarding() throws {
        use(.de)
        let jonas = student(name: "Jonas", country: .de, track: "de.gymnasium",
                            subjects: ["Mathematik", "Deutsch", "Englisch", "Biologie"], current: 13, target: 17)
        try RenderGallery.render("onb5-de-exam", height: 852,
                                 page(.exam, jonas, reaction: true) { ExamStepView() })
        try RenderGallery.render("onb5-de-current", height: 852,
                                 page(.currentAverage, jonas) { CurrentAverageStepView() })
        try RenderGallery.render("onb5-de-plan", height: 1_120,
                                 page(.profileSummary, jonas) { ProfileSummaryStepView() })
        try RenderGallery.render("onb5-de-trial", height: 852,
                                 page(.trialOffer, jonas) { TrialOfferStepView() })
        try RenderGallery.render("onb5-de-paywall", height: 1_250, paywall())

        // Une élève de Realschule : 1 est la meilleure note.
        let mia = student(name: "Mia", country: .de, track: "de.realschule",
                          subjects: ["Mathematik", "Deutsch"], current: 13, target: 16)
        try RenderGallery.render("onb5-de-current-realschule", height: 852,
                                 page(.currentAverage, mia) { CurrentAverageStepView() })
    }

    // MARK: - Anglais, États-Unis

    func testAmericanOnboarding() throws {
        use(.en)
        let maya = student(name: "Maya", country: .us, track: "us.high", yearIndex: 2,
                           subjects: ["Algebra", "Chemistry", "US History", "English"], current: 14, target: 18)
        try RenderGallery.render("onb5-en-exam", height: 852,
                                 page(.exam, maya, reaction: true) { ExamStepView() })
        try RenderGallery.render("onb5-en-target", height: 852,
                                 page(.targetAverage, maya) { TargetAverageStepView() })
        try RenderGallery.render("onb5-en-plan", height: 1_120,
                                 page(.profileSummary, maya) { ProfileSummaryStepView() })
        try RenderGallery.render("onb5-en-paywall", height: 1_250, paywall())
    }

    // MARK: - Arabe, de droite à gauche

    func testArabicOnboarding() throws {
        use(.ar)
        let omar = student(name: "عمر", country: .other, custom: WorldCountry(code: "EG", name: "مصر"),
                           track: "eg.thanawi", subjects: ["الرياضيات", "الفيزياء", "اللغة العربية"])
        try RenderGallery.render("onb5-ar-name", height: 852,
                                 page(.name, omar, rtl: true) { NameStepView() })
        try RenderGallery.render("onb5-ar-exam", height: 852,
                                 page(.exam, omar, rtl: true, reaction: true) { ExamStepView() })
        try RenderGallery.render("onb5-ar-plan", height: 1_120,
                                 page(.profileSummary, omar, rtl: true) { ProfileSummaryStepView() })
        try RenderGallery.render("onb5-ar-trial", height: 852,
                                 page(.trialOffer, omar, rtl: true) { TrialOfferStepView() })
        try RenderGallery.render("onb5-ar-paywall", height: 1_250, paywall(rtl: true))
    }

    // MARK: - Italie, Espagne, Autriche, Brésil

    func testCountrySpecificQuestions() throws {
        use(.it)
        let giulia = student(name: "Giulia", country: .it, track: "it.liceo",
                             subjects: ["Matematica", "Latino", "Filosofia"])
        try RenderGallery.render("onb5-it-exam", height: 852,
                                 page(.exam, giulia, reaction: true) { ExamStepView() })
        try RenderGallery.render("onb5-it-year", height: 852,
                                 page(.year, giulia) { SchoolYearStepView() })

        use(.es)
        let lucia = student(name: "Lucía", country: .es, track: "es.bachCiencias",
                            subjects: ["Matemáticas", "Física", "Química"])
        try RenderGallery.render("onb5-es-exam", height: 852,
                                 page(.exam, lucia, reaction: true) { ExamStepView() })
        try RenderGallery.render("onb5-es-subjects", height: 852,
                                 page(.subjects, lucia) { SubjectsStepView() })

        use(.de)
        let lena = student(name: "Lena", country: .other, custom: WorldCountry(code: "AT", name: "Österreich"),
                           track: "at.oberstufe", subjects: ["Mathematik", "Deutsch"])
        try RenderGallery.render("onb5-at-exam", height: 852,
                                 page(.exam, lena, reaction: true) { ExamStepView() })

        use(.ptBR)
        let ana = student(name: "Ana", country: .other, custom: WorldCountry(code: "BR", name: "Brasil"),
                          track: "br.medio", subjects: ["Matemática", "Redação", "Biologia"], current: 13, target: 17)
        try RenderGallery.render("onb5-br-exam", height: 852,
                                 page(.exam, ana, reaction: true) { ExamStepView() })
        try RenderGallery.render("onb5-br-current", height: 852,
                                 page(.currentAverage, ana) { CurrentAverageStepView() })
    }
}
