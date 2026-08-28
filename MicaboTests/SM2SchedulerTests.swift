import XCTest
@testable import Micabo

/// Le planificateur doit reproduire le SM-2 legacy d'Anki, réglages par défaut.
final class SM2SchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let config = SM2Scheduler.Configuration.deterministic

    // MARK: - Apprentissage

    func testNewCardAgainStaysOnFirstStep() {
        let outcome = SM2Scheduler.schedule(snapshot: SM2CardSnapshot(), rating: .again, now: now, config: config)

        XCTAssertEqual(outcome.state, .learning)
        XCTAssertEqual(outcome.stepIndex, 0)
        XCTAssertEqual(outcome.delay(from: now), 60, accuracy: 1)
    }

    func testNewCardHardIsTheAverageOfTheFirstTwoSteps() {
        let outcome = SM2Scheduler.schedule(snapshot: SM2CardSnapshot(), rating: .hard, now: now, config: config)

        XCTAssertEqual(outcome.state, .learning)
        XCTAssertEqual(outcome.stepIndex, 0)
        XCTAssertEqual(outcome.delay(from: now), 5.5 * 60, accuracy: 1)
        XCTAssertEqual(SM2Scheduler.hardStepMinutes([1, 10], stepIndex: 0), 5.5)
    }

    func testNewCardGoodAdvancesToTenMinutesWithoutGraduating() {
        let outcome = SM2Scheduler.schedule(snapshot: SM2CardSnapshot(), rating: .good, now: now, config: config)

        XCTAssertEqual(outcome.state, .learning)
        XCTAssertEqual(outcome.stepIndex, 1)
        XCTAssertEqual(outcome.delay(from: now), 10 * 60, accuracy: 1)
        XCTAssertEqual(outcome.repetitions, 0)
    }

    func testGoodFromTheLastStepGraduatesToOneDay() {
        let snapshot = SM2CardSnapshot(state: .learning, stepIndex: 1)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .good, now: now, config: config)

        XCTAssertEqual(outcome.state, .review)
        XCTAssertEqual(outcome.intervalDays, 1)
        XCTAssertEqual(outcome.repetitions, 1)
    }

    func testHardOnTheLastStepRepeatsThatStep() {
        let snapshot = SM2CardSnapshot(state: .learning, stepIndex: 1)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .hard, now: now, config: config)

        XCTAssertEqual(outcome.state, .learning)
        XCTAssertEqual(outcome.stepIndex, 1)
        XCTAssertEqual(outcome.delay(from: now), 10 * 60, accuracy: 1)
    }

    func testEasyOnNewCardJumpsToFourDays() {
        let outcome = SM2Scheduler.schedule(snapshot: SM2CardSnapshot(), rating: .easy, now: now, config: config)

        XCTAssertEqual(outcome.state, .review)
        XCTAssertEqual(outcome.intervalDays, 4)
    }

    // MARK: - Révision

    func testReviewGoodMultipliesByEaseFactor() {
        let snapshot = SM2CardSnapshot(state: .review, intervalDays: 10, easeFactor: 2.5, repetitions: 3)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .good, now: now, config: config)

        XCTAssertEqual(outcome.intervalDays, 25)
        XCTAssertEqual(outcome.easeFactor, 2.5, accuracy: 0.001)
    }

    func testReviewHardReducesEaseAndUsesHardMultiplier() {
        let snapshot = SM2CardSnapshot(state: .review, intervalDays: 10, easeFactor: 2.5, repetitions: 3)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .hard, now: now, config: config)

        XCTAssertEqual(outcome.easeFactor, 2.35, accuracy: 0.001)
        XCTAssertEqual(outcome.intervalDays, 12)
    }

    func testReviewEasyUsesCurrentEaseThenRaisesIt() {
        let snapshot = SM2CardSnapshot(state: .review, intervalDays: 10, easeFactor: 2.5, repetitions: 3)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .easy, now: now, config: config)

        XCTAssertEqual(outcome.easeFactor, 2.65, accuracy: 0.001)
        XCTAssertEqual(outcome.intervalDays, 32)
    }

    func testIntervalAlwaysGrowsByAtLeastOneDay() {
        let snapshot = SM2CardSnapshot(state: .review, intervalDays: 30, easeFactor: 1.3, repetitions: 8)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .hard, now: now, config: config)

        XCTAssertGreaterThanOrEqual(outcome.intervalDays, 31)
    }

    func testDaysLateAreHalvedIntoTheGoodInterval() {
        let due = now.addingTimeInterval(-4 * SM2Scheduler.day)
        let snapshot = SM2CardSnapshot(state: .review, intervalDays: 10, easeFactor: 2.5, dueDate: due)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .good, now: now, config: config)

        XCTAssertEqual(outcome.intervalDays, 30)
    }

    // MARK: - Rechute

    func testAgainOnReviewEntersRelearningAtTenMinutes() {
        let snapshot = SM2CardSnapshot(state: .review, intervalDays: 30, easeFactor: 2.5, repetitions: 6, lapses: 1)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .again, now: now, config: config)

        XCTAssertEqual(outcome.state, .relearning)
        XCTAssertEqual(outcome.lapses, 2)
        XCTAssertEqual(outcome.easeFactor, 2.3, accuracy: 0.001)
        XCTAssertEqual(outcome.delay(from: now), 10 * 60, accuracy: 1)
        XCTAssertEqual(outcome.intervalDays, 1)
    }

    func testRelearningGoodReturnsToReview() {
        let snapshot = SM2CardSnapshot(state: .relearning, intervalDays: 1, easeFactor: 2.3, repetitions: 6, lapses: 2)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .good, now: now, config: config)

        XCTAssertEqual(outcome.state, .review)
        XCTAssertEqual(outcome.intervalDays, 1)
        XCTAssertEqual(outcome.repetitions, 7)
    }

    func testRelearningEasyAddsOneDay() {
        let snapshot = SM2CardSnapshot(state: .relearning, intervalDays: 1, easeFactor: 2.3, repetitions: 6, lapses: 2)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .easy, now: now, config: config)

        XCTAssertEqual(outcome.state, .review)
        XCTAssertEqual(outcome.intervalDays, 2)
    }

    func testRelearningHardOnASingleStepIsFifteenMinutes() {
        let snapshot = SM2CardSnapshot(state: .relearning, intervalDays: 1, easeFactor: 2.3, repetitions: 6, lapses: 2)
        let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .hard, now: now, config: config)

        XCTAssertEqual(outcome.state, .relearning)
        XCTAssertEqual(outcome.delay(from: now), 15 * 60, accuracy: 1)
    }

    func testEaseNeverDropsBelowMinimum() {
        var snapshot = SM2CardSnapshot(state: .review, intervalDays: 5, easeFactor: 1.35, repetitions: 4)
        for _ in 0..<5 {
            let outcome = SM2Scheduler.schedule(snapshot: snapshot, rating: .hard, now: now, config: config)
            snapshot = SM2CardSnapshot(
                state: outcome.state,
                intervalDays: outcome.intervalDays,
                easeFactor: outcome.easeFactor,
                repetitions: outcome.repetitions,
                lapses: outcome.lapses,
                stepIndex: outcome.stepIndex
            )
        }
        XCTAssertEqual(snapshot.easeFactor, 1.3, accuracy: 0.0001)
    }

    // MARK: - Libellés

    func testPreviewLabelsForNewCardMatchAnkiDefaults() {
        let labels = SM2Scheduler.previewLabels(for: SM2CardSnapshot(), now: now, config: config)

        XCTAssertEqual(labels[.again], "1 min")
        XCTAssertEqual(labels[.hard], "6 min")
        XCTAssertEqual(labels[.good], "10 min")
        XCTAssertEqual(labels[.easy], "4 j")
        XCTAssertEqual(Set(labels.values).count, 4, "Quatre boutons, quatre délais différents")
    }

    func testDelayFormatting() {
        XCTAssertEqual(SM2Scheduler.format(delay: 30), "< 1 min")
        XCTAssertEqual(SM2Scheduler.format(delay: 330), "6 min")
        XCTAssertEqual(SM2Scheduler.format(delay: 600), "10 min")
        XCTAssertEqual(SM2Scheduler.format(delay: 7_200), "2 h")
        XCTAssertEqual(SM2Scheduler.format(delay: 4 * 86_400), "4 j")
        XCTAssertEqual(SM2Scheduler.format(delay: 90 * 86_400), "3 mois")
        XCTAssertEqual(SM2Scheduler.format(delay: 730 * 86_400), "2 ans")
    }
}
