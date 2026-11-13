import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus des supports et des modes de révision** (`docs/supports.md`) : la feuille du
/// « + », le lien web, l'import de flashcards, la rangée des modes dans une leçon, l'écoute,
/// la révision à voix haute, la carte mentale et la fiche PDF. De jour et de nuit en
/// français, puis en allemand et en arabe (de droite à gauche). Les écrans sont posés
/// immobiles (`homeStill`) et sans défilement : `ImageRenderer` ne dessine pas au-delà.
@MainActor
final class SupportsRenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    // MARK: - Les données

    private static let notes = ThemeNotes(
        oneLiner: "Après 1945, les **États-Unis** et l'**URSS** s'opposent sans jamais se battre directement.",
        blocks: [
            .subtitle("Deux visions du monde"),
            .list(["Le capitalisme et la démocratie libérale", "Le communisme et le parti unique"]),
            .definition(term: "Rideau de fer", text: "La frontière qui coupe l'Europe en deux blocs."),
            .dates([NoteBlock.DateItem(date: "1947", text: "Doctrine Truman"), NoteBlock.DateItem(date: "1961", text: "Construction du mur de Berlin")]),
            .callout(kind: .remember, title: "L'équilibre de la terreur", text: "La bombe empêche la guerre directe."),
        ],
        takeaways: ["Deux blocs s'opposent sans guerre directe.", "Berlin est le symbole de la division."]
    )

    private static let digest = LessonDigest(
        title: "La guerre froide",
        subject: "Histoire",
        takeaways: ["Deux blocs, jamais de guerre directe."],
        themes: [
            LessonDigest.Theme(title: "Deux blocs face à face", notes: notes, cards: []),
            LessonDigest.Theme(title: "Berlin, ville coupée", notes: notes, cards: []),
            LessonDigest.Theme(title: "Cuba au bord du gouffre", notes: notes, cards: []),
            LessonDigest.Theme(title: "La détente", notes: notes, cards: []),
        ]
    )

    private func lessonCourse() throws -> (Course, LessonSession, ModelContainer) {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "La guerre froide", subject: "Histoire")
        course.toneRaw = LessonTone.mint.rawValue
        course.iconID = MicaboIcon.globe.rawValue
        context.insert(course)
        for (index, title) in ["Deux blocs face à face", "Berlin, ville coupée", "La détente"].enumerated() {
            let chapter = Chapter(position: index, title: title, course: course)
            chapter.iconID = MicaboIcon.flag.rawValue
            chapter.setNotes(Self.notes)
            context.insert(chapter)
        }
        course.setLessonPath(LessonPath(
            icon: MicaboIcon.globe.rawValue,
            intro: LessonPath.Intro(lines: ["Pourquoi deux blocs"], minutes: 20),
            takeaways: [],
            groups: [LessonPath.Group(name: "", themes: [0, 1, 2])],
            status: .ready
        ))
        course.updateProgress { $0.done = ["intro", "notes:0"] }
        try context.save()
        return (course, LessonSession(course: course), container)
    }

    // MARK: - Les écrans

    private func sources() -> some View {
        HomeSourcesSheet(isPro: false, freeLessonLeft: true) { _ in }
            .environment(\.homeStill, true)
    }

    private func webLink() -> some View {
        WebLinkSheet(link: "https://fr.wikipedia.org/wiki/Guerre_froide") { _ in }
            .frame(height: 400)
    }

    private func flashcards() -> some View {
        let cards = [
            DeckLessonBuilder.Card(front: "Rideau de fer", back: "La frontière qui coupe l'Europe en deux"),
            DeckLessonBuilder.Card(front: "OTAN", back: "L'alliance militaire de l'Ouest, née en 1949"),
            DeckLessonBuilder.Card(front: "Pacte de Varsovie", back: "L'alliance militaire de l'Est, née en 1955"),
            DeckLessonBuilder.Card(front: "Doctrine Truman", back: "Contenir l'expansion du communisme"),
        ] + (1...44).map { DeckLessonBuilder.Card(front: "Terme \($0)", back: "Définition \($0)") }
        return HStack(alignment: .top, spacing: 0) {
            FlashcardImportSheet(step: .choose) { _ in }
                .frame(width: 393, height: 600)
            FlashcardImportSheet(step: .preview(title: "Histoire : la guerre froide", cards: cards, skipped: 2)) { _ in }
                .frame(width: 393, height: 860)
        }
    }

    private func modesRow(course: Course, session: LessonSession) -> some View {
        VStack(spacing: 0) {
            LessonPathHeader(course: course, session: session, exam: nil)
                .padding(.top, 30)
                .padding(.bottom, 26)
            LessonToolGrid(isPro: false) { _ in }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 30)
        }
    }

    private func mindMap() -> some View {
        let root = MindMap.build(Self.digest)
        return MindMapView(root: root, icon: .globe, expanded: [root.children[0].id])
            .environment(\.homeStill, true)
    }

    private func export() -> some View {
        VStack(spacing: 0) {
            RevisionModeHeader(mode: .export, lessonTitle: "La guerre froide") {}
            SheetExportCard(title: "La guerre froide", themes: 4, pages: 3, ready: true, tone: .yellow) {
                Button {} label: {
                    Label(L10n.t("ios.sup.export.share", locale: .resolved()), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(LessonPrimaryButtonStyle())
            }
            .padding(20)
        }
    }

    // MARK: - Les rendus

    private func renderAll(suffix: String, night: Bool, rtl: Bool) throws {
        let (course, session, container) = try lessonCourse()
        _ = container
        func render<V: View>(_ name: String, width: CGFloat = 393, _ view: V) throws {
            let directed = view.environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
            try RenderGallery.render(name + suffix, width: width, night: night, directed)
        }
        try render("sup-sources", sources())
        try render("sup-web", webLink())
        try render("sup-flashcards", width: 786, flashcards())
        try render("sup-modes", modesRow(course: course, session: session))
        try render("sup-mindmap", mindMap())
        try render("sup-export", export())
    }

    func testSupportsScreensInFrench() throws {
        try withLocale(.fr) { try renderAll(suffix: "", night: true, rtl: false) }
    }

    func testSupportsScreensInGerman() throws {
        try withLocale(.de) { try renderAll(suffix: "-de", night: false, rtl: false) }
    }

    func testSupportsScreensInArabic() throws {
        try withLocale(.ar) { try renderAll(suffix: "-ar", night: false, rtl: true) }
    }

    private func withLocale(_ locale: UiLocale, _ body: () throws -> Void) throws {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: UiLocale.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) } else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }
        defaults.set(locale.rawValue, forKey: UiLocale.storageKey)
        try body()
    }
}
