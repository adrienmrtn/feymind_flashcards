import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus de la finition « entrée, compte et système »** (lot 6, agent C) : les
/// composants partagés côte à côte, la barre d'onglets dans les langues longues, le parcours
/// d'accueil et le paywall en allemand, en arabe et en très grand texte sur un iPhone SE, le
/// Profil d'un élève nouveau et d'un élève actif.
///
/// Les écrans sont posés immobiles (`onboardingStill`, `mikaStill`, `homeStill`) : ni
/// entrée, ni défilement (`ImageRenderer` ne dessine pas l'intérieur d'un `ScrollView`).
@MainActor
final class PolishSystemRenderTests: XCTestCase {
    private var savedLocale: String?

    /// L'iPhone SE : la largeur sur laquelle rien ne doit se couper.
    private let small: CGFloat = 375

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

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        L10n.t(key, locale: .resolved(), vars: vars)
    }

    // MARK: - Les composants

    /// Les boutons, les cartes, les titres de section, les rangées, les pastilles et l'écran
    /// vide : ce qu'on retrouve sur tous les onglets, réuni sur une planche.
    private func components() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            MicaboSectionHeading(title: t("ios.profile.whatYouKnow"), subtitle: t("ios.profile.perDeck")) {
                MicaboSeeAllLink(title: t("ios.profile.seeAll")) {}
            }

            VStack(spacing: 12) {
                Button(t("common.continue")) {}
                    .buttonStyle(MicaboPrimaryButtonStyle())
                Button(t("ios.onb5.trial.noCharge")) {}
                    .buttonStyle(LessonPrimaryButtonStyle())
                Button(t("ios.onb5.trial.cancel")) {}
                    .buttonStyle(MicaboSecondaryButtonStyle())
                HStack(spacing: 12) {
                    Button(t("common.skip")) {}
                        .buttonStyle(MicaboQuietButtonStyle())
                    Button(t("common.continue")) {}
                        .buttonStyle(LessonPrimaryButtonStyle(enabled: false))
                }
            }

            MicaboRowGroup(rows: [
                MicaboRow(tile: MicaboTile(glyph: .emoji("📐")), title: t("ios.onb5.plan.exam"), subtitle: t("ios.onb5.trial.reminderDetail"), accessory: .badge("4", .accent)) {},
                MicaboRow(tile: MicaboTile(glyph: .symbol("bell")), title: t("ios.onb5.trial.reminder", ["n": "2"]), accessory: .value(t("ios.onb5.plan.daily"))) {},
            ], layout: .grouped)

            HStack(spacing: 8) {
                MicaboSelectChip(title: t("ios.onb5.plan.subjects"), isSelected: true) {}
                MicaboFilterChip(title: t("ios.onb5.plan.goal"), isSelected: false) {}
                MicaboCountdownPill(days: 12)
                MicaboStreakPill(days: 7)
            }

            MicaboStreakCard(
                days: 12,
                best: 18,
                title: t("ios.profile.streakDays", ["count": "12"]),
                note: t("ios.profile.streakToBeat", ["best": "18", "days": "6"]),
                mika: .happy
            )

            MicaboEmptyState(
                systemImage: "tray",
                title: t("ios.streak.zeroTitle"),
                message: t("ios.streak.emptyBody"),
                actionTitle: t("common.continue"),
                action: {}
            )
            .micaboCard()
        }
        .padding(MicaboSpacing.screen)
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }

    func testComponents() throws {
        use(.fr)
        try RenderGallery.render("pol-components", night: true, components())
        use(.de)
        try RenderGallery.render("pol-components-de-xl", width: small, components().environment(\.dynamicTypeSize, .xxxLarge))
        use(.ar)
        try RenderGallery.render("pol-components-ar", components().environment(\.layoutDirection, .rightToLeft))
    }

    // MARK: - La barre d'onglets

    private func tabBar() -> some View {
        MicaboTabBar()
            .environment(TabRouter())
            .padding(.vertical, 12)
    }

    func testTabBars() throws {
        for (locale, name) in [(UiLocale.fr, "fr"), (.de, "de"), (.fi, "fi"), (.el, "el"), (.es, "es"), (.cs, "cs")] {
            use(locale)
            try RenderGallery.render("pol-tabbar-\(name)", width: small, night: locale == .fr, tabBar())
        }
        use(.ar)
        try RenderGallery.render("pol-tabbar-ar", width: small, tabBar().environment(\.layoutDirection, .rightToLeft))
        use(.de)
        try RenderGallery.render("pol-tabbar-de-xl", width: small, tabBar().environment(\.dynamicTypeSize, .xxxLarge))
    }

    // MARK: - Le Profil

    /// Le Profil d'un élève actif : sa carte, sa série, l'offre Pro, les réglages et le support.
    private func activeProfile() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            MicaboPageHeading(title: t("lesson.tab.profile"))
            ProfileCard(name: "Marie-Charlotte", identity: "@marie", studies: OnboardingPreferences.educationStage?.localizedTitle ?? "Terminale générale") {}
            MicaboStreakCard(
                days: 12,
                best: 18,
                title: t("ios.profile.streakDays", ["count": "12"]),
                note: t("ios.profile.streakToBeat", ["best": "18", "days": "6"]),
                mika: .happy
            )
            ProUpgradeCard {}
            ProfileGroup(title: t("lesson.profile.settings")) {
                ProfileRow(icon: .language, title: t("lesson.profile.language"), value: UiLocale.resolved().nativeName) {}.label
                ProfileRow(icon: .theme, title: t("lesson.profile.theme"), value: t(MicaboAppearance.system.titleKey)) {}.label
                ProfileRow(icon: .rate, title: t("lesson.profile.rate"), showsDivider: false) {}.label
            }
        }
        .padding(MicaboSpacing.screen)
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }

    /// Un élève qui vient d'arriver : pas encore de série, pas de compte.
    private func newProfile() -> some View {
        VStack(alignment: .leading, spacing: 24) {
            MicaboPageHeading(title: t("lesson.tab.profile"))
            ProfileCard(name: "Lina", identity: t("app.profile.offline"), studies: nil) {}
            ProUpgradeCard {}
            ProfileSupportGroup()
        }
        .padding(MicaboSpacing.screen)
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }

    func testProfile() throws {
        use(.fr)
        try RenderGallery.render("pol-profile", night: true, activeProfile())
        try RenderGallery.render("pol-profile-new", night: true, newProfile())
        use(.de)
        try RenderGallery.render("pol-profile-de-xl", width: small, activeProfile().environment(\.dynamicTypeSize, .xxxLarge))
        use(.ar)
        try RenderGallery.render("pol-profile-ar", activeProfile().environment(\.layoutDirection, .rightToLeft))
    }

    // MARK: - Le parcours d'accueil

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

    /// Une page du parcours, sous sa barre du haut (`OnboardingRenderPage`). `reaction` date du
    /// parcours d'avant : Mika réagit maintenant dès que la réponse est là.
    private func page<V: View>(_ step: OnboardingStep, _ model: OnboardingModel, rtl: Bool = false, reaction: Bool = false, @ViewBuilder _ content: () -> V) -> some View {
        model.place(on: step)
        return OnboardingRenderPage(step: step, model: model, rtl: rtl, safeTop: 0, safeBottom: 0, content: content)
    }

    private func paywall(rtl: Bool = false) -> some View {
        PaywallScreen(name: OnboardingPreferences.displayName, isPurchasing: false, onClose: {}, onSubscribe: { _ in }, onRestore: {})
            .environment(\.onboardingStill, true)
            .environment(\.mikaStill, true)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
    }

    func testFrenchOnboarding() throws {
        use(.fr)
        let lina = student(name: "Lina", country: .fr, track: "fr.lyceeGeneral",
                           subjects: ["Mathématiques", "Philosophie", "Physique-Chimie", "SVT"])
        try RenderGallery.render("pol-onb-fr-name", height: 852, night: true, page(.name, lina) { NameStepView() })
        try RenderGallery.render("pol-onb-fr-exam", height: 852, night: true, page(.exam, lina, reaction: true) { ExamStepView() })
        try RenderGallery.render("pol-onb-fr-trial", height: 852, night: true, page(.trialOffer, lina) { TrialOfferStepView() })
        try RenderGallery.render("pol-onb-fr-paywall", height: 1_250, night: true, paywall())

        // Un lycéen marocain, en français : le bac national.
        let yassine = student(name: "Yassine", country: .ma, track: "ma.lycee",
                              subjects: ["Mathématiques", "Physique-Chimie"])
        try RenderGallery.render("pol-onb-ma-exam", height: 852, page(.exam, yassine, reaction: true) { ExamStepView() })

        // Une étudiante : ses partiels, pas un bac.
        let ines = student(name: "Inès", country: .fr, track: "fr.universite",
                           subjects: ["Droit constitutionnel"])
        try RenderGallery.render("pol-onb-fr-uni-exam", height: 852, page(.exam, ines, reaction: true) { ExamStepView() })
    }

    func testGermanOnboardingOnASmallPhoneWithLargeText() throws {
        use(.de)
        let jonas = student(name: "Jonas", country: .de, track: "de.gymnasium",
                            subjects: ["Mathematik", "Deutsch", "Englisch", "Biologie"], current: 13, target: 17)
        func xl<V: View>(_ view: V) -> some View { view.environment(\.dynamicTypeSize, .xxxLarge) }
        try RenderGallery.render("pol-onb-de-exam-xl", width: small, height: 667, xl(page(.exam, jonas, reaction: true) { ExamStepView() }))
        try RenderGallery.render("pol-onb-de-subjects-xl", width: small, height: 667, xl(page(.subjects, jonas) { SubjectsStepView() }))
        try RenderGallery.render("pol-onb-de-current", width: small, height: 667, page(.currentAverage, jonas) { CurrentAverageStepView() })
        try RenderGallery.render("pol-onb-de-trial-xl", width: small, height: 667, xl(page(.trialOffer, jonas) { TrialOfferStepView() }))
        try RenderGallery.render("pol-onb-de-paywall-xl", width: small, height: 1_900, xl(paywall()))
    }

    func testFinnishAndAmericanOnboarding() throws {
        use(.fi)
        let aino = student(name: "Aino", country: .other, custom: WorldCountry(code: "FI", name: "Suomi"),
                           track: "fi.lukio", subjects: ["Matematiikka", "Fysiikka"])
        try RenderGallery.render("pol-onb-fi-worries", width: small, height: 667, page(.worries, aino, reaction: true) { WorriesStepView() })
        try RenderGallery.render("pol-onb-fi-exam", width: small, height: 667, page(.exam, aino, reaction: true) { ExamStepView() })

        use(.en)
        let maya = student(name: "Maya", country: .us, track: "us.high", yearIndex: 2,
                           subjects: ["Algebra", "Chemistry", "US History", "English"], current: 14, target: 18)
        try RenderGallery.render("pol-onb-us-target", height: 852, page(.targetAverage, maya) { TargetAverageStepView() })
        try RenderGallery.render("pol-onb-us-exam", height: 852, page(.exam, maya, reaction: true) { ExamStepView() })
    }

    func testArabicOnboarding() throws {
        use(.ar)
        let sara = student(name: "سارة", country: .other, custom: WorldCountry(code: "SA", name: "السعودية"),
                           track: "sa.thanawi", subjects: ["الرياضيات", "الفيزياء"])
        try RenderGallery.render("pol-onb-ar-exam", height: 852, page(.exam, sara, rtl: true, reaction: true) { ExamStepView() })
        try RenderGallery.render("pol-onb-ar-current", height: 852, page(.currentAverage, sara, rtl: true) { CurrentAverageStepView() })
        try RenderGallery.render("pol-onb-ar-paywall", height: 1_250, night: true, paywall(rtl: true))
    }
}
