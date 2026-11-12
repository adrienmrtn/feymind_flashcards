import CoreText
import QuartzCore
import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// **Le banc d'essai de la fluidité** (lot 10, `PERF.md` § 1).
///
/// Chaque écran principal est posé dans une vraie fenêtre, avec les données de l'élève du banc
/// (`PerfFixture`), et l'on mesure ce que le fil principal travaille :
///
/// - `froid` : la première mise en page de l'écran sur une base tout juste rouverte ;
/// - `chaud` : la médiane des suivantes ;
/// - `arrivee` : tout le travail de la première demi-seconde (tâches d'apparition, entrées) ;
/// - `blocage` : le plus long travail d'un seul tenant pendant l'arrivée ;
/// - `repos` : le travail par seconde quand on ne touche à rien ;
/// - `cran` et `cranPire` : le coût d'un cran de défilement ;
/// - `frappe` et `phrasesParFrappe` : le coût d'une frappe dans le premier champ, et le nombre
///   de phrases relues à chaque frappe.
///
/// Les lignes `PERF|…` partent dans le journal et dans `perf.txt` (dossier des rendus). Le
/// banc ne tourne que là où les rendus tournent : sans `MICABO_RENDER_DIR`, chaque test passe.
/// **Les plafonds y sont aussi**, là où l'écran est déjà posé : la première mise en page à chaud
/// d'un écran (large : six fois la mesure du jour), une minuterie qui ne relit pas son écran,
/// une frappe qui ne redessine pas tout, les étapes du lancement. Les garde-fous qui relisent
/// les sources sont dans `PerfGuardTests`.
/// Un compteur que les fermetures d'une pièce d'écran incrémentent.
final class PerfCounter {
    var value = 0
}

@MainActor
final class PerfBenchTests: XCTestCase {
    private static var shared: PerfFixture?

