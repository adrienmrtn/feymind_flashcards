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
