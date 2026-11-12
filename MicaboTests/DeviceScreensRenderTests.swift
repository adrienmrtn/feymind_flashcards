import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Lot 11 : chaque écran de l'app, sur un vrai iPhone** — l'audit d'alignement.
///
/// Les écrans sont les vrais (`HomeView`, `LessonPathView`, `CalendarView`…), posés sur la base
/// du banc d'essai (`PerfFixture` : 40 leçons, des cartes, des examens, des événements), avec
/// l'environnement de l'app (`PerfEnvironment`), dans une fenêtre aux marges de l'iPhone 15 Pro
/// (59/34) et de l'iPhone SE (20/0) : `RenderGallery.renderDevice`. Les onglets passent par la
/// vraie racine (`RootTabView`) : la barre d'onglets est la vraie, et ce qui passerait dessous
/// se voit. Une feuille est posée plein écran (le haut de sa carte, dans l'app, est un peu plus
/// bas que la marge de l'encoche).
@MainActor
final class DeviceScreensRenderTests: XCTestCase {
    private static var shared: PerfFixture?
    private var fixture: PerfFixture!
    private var env: PerfEnvironment!
    private var savedDefaults: [String: Any]?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        executionTimeAllowance = 170
        if let domain = Bundle.main.bundleIdentifier {
            savedDefaults = UserDefaults.standard.persistentDomain(forName: domain)
        }
        UserDefaults.standard.set(UiLocale.fr.rawValue, forKey: UiLocale.storageKey)
        UserDefaults.standard.set(true, forKey: SampleContentPurge.key)
        UserDefaults.standard.set(true, forKey: SubjectCasePass.key)
        UserDefaults.standard.set(true, forKey: CalendarDefaults.seededKey)
        UserDefaults.standard.set(true, forKey: StudyStreak.Key.adoptedReviews)
        FontLoader.registerFonts()
        if Self.shared == nil { Self.shared = try PerfFixture() }
        fixture = Self.shared
        env = PerfEnvironment()
    }

    override func tearDownWithError() throws {
        if let domain = Bundle.main.bundleIdentifier, RenderGallery.directory != nil {
            UserDefaults.standard.setPersistentDomain(savedDefaults ?? [:], forName: domain)
        }
    }

    private func render<V: View>(_ name: String, _ view: V) throws {
        // Sans `homeStill` : un écran « immobile » pose sa page sans défilement, et ce qui
        // dépasse se centre et passe sous l'encoche — ce n'est pas l'écran de l'app.
        try RenderGallery.renderDevice("dev-\(name)", env.wrap(view, container: fixture.container))
    }

    private func firstLesson() throws -> Course {
        var descriptor = FetchDescriptor<Course>(sortBy: [SortDescriptor(\Course.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try XCTUnwrap(try fixture.context.fetch(descriptor).first)
    }

    // MARK: - Les cinq onglets, dans la vraie racine

    func testTabs() throws {
        for (tab, name) in [(RootTab.today, "home"), (.decks, "lecons"), (.calendar, "calendrier"), (.focus, "focus"), (.profile, "profil")] {
            let router = env.router
            router.selection = tab
            try render("tab-\(name)", RootTabView(router: router))
        }
    }

    // MARK: - La leçon et ses outils

    func testLesson() throws {
        let course = try firstLesson()
        try render("lecon", NavigationStack { LessonPathView(course: course) })
        let session = LessonSession(course: course)
        try render("notes", NotesCircleView(session: session, chapter: course.orderedChapters[0], onDone: {}))
        try render("notes-entieres", LessonNotesReader(session: LessonSession(course: course)))
        try render("quiz", LessonQuizView(session: session, questions: session.fullQuiz(attempt: 1), title: "Quiz", circleID: nil, onClose: {}))
        try render("entrainement", LessonPracticeView(session: LessonSession(course: course), attempt: 1))
        try render("cartes", LessonCardsHub(session: LessonSession(course: course)))
        let run = LessonSession(course: course)
        try render("cartes-serie", LessonCardsRun(session: run, cards: run.studyQueue(), onClose: {}))
        try render("carte-mentale", MindMapView(course: course))
        try render("mika", LessonMikaView(course: course))
        try render("fiche-pdf", SheetExportView(digest: LessonDigest(course: course), tone: course.tone))
        try render("lecon-finie", LessonFinishedView(session: LessonSession(course: course)) { _ in })
    }

    // MARK: - Examens, scanner, tuteur, texte, import

    func testTools() throws {
        try render("examens", NavigationStack { ExamsView() })
        try render("examen-blanc", MockExamFlow(start: MockExamStart(exam: fixture.exams().first), lessons: Array(fixture.lessons().prefix(12))))
        try render("examen-copie", MockExamRunView(paper: fixture.paper(), tone: .blue, onQuit: {}, onSubmit: { _, _ in }))
        try render("scanner", SolverFlowView())
        try render("tuteur", TutorThreadView(subject: .math, onBack: {}, onOpenExercise: { _ in }))
        try render("corriger", WritingCoachView())
        try render("import-cartes", FlashcardImportSheet(step: .paste, onCreated: { _ in }))
        try render("sources", HomeSourcesSheet(isPro: false, freeLessonLeft: true) { _ in })
    }

    // MARK: - Calendrier, événement, concentration, tâches

    func testCalendarAndFocus() throws {
        let today = MicaboCalendar.shared.startOfDay(for: Date())
        try render("calendrier-mois", CalendarMonthSheet(selected: today, dots: { _ in [0, 9] }, onSelect: { _ in }))
        try render("evenement", EventEditSheet(target: .new(day: today), calendars: fixture.calendars(), lessons: Array(fixture.lessons().prefix(12))))
        try render("focus-reglage", FocusSetupSheet(
            initial: FocusPlan(),
            lessons: Array(fixture.lessons().prefix(12)),
            tasks: fixture.tasks().filter { !$0.isDone }.map(\.spec),
            onStart: { _ in }
        ))
        try render("focus-seance", FocusTimerView(plan: FocusPlan()))
        try render("taches", TasksSheet(lessons: Array(fixture.lessons().prefix(12))))
    }

    // MARK: - Profil, réglages, série, ligue, connexion

    func testProfileAndAccount() throws {
        try render("reglages", SettingsView())
        try render("serie", StreakSheet())
        try render("ligue", LeagueSheet())
        try render("serie-fete", StreakCelebrationView {})
        try render("connexion", AuthView())
        try render("amis", NavigationStack { FriendsView(onOpen: { _ in }) })
        try render("ecole", SettingsSchoolSheet())
        try render("matieres", SettingsSubjectsSheet())
        try render("avis", FeedbackView())
    }

    // MARK: - La création d'une leçon, le lien, le carnet du scanner

    func testCreation() throws {
        let composer = LessonComposer()
        composer.draft = "La photosynthèse"
        try render("creation", LessonCreationFlow(composer: composer, onGenerate: { _ in }, onLocked: { _ in }, onCancel: {}))
        try render("lien-web", WebLinkSheet(onDone: { _ in }))
        try render("scanner-carnet", SolverHistoryView(onBack: {}, onOpen: { _ in }))
    }
}
