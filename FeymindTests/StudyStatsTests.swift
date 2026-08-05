import XCTest
@testable import Feymind

final class StudyStatsTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func day(_ offset: Int) -> Date {
        calendar.startOfDay(for: now).addingTimeInterval(Double(offset) * 86_400)
    }

    func testStreakCountsConsecutiveDays() {
        let dates = [day(0), day(-1), day(-2), day(-4)]
        XCTAssertEqual(StudyStats.streak(reviewDates: dates, calendar: calendar, now: now), 3)
    }

    func testStreakSurvivesADayNotYetStarted() {
        // Rien aujourd'hui, mais hier et avant-hier : la série tient encore.
        let dates = [day(-1), day(-2)]
        XCTAssertEqual(StudyStats.streak(reviewDates: dates, calendar: calendar, now: now), 2)
    }

    func testStreakBreaksAfterAMissedDay() {
        XCTAssertEqual(StudyStats.streak(reviewDates: [day(-3)], calendar: calendar, now: now), 0)
        XCTAssertEqual(StudyStats.streak(reviewDates: [], calendar: calendar, now: now), 0)
    }

    func testReviewsTodayIgnoresOtherDays() {
        let dates = [day(0), day(0), day(-1)]
        XCTAssertEqual(StudyStats.reviewsToday(reviewDates: dates, calendar: calendar, now: now), 2)
    }

    func testDailyCountsAreOrderedFromOldestToNewest() {
        let counts = StudyStats.dailyCounts(
            reviewDates: [day(0), day(0), day(-2)],
            days: 3,
            calendar: calendar,
            now: now
        )
        XCTAssertEqual(counts, [1, 0, 2])
    }
}
