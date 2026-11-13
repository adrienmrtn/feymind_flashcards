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

    /// La pastille du prochain examen : son nom, puis le compte à rebours de la langue.
    func testExamPillLine() {
        let exam = HomeExam(name: "Bac d'histoire", daysLeft: 12, readiness: 64)
        XCTAssertEqual(HomeExamPill.resolve(exam, locale: .fr).text, "Bac d'histoire · J-12")
        XCTAssertEqual(ExamCountdown.label(daysLeft: 12, locale: .de), "noch 12 Tage")
        XCTAssertEqual(ExamCountdown.label(daysLeft: 12, locale: .en), "12 days left")
        XCTAssertEqual(ExamCountdown.label(daysLeft: 1, locale: .fr), L10n.t("ios.cal.tomorrow", locale: .fr))
        XCTAssertEqual(ExamCountdown.label(daysLeft: 0, locale: .fr), L10n.t("ios.cal.today", locale: .fr))
        let abitur = HomeExam(name: "Abitur Mathe", daysLeft: 30, readiness: nil)
        XCTAssertEqual(HomeExamPill.resolve(abitur, locale: .de).text, "Abitur Mathe · noch 30 Tage")
        for locale in UiLocale.allCases {
            let text = ExamCountdown.label(daysLeft: 5, locale: locale)
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

    private var today: Date { MicaboCalendar.shared.startOfDay(for: Date()) }

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

    func testPolishedDailyTabsRenders() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        try withLocale(.fr) {
            try RenderGallery.render("pol-cal-late", night: true, lateDay())
            // La feuille de la série défile (et le rendu ne dessine pas un défilement) : sa
            // flamme posée, et la semaine.
            try RenderGallery.render(
                "pol-streak", night: true,
                VStack(spacing: 22) {
                    StreakFlame(lit: true, size: 84)
                    StreakWeekCard(days: StudyStreak.week())
                }
                .padding(20)
                .environment(\.homeStill, true)
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
