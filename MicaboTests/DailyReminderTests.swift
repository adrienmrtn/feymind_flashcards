import XCTest
@testable import Micabo

/// Le rappel du jour : quand il part, et ce qu'il dit.
final class DailyReminderTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func plan(
        courses: [String] = [],
        trialEndsAt: Date? = nil,
        studiedToday: Bool = false,
        now: Date
    ) -> [DailyReminder.Planned] {
        DailyReminder.plan(
            courseTitles: courses,
            trialEndsAt: trialEndsAt,
            studiedToday: studiedToday,
            hour: 18,
            now: now,
            calendar: calendar,
            locale: .fr
        )
    }

    /// Sans cours, un rappel par jour qui invite à en importer un, dès ce soir.
    func testWithoutACourseItInvitesToImportOneEveryDay() {
        let planned = plan(now: date(18, 10))
        XCTAssertEqual(planned.count, DailyReminder.days)
        XCTAssertEqual(planned.first?.date.day, 18)
        XCTAssertEqual(planned.first?.date.hour, 18)
        let titles = Set(["Viens importer ton cours", "Un examen qui approche ?"])
        XCTAssertTrue(planned.allSatisfy { titles.contains($0.title) })
        XCTAssertNotEqual(planned[0].title, planned[1].title, "le texte change d'un jour à l'autre")
        XCTAssertEqual(Set(planned.map(\.identifier)).count, planned.count)
        XCTAssertTrue(planned.allSatisfy { $0.identifier.hasPrefix(DailyReminder.identifierPrefix) })
    }

    /// L'heure passée, ou la journée déjà travaillée : le premier rappel est pour demain.
    func testOnceTheHourHasPassedOrTheDayIsWorkedItStartsTomorrow() {
        let late = plan(now: date(18, 19))
        XCTAssertEqual(late.first?.date.day, 19)
        XCTAssertEqual(late.count, DailyReminder.days - 1)

        let worked = plan(studiedToday: true, now: date(18, 10))
        XCTAssertEqual(worked.first?.date.day, 19)
    }

    /// Avec des cours, il les nomme : le plus pressant d'abord, puis chacun son tour.
    func testWithCoursesItNamesThemInTurnMostPressingFirst() {
        let planned = plan(courses: ["Photosynthèse", "La Révolution"], now: date(18, 10))
        XCTAssertEqual(planned.map(\.title).prefix(3), [
            "Viens t'entraîner sur Photosynthèse",
            "Viens t'entraîner sur La Révolution",
            "Viens t'entraîner sur Photosynthèse"
        ])
        XCTAssertNotEqual(planned[0].body, planned[1].body)
    }

    /// Pendant l'essai, rien ; les rappels commencent le jour où il finit.
    func testNothingDuringTheTrialThenEveryDayAfterIt() {
        let trialEnd = date(23, 12)
        let planned = plan(trialEndsAt: trialEnd, now: date(18, 10))
        XCTAssertEqual(planned.first?.date.day, 23)
        XCTAssertTrue(planned.allSatisfy { calendar.date(from: $0.date)! >= trialEnd })

        XCTAssertTrue(plan(trialEndsAt: .distantFuture, now: date(18, 10)).isEmpty, "un essai sans date de fin ne reçoit rien")
        XCTAssertEqual(plan(trialEndsAt: date(17, 9), now: date(18, 10)).count, DailyReminder.days, "un essai fini ne retient plus rien")
    }

    /// Chaque langue a ses phrases, et le nom du cours y trouve sa place.
    func testEveryLanguageSaysItInItsOwnWords() {
        for locale in UiLocale.allCases {
            let title = L10n.t("ios.reminder.practice.title", locale: locale, vars: ["course": "Biologie"])
            XCTAssertTrue(title.contains("Biologie"), locale.rawValue)
            for key in ["import1.title", "import1.body", "import2.title", "import2.body", "practice.body1", "practice.body2"] {
                XCTAssertNotEqual(L10n.t("ios.reminder.\(key)", locale: locale), "ios.reminder.\(key)", locale.rawValue)
            }
        }
        XCTAssertEqual(L10n.t("ios.reminder.import1.title", locale: .it), "Importa il tuo corso")
    }
}
