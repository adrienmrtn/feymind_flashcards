import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Le même langage dans tous les onglets, et Mika hors du fond bleu**
/// (`docs/refonte-knowunity.md` § 9) : les cadres de Mika sur le clair et la nuit, le Profil,
/// la liste des leçons et la Home du nouvel élève en allemand et en arabe. Tout est posé
/// immobile (`homeStill`) et sans défilement.
@MainActor
final class LookRenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        L10n.t(key, locale: .resolved(), vars: vars)
    }

    // MARK: - Mika sur le clair

    /// Les trois moments de Mika : le nid à côté d'une phrase, le buste qui dépasse d'une carte,
    /// le buste assis sur le bord bas d'une carte.
    private func mikaPlaces() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom, spacing: 14) {
                MikaMascot(mood: .happy, size: 96, frame: .circle)
                MikaMascot(mood: .wave, size: 64, frame: .circle)
                MikaMascot(mood: .think, size: 44, frame: .circle)
                MikaMascot(mood: .sleep, size: 30, frame: .circle)
                Spacer(minLength: 0)
            }
            // Sur le papier de la page, sans cadre.
            HStack(alignment: .bottom, spacing: 18) {
                MikaMascot(mood: .idle, size: 110)
                MikaMascot(mood: .wink, size: 80)
                Spacer(minLength: 0)
            }
            .frame(height: 110, alignment: .bottom)
            .clipped()
            DayEmptyState {}
            MicaboStreakCard(days: 12, best: 18, title: t("ios.profile.streakDays", ["count": "12"]), note: t("ios.profile.streakToBeat", ["best": "18", "days": "6"]), mika: .happy)
        }
        .padding(20)
        .environment(\.homeStill, true)
    }

    // MARK: - Le Profil

    private func profile() -> some View {
        VStack(alignment: .leading, spacing: 22) {
            MicaboPageHeading(title: t("lesson.tab.profile"))
            ProfileCard(name: "Marie", identity: "@marie", studies: "Terminale") {}
            MicaboStreakCard(
                days: 12,
                best: 18,
                title: t("ios.profile.streakDays", ["count": "12"]),
                note: t("ios.profile.streakToBeat", ["best": "18", "days": "6"]),
                mika: .happy
            )
            ProUpgradeCard {}
            // Les menus de langue et de thème ne se dessinent pas dans un rendu : leurs rangées.
            ProfileGroup(title: t("lesson.profile.settings")) {
                ProfileRow(icon: .language, title: t("lesson.profile.language"), value: "Français") {}.label
                ProfileRow(icon: .theme, title: t("lesson.profile.theme"), value: t(MicaboAppearance.system.titleKey)) {}.label
                ProfileRow(icon: .rate, title: t("lesson.profile.rate"), showsDivider: false) {}.label
            }
            ProfileSupportGroup()
        }
        .padding(20)
        .environment(\.homeStill, true)
    }

    // MARK: - Les leçons

    private func lessons(_ course: Course, _ old: Course) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MicaboPageHeading(title: t("lesson.tab.lessons"), subtitle: t("lesson.lessons.count", ["count": "5"]))
                .padding(.bottom, 4)
            LessonFolderCard(name: "Bac de maths", count: 4) {}
            LessonCard(course: course, dueCount: 8, examDays: 12) {}
            LessonCard(course: old) {}
            NewLessonRow {}
        }
        .padding(20)
        .environment(\.homeStill, true)
    }

    private func emptyLessons() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MicaboPageHeading(title: t("lesson.tab.lessons"), subtitle: t("lesson.lessons.none"))
            MicaboEmptyState(
                systemImage: "books.vertical",
                title: t("lesson.lessons.emptyTitle"),
                message: t("lesson.lessons.emptyBody"),
                actionTitle: t("lesson.lessons.new"),
                mika: .wave
            ) {}
        }
        .padding(20)
        .environment(\.homeStill, true)
    }

    // MARK: - Les rendus

    /// **La planche du nouveau Mika** : ses douze poses fixes, en entier, sur le papier.
    private func poses() -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
            ForEach(MikaStill.allCases, id: \.self) { still in
                VStack(spacing: 4) {
                    Image(still.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .background {
                            MikaHalo(still: still, side: 84, night: false)
                        }
                    Text(still.rawValue)
                        .font(MicaboFont.ui(12, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
            }
        }
        .padding(20)
    }

    /// Mika qui arrive (fixe : arrivé), et la fête de l'objectif.
    private func journeys() -> some View {
        VStack(spacing: 18) {
            MikaJourney(kind: .enter, height: 120)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            MikaJourney(kind: .walkAcross, height: 120)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            XPGoalCard(showsButton: true)
        }
        .padding(20)
        .environment(\.homeStill, true)
    }

    func testMikaOnLight() throws {
        try RenderGallery.render("look-mika", night: true, mikaPlaces())
        try RenderGallery.render("look-mika-poses", night: true, poses())
        try RenderGallery.render("look-mika-journeys", night: true, journeys())
    }

    func testProfileAndLessons() throws {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "Les fonctions affines", subject: "Mathématiques")
        course.toneRaw = LessonTone.lilac.rawValue
        context.insert(course)
        for index in 0..<3 {
            context.insert(Chapter(position: index, title: "Thème \(index + 1)", course: course))
        }
        course.setLessonPath(LessonPath(
            icon: MicaboIcon.calculator.rawValue,
            intro: LessonPath.Intro(lines: [], minutes: 15),
            takeaways: [],
            groups: [LessonPath.Group(name: "", themes: [0, 1, 2])],
            status: .ready
        ))
        course.iconID = MicaboIcon.calculator.rawValue
        course.updateProgress { $0.done = ["intro", "notes:0"] }
        let old = Course(title: "Ancien cours d'histoire", subject: "Histoire")
        context.insert(old)
        try context.save()

        try RenderGallery.render("look-profile", night: true, profile())
        try RenderGallery.render("look-lessons", night: true, lessons(course, old))
        try RenderGallery.render("look-lessons-empty", night: true, emptyLessons())
    }

    /// La Home du nouvel élève, dans les langues longues et de droite à gauche.
    func testNewcomerHomeInOtherLanguages() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: UiLocale.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) } else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }
        let suite = "micabo.render.look"
        let xpDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        xpDefaults.removePersistentDomain(forName: suite)
        let xp = XPStore(defaults: xpDefaults)

        defaults.set(UiLocale.de.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("look-home-new-de", LookNewcomerHome().environment(xp))
        defaults.set(UiLocale.ar.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("look-home-new-ar", LookNewcomerHome().environment(xp).environment(\.layoutDirection, .rightToLeft))
        try RenderGallery.render("look-profile-ar", profile().environment(\.layoutDirection, .rightToLeft))
    }
}

/// Home d'un élève tout neuf, immobile : la barre a besoin d'un focus, cette vue le porte.
private struct LookNewcomerHome: View {
    @FocusState private var focused: Bool

    var body: some View {
        HomeScreen(
            composer: LessonComposer(),
            focused: $focused,
            isPro: false,
            name: nil,
            hello: HomeGreeting.hello(name: nil, moment: .day),
            greeting: HomeGreeting.lines(name: nil, moment: .day, dueCount: 0),
            day: HomeDay(hasCourses: false, studiedToday: false),
            resume: nil,
            plan: HomePlan(),
            motion: HomeMotion(still: true, reduceMotion: false),
            appeared: true,
            streakPreview: StudyStreak.Status(current: 0, best: 0, studiedToday: false),
            actions: HomeActions()
        )
        .environment(\.homeStill, true)
    }
}
