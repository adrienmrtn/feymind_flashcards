import XCTest
@testable import Micabo

/// **Ce que Mika dit et les missions du jour** : tout se tire de ce que l'app sait déjà.
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
        let missions = HomeDay(hasCourses: false).missions(locale: .fr)
        XCTAssertEqual(missions.map(\.kind), [.create, .streak])
        XCTAssertEqual(missions.first?.reward, .xp(XPRules.lessonCreated))
        XCTAssertFalse(missions.contains(where: \.done))
    }

    func testBusyDayListsCardsLessonAndStreak() {
        let day = HomeDay(
            dueCount: 8,
            hasCourses: true,
            lessonTitle: "La photosynthèse",
            lessonCircle: "Cercle 4",
            lessonAdvancedToday: false,
            studiedToday: true
        )
        let missions = day.missions(locale: .fr)
        XCTAssertEqual(missions.map(\.kind), [.cards, .lesson, .streak])
        XCTAssertEqual(missions[0].reward, .xp(8 * XPRules.cardReviewed))
        XCTAssertEqual(missions[1].subtitle, "La photosynthèse · Cercle 4")
        XCTAssertEqual(missions.map(\.done), [false, false, true])
    }

    func testReviewedCardsStayCheckedOnceNothingIsDue() {
        let missions = HomeDay(dueCount: 0, reviewedToday: 5, hasCourses: true).missions(locale: .fr)
        XCTAssertEqual(missions.first?.kind, .cards)
        XCTAssertEqual(missions.first?.done, true)
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