    private var stage: PerfStage!
    private var fixture: PerfFixture!
    private var env: PerfEnvironment!
    private var savedDefaults: [String: Any]?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de banc d'essai") }
        executionTimeAllowance = 150
        // Les réglages de l'app sont rendus tels quels à la fin : les écrans posés ici écrivent
        // comme dans l'app (la série, le parcours, l'offre), et les tests suivants ne doivent
        // rien en voir.
        if let domain = Bundle.main.bundleIdentifier {
            savedDefaults = UserDefaults.standard.persistentDomain(forName: domain)
        }
        seedDefaults()
        FontLoader.registerFonts()
        if Self.shared == nil {
            let build = try PerfReport.once { Self.shared = try PerfFixture() }
            PerfReport.record("donnees", "semis", [("ms", build)], note: "40 leçons, 600 cartes, 30 événements, sur disque")
        }
        fixture = Self.shared
        env = PerfEnvironment()
        stage = PerfStage()
        // Le compte se relit comme au lancement : sans session, il est « déconnecté ».
        let auth = env.auth
        Task { await auth.restore() }
        stage.meter.measure(pump: 0.1)
        PerfProbe.reset()
        PerfProbe.isRecording = true
    }

    override func record(_ issue: XCTIssue) {
        PerfVerdict.failure(in: name, issue)
        super.record(issue)
    }

    override class func tearDown() {
        PerfVerdict.write("PERF|bilan|PerfBenchTests|fini")
        super.tearDown()
    }

    override func tearDownWithError() throws {
        PerfProbe.isRecording = false
        // Les gestes mesurés gagnent de l'XP dans le magasin de l'app : il repart de zéro.
        if RenderGallery.directory != nil { XPStore.shared.reset() }
        stage?.close()
        stage = nil
        if let domain = Bundle.main.bundleIdentifier, RenderGallery.directory != nil {
            UserDefaults.standard.setPersistentDomain(savedDefaults ?? [:], forName: domain)
        }
    }

    /// Une série de quarante-cinq jours, comme un élève régulier.
    private func seedDefaults() {
        let calendar = MicaboCalendar.shared
        let today = calendar.startOfDay(for: Date())
        var days: [String] = []
        for offset in 0..<45 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            days.append(StudyStreak.stamp(day, calendar: calendar))
        }
        UserDefaults.standard.set(days, forKey: StudyStreak.Key.days)
        UserDefaults.standard.set(45, forKey: StudyStreak.Key.best)
        // Les passes d'une fois sont déjà faites, comme chez un élève installé depuis un mois.
        UserDefaults.standard.set(true, forKey: StudyStreak.Key.adoptedReviews)
        UserDefaults.standard.set(true, forKey: SampleContentPurge.key)
        UserDefaults.standard.set(true, forKey: SubjectCasePass.key)
        UserDefaults.standard.set(true, forKey: CalendarDefaults.seededKey)
    }

    // MARK: - La mesure d'un écran

    private struct Options {
        var warm = 3
        var settle: TimeInterval = 0.5
        /// La demi-seconde qui suit l'arrivée : la fin des entrées animées s'y voit.
        var tail: TimeInterval = 0.5
        var idle: TimeInterval = 0.6
        var scrolls = true
        var types = false
        /// **Le plafond de la première mise en page à chaud**, en millisecondes : large, au
        /// moins six fois la mesure du jour où il a été posé. Il n'attrape qu'une régression
        /// grossière ; le simulateur de la CI est trop bruité pour mieux.
        var ceiling: Double?
        /// Vrai quand l'écran ne doit relire aucune phrase au repos : sa minuterie se dessine
        /// seule.
        var quietAtRest = false
        /// Le nombre de phrases qu'une frappe peut faire relire : au-delà, c'est tout l'écran
        /// qui se redessine à chaque lettre.
        var phrasesPerKeystroke: Double?
    }

    /// Mesure un écran : à froid sur une base rouverte, puis à chaud, au repos, en défilant,
    /// et en tapant s'il a un champ.
    private func bench<V: View>(_ name: String, _ options: Options = Options(), section: String = "ecran", _ make: () -> V) throws {
        try fixture.reopen()
        let container = fixture.container
        let lookupsBefore = PerfProbe.count("l10n")
        let cold = stage.mount(settle: options.settle) { env.wrap(make(), container: container) }
        let lookups = PerfProbe.count("l10n") - lookupsBefore
        var values: [(String, Double)] = [
            ("froid", cold.first),
            ("arrivee", cold.settle),
            ("blocage", cold.stall),
            ("phrases", Double(lookups)),
        ]
        if options.tail > 0 {
            values.append(("suite", stage.meter.measure(pump: options.tail).busy))
        }
        if options.idle > 0 {
            let lookupsAtRest = PerfProbe.count("l10n")
            values.append(("repos", stage.idle(seconds: options.idle)))
            let read = PerfProbe.count("l10n") - lookupsAtRest
            values.append(("phrasesAuRepos", Double(read) / options.idle))
            if options.quietAtRest {
                XCTAssertEqual(read, 0, "« \(name) » relit \(read) phrases en \(options.idle) s sans qu'on y touche : une minuterie redessine l'écran")
            }
        }
        if options.scrolls, let scroll = stage.scroll() {
            values.append(("cran", scroll.median))
            values.append(("cranPire", scroll.worst))
            values.append(("defile", Double(scroll.travelled)))
        }
        if options.types, let typing = stage.typeText() {
            values.append(("frappe", typing.median))
            values.append(("frappePire", typing.worst))
            values.append(("frappes", Double(typing.typed)))
            values.append(("phrasesParFrappe", typing.lookups))
            if let limit = options.phrasesPerKeystroke, typing.typed > 0 {
                XCTAssertLessThanOrEqual(typing.lookups, limit, "« \(name) » relit \(typing.lookups) phrases à chaque frappe : le champ fait redessiner tout l'écran")
            }
        }
        stage.clear()
        var warm: [Double] = []
        for _ in 0..<options.warm {
            warm.append(stage.mount(settle: 0.12) { env.wrap(make(), container: container) }.first)
            stage.clear()
        }
        if !warm.isEmpty {
            let median = PerfStage.median(warm)
            values.insert(("chaud", median), at: 1)
            if let ceiling = options.ceiling {
                XCTAssertLessThanOrEqual(median, ceiling, "« \(name) » : première mise en page à chaud en \(Int(median)) ms, plafond \(Int(ceiling)) ms")
            }
        }
        PerfReport.record(section, name, values)
    }

    /// Une pièce d'écran, posée seule : la première mise en page à froid et à chaud.
    private func part<V: View>(_ name: String, _ make: () -> V) throws {
        try bench(name, Options(warm: 3, settle: 0.2, tail: 0, idle: 0, scrolls: false), section: "piece", make)
    }

    private func firstLesson() throws -> Course {
        var descriptor = FetchDescriptor<Course>(sortBy: [SortDescriptor(\Course.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try XCTUnwrap(try fixture.context.fetch(descriptor).first)
    }

    // MARK: - Les cinq onglets

    func testTabs() throws {
        try bench("home", Options(types: true)) { HomeView() }
        try bench("lecons") { CoursesListView() }
        try bench("calendrier", Options(ceiling: 2_400)) { CalendarView() }
        try bench("concentration", Options(ceiling: 600)) { FocusView() }
        try bench("profil", Options(ceiling: 500)) { ProfileView() }
    }

    /// **Changer d'onglet**, dans la vraie racine : la première visite de chaque onglet, puis
    /// le retour sur un onglet déjà ouvert. Et ce que coûte, tous onglets ouverts, une écriture
    /// banale dans la base (rouvrir une leçon écrit `lastOpenedAt`).
    func testTabSwitches() throws {
        try fixture.reopen()
        let container = fixture.container
        let router = env.router
        let mount = stage.mount(settle: 0.6) { env.wrap(RootTabView(router: router), container: container) }
        PerfReport.record("racine", "premiere-image", [("froid", mount.first), ("arrivee", mount.settle), ("blocage", mount.stall)])

        let order: [(RootTab, String)] = [(.decks, "lecons"), (.calendar, "calendrier"), (.focus, "concentration"), (.profile, "profil"), (.today, "home")]
        for (tab, name) in order {
            let lookups = PerfProbe.count("l10n")
            let sample = stage.meter.measure(pump: 0.5) {
                router.selection = tab
                stage.window.layoutIfNeeded()
                CATransaction.flush()
            }
            let read = PerfProbe.count("l10n") - lookups
            PerfReport.record("onglet", "premiere-visite-\(name)", [
                ("travail", sample.busy), ("blocage", sample.longest), ("phrases", Double(read)),
            ])
            // Une page neuve lit ses phrases en se dessinant : aucune phrase lue, c'est que
            // l'onglet n'a pas changé.
            if tab != .today {
                XCTAssertGreaterThan(read, 0, "l'onglet « \(name) » ne s'est pas ouvert : la racine ne suit plus le routeur")
            }
        }
        for (tab, name) in order {
            let lookups = PerfProbe.count("l10n")
            let sample = stage.meter.measure(pump: 0.4) {
                router.selection = tab
                stage.window.layoutIfNeeded()
                CATransaction.flush()
            }
            PerfReport.record("onglet", "retour-\(name)", [
                ("travail", sample.busy), ("blocage", sample.longest), ("phrases", Double(PerfProbe.count("l10n") - lookups)),
            ])
        }

        // Une écriture banale, tous onglets ouverts : ce que paie chaque réponse à un quiz.
        // Mesurée depuis chaque onglet : ce que les onglets cachés relisent s'y voit.
        let course = try firstLesson()
        for (tab, name) in order {
            router.selection = tab
            stage.meter.measure(pump: 0.5)
            var costs: [Double] = []
            var stalls: [Double] = []
            let lookups = PerfProbe.count("l10n")
            for round in 0..<4 {
                let sample = stage.meter.measure(pump: 0.25) {
                    if round % 2 == 0 {
                        course.lastOpenedAt = Date()
                    } else {
                        course.updateProgress { $0.inCircle = Double(round) / 10 }
                    }
                    try? container.mainContext.save()
                }
                costs.append(sample.busy)
                stalls.append(sample.longest)
            }
            PerfReport.record("ecriture", "depuis-\(name)", [
                ("travail", PerfStage.median(costs)), ("blocage", PerfStage.median(stalls)),
                ("phrases", Double(PerfProbe.count("l10n") - lookups) / 4),
            ])
        }
    }

    // MARK: - Dans une leçon

    func testLessonScreens() throws {
        try bench("lecon-ouverte") { NavigationStack { LessonPathView(course: try! firstLesson()) } }
        try bench("notes", Options(ceiling: 300)) {
            let course = try! firstLesson()
            let session = LessonSession(course: course)
            return NotesCircleView(session: session, chapter: course.orderedChapters[0], onDone: {})
        }
        try bench("notes-entieres", Options(ceiling: 1_200)) {
            LessonNotesReader(session: LessonSession(course: try! firstLesson()))
        }
        try bench("quiz", Options(ceiling: 300)) {
            let session = LessonSession(course: try! firstLesson())
            return LessonQuizView(session: session, questions: session.fullQuiz(attempt: 1), title: "Quiz", circleID: nil, onClose: {})
        }
        try bench("entrainement", Options(ceiling: 300)) {
            LessonPracticeView(session: LessonSession(course: try! firstLesson()), attempt: 1)
        }
    }

    func testLessonTools() throws {
        try bench("flashcards", Options(ceiling: 400)) {
            LessonCardsHub(session: LessonSession(course: try! firstLesson()))
        }
        try bench("flashcards-serie", Options(ceiling: 400)) {
            let session = LessonSession(course: try! firstLesson())
            return LessonCardsRun(session: session, cards: session.studyQueue(), onClose: {})
        }
        try bench("carte-mentale", Options(ceiling: 400)) { MindMapView(course: try! firstLesson()) }
        try bench("mika-lecon", Options(types: true, ceiling: 400, phrasesPerKeystroke: 14)) { LessonMikaView(course: try! firstLesson()) }
    }

    // MARK: - Pièce par pièce

    /// **Le calendrier et la concentration, pièce par pièce** : où part le temps de la page.
    func testParts() throws {
        let calendar = MicaboCalendar.shared
        let today = calendar.startOfDay(for: Date())
        let snapshot = StudyPlan.snapshot(in: fixture.context)
        let items = StudyAgenda.items(on: today, in: snapshot)

        // Les semaines : combien de jours demandent leurs points à la pose de la page.
        let asked = PerfCounter()
        try part("calendrier-semaines") {
            WeekPager(weekOffset: .constant(0), selected: today, dots: { day in
                asked.value += 1
                return StudyAgenda.dots(on: day, in: snapshot)
            }, onSelect: { _ in })
        }
        PerfReport.record("piece", "calendrier-semaines-points-demandes", [("parPose", Double(asked.value) / 4)])
        try part("calendrier-semaines-sans-points") {
            WeekPager(weekOffset: .constant(0), selected: today, dots: { _ in [0] }, onSelect: { _ in })
        }
        try part("calendrier-agenda-du-jour") {
            DayAgendaSection(day: today, items: items, onTap: { _ in }, onStart: { _ in }, onToggleTask: { _ in }, onAdd: {})
        }
        try part("calendrier-mois") {
            MonthGrid(month: .constant(today), selected: today, dots: { StudyAgenda.dots(on: $0, in: snapshot) }, onSelect: { _ in })
        }
        let summary = NextExamSummary(
            examID: UUID(),
            name: "Bac blanc d'histoire",
            date: today.addingTimeInterval(12 * 86_400),
            daysLeft: 12,
            lessonTitles: ["La guerre froide", "La décolonisation", "La Ve République", "L'Europe"],
            readiness: 64,
            plannedCount: 8,
            nextSession: "Aujourd'hui, 18:00",
            hasLessons: true
        )
        try part("calendrier-prochain-examen") {
            NextExamCard(summary: summary, onRevise: {}, onMock: {}, onPlan: {}, onPlanMenu: {}, onEdit: {})
        }

        // La concentration : le graphique de la semaine est le seul de l'app.
        let minutes = [20, 45, 0, 30, 60, 15, 25]
        var days: [FocusDayBar] = []
        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset - 6, to: today) ?? today
            days.append(FocusDayBar(day: day, minutes: minutes[offset]))
        }
        try part("concentration-graphique") {
            FocusStatsCard(days: days, goalMinutes: 30, weekMinutes: 195, weekSessions: 8, bestStreak: 18)
        }
        try part("concentration-journee") {
            FocusHeroCard(minutesToday: 25, goalMinutes: 30, streak: 12, streakLit: true, onStart: {})
        }

        // Ce que tous les écrans partagent : Mika, et vingt lignes de texte dans la police de
        // l'app, à côté des mêmes vingt lignes dans la police du système (le témoin).
        try part("mika-120") { MikaMascot(mood: .idle, size: 120) }
        try part("vingt-lignes-police-app") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<20, id: \.self) { row in
                    Text("Ligne \(row) du banc d'essai").font(MicaboFont.ui(17, weight: .bold))
                }
            }
        }
        try part("vingt-lignes-police-systeme") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<20, id: \.self) { row in
                    Text("Ligne \(row) du banc d'essai").font(.system(size: 17, weight: .bold))
                }
            }
        }
        let chapter = try firstLesson().orderedChapters[0]
        PerfReport.record("micro", "NotesPage.pages", [("us", PerfReport.micro(50) { _ = NotesPage.pages(for: chapter, hasQuestion: true) })])
        let context = fixture.context
        PerfReport.record("micro", "StudyPlan.snapshot", [("us", PerfReport.micro(20) { _ = StudyPlan.snapshot(in: context) })])
        // D'où vient le temps de l'agenda : ses lectures, ou les rendez-vous des examens.
        PerfReport.record("micro", "StudyPlan.snapshot-sans-rendez-vous", [("us", PerfReport.micro(20) { _ = StudyPlan.snapshot(in: context, withMilestones: false) })])
        let exams = ExamRepository.all(in: context)
        PerfReport.record("micro", "StudyPlan.milestones", [("us", PerfReport.micro(20) { _ = StudyPlan.milestones(for: exams, in: context) })])
        PerfReport.record("micro", "CourseRepository.allCourses", [("us", PerfReport.micro(20) { _ = CourseRepository.allCourses(in: context) })])
        // Le compte des cartes d'un examen : par la base, et le même nombre que la lecture.
        for exam in exams {
            XCTAssertEqual(
                ExamRepository.cardCount(of: exam, in: context),
                ExamRepository.cards(of: exam, in: context).count,
                "le compte des cartes de « \(exam.name) » par la base ne dit pas ce que dit la lecture"
            )
        }
        if let exam = exams.first {
            PerfReport.record("micro", "ExamRepository.cardCount", [("us", PerfReport.micro(20) { _ = ExamRepository.cardCount(of: exam, in: context) })])
            PerfReport.record("micro", "ExamRepository.cards.count", [("us", PerfReport.micro(20) { _ = ExamRepository.cards(of: exam, in: context).count })])
        }
        PerfReport.record("micro", "fetch-evenements", [("us", PerfReport.micro(20) { _ = try? context.fetch(FetchDescriptor<CalendarEvent>()) })])
    }

    // MARK: - Examens, scanner, tuteur, texte

    func testExamScreens() throws {
        try bench("examens", Options(ceiling: 700)) { NavigationStack { ExamsView() } }
        try bench("examen-blanc-reglage", Options(ceiling: 500)) {
            let lessons = Array(fixture.lessons().prefix(12))
            return MockExamFlow(start: MockExamStart(exam: fixture.exams().first), lessons: lessons)
        }
        // La copie a une minuterie d'une seconde : le repos dit ce qu'elle fait redessiner.
        let paper = fixture.paper()
        try bench("examen-blanc-copie", Options(idle: 3, ceiling: 400, quietAtRest: true)) {
            MockExamRunView(paper: paper, tone: .blue, onQuit: {}, onSubmit: { _, _ in })
        }
    }

    func testToolScreens() throws {
        try bench("scanner", Options(ceiling: 400)) { SolverFlowView() }
        try bench("solution", Options(ceiling: 400)) {
            let exercise = try! XCTUnwrap(try! fixture.context.fetch(FetchDescriptor<SolvedExercise>()).first)
            return SolverSolutionView(session: SolverSession(exercise: exercise, xp: nil), onBack: {}, onAskMika: { _ in })
        }
        try bench("tuteur", Options(types: true, ceiling: 400, phrasesPerKeystroke: 12)) {
            TutorThreadView(subject: .math, onBack: {}, onOpenExercise: { _ in })
        }
        try bench("corriger-un-texte", Options(types: true, ceiling: 400, phrasesPerKeystroke: 16)) { WritingCoachView() }
        try bench("import-cartes", Options(types: true, ceiling: 300)) {
            FlashcardImportSheet(step: .paste, onCreated: { _ in })
        }
    }

    // MARK: - Calendrier, concentration

    func testCalendarAndFocusScreens() throws {
        let today = MicaboCalendar.shared.startOfDay(for: Date())
        try bench("calendrier-mois", Options(ceiling: 500)) {
            CalendarMonthSheet(selected: today, dots: { _ in [0, 9] }, onSelect: { _ in })
        }
        try bench("evenement", Options(types: true, ceiling: 1_500)) {
            EventEditSheet(target: .new(day: today), calendars: fixture.calendars(), lessons: Array(fixture.lessons().prefix(12)))
        }
        try bench("concentration-reglage", Options(ceiling: 500)) {
            FocusSetupSheet(
                initial: FocusPlan(),
                lessons: Array(fixture.lessons().prefix(12)),
                tasks: fixture.tasks().filter { !$0.isDone }.map(\.spec),
                onStart: { _ in }
            )
        }
        // La séance a une horloge : le repos dit ce qu'une seconde fait redessiner.
        try bench("concentration-seance", Options(idle: 3, ceiling: 400)) { FocusTimerView(plan: FocusPlan()) }
        try bench("taches", Options(ceiling: 900)) { TasksSheet(lessons: Array(fixture.lessons().prefix(12))) }
    }

    // MARK: - Profil, réglages, série, ligue

    func testProfileScreens() throws {
        try bench("reglages", Options(types: true, ceiling: 1_300)) { SettingsView() }
        try bench("serie", Options(ceiling: 400)) { StreakSheet() }
        try bench("ligue", Options(ceiling: 500)) { LeagueSheet() }
    }

    // MARK: - Parcours d'accueil, paywall

    func testOnboardingAndPaywall() throws {
        try bench("parcours-accueil", Options(settle: 1.0, idle: 2, scrolls: false)) {
            OnboardingFlowView(library: fixture.context, onFinish: {})
        }
        // Le paywall s'ouvre en feuille : son arrivée compte la présentation et son contenu.
        try bench("paywall", Options(warm: 0, settle: 1.5, idle: 1, scrolls: false)) {
            MicaboColor.canvas.ignoresSafeArea().micaboPaywall(.constant(.upgrade))
        }
    }

    // MARK: - Le lancement

    /// **Ce que le lancement fait sur le fil principal**, étape par étape, avec les données de
    /// l'élève du banc. RevenueCat n'est pas mesuré ici : le configurer depuis un test ouvrirait
    /// une vraie session chez lui.
    func testLaunch() throws {
        // Les polices : huit fichiers à lire. On ne les désenregistre pas (les rendus des autres
        // tests en dépendent) ; lire leurs descripteurs coûte la même analyse de fichier.
        let fontURLs = FontLoader.fileNames.compactMap {
            Bundle.main.url(forResource: $0, withExtension: "ttf") ?? Bundle.main.url(forResource: $0, withExtension: "ttf", subdirectory: "Fonts")
        }
        let fonts = PerfReport.once {
            for url in fontURLs { _ = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) }
        }
        PerfReport.record("lancement", "polices", [("ms", fonts), ("fichiers", Double(fontURLs.count))], note: "lecture des descripteurs, pas l'enregistrement")

        // La base : ouverture d'un fichier existant, trois fois.
        var opens: [Double] = []
        for _ in 0..<3 {
            opens.append(try PerfReport.once { _ = try fixture.reopen() })
        }
        PerfReport.record("lancement", "base-ouverture", [("ms", PerfStage.median(opens)), ("premiere", opens[0])])
        XCTAssertLessThan(PerfStage.median(opens), 500, "ouvrir la base de l'élève du banc prend plus d'une demi-seconde")

        // Ce que le premier écran lit : toutes les leçons, puis leurs cartes.
        try fixture.reopen()
        var courses: [Course] = []
        let fetch = try PerfReport.once {
            courses = try fixture.context.fetch(FetchDescriptor<Course>(sortBy: [SortDescriptor(\Course.createdAt, order: .reverse)]))
        }
        let cards = PerfReport.once {
            var due = 0
            for course in courses { due += course.dueCount }
            XCTAssertGreaterThan(due, 0)
        }
        let cardsAgain = PerfReport.once {
            var due = 0
            for course in courses { due += course.dueCount }
            XCTAssertGreaterThan(due, 0)
        }
        PerfReport.record("lancement", "base-lecture", [("lecons", fetch), ("cartesDues", cards), ("cartesDuesRelues", cardsAgain), ("n", Double(courses.count))])

        // Les services posés dans l'environnement.
        let services = PerfReport.once { _ = PerfEnvironment() }
        PerfReport.record("lancement", "services", [("ms", services)])
        XCTAssertLessThan(services, 300, "les services posés dans l'environnement font un travail lourd à leur création")

        // Les passes d'une fois, déjà faites : ce qu'elles coûtent à chaque lancement suivant.
        let passes = PerfReport.once {
            SampleContentPurge.purgeIfNeeded(in: fixture.context)
            SubjectCasePass.runIfNeeded(in: fixture.context)
        }
        PerfReport.record("lancement", "passes-deja-faites", [("ms", passes)])
        XCTAssertLessThan(passes, 50, "une passe d'une fois relit la base à chaque lancement")

        // Les rappels, reposés après la synchro et en partant.
        let reminders = PerfReport.once { StudyNotifications.refresh(in: fixture.context) }
        PerfReport.record("lancement", "rappels-calendrier", [("ms", reminders)])
        XCTAssertLessThan(reminders, 300, "reposer les rappels du calendrier bloque le fil principal")

        // La première image : la racine, sur une base rouverte.
        try fixture.reopen()
        let container = fixture.container
        let router = TabRouter()
        let root = stage.mount(settle: 0.8) { env.wrap(RootTabView(router: router), container: container) }
        PerfReport.record("lancement", "premiere-image", [("froid", root.first), ("arrivee", root.settle), ("blocage", root.stall)])
    }

    // MARK: - Les appels qui reviennent à chaque `body`

    /// Le coût d'un appel, en microsecondes, pour ce que les `body` appellent sans y penser.
    func testMicro() throws {
        let locale = UiLocale.resolved()
        PerfReport.record("micro", "L10n.t-simple", [("us", PerfReport.micro { _ = L10n.t("lesson.quiz.continue", locale: locale) })])
        PerfReport.record("micro", "L10n.t-variable", [("us", PerfReport.micro { _ = L10n.t("lesson.intro.estimate", locale: locale, vars: ["minutes": "25"]) })])
        PerfReport.record("micro", "L10n.t-pluriel", [("us", PerfReport.micro { _ = L10n.t("ios.ku7.writing.fixes", locale: locale, vars: ["count": "3"]) })])
        PerfReport.record("micro", "loc", [("us", PerfReport.micro { _ = loc("ios.cal.myCalendars") })])
        PerfReport.record("micro", "UiLocale.resolved", [("us", PerfReport.micro { _ = UiLocale.resolved() })])

        // Une table de langue régionale : toutes se construisent au premier accès à l'une d'elles.
        let sample = IosI18nCatalogs.fr
        let table = PerfReport.once {
            for _ in 0..<21 { _ = Dictionary(uniqueKeysWithValues: sample.map { ($0.key, $0.value) }) }
        }
        PerfReport.record("micro", "tables-regionales", [("ms", table), ("entrees", Double(sample.count))], note: "21 tables de la taille de la française, reconstruites")

        PerfReport.record("micro", "MicaboIcon.subjectIcon", [("us", PerfReport.micro { _ = MicaboIcon.subjectIcon("Physique-chimie") })])
        PerfReport.record("micro", "MicaboIcon.guess", [("us", PerfReport.micro { _ = MicaboIcon.guess(subject: nil, title: "La guerre froide et ses crises") })])
        // Un libellé de date : le formateur refait à chaque appel (le chemin d'avant), puis gardé.
        let someDay = Date(timeIntervalSince1970: 1_800_000_000)
        PerfReport.record("micro", "DateFormatter-refait", [("us", PerfReport.micro {
            let formatter = DateFormatter()
            formatter.locale = UiLocale.fr.foundation
            formatter.calendar = MicaboCalendar.shared
            formatter.setLocalizedDateFormatFromTemplate("EEE")
            _ = formatter.string(from: someDay)
        })])
        PerfReport.record("micro", "MicaboCalendar.shortWeekday", [("us", PerfReport.micro { _ = MicaboCalendar.shortWeekday(someDay, locale: .fr) })])
        PerfReport.record("micro", "CalendarTime.label", [("us", PerfReport.micro { _ = CalendarTime.label(minute: 870, locale: .fr) })])
        PerfReport.record("micro", "StudyStreak.status", [("us", PerfReport.micro { _ = StudyStreak.status() })])
        PerfReport.record("micro", "StudyStreak.week", [("us", PerfReport.micro { _ = StudyStreak.week() })])

        let course = try firstLesson()
        let chapter = course.orderedChapters[0]
        PerfReport.record("micro", "Course.tone", [("us", PerfReport.micro { _ = course.tone })])
        PerfReport.record("micro", "Course.icon", [("us", PerfReport.micro { _ = course.icon })])
        PerfReport.record("micro", "Course.progress", [("us", PerfReport.micro { _ = course.progress })])
        PerfReport.record("micro", "Course.lessonPath", [("us", PerfReport.micro { _ = course.lessonPath })])
        PerfReport.record("micro", "Course.pathSteps", [("us", PerfReport.micro(50) { _ = course.pathSteps() })])
        PerfReport.record("micro", "Course.orderedChapters", [("us", PerfReport.micro { _ = course.orderedChapters })])
        PerfReport.record("micro", "Course.dueCount", [("us", PerfReport.micro(50) { _ = course.dueCount })])
        PerfReport.record("micro", "Chapter.notes", [("us", PerfReport.micro(50) { _ = chapter.notes })])
        PerfReport.record("micro", "Chapter.quiz", [("us", PerfReport.micro(50) { _ = chapter.quiz })])
        PerfReport.record("micro", "LessonSession.init", [("us", PerfReport.micro(20) { _ = LessonSession(course: course) })])
        let session = LessonSession(course: course)
        PerfReport.record("micro", "LessonSession.dueCards", [("us", PerfReport.micro(50) { _ = session.dueCards() })])
        PerfReport.record("micro", "LessonDigest.init", [("us", PerfReport.micro(20) { _ = LessonDigest(course: course) })])

        let exercise = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<SolvedExercise>()).first)
        PerfReport.record("micro", "SolvedExercise.solution", [("us", PerfReport.micro(50) { _ = exercise.solution })])

        // Les gestes : ce qu'un appui écrit, sur le fil principal, avant que l'écran ne réponde.
        let context = fixture.context
        let question = try XCTUnwrap(chapter.quiz?.questions.first)
        let rightAnswer = PerfReport.micro(10, rounds: 3) { session.answered(question, right: true, in: context) }
        PerfReport.record("geste", "reponse-juste", [("ms", rightAnswer / 1000)])
        let wrongAnswer = PerfReport.micro(10, rounds: 3) { session.answered(question, right: false, in: context) }
        PerfReport.record("geste", "reponse-fausse", [("ms", wrongAnswer / 1000)])
        let card = try XCTUnwrap(course.cards.first)
        let rating = PerfReport.micro(10, rounds: 3) {
            LessonReview.rate(card, .good)
            course.updatedAt = Date()
            try? context.save()
        }
        PerfReport.record("geste", "note-de-carte", [("ms", rating / 1000)])
        let plainSave = PerfReport.micro(10, rounds: 3) {
            course.lastOpenedAt = Date()
            try? context.save()
        }
        PerfReport.record("geste", "ecriture-seule", [("ms", plainSave / 1000)])
        PerfReport.record("micro", "StudyStreak.record-meme-jour", [("us", PerfReport.micro { StudyStreak.record() })])
        PerfReport.record("micro", "XPStore.award", [("us", PerfReport.micro(50) { env.xp.award(.cardReviewed) })])

        let text = PerfFixture.notes(0).plainText
        PerfReport.record("micro", "KeywordText.attributed", [("us", PerfReport.micro(50) { _ = KeywordText.attributed(text) })])

        // Les couleurs et les polices, lues des centaines de fois par écran.
        PerfReport.record("micro", "MicaboColor.ink", [("us", PerfReport.micro(1_000) { _ = MicaboColor.ink })])
        PerfReport.record("micro", "MicaboFont.ui", [("us", PerfReport.micro(1_000) { _ = MicaboFont.ui(17, weight: .bold) })])
        PerfReport.record("micro", "CalendarTint.color", [("us", PerfReport.micro(1_000) { _ = CalendarTint.at(3).color })])

        // L'agenda : ce que le calendrier recalcule à chaque `body`.
        let calendar = MicaboCalendar.shared
        let today = calendar.startOfDay(for: Date())
        let snapshot = AgendaSnapshot(
            calendars: fixture.calendars().map { AgendaCalendarInfo(id: $0.id, name: $0.name, emoji: $0.emoji, tintIndex: $0.colorIndex, isVisible: $0.isVisible) },
            events: ((try? fixture.context.fetch(FetchDescriptor<CalendarEvent>())) ?? []).map(\.spec),
            exams: fixture.exams().map { AgendaExamInfo(id: $0.id, name: $0.name, date: $0.date, courseIDs: $0.courseIDs) },
            milestones: [],
            tasks: fixture.tasks().map(\.spec),
            focus: []
        )
        PerfReport.record("micro", "StudyAgenda.items", [("us", PerfReport.micro(50) { _ = StudyAgenda.items(on: today, in: snapshot) })])
        PerfReport.record("micro", "StudyAgenda.dots-42-jours", [("us", PerfReport.micro(10) {
            for offset in 0..<42 {
                _ = StudyAgenda.dots(on: calendar.date(byAdding: .day, value: offset, to: today) ?? today, in: snapshot)
            }
        })])
    }
}
