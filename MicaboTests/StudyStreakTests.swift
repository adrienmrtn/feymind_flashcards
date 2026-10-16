import SwiftData
import XCTest
@testable import Micabo

/// **La série des jours travaillés** (`StudyStreak`).
///
/// Tout passe par un `UserDefaults` à part et un calendrier fixe, en UTC, la semaine
/// commençant le lundi : les tests ne dépendent ni du fuseau de la machine de CI, ni de
/// l'heure à laquelle ils tournent, et ne touchent pas à la série de l'app qui les héberge.
final class StudyStreakTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "micabo.tests.studyStreak"

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Le jeudi 15 octobre 2026, à midi.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12))!
    }

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    /// Midi, `offset` jours avant ou après aujourd'hui.
    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let noon = calendar.date(byAdding: .day, value: offset, to: now)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: noon)!
    }

    @discardableResult
    private func record(_ offset: Int, hour: Int = 12) -> Bool {
        StudyStreak.record(now: day(offset, hour: hour), calendar: calendar, defaults: defaults)
    }

    private func current(at offset: Int = 0) -> Int {
        StudyStreak.current(now: day(offset), calendar: calendar, defaults: defaults)
    }

    private func best() -> Int {
        StudyStreak.best(now: now, calendar: calendar, defaults: defaults)
    }

    // MARK: Le jour

    func testFirstRecordOfTheDayReturnsTrueThenFalse() {
        XCTAssertFalse(StudyStreak.hasStudiedToday(now: now, calendar: calendar, defaults: defaults))
        XCTAssertTrue(record(0, hour: 8))
        XCTAssertFalse(record(0, hour: 13))
        XCTAssertFalse(record(0, hour: 23))
        XCTAssertTrue(StudyStreak.hasStudiedToday(now: now, calendar: calendar, defaults: defaults))
        XCTAssertEqual(current(), 1)
        XCTAssertEqual(StudyStreak.days(in: defaults), ["2026-10-15"])
    }

    func testStampIsTheCalendarDay() {
        XCTAssertEqual(StudyStreak.stamp(day(0, hour: 0), calendar: calendar), "2026-10-15")
        XCTAssertEqual(StudyStreak.stamp(day(0, hour: 23), calendar: calendar), "2026-10-15")
        XCTAssertEqual(StudyStreak.stamp(day(-15), calendar: calendar), "2026-09-30")
    }

    // MARK: La série

    func testConsecutiveDaysCount() {
        record(-2)
        record(-1)
        record(0)
        XCTAssertEqual(current(), 3)
    }

    func testAGapResetsTheStreak() {
        record(-5)
        record(-4)
        record(-3)
        // Ni avant-hier ni hier : la série d'avant est morte.
        XCTAssertEqual(current(), 0)
        XCTAssertTrue(record(0))
        XCTAssertEqual(current(), 1)
    }

    /// Rien encore aujourd'hui, mais hier oui : la série tient jusqu'à minuit.
    func testYesterdayOnlyStillCounts() {
        record(-2)
        record(-1)
        XCTAssertFalse(StudyStreak.hasStudiedToday(now: now, calendar: calendar, defaults: defaults))
        XCTAssertEqual(current(), 2)
        // Le lendemain sans rien de plus, elle s'éteint.
        XCTAssertEqual(current(at: 1), 0)
    }

    func testBestStreakOutlivesTheCurrentOne() {
        for offset in -10 ... -7 {
            record(offset)
        }
        record(-1)
        record(0)
        XCTAssertEqual(current(), 2)
        XCTAssertEqual(best(), 4)

        let status = StudyStreak.status(now: now, calendar: calendar, defaults: defaults)
        XCTAssertEqual(status, StudyStreak.Status(current: 2, best: 4, studiedToday: true))
    }

    func testBestFollowsACurrentStreakThatBeatsIt() {
        record(-6)
        record(-5)
        for offset in -2 ... 0 {
            record(offset)
        }
        XCTAssertEqual(best(), 3)
    }

    // MARK: L'historique des cartes

    func testLegacyReviewDatesMergeIntoTheStreak() {
        // Plusieurs révisions par jour, les trois jours d'avant.
        let reviews = [day(-3, hour: 9), day(-3, hour: 21), day(-2, hour: 10), day(-1, hour: 7), day(-1, hour: 22)]
        StudyStreak.merge(reviews, calendar: calendar, defaults: defaults)
        XCTAssertEqual(current(), 3)
        XCTAssertEqual(StudyStreak.days(in: defaults).count, 3)

        // La première leçon du jour fait grandir la série reprise.
        XCTAssertTrue(record(0))
        XCTAssertEqual(current(), 4)

        // Relire le même journal ne change rien.
        StudyStreak.merge(reviews, calendar: calendar, defaults: defaults)
        XCTAssertEqual(StudyStreak.days(in: defaults).count, 4)
        XCTAssertEqual(best(), 4)
    }

    func testLegacyRecordIsKept() {
        StudyStreak.merge((-30 ... -21).map { day($0) }, calendar: calendar, defaults: defaults)
        record(0)
        XCTAssertEqual(current(), 1)
        XCTAssertEqual(best(), 10)
    }

    func testReviewHistoryIsAdoptedOnce() throws {
        let container = try ModelContainer(
            for: Course.self, Flashcard.self, ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        context.insert(ReviewLog(
            reviewedAt: Date(),
            rating: .good,
            stateBefore: .new,
            previousIntervalDays: 0,
            newIntervalDays: 1,
            easeAfter: 2.5
        ))
        try context.save()

        StudyStreak.adoptReviewHistoryIfNeeded(in: context, defaults: defaults)
        XCTAssertTrue(StudyStreak.hasStudiedToday(defaults: defaults))
        XCTAssertEqual(StudyStreak.days(in: defaults).count, 1)

        // Une seconde fois, le journal n'est plus relu : c'est le Profil qui le verse ensuite.
        let yesterday = MicaboCalendar.shared.date(byAdding: .day, value: -1, to: Date())!
        context.insert(ReviewLog(
            reviewedAt: yesterday,
            rating: .good,
            stateBefore: .new,
            previousIntervalDays: 0,
            newIntervalDays: 1,
            easeAfter: 2.5
        ))
        try context.save()
        StudyStreak.adoptReviewHistoryIfNeeded(in: context, defaults: defaults)
        XCTAssertEqual(StudyStreak.days(in: defaults).count, 1)
    }

    // MARK: La fenêtre

    /// Quatre cents jours gardés, et une série plus longue que la fenêtre garde tous ses jours.
    func testAStreakLongerThanTheWindowKeepsCounting() {
        // Quatre cent vingt jours d'historique d'un coup, puis trente jours vécus un par un.
        StudyStreak.merge((-449 ... -30).map { day($0) }, calendar: calendar, defaults: defaults)
        XCTAssertEqual(StudyStreak.days(in: defaults).count, StudyStreak.keptDays)
        XCTAssertEqual(current(at: -30), 420)

        for offset in -29 ... 0 {
            XCTAssertTrue(record(offset))
        }
        XCTAssertEqual(StudyStreak.days(in: defaults).count, StudyStreak.keptDays)
        XCTAssertEqual(current(), 450)
        XCTAssertEqual(best(), 450)

        // Un jour manqué : la série repart, le record reste.
        record(2)
        XCTAssertEqual(StudyStreak.current(now: day(2), calendar: calendar, defaults: defaults), 1)
        XCTAssertEqual(StudyStreak.best(now: day(2), calendar: calendar, defaults: defaults), 450)
    }

    // MARK: La semaine

    func testWeekStartsOnTheCalendarFirstWeekday() {
        record(-3) // lundi 12
        record(-1) // mercredi 14
        record(0) // jeudi 15
        let week = StudyStreak.week(now: now, calendar: calendar, defaults: defaults)

        XCTAssertEqual(week.map(\.stamp), [
            "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15",
            "2026-10-16", "2026-10-17", "2026-10-18",
        ])
        XCTAssertEqual(week.map(\.studied), [true, false, true, true, false, false, false])
        XCTAssertEqual(week.firstIndex { $0.isToday }, 3)
        XCTAssertEqual(week.map(\.isFuture), [false, false, false, false, true, true, true])
    }

    // MARK: La fête

    func testCelebrationHappensOncePerStudiedDay() {
        XCTAssertFalse(StudyStreak.claimCelebration(now: now, calendar: calendar, defaults: defaults))

        record(0)
        XCTAssertTrue(StudyStreak.celebrationIsDue(now: now, calendar: calendar, defaults: defaults))
        XCTAssertTrue(StudyStreak.claimCelebration(now: now, calendar: calendar, defaults: defaults))
        XCTAssertFalse(StudyStreak.celebrationIsDue(now: now, calendar: calendar, defaults: defaults))
        XCTAssertFalse(StudyStreak.claimCelebration(now: day(0, hour: 20), calendar: calendar, defaults: defaults))

        record(1)
        XCTAssertTrue(StudyStreak.claimCelebration(now: day(1), calendar: calendar, defaults: defaults))
    }

    func testResetForgetsEverything() {
        record(-1)
        record(0)
        StudyStreak.reset(defaults: defaults)
        XCTAssertEqual(current(), 0)
        XCTAssertEqual(best(), 0)
        XCTAssertTrue(StudyStreak.days(in: defaults).isEmpty)
    }
}
