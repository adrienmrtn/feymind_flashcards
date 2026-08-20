import SwiftData
import XCTest
@testable import Micabo

/// Le curseur de rythme ne doit pas être décoratif : ces tests verrouillent ses paliers
/// et le plafond de cartes neuves qu'il commande.
final class DailyLoadTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Paliers

    func testRangeGoesFromFiveMinutesToTwoHours() {
        XCTAssertEqual(DailyLoad.minimumMinutes, 5)
        XCTAssertEqual(DailyLoad.maximumMinutes, 120)
    }

    func testStepsAreFiveMinutesUpToThirtyThenFifteen() {
        for (previous, next) in zip(DailyLoad.steps, DailyLoad.steps.dropFirst()) {
            let expected = previous < 30 ? 5 : 15
            XCTAssertEqual(next - previous, expected, "Palier inattendu entre \(previous) et \(next)")
        }
    }

    func testNearestStepSnapsToAnExistingNotch() {
        XCTAssertEqual(DailyLoad.nearestStep(to: 13), 15)
        XCTAssertEqual(DailyLoad.nearestStep(to: 40), 45)
        XCTAssertEqual(DailyLoad.nearestStep(to: 1), 5)
        XCTAssertEqual(DailyLoad.nearestStep(to: 500), 120)
    }

    func testLabelSwitchesToHoursPastSixty() {
        XCTAssertEqual(DailyLoad.label(forMinutes: 25), "25 min")
        XCTAssertEqual(DailyLoad.label(forMinutes: 60), "1 h")
        XCTAssertEqual(DailyLoad.label(forMinutes: 90), "1 h 30")
        XCTAssertEqual(DailyLoad.label(forMinutes: 120), "2 h")
    }

    func testPaceChangesAlongTheRange() {
        XCTAssertEqual(DailyLoad.pace(forDailyMinutes: 5).label, "le rythme tranquille")
        XCTAssertEqual(DailyLoad.pace(forDailyMinutes: 20).label, "le rythme de croisière")
        XCTAssertEqual(DailyLoad.pace(forDailyMinutes: 45).label, "le rythme soutenu")
        XCTAssertEqual(DailyLoad.pace(forDailyMinutes: 120).label, "le rythme intensif")
    }

    // MARK: - Plafond de cartes neuves

    func testNewCardsPerDayGrowsWithTheTimeGiven() {
        var previous = 0
        for minutes in DailyLoad.steps {
            let cap = DailyLoad.newCardsPerDay(dailyMinutes: minutes)
            XCTAssertGreaterThanOrEqual(cap, previous, "Le plafond recule à \(minutes) min")
            previous = cap
        }
    }

    func testNewCardsPerDayNeverFallsToNothing() {
        XCTAssertGreaterThanOrEqual(DailyLoad.newCardsPerDay(dailyMinutes: 1), 2)
    }

    func testQuarterHourIntroducesAHandfulAndTwoHoursMuchMore() {
        XCTAssertEqual(DailyLoad.newCardsPerDay(dailyMinutes: 15), 8)
        XCTAssertEqual(DailyLoad.newCardsPerDay(dailyMinutes: 120), 60)
    }

    // MARK: - Effet réel sur la file

    func testDailyLimitCapsNewCardsInTheQueue() throws {
        let container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let cards = (0..<40).map { index -> Flashcard in
            let card = Flashcard(front: "carte \(index)", back: "réponse", position: index)
            card.state = .new
            card.dueDate = now.addingTimeInterval(-60)
            context.insert(card)
            return card
        }

        let limits = StudyQueueBuilder.Limits.daily(minutes: 15)
        let queue = StudyQueueBuilder.build(from: cards, now: now, limits: limits)

        XCTAssertEqual(queue.count, DailyLoad.newCardsPerDay(dailyMinutes: 15))
    }
}
