import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Lot 13 : la leçon au centre, sur un vrai iPhone** (marges du 15 Pro et du SE, jour et
/// nuit). La Home vide qui reprend le sujet du parcours d'accueil, la Home d'un élève actif et
/// sa puce « + Nouvelle leçon », des supports lus qui deviennent « Écrire ma leçon », la leçon
/// qui s'écrit, la feuille « Nouvelle leçon », l'onglet Leçons vide ; en allemand et en arabe
/// pour ce qui s'allonge et se retourne.
@MainActor
final class Core13RenderTests: XCTestCase {
    private var retained: [ModelContainer] = []

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
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

    private var exam: HomeExam { HomeExam(name: "Bac", daysLeft: 212, readiness: nil) }
    private var newcomerShortcuts: [HomeShortcut] { HomeShortcut.available(isNewcomer: true, hasLesson: false, dueCount: 0) }
    private var activeShortcuts: [HomeShortcut] { HomeShortcut.available(isNewcomer: false, hasLesson: true, dueCount: 0) }

    private func page(_ input: HomeBoardInput, shortcuts: [HomeShortcut], composer: LessonComposer = LessonComposer()) -> some View {
        RenderTabRoot {
            HomePage(board: HomeBoard.resolve(input), exam: exam, shortcuts: shortcuts, dueCount: 0, composer: composer)
        }
        .environment(\.mikaStill, true)
    }

    // MARK: - La Home

    func testEmptyHomeWithTheOnboardingTopic() throws {
        let input = HomeBoardInput(name: "Lina", firstTopic: "la guerre froide")
        try RenderGallery.renderDevice("core13-home-first", page(input, shortcuts: newcomerShortcuts))
        try inLanguage(.de) {
            try RenderGallery.renderDevice("core13-home-first-de", devices: [.iPhoneSE], page(input, shortcuts: newcomerShortcuts))
        }
        try inLanguage(.ar) {
            try RenderGallery.renderDevice("core13-home-first-ar", devices: [.iPhone15Pro], page(input, shortcuts: newcomerShortcuts))
        }
    }

    func testEmptyHomeWithoutTopic() throws {
        try RenderGallery.renderDevice("core13-home-new", page(HomeBoardInput(name: "Lina"), shortcuts: newcomerShortcuts))
    }

    func testActiveHomeShowsNewLesson() throws {
        let day = HomeDay(hasCourses: true, lessonTitle: "La photosynthèse", lessonStep: 3, lessonStarted: true)
        let input = HomeBoardInput(day: day, name: "Léa", hasLesson: true)
        try RenderGallery.renderDevice("core13-home-active", page(input, shortcuts: activeShortcuts))
        try inLanguage(.de) {
            try RenderGallery.renderDevice("core13-home-active-de", devices: [.iPhoneSE], page(input, shortcuts: activeShortcuts))
        }
    }

    func testSupportsReadBecomeALesson() throws {
        let composer = LessonComposer()
        if let id = composer.begin(.pdf, title: "Chapitre 4 - Les volcans.pdf") {
            composer.finish(id, with: ImportedDocument(text: String(repeating: "Les volcans naissent de la remontée du magma. ", count: 20), pageImages: [], coverImage: nil, pageCount: 4, fileName: "Chapitre 4", source: .pdf, extractionNote: nil))
        }
        let input = HomeBoardInput(day: HomeDay(hasCourses: true), name: "Léa", hasLesson: true, composing: .ready)
        try RenderGallery.renderDevice("core13-home-ready", page(input, shortcuts: activeShortcuts, composer: composer))
    }

    func testTheLessonBeingWritten() throws {
        let input = HomeBoardInput(day: HomeDay(hasCourses: true), name: "Léa", phase: .running, stage: .writing, subject: "La guerre froide")
        try RenderGallery.renderDevice("core13-home-writing", page(input, shortcuts: activeShortcuts))
    }

    // MARK: - La feuille « Nouvelle leçon »

    private func sheet(topic: String = "") -> some View {
        HomeSourcesSheet(isPro: false, freeLessonLeft: true, topic: topic, onTopic: { _ in }) { _ in }
    }

    func testTheNewLessonSheet() throws {
        try RenderGallery.renderDevice("core13-new", sheet())
        try RenderGallery.renderDevice("core13-new-topic", devices: [.iPhone15Pro], sheet(topic: "La guerre froide"))
        try inLanguage(.de) {
            try RenderGallery.renderDevice("core13-new-de", devices: [.iPhoneSE], sheet())
        }
        try inLanguage(.ar) {
            try RenderGallery.renderDevice("core13-new-ar", devices: [.iPhone15Pro], sheet())
        }
    }

    // MARK: - L'onglet Leçons vide

    func testEmptyLessonsTab() throws {
        let container = try ModelContainer(
            for: MicaboApp.schema,
            configurations: ModelConfiguration(schema: MicaboApp.schema, isStoredInMemoryOnly: true)
        )
        retained.append(container)
        let view = RenderTabRoot(selection: .decks) { CoursesListView() }
            .modelContainer(container)
            .environment(\.mikaStill, true)
        try RenderGallery.renderDevice("core13-lessons-empty", view)
    }
}
