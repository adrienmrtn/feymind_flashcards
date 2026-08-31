import SwiftData
import XCTest
@testable import Micabo

final class StudyQueueTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            Exam.self,
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

    func testRemainingNewCardsAfterACourseSessionIsZero() {
        XCTAssertEqual(DailyNewQuota.remaining(introduced: 8, dailyMinutes: 15), 0)
        XCTAssertEqual(DailyNewQuota.remaining(introduced: 3, dailyMinutes: 15), 5)
    }

    func testIntroducedTodayCountsOnlyNewCardsFromToday() {
        let today = makeCard("neuve", state: .new, due: -60, position: 0)
        today.apply(
            SM2Scheduler.schedule(
                snapshot: SM2CardSnapshot(card: today),
                rating: .good,
                now: now,
                config: .deterministic
            ),
            at: now
        )

        let yesterday = ReviewLog(
            reviewedAt: now.addingTimeInterval(-86_400),
            rating: .good,
            stateBefore: .new,
            previousIntervalDays: 0,
            newIntervalDays: 0,
            easeAfter: 2.5
        )
        context.insert(yesterday)

        let logs = (try? context.fetch(FetchDescriptor<ReviewLog>())) ?? []
        XCTAssertEqual(DailyNewQuota.introducedToday(from: logs, now: now), 1)
    }

    func testImmediateDuePreviewSkipsQuotaAndExams() {
        let due = makeCard("due", state: .review, due: -60, position: 0)
        let later = makeCard("plus tard", state: .review, due: 86_400, position: 1)

        let preview = CourseDuePreview.immediate(from: [due, later], now: now)

        XCTAssertEqual(preview.dueCount, 1)
        XCTAssertEqual(preview.heldBackNewCards, 0)
        XCTAssertNil(preview.examName)
    }

    func testScheduledDuePreviewAppliesTheDailyNewCap() {
        let cards = (0..<30).map { makeCard("carte \($0)", state: .new, due: -60, position: $0) }
        let preview = CourseDuePreview.scheduled(
            from: cards,
            courseID: UUID(),
            in: context,
            now: now
        )
        let remaining = DailyNewQuota.remaining(introduced: 0)

        XCTAssertEqual(preview.dueCount, min(30, remaining))
        XCTAssertEqual(preview.heldBackNewCards, max(0, 30 - remaining))
        XCTAssertNil(preview.examName)
    }

    func testNearestExamNamePicksTheSoonestPlannedExam() {
        let courseID = UUID()
        let later = Exam(name: "Partiel", date: now.addingTimeInterval(14 * 86_400))
        later.courseIDs = [courseID]
        later.isPlanned = true
        let sooner = Exam(name: "Bac blanc", date: now.addingTimeInterval(3 * 86_400))
        sooner.courseIDs = [courseID]
        sooner.isPlanned = true
        let past = Exam(name: "Ancien", date: now.addingTimeInterval(-86_400))
        past.courseIDs = [courseID]
        past.isPlanned = true

        XCTAssertEqual(
            CourseDuePreview.nearestExamName(exams: [later, sooner, past], courseID: courseID, now: now),
            "Bac blanc"
        )
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

    /// Glisser le curseur ne doit changer que le nombre de neuves. Les révisions
    /// restent celles déjà dues : c'est ce qui évite de reconstruire la file à
    /// chaque cran.
    func testSetupPreviewTracksTheSliderWithoutRebuildingTheQueue() {
        let cards = [
            makeCard("apprentissage", state: .learning, due: -10, position: 0),
            makeCard("révision", state: .review, due: -10, position: 1)
        ] + (0..<12).map { makeCard("neuve \($0)", state: .new, due: -10, position: $0 + 2) }

        let due = StudyQueueBuilder.dueBreakdown(from: cards, now: now)
        XCTAssertEqual(due.learning, 1)
        XCTAssertEqual(due.review, 1)
        XCTAssertEqual(due.newCards, 12)

        let atThree = DailyNewQuota.setupCounts(due: due, newPerSession: 3)
        let builtThree = StudyQueueBuilder.counts(
            for: cards,
            now: now,
            limits: .daily(newRemaining: 3)
        )
        XCTAssertEqual(atThree, builtThree)
        XCTAssertEqual(atThree.total, 5)

        let atTen = DailyNewQuota.setupCounts(due: due, newPerSession: 10)
        let builtTen = StudyQueueBuilder.counts(
            for: cards,
            now: now,
            limits: .daily(newRemaining: 10)
        )
        XCTAssertEqual(atTen, builtTen)
        XCTAssertEqual(atTen.learning, atThree.learning)
        XCTAssertEqual(atTen.review, atThree.review)
        XCTAssertEqual(atTen.newCards, 10)

        let capped = DailyNewQuota.setupCounts(due: due, newPerSession: 80)
        XCTAssertEqual(capped.newCards, 12)
        XCTAssertEqual(capped.learning, 1)
        XCTAssertEqual(capped.review, 1)
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
