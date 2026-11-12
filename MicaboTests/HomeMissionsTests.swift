import XCTest
@testable import Micabo

/// **Ce que la Home lit de la journée** : l'heure qu'il est, le prénom, la séance que le
/// calendrier a posée. Ce qu'elle en fait — une phrase, une action — est dans `Home10Tests`.
final class HomeMissionsTests: XCTestCase {
    func testGreetingFollowsTheHour() {
        XCTAssertEqual(HomeGreeting.moment(hour: 7), .morning)
        XCTAssertEqual(HomeGreeting.moment(hour: 14), .day)
        XCTAssertEqual(HomeGreeting.moment(hour: 20), .evening)
        XCTAssertEqual(HomeGreeting.moment(hour: 23), .night)
        XCTAssertEqual(HomeGreeting.moment(hour: 2), .night)
    }

    func testFirstNameIsTheFirstWord() {
        XCTAssertEqual(HomeGreeting.firstName("  Léa Martin "), "Léa")
        XCTAssertNil(HomeGreeting.firstName("   "))
        XCTAssertNil(HomeGreeting.firstName(nil))
    }

    /// La séance proposée est la première du jour qui n'est ni faite ni finie.
    func testTheSessionFollowsTheClock() {
        let calendar = MicaboCalendar.shared
        let today = calendar.startOfDay(for: Date())
        let examID = UUID()
        let first = UUID()
        let items = [
            AgendaItem(id: "t", kind: .task, title: "DM", day: today, tintIndex: 0, taskID: UUID()),
            AgendaItem(id: "a", kind: .lesson, title: "Maths", day: today, startMinute: 8 * 60, endMinute: 9 * 60, tintIndex: 0),
            AgendaItem(id: "f", kind: .focus, title: "", day: today, startMinute: 14 * 60, endMinute: 14 * 60 + 25, tintIndex: 0, minutes: 25, isDone: true),
            AgendaItem(id: "r", kind: .revision, title: "La guerre froide", day: today, startMinute: 18 * 60, endMinute: 18 * 60 + 30, tintIndex: 0, examID: examID, eventID: first),
            AgendaItem(id: "d", kind: .revision, title: "Fait", day: today, startMinute: 19 * 60, endMinute: 19 * 60 + 30, tintIndex: 0, eventID: UUID(), isDone: true),
            AgendaItem(id: "r2", kind: .revision, title: "La décolonisation", day: today, startMinute: 20 * 60, endMinute: 20 * 60 + 30, tintIndex: 0, eventID: UUID()),
        ]
        let evening = CalendarTime.date(minute: 17 * 60 + 55, on: today, calendar: calendar)
        let session = HomeSession.next(in: items, now: evening, examNames: [examID: "Bac"], calendar: calendar)
        XCTAssertEqual(session?.eventID, first)
        XCTAssertEqual(session?.examName, "Bac")
        XCTAssertEqual(session?.minutes, 30)

        let later = CalendarTime.date(minute: 18 * 60 + 40, on: today, calendar: calendar)
        XCTAssertEqual(HomeSession.next(in: items, now: later, calendar: calendar)?.title, "La décolonisation")
        let night = CalendarTime.date(minute: 22 * 60, on: today, calendar: calendar)
        XCTAssertNil(HomeSession.next(in: items, now: night, calendar: calendar))
    }

    /// La séance posée au calendrier passe devant tout : c'est le plan de l'élève. L'élève sans
    /// leçon, lui, crée d'abord la sienne.
    func testPlannedSessionComesFirst() {
        let session = HomeSession(eventID: UUID(), courseID: nil, title: "La guerre froide", startMinute: 18 * 60, endMinute: 18 * 60 + 30, examName: "Bac d'histoire")
        var day = HomeDay(dueCount: 8, hasCourses: true, lessonTitle: "La photosynthèse", session: session, lessonStep: 4)
        XCTAssertEqual(day.proposal, .session)
        day.session = nil
        XCTAssertEqual(day.proposal, .cards)
        XCTAssertEqual(HomeDay(hasCourses: false, session: session).proposal, .newcomer)
    }

    /// Les phrases des Homes précédentes restent dans chaque langue : d'autres écrans et
    /// d'anciennes versions les lisent encore.
    func testEarlierHomeCopyStillExistsInEveryLanguage() {
        let keys = IosI18nCatalogs.fr.keys.filter {
            $0.hasPrefix("ios.home2.") || $0.hasPrefix("ios.home3.") || $0.hasPrefix("ios.home4.") || $0.hasPrefix("ios.pay3.")
        }
        XCTAssertGreaterThanOrEqual(keys.count, 60)
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in keys {
                XCTAssertNotNil(table[key], "\(locale.rawValue) \(key)")
            }
        }
        XCTAssertTrue(L10n.t("ios.pay3.titleName", locale: .de, vars: ["name": "Lina"]).contains("Lina"))
    }
}
