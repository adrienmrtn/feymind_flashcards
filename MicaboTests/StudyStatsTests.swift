import XCTest
@testable import Micabo

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

    /// Le record se calcule sur tout l'historique, et il n'a rien à voir avec la série en
    /// cours : le Profil affiche les deux côte à côte, et un record qui suivrait la série ne
    /// servirait à rien.
    func testBestStreakLooksAtTheWholeHistory() {
        // Une série de quatre jours il y a longtemps, une de deux jours qui court encore.
        let dates = [day(-20), day(-19), day(-18), day(-17), day(-1), day(0)]

        XCTAssertEqual(StudyStats.bestStreak(reviewDates: dates, calendar: calendar), 4)
        XCTAssertEqual(StudyStats.streak(reviewDates: dates, calendar: calendar, now: now), 2)
    }

    /// Plusieurs révisions le même jour font un seul jour de série : c'est un compte de jours,
    /// pas de cartes.
    func testBestStreakCountsDaysAndNotReviews() {
        let dates = [day(0), day(0), day(0)]
        XCTAssertEqual(StudyStats.bestStreak(reviewDates: dates, calendar: calendar), 1)
        XCTAssertEqual(StudyStats.bestStreak(reviewDates: [], calendar: calendar), 0)
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
