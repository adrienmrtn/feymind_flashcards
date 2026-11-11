import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Lot 7 : une app claire, fraîche, et une icône par matière.** La palette du jour et de la
/// nuit sur les briques de l'app (carte, bloc, pastilles, boutons, état vide, rangée de
/// réglages), et la liste des leçons d'un élève qui a six matières : chacune son icône et sa
/// couleur. En français, allemand, arabe, et en très grand texte sur un iPhone SE.
@MainActor
final class Look7RenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        L10n.t(key, locale: .resolved(), vars: vars)
    }

    private func inLanguage(_ locale: UiLocale, _ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: UiLocale.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) } else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }
        defaults.set(locale.rawValue, forKey: UiLocale.storageKey)
        try body()
    }

    // MARK: - Les données

    /// Six leçons, six matières : le modèle leur a toutes donné le globe, comme sur l'iPhone de
    /// l'élève ; c'est la matière qui doit décider de l'icône et de la couleur.
    private func courses(_ items: [(String, String)]) throws -> (ModelContainer, [Course]) {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        var made: [Course] = []
        for (index, item) in items.enumerated() {
            let course = Course(title: item.0, subject: item.1)
            course.iconID = MicaboIcon.globe.rawValue
            course.toneRaw = LessonTone.allCases[index % LessonTone.allCases.count].rawValue
            context.insert(course)
            for position in 0..<3 {
                context.insert(Chapter(position: position, title: "Thème \(position + 1)", course: course))
            }
            course.setLessonPath(LessonPath(
                icon: MicaboIcon.globe.rawValue,
                intro: LessonPath.Intro(lines: [], minutes: 15),
                takeaways: [],
                groups: [LessonPath.Group(name: "", themes: [0, 1, 2])],
                status: .ready
            ))
            if index % 2 == 0 { course.updateProgress { $0.done = ["intro", "notes:0"] } }
            made.append(course)
        }
        try context.save()
        return (container, made)
    }

    private func lessonList(_ courses: [Course]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MicaboPageHeading(title: t("lesson.tab.lessons"), subtitle: t("lesson.lessons.count", ["count": "\(courses.count)"]))
                .padding(.bottom, 4)
            ForEach(Array(courses.enumerated()), id: \.offset) { index, course in
                LessonCard(course: course, dueCount: index == 0 ? 8 : 0, examDays: index == 0 ? 12 : nil) {}
            }
            NewLessonRow {}
        }
        .padding(20)
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }

    // MARK: - La palette

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(height: 34)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(MicaboColor.hairline, lineWidth: 1))
            Text(name)
                .font(MicaboFont.ui(10, weight: .bold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// Les briques de l'app sur le fond : ce qui donne son air à chaque écran.
    private func palette() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                swatch("canvas", MicaboColor.canvas)
                swatch("surface", MicaboColor.surface)
                swatch("muted", MicaboColor.surfaceMuted)
                swatch("stroke", MicaboColor.stroke)
                swatch("accent", MicaboColor.accent)
                swatch("soft", MicaboColor.accentSoft)
                ForEach(LessonTone.allCases) { tone in
                    self.swatch(tone.rawValue, tone.pale)
                }
                swatch("flame", MicaboColor.flame)
            }
            MicaboSectionHeader(title: t("lesson.tab.lessons"), actionTitle: t("ios.profile.seeAll")) {}
            VStack(alignment: .leading, spacing: 8) {
                Text("La guerre froide")
                    .font(MicaboFont.cardTitle)
                    .foregroundStyle(MicaboColor.ink)
                Text("Bac d'histoire · J-12")
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkSecondary)
                MicaboProgressBar(progress: 0.43)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboCard()
            Button(t("ios.cal.startSession")) {}
                .buttonStyle(MicaboPrimaryButtonStyle())
            ProfileGroup(title: t("lesson.profile.settings")) {
                ProfileRow(icon: .language, title: t("lesson.profile.language"), value: "Français") {}.label
                ProfileRow(icon: .theme, title: t("lesson.profile.theme"), value: t(MicaboAppearance.defaultAppearance.titleKey)) {}.label
                ProfileRow(icon: .rate, title: t("lesson.profile.rate"), showsDivider: false) {}.label
            }
            MicaboEmptyState(systemImage: "tray", title: t("lesson.lessons.emptyTitle"), message: t("lesson.lessons.emptyBody"))
                .micaboCard()
        }
        .padding(20)
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }

    // MARK: - Les rendus

    func testPaletteDayAndNight() throws {
        try inLanguage(.fr) {
            try RenderGallery.render("look7-palette", night: true, palette())
        }
        try inLanguage(.de) {
            try RenderGallery.render("look7-palette-de-xxxl", width: 375, palette().environment(\.dynamicTypeSize, .xxxLarge))
        }
        try inLanguage(.ar) {
            try RenderGallery.render("look7-palette-ar", palette().environment(\.layoutDirection, .rightToLeft))
        }
    }

    func testEachSubjectHasItsIcon() throws {
        try inLanguage(.fr) {
            let (container, list) = try courses([
                ("Les fonctions affines", "Mathématiques"),
                ("La guerre froide", "Histoire-géographie"),
                ("La photosynthèse", "SVT"),
                ("Les ondes", "Physique-chimie"),
                ("Le présent perfect", "Anglais"),
                ("La conscience", "Philosophie"),
            ])
            try RenderGallery.render("look7-lessons", night: true, lessonList(list))
            try RenderGallery.render("look7-lessons-se-xxxl", width: 375, lessonList(Array(list.prefix(3))).environment(\.dynamicTypeSize, .xxxLarge))
            _ = container
        }
        try inLanguage(.de) {
            let (container, list) = try courses([
                ("Lineare Funktionen und ihre Graphen", "Mathematik"),
                ("Der Kalte Krieg", "Geschichte"),
                ("Fotosynthese", "Biologie"),
                ("Present Perfect", "Englisch"),
            ])
            try RenderGallery.render("look7-lessons-de", lessonList(list))
            _ = container
        }
        try inLanguage(.ar) {
            let (container, list) = try courses([
                ("الدوال الخطية", "الرياضيات"),
                ("الحرب الباردة", "التاريخ"),
                ("Les ondes", "Physique"),
            ])
            try RenderGallery.render("look7-lessons-ar", lessonList(list).environment(\.layoutDirection, .rightToLeft))
            _ = container
        }
    }
}
