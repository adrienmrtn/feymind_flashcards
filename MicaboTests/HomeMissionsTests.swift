import XCTest
@testable import Micabo

/// **Ce que Mika dit et la prochaine étape du jour** : tout se tire de ce que l'app sait déjà.
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

    func testGreetingNamesTheStudentWhenItCan() {
        let named = HomeGreeting.lines(name: "Léa", moment: .day, dueCount: 0, locale: .fr)
        XCTAssertEqual(named.first, "Salut Léa ! On apprend quoi aujourd'hui ?")
        XCTAssertEqual(named.count, 4)
        let anonymous = HomeGreeting.lines(name: nil, moment: .day, dueCount: 3, locale: .fr)
        XCTAssertEqual(anonymous.first, "Salut ! On apprend quoi aujourd'hui ?")
        XCTAssertEqual(anonymous[1], L10n.t("ios.home2.line.due", locale: .fr))
        for line in named + anonymous {
            XCTAssertFalse(line.contains("{"), line)
        }
    }

    func testNewStudentIsAskedForAFirstLesson() {
        let day = HomeDay(hasCourses: false)
        XCTAssertEqual(day.primary, .create)
        XCTAssertNil(day.secondary)
    }

    /// La leçon en cours passe devant les cartes tant qu'elle n'a pas avancé aujourd'hui ; les
    /// cartes restent en seconde ligne.
    func testOpenLessonComesFirstThenTheCards() {
        var day = HomeDay(
            dueCount: 8,
            hasCourses: true,
            lessonTitle: "La photosynthèse",
            lessonCircle: "Cercle 4",
            lessonAdvancedToday: false,
            studiedToday: true
        )
        XCTAssertEqual(day.primary, .lesson)
        XCTAssertEqual(day.secondary, .cards)

        day.lessonAdvancedToday = true
        XCTAssertEqual(day.primary, .cards)
        XCTAssertEqual(day.secondary, .lesson)

        day.dueCount = 0
        XCTAssertEqual(day.primary, .lesson)
        XCTAssertNil(day.secondary)
    }

    /// Des leçons, toutes terminées, rien à réviser : la prochaine leçon à écrire.
    func testFinishedLessonsAskForTheNextOne() {
        XCTAssertEqual(HomeDay(dueCount: 0, reviewedToday: 5, hasCourses: true).primary, .create)
        XCTAssertEqual(HomeDay(dueCount: 3, hasCourses: true).primary, .cards)
        XCTAssertNil(HomeDay(dueCount: 3, hasCourses: true).secondary)
    }

    /// **La séance que le calendrier a posée passe devant tout** : c'est le plan de l'élève. Les
    /// cartes dues restent en seconde ligne, sinon la leçon en cours. L'élève sans leçon, lui,
    /// écrit d'abord la sienne.
    func testPlannedSessionComesFirst() {
        let session = HomeSession(eventID: UUID(), courseID: nil, title: "La guerre froide", startMinute: 18 * 60, endMinute: 18 * 60 + 30, examName: "Bac d'histoire")
        var day = HomeDay(dueCount: 8, hasCourses: true, lessonTitle: "La photosynthèse", lessonCircle: "Cercle 4", session: session)
        XCTAssertEqual(day.primary, .session)
        XCTAssertEqual(day.secondary, .cards)
        day.dueCount = 0
        XCTAssertEqual(day.secondary, .lesson)
        XCTAssertEqual(HomeDay(hasCourses: false, session: session).primary, .create)
        XCTAssertEqual(session.minutes, 30)
    }

    /// La séance proposée est la première du jour qui n'est ni faite ni finie ; l'agenda de Home
    /// garde ce qui reste, sans elle, sans ce qui est passé ni les séances menées.
    func testSessionAndAgendaFollowTheClock() {
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
        XCTAssertEqual(HomePlan.upcoming(items, now: evening, excluding: session, calendar: calendar).map(\.id), ["t", "r2"])

        let later = CalendarTime.date(minute: 18 * 60 + 40, on: today, calendar: calendar)
        XCTAssertEqual(HomeSession.next(in: items, now: later, calendar: calendar)?.title, "La décolonisation")
        let night = CalendarTime.date(minute: 22 * 60, on: today, calendar: calendar)
        XCTAssertNil(HomeSession.next(in: items, now: night, calendar: calendar))
    }

    /// Le plan du jour parle toutes les langues de l'app, avec le prénom là où il le faut.
    func testHome4CopyExistsInEveryLanguage() {
        let keys = IosI18nCatalogs.fr.keys.filter { $0.hasPrefix("ios.home4.") }
        XCTAssertEqual(keys.count, 18)
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in keys {
                XCTAssertNotNil(table[key], "\(locale.rawValue) \(key)")
            }
            for moment in [HomeGreeting.Moment.morning, .day, .evening, .night] {
                XCTAssertTrue(HomeGreeting.hello(name: "Lina", moment: moment, locale: locale).contains("Lina"), "\(locale.rawValue) \(moment)")
                XCTAssertFalse(HomeGreeting.hello(name: nil, moment: moment, locale: locale).contains("{"), "\(locale.rawValue) \(moment)")
            }
            for step in 1...3 {
                XCTAssertNotNil(table["ios.home4.how.step\(step)"], "\(locale.rawValue) \(step)")
                XCTAssertNotNil(table["ios.home4.how.step\(step)Sub"], "\(locale.rawValue) \(step)")
            }
        }
        XCTAssertEqual(HomeGreeting.hello(name: "Léa", moment: .night, locale: .fr), "Bonsoir Léa")
    }

    /// Chaque phrase de la Home calme et du paywall existe dans chaque langue, sans retomber
    /// sur l'anglais, et sans variable perdue.
    func testHome3AndPaywallCopyExistsInEveryLanguage() {
        let keys = IosI18nCatalogs.fr.keys.filter { $0.hasPrefix("ios.home3.") || $0.hasPrefix("ios.pay3.") }
        XCTAssertGreaterThanOrEqual(keys.count, 18)
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in keys {
                XCTAssertNotNil(table[key], "\(locale.rawValue) \(key)")
                if locale != .en, locale != .fr, let value = table[key] {
                    XCTAssertFalse(value.isEmpty, "\(locale.rawValue) \(key)")
                }
            }
        }
        XCTAssertTrue(L10n.t("ios.pay3.titleName", locale: .de, vars: ["name": "Lina"]).contains("Lina"))
    }

    /// Chaque phrase de la nouvelle Home existe dans chaque langue, sans retomber sur l'anglais.
    func testHomeCopyExistsInEveryLanguage() {
        let keys = IosI18nCatalogs.fr.keys.filter { $0.hasPrefix("ios.home2.") }
        XCTAssertEqual(keys.count, 29)
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in keys {
                XCTAssertNotNil(table[key], "\(locale.rawValue) \(key)")
            }
        }
    }
}
