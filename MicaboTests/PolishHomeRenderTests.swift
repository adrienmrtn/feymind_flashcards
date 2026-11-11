import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Lot 6, agent A : la Home et les onglets du quotidien.**
///
/// D'abord les règles qui se vérifient sans écran (la charte du lot 6) : une seule famille de
/// courbes, aucune boucle, aucun nom d'examen écrit en dur dans les phrases de ces onglets, le
/// rouge réservé au retard, pas d'outil en double sur Home. Puis les rendus : la Home de
/// l'élève actif et du nouvel élève, gratuit et abonné, jour et nuit, en allemand, finnois et
/// arabe, au texte agrandi et sur un iPhone SE ; le calendrier avec du retard ; la
/// Concentration ; la série.
@MainActor
final class PolishHomeTests: XCTestCase {
    // MARK: - Les règles

    /// Les dossiers de ce lot, lus depuis les sources.
    private func sources() throws -> [(String, String)] {
        let features = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo/Features", isDirectory: true)
        var found: [(String, String)] = []
        for folder in ["Home", "Calendar", "Focus", "Streak", "XP"] {
            let url = features.appendingPathComponent(folder, isDirectory: true)
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
                throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
            }
            for name in names where name.hasSuffix(".swift") {
                let text = try String(contentsOf: url.appendingPathComponent(name), encoding: .utf8)
                found.append(("\(folder)/\(name)", text))
            }
        }
        return found
    }

    /// Une seule courbe (`MicaboMotion`), aucune animation qui tourne sans fin.
    func testDailyTabsUseOnlyMicaboMotion() throws {
        let forbidden = [".spring(", ".easeOut(", ".easeIn(", ".easeInOut(", "repeatForever", ".bouncy", ".snappy", "interactiveSpring"]
        var offenders: [String] = []
        for (name, text) in try sources() {
            for line in text.split(separator: "\n") {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), !code.hasPrefix("///") else { continue }
                if let hit = forbidden.first(where: { code.contains($0) }) {
                    offenders.append("\(name) : \(hit)")
                }
            }
        }
        XCTAssertEqual(offenders, [], "courbes hors de MicaboMotion")
    }

    /// Les phrases de Home, du calendrier, de la concentration, de la série et de l'XP ne
    /// nomment aucun examen : le nom vient de l'examen de l'élève, donc de son pays.
    func testNoExamNameIsWrittenInTheDailyTabs() throws {
        let prefixes = ["ios.home", "ios.cal.", "ios.focus.", "ios.streak.", "ios.kx.", "ios.pol.home."]
        let names = try NSRegularExpression(pattern: "\\b(Bac|Abitur|GCSE|A-levels?|Selectividad|EBAU|Maturità|Matura|SAT|ACT|Brevet)\\b")
        var offenders: [String] = []
        for locale in UiLocale.allCases {
            for (key, value) in IosI18nCatalogs.table(for: locale.rawValue) where prefixes.contains(where: key.hasPrefix) {
                let range = NSRange(value.startIndex..., in: value)
                if names.firstMatch(in: value, range: range) != nil {
                    offenders.append("\(locale.rawValue) \(key)")
                }
            }
        }
        XCTAssertEqual(offenders.sorted(), [])
    }

    /// La ligne méta du prochain examen : son nom, le compte à rebours de la langue, la
    /// préparation.
    func testExamMetaLine() {
        let exam = HomeExam(name: "Bac d'histoire", daysLeft: 12, readiness: 64)
        XCTAssertEqual(HomeExamMeta.line(for: exam, locale: .fr), "Bac d'histoire · J-12 · \(L10n.percent(64, locale: .fr))")
        XCTAssertEqual(HomeExamMeta.countdown(daysLeft: 12, locale: .de), "noch 12 Tage")
        XCTAssertEqual(HomeExamMeta.countdown(daysLeft: 12, locale: .en), "12 days left")
        XCTAssertEqual(HomeExamMeta.countdown(daysLeft: 1, locale: .fr), L10n.t("ios.cal.tomorrow", locale: .fr))
        XCTAssertEqual(HomeExamMeta.countdown(daysLeft: 0, locale: .fr), L10n.t("ios.cal.today", locale: .fr))
        let abitur = HomeExam(name: "Abitur Mathe", daysLeft: 30, readiness: nil)
        XCTAssertEqual(HomeExamMeta.line(for: abitur, locale: .de), "Abitur Mathe · noch 30 Tage")
        for locale in UiLocale.allCases {
            let text = HomeExamMeta.countdown(daysLeft: 5, locale: locale)
            XCTAssertTrue(text.contains("5"), "\(locale.rawValue) : \(text)")
            XCTAssertFalse(text.contains("{"), "\(locale.rawValue) : \(text)")
        }
    }

    /// Le rouge ne va qu'à ce qui est en retard : une tâche d'hier, une séance passée. Un cours
    /// passé, une séance menée, un examen, ce qui est fait ne le sont jamais.
    func testOnlyOverdueThingsAreLate() {
        let calendar = MicaboCalendar.shared
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let noon = CalendarTime.date(minute: 12 * 60, on: today)
        let task = AgendaItem(id: "t", kind: .task, title: "DM", day: yesterday, tintIndex: StudyAgenda.taskTint)
        XCTAssertTrue(task.isOverdue(now: noon))
        var done = task
        done.isDone = true
        XCTAssertFalse(done.isOverdue(now: noon))
        let todayTask = AgendaItem(id: "t2", kind: .task, title: "DM", day: today, tintIndex: StudyAgenda.taskTint)
        XCTAssertFalse(todayTask.isOverdue(now: noon))
        let morning = AgendaItem(id: "r", kind: .revision, title: "Révision", day: today, startMinute: 8 * 60, endMinute: 9 * 60, tintIndex: 0)
        XCTAssertTrue(morning.isOverdue(now: noon))
        let evening = AgendaItem(id: "r2", kind: .revision, title: "Révision", day: today, startMinute: 18 * 60, endMinute: 19 * 60, tintIndex: 0)
        XCTAssertFalse(evening.isOverdue(now: noon))
        let lesson = AgendaItem(id: "c", kind: .lesson, title: "Maths", day: yesterday, startMinute: 8 * 60, endMinute: 9 * 60, tintIndex: 9)
        XCTAssertFalse(lesson.isOverdue(now: noon))
        // Le rouge des calendriers n'est plus pris par l'examen ni par les tâches.
        XCTAssertNotEqual(StudyAgenda.examTint, 7)
        XCTAssertNotEqual(StudyAgenda.taskTint, 5)
    }

    /// Pas de doublon sur Home : le minuteur est l'onglet Concentration, la ligue l'éclair de
    /// la rangée du haut. Le quiz éclair n'apparaît qu'avec une leçon.
    func testHomeToolsHaveNoDuplicate() {
        XCTAssertEqual(HomeTool.allCases, [.scan, .quiz])
        XCTAssertEqual(HomeTool.available(hasLesson: false), [.scan])
        XCTAssertEqual(HomeTool.available(hasLesson: true), [.scan, .quiz])
    }

    // MARK: - Les données des rendus

    private struct Fixture {
        let container: ModelContainer
        let course: Course
        let resume: (Course, ResumeTarget)
        let busyXP: XPStore
        let freshXP: XPStore
    }

    private func fixture() throws -> Fixture {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "La photosynthèse", subject: "Biologie")
        course.toneRaw = LessonTone.yellow.rawValue
        context.insert(course)
        for index in 0..<4 {
            context.insert(Chapter(position: index, title: ["La lumière", "La chlorophylle", "Le cycle de Calvin", "Le bilan"][index], course: course))
        }
        course.setLessonPath(LessonPath(
            icon: MicaboIcon.flask.rawValue,
            intro: LessonPath.Intro(lines: [], minutes: 20),
            takeaways: [],
            groups: [LessonPath.Group(name: "", themes: [0, 1]), LessonPath.Group(name: "", themes: [2, 3])],
            status: .ready
        ))
        course.iconID = MicaboIcon.flask.rawValue
        course.updateProgress { progress in
            progress.done = ["intro", "notes:0", "notes:1"]
            progress.addTime(2_700, to: .notes)
        }
        course.lastOpenedAt = Date()
        try context.save()
        let resume = try XCTUnwrap(ResumeTarget.pick(from: [course]))
        let suite = "micabo.render.polish.home"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let busyXP = XPStore(defaults: defaults)
        busyXP.award(points: 30)
        let empty = try XCTUnwrap(UserDefaults(suiteName: suite + ".empty"))
        empty.removePersistentDomain(forName: suite + ".empty")
        return Fixture(container: container, course: course, resume: resume, busyXP: busyXP, freshXP: XPStore(defaults: empty))
    }

    private var today: Date { MicaboCalendar.shared.startOfDay(for: Date()) }

    /// La journée d'un élève de terminale, à 17 h 55 : la séance de 18 h sur la guerre froide,
    /// l'examen blanc conseillé, le DM de maths, une seconde séance ce soir.
    private func agenda(examID: UUID) -> [AgendaItem] {
        [
            AgendaItem(id: "m", kind: .milestone, title: "Bac blanc d'histoire", day: today, tintIndex: StudyAgenda.examTint, examID: examID, milestone: .mock, minutes: 15),
            AgendaItem(id: "t", kind: .task, title: "Rendre le DM de maths", day: today, tintIndex: StudyAgenda.taskTint, taskID: UUID()),
            AgendaItem(id: "r", kind: .revision, title: "La guerre froide", day: today, startMinute: 18 * 60, endMinute: 18 * 60 + 30, tintIndex: CalendarTint.revisionIndex, emoji: "📚", calendarName: "Révisions", examID: examID, eventID: UUID()),
            AgendaItem(id: "r2", kind: .revision, title: "La décolonisation", day: today, startMinute: 20 * 60 + 30, endMinute: 21 * 60, tintIndex: CalendarTint.revisionIndex, emoji: "📚", calendarName: "Révisions", examID: examID, eventID: UUID()),
        ]
    }

    private func lessons(_ fixture: Fixture) -> [HomeLessonCard] {
        [
            HomeLessonCard(id: fixture.course.id, title: "La photosynthèse", icon: .flask, tone: .yellow, percent: fixture.resume.1.percent),
            HomeLessonCard(id: UUID(), title: "La guerre froide", icon: .globe, tone: .pink, percent: 70),
            HomeLessonCard(id: UUID(), title: "Les fonctions affines", icon: .calculator, tone: .blue, percent: 15),
        ]
    }

    /// La Home de l'élève actif : la séance de 18 h avec l'examen, ou, sans séance ni examen,
    /// la leçon en cours.
    private func busyHome(_ fixture: Fixture, isPro: Bool = false, withSession: Bool = true) -> AnyView {
        let examID = UUID()
        let items = agenda(examID: examID)
        let evening = CalendarTime.date(minute: 17 * 60 + 55, on: today)
        let session = withSession ? HomeSession.next(in: items, now: evening, examNames: [examID: "Bac d'histoire"]) : nil
        let plan = withSession
            ? HomePlan(exam: HomeExam(name: "Bac d'histoire", daysLeft: 12, readiness: 64), agenda: HomePlan.upcoming(items, now: evening, excluding: session), lessons: lessons(fixture))
            : HomePlan(exam: nil, agenda: [], lessons: lessons(fixture))
        let day = HomeDay(
            dueCount: 8,
            reviewedToday: 0,
            hasCourses: true,
            lessonTitle: fixture.resume.1.title,
            lessonCircle: fixture.resume.1.circleNumber.map { L10n.t("lesson.path.circleNumber", locale: .resolved(), vars: ["n": String($0)]) },
            lessonAdvancedToday: false,
            studiedToday: true,
            session: session
        )
        return AnyView(PolishHomePreview(
            isPro: isPro,
            name: "Léa",
            moment: withSession ? .evening : .morning,
            day: day,
            resume: fixture.resume,
            plan: plan,
            streak: StudyStreak.Status(current: 12, best: 18, studiedToday: true)
        )
        .environment(fixture.busyXP))
    }

    private func newHome(_ fixture: Fixture, isPro: Bool = false) -> AnyView {
        AnyView(PolishHomePreview(
            isPro: isPro,
            name: nil,
            moment: .day,
            day: HomeDay(hasCourses: false, studiedToday: false),
            resume: nil,
            plan: HomePlan(),
            streak: StudyStreak.Status(current: 0, best: 0, studiedToday: false)
        )
        .environment(fixture.freshXP))
    }

    /// Le premier écran, coupé à la hauteur d'un iPhone.
    private func fold(_ view: AnyView, height: CGFloat = 852) -> some View {
        view
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: height, alignment: .top)
            .clipped()
    }

    /// L'agenda d'hier, avec du retard : la seule ligne rouge, et ce qui est fait.
    private func lateDay() -> some View {
        let yesterday = MicaboCalendar.shared.date(byAdding: .day, value: -1, to: today) ?? today
        let items = [
            AgendaItem(id: "t", kind: .task, title: "Rendre le DM de maths", day: yesterday, tintIndex: StudyAgenda.taskTint, taskID: UUID()),
            AgendaItem(id: "t2", kind: .task, title: "Fiche sur la guerre froide", day: yesterday, tintIndex: StudyAgenda.taskTint, taskID: UUID(), isDone: true),
            AgendaItem(id: "a", kind: .lesson, title: "Mathématiques", day: yesterday, startMinute: 8 * 60, endMinute: 9 * 60 + 30, tintIndex: CalendarTint.classesIndex, emoji: "🏫", calendarName: "Cours", room: "B12"),
            AgendaItem(id: "r", kind: .revision, title: "La guerre froide", day: yesterday, startMinute: 18 * 60, endMinute: 18 * 60 + 30, tintIndex: CalendarTint.revisionIndex, emoji: "📚", calendarName: "Révisions", eventID: UUID()),
        ]
        return DayAgendaSection(day: yesterday, items: items, onTap: { _ in }, onStart: { _ in }, onToggleTask: { _ in }, onAdd: {})
            .padding(20)
            .environment(\.homeStill, true)
    }

    private func withLocale(_ locale: UiLocale, _ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: UiLocale.storageKey)
        defaults.set(locale.rawValue, forKey: UiLocale.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) } else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }
        try body()
    }

    // MARK: - Les rendus

    func testPolishedHomeRenders() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        let fixture = try fixture()
        try withLocale(.fr) {
            try RenderGallery.render("pol-home", night: true, busyHome(fixture))
            try RenderGallery.render("pol-home-top", night: true, fold(busyHome(fixture)))
            try RenderGallery.render("pol-home-pro", fold(busyHome(fixture, isPro: true)))
            try RenderGallery.render("pol-home-lesson", night: true, busyHome(fixture, withSession: false))
            try RenderGallery.render("pol-home-new", night: true, newHome(fixture))
            try RenderGallery.render("pol-home-new-pro", newHome(fixture, isPro: true))
            // Le texte agrandi, sur un grand et un petit écran.
            try RenderGallery.render("pol-home-xl", fold(busyHome(fixture)).environment(\.dynamicTypeSize, .xxxLarge))
            try RenderGallery.render("pol-home-se", width: 375, fold(busyHome(fixture), height: 667))
            try RenderGallery.render("pol-home-se-xl", width: 375, fold(busyHome(fixture), height: 1_000).environment(\.dynamicTypeSize, .xxxLarge))
            try RenderGallery.render("pol-home-new-se-xl", width: 375, newHome(fixture).environment(\.dynamicTypeSize, .xxxLarge))
        }
        try withLocale(.de) {
            try RenderGallery.render("pol-home-de", busyHome(fixture))
            try RenderGallery.render("pol-home-new-de", newHome(fixture))
            try RenderGallery.render("pol-home-se-de", width: 375, fold(busyHome(fixture), height: 900))
        }
        try withLocale(.fi) {
            try RenderGallery.render("pol-home-fi", fold(busyHome(fixture)))
        }
        try withLocale(.en) {
            try RenderGallery.render("pol-home-en", fold(busyHome(fixture)))
        }
        try withLocale(.ar) {
            try RenderGallery.render("pol-home-ar", busyHome(fixture).environment(\.layoutDirection, .rightToLeft))
            try RenderGallery.render("pol-home-new-ar", newHome(fixture).environment(\.layoutDirection, .rightToLeft))
        }
    }

    func testPolishedDailyTabsRenders() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        try withLocale(.fr) {
            try RenderGallery.render("pol-cal-late", night: true, lateDay())
            try RenderGallery.render(
                "pol-streak", height: 852, night: true,
                StreakSheet(onStudy: {}).environment(\.homeStill, true)
            )
        }
        try withLocale(.de) {
            try RenderGallery.render("pol-cal-late-de", lateDay())
        }
        try withLocale(.ar) {
            try RenderGallery.render("pol-cal-late-ar", lateDay().environment(\.layoutDirection, .rightToLeft))
        }
    }
}

/// Home a besoin d'un focus pour sa barre : une vue le porte, le temps du rendu. L'écran est
/// posé immobile (`homeStill`).
private struct PolishHomePreview: View {
    let isPro: Bool
    let name: String?
    var moment: HomeGreeting.Moment = .day
    let day: HomeDay
    let resume: (Course, ResumeTarget)?
    var plan = HomePlan()
    let streak: StudyStreak.Status
    @State private var composer = LessonComposer()
    @FocusState private var focused: Bool

    var body: some View {
        HomeScreen(
            composer: composer,
            focused: $focused,
            isPro: isPro,
            name: name,
            hello: HomeGreeting.hello(name: name, moment: moment),
            greeting: HomeGreeting.lines(name: name, moment: moment, dueCount: day.dueCount),
            day: day,
            resume: resume,
            plan: plan,
            motion: HomeMotion(still: true, reduceMotion: false),
            appeared: true,
            streakPreview: streak,
            actions: HomeActions()
        )
        .environment(\.homeStill, true)
    }
}
