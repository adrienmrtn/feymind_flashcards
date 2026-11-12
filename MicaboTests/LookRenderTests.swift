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

    /// Les trois formes de Mika : en entier sur le papier, en demi au bas d'une carte, en
    /// avatar.
    private func mikaPlaces() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom, spacing: 18) {
                MikaMascot(mood: .wave, size: 120)
                MikaMascot(mood: .wink, size: 90)
                MikaAvatar(size: 40)
                MikaAvatar(size: 30)
                Spacer(minLength: 0)
            }
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

    /// **La planche de Mika** : l'expression de chaque humeur, en entier, sur le fond de l'app
    /// (le détail est dans `MikaRenderTests`).
    private func poses() -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
            ForEach(MikaMood.allCases) { mood in
                VStack(spacing: 4) {
                    MikaMascot(mood: mood, size: 84, frozenAt: 0)
                    Text(mood.rawValue)
                        .font(MicaboFont.ui(12, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
            }
        }
        .padding(20)
    }

    /// La fête de l'objectif du jour : Mika en entier.
    private func journeys() -> some View {
        VStack(spacing: 18) {
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

/// Home d'un élève tout neuf, immobile (lot 10) : la phrase de Mika, « Créer ma première
/// leçon », les trois sources en puces et la barre de saisie.
private struct LookNewcomerHome: View {
    var body: some View {
        Home10Board(
            board: HomeBoard.resolve(HomeBoardInput()),
            exam: nil,
            xp: 0,
            streak: .empty,
            shortcuts: HomeShortcut.available(isNewcomer: true, hasLesson: false, dueCount: 0),
            dueCount: 0,
            composer: LessonComposer()
        )
    }
}
