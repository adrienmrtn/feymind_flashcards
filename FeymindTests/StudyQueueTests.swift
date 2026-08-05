import SwiftData
import XCTest
@testable import Feymind

final class StudyQueueTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            CourseBlockEntity.self,
            Flashcard.self,
            ReviewLog.self,
            TextHighlight.self,
            CoursePodcast.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    private func makeCard(
        _ front: String,
        state: CardState,
        due: TimeInterval,
        position: Int
    ) -> Flashcard {
        let card = Flashcard(front: front, back: "réponse", position: position)
        card.state = state
        card.dueDate = now.addingTimeInterval(due)
        context.insert(card)
        return card
    }

    func testQueueOrdersLearningThenReviewThenNew() {
        let learning = makeCard("apprentissage", state: .learning, due: -30, position: 0)
        let review = makeCard("révision", state: .review, due: -3_600, position: 1)
        let fresh = makeCard("nouvelle", state: .new, due: -10, position: 2)
        let future = makeCard("plus tard", state: .review, due: 86_400, position: 3)

        let queue = StudyQueueBuilder.build(from: [fresh, future, review, learning], now: now)

        XCTAssertEqual(queue.map(\.front), ["apprentissage", "révision", "nouvelle"])
    }

    func testSuspendedCardsNeverEnterTheQueue() {
        let card = makeCard("suspendue", state: .review, due: -60, position: 0)
        card.isSuspended = true

        XCTAssertTrue(StudyQueueBuilder.build(from: [card], now: now).isEmpty)
    }

    func testNewCardsRespectTheSessionLimit() {
        let cards = (0..<30).map { makeCard("carte \($0)", state: .new, due: -60, position: $0) }
        var limits = StudyQueueBuilder.Limits.default
        limits.newPerSession = 5

        XCTAssertEqual(StudyQueueBuilder.build(from: cards, now: now, limits: limits).count, 5)
    }

    func testCountsSplitByState() {
        let cards = [
            makeCard("a", state: .new, due: -10, position: 0),
            makeCard("b", state: .learning, due: -10, position: 1),
            makeCard("c", state: .relearning, due: -10, position: 2),
            makeCard("d", state: .review, due: -10, position: 3)
        ]

        let counts = StudyQueueBuilder.counts(for: cards, now: now)

        XCTAssertEqual(counts.newCards, 1)
        XCTAssertEqual(counts.learning, 2)
        XCTAssertEqual(counts.review, 1)
        XCTAssertEqual(counts.total, 4)
    }

    // MARK: - Application d'une réponse

    func testAnsweringWritesTheOutcomeAndLogsIt() {
        let card = makeCard("question", state: .review, due: -60, position: 0)
        card.intervalDays = 10
        card.easeFactor = 2.5

        let outcome = SM2Scheduler.schedule(
            snapshot: SM2CardSnapshot(card: card),
            rating: .good,
            now: now,
            config: .deterministic
        )
        card.apply(outcome, at: now)

        XCTAssertEqual(card.intervalDays, 25, accuracy: 0.01)
        XCTAssertEqual(card.state, .review)
        XCTAssertEqual(card.lastReviewedAt, now)
        XCTAssertEqual(card.logs?.count, 1)
        XCTAssertEqual(card.logs?.first?.rating, .good)
        XCTAssertEqual(card.logs?.first?.previousIntervalDays, 10)
    }

    func testResetSchedulingReturnsTheCardToNew() {
        let card = makeCard("question", state: .review, due: 86_400, position: 0)
        card.intervalDays = 42
        card.lapses = 3

        card.resetScheduling()

        XCTAssertEqual(card.state, .new)
        XCTAssertEqual(card.intervalDays, 0)
        XCTAssertEqual(card.lapses, 0)
        XCTAssertTrue(card.isDue())
    }
}
