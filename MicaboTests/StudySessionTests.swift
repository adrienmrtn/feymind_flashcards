import SwiftData
import XCTest
@testable import Micabo

/// Les garanties de la session : annuler une note remet la carte exactement dans son
/// état d'avant, l'entraînement libre ne touche à rien, et une session interrompue se
/// reprend à la carte près.
final class StudySessionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        StudySessionStore.clear()
    }

    override func tearDown() {
        StudySessionStore.clear()
        context = nil
        container = nil
    }

    private func makeCard(
        _ front: String = "question",
        state: CardState = .review,
        due: TimeInterval = -60,
        interval: Double = 10,
        position: Int = 0
    ) -> Flashcard {
        let card = Flashcard(front: front, back: "réponse", position: position)
        card.state = state
        card.dueDate = now.addingTimeInterval(due)
        card.intervalDays = interval
        card.easeFactor = 2.5
        context.insert(card)
        return card
    }

    private func logCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<ReviewLog>())) ?? -1
    }

    // MARK: - Annulation

    func testUndoIsUnavailableBeforeTheFirstRating() {
        let session = StudySession()
        session.start(with: [makeCard()], context: context, sourceKey: nil, now: now)

        XCTAssertFalse(session.canUndo)
    }

    func testUndoRestoresTheExactStateOfThePreviousCard() {
        let card = makeCard()
        let before = CardScheduling(card: card)

        let session = StudySession()
        session.start(with: [card], context: context, sourceKey: nil, now: now)
        session.answer(.good, now: now)

        XCTAssertTrue(session.canUndo)
        XCTAssertEqual(session.answeredCount, 1)
        XCTAssertNotEqual(CardScheduling(card: card), before)
        XCTAssertEqual(logCount(), 1)

        session.undo()

        XCTAssertEqual(CardScheduling(card: card), before, "L'annulation doit rendre la carte à l'identique")
        XCTAssertEqual(logCount(), 0, "Le journal de la note annulée doit disparaître")
        XCTAssertEqual(session.answeredCount, 0)
        XCTAssertEqual(session.goodCount, 0)
        XCTAssertEqual(session.current?.id, card.id)
        XCTAssertTrue(session.isRevealed, "On revient sur la carte réponse visible, prête à être renotée")
        XCTAssertFalse(session.canUndo)
    }

    func testUndoAfterTheLastCardReopensTheSession() {
        let session = StudySession()
        session.start(with: [makeCard()], context: context, sourceKey: nil, now: now)
        session.answer(.easy, now: now)

        XCTAssertTrue(session.isFinished)

        session.undo()

        XCTAssertFalse(session.isFinished)
        XCTAssertNotNil(session.current)
    }

    func testUndoBringsBackACardSetAside() {
        let card = makeCard()
        let session = StudySession()
        session.start(with: [card], context: context, sourceKey: nil, now: now)

        session.setAsideCurrent()
        XCTAssertTrue(card.isSuspended)
        XCTAssertTrue(session.canUndo)

        session.undo()
        XCTAssertFalse(card.isSuspended)
        XCTAssertEqual(session.current?.id, card.id)
    }

    // MARK: - Entraînement libre

    func testPracticeModeLeavesTheScheduleAlone() {
        let card = makeCard(due: 86_400)
        let before = CardScheduling(card: card)

        let session = StudySession()
        session.start(with: [card], context: context, mode: .practice, sourceKey: nil, now: now)

        XCTAssertEqual(session.initialCount, 1, "L'entraînement libre sert aussi les cartes non dues")

        session.answer(.easy, now: now)

        XCTAssertEqual(CardScheduling(card: card), before, "Aucune échéance ne doit bouger")
        XCTAssertEqual(logCount(), 0, "Un entraînement ne laisse pas de trace dans l'historique")
        XCTAssertEqual(session.answeredCount, 1)
    }

    func testPracticeKeepsCardsRatedAgain() {
        let session = StudySession()
        session.start(with: [makeCard(due: 86_400)], context: context, mode: .practice, sourceKey: nil, now: now)

        session.answer(.again, now: now)

        XCTAssertFalse(session.isFinished, "Une carte ratée revient dans le tour")
    }

    func testPracticeNeverSavesProgress() {
        let session = StudySession()
        session.start(with: [makeCard(), makeCard(position: 1)], context: context, mode: .practice, sourceKey: "allDue", now: now)
        session.answer(.good, now: now)

        XCTAssertNil(StudySessionStore.load(for: "allDue", now: now))
    }

    // MARK: - Rien à réviser

    func testScheduledSessionIsEmptyWhenNothingIsDue() {
        let session = StudySession()
        session.start(with: [makeCard(due: 86_400)], context: context, sourceKey: nil, now: now)

        XCTAssertTrue(session.isEmpty)
        XCTAssertEqual(session.initialCount, 0)
        XCTAssertNil(session.current)
    }

    // MARK: - Reprise

    func testProgressIsSavedAfterEachRating() {
        let cards = (0..<3).map { makeCard("carte \($0)", state: .review, due: -60, interval: 10, position: $0) }

        let session = StudySession()
        session.start(with: cards, context: context, sourceKey: "allDue", now: now)
        session.answer(.good, now: now)

        let snapshot = StudySessionStore.load(for: "allDue", now: now)

        XCTAssertEqual(snapshot?.answeredCount, 1)
        XCTAssertEqual(snapshot?.initialCount, 3)
        XCTAssertEqual(snapshot?.remainingCardIDs.count, 2)
        XCTAssertEqual(snapshot?.position, 2)
    }

    func testResumePicksUpWhereTheSessionStopped() {
        let cards = (0..<4).map { makeCard("carte \($0)", state: .review, due: -60, interval: 10, position: $0) }
        let snapshot = StudySessionSnapshot(
            sourceKey: "allDue",
            remainingCardIDs: [cards[2].id, cards[3].id],
            initialCount: 4,
            answeredCount: 2,
            againCount: 1,
            goodCount: 1,
            elapsed: 120,
            savedAt: now
        )

        let session = StudySession()
        session.resume(snapshot, cards: cards, context: context, now: now)

        XCTAssertEqual(session.current?.id, cards[2].id, "On reprend sur la carte laissée en cours")
        XCTAssertEqual(session.answeredCount, 2)
        XCTAssertEqual(session.initialCount, 4)
        XCTAssertEqual(session.againCount, 1)
        XCTAssertEqual(session.goodCount, 1)
    }

    func testFinishedSessionLeavesNothingToResume() {
        let session = StudySession()
        session.start(with: [makeCard()], context: context, sourceKey: "allDue", now: now)
        session.answer(.easy, now: now)

        XCTAssertTrue(session.isFinished)
        XCTAssertNil(StudySessionStore.load(for: "allDue", now: now))
    }
}

/// La sauvegarde elle-même : ce qu'on relit, ce qu'on refuse.
final class StudySessionStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let suiteName = "micabo.tests.session"
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: suiteName)
        StudySessionStore.clear(defaults: defaults)
    }

    override func tearDown() {
        StudySessionStore.clear(defaults: defaults)
        defaults = nil
    }

    private func snapshot(answered: Int = 11, initial: Int = 22, savedAt: Date? = nil) -> StudySessionSnapshot {
        StudySessionSnapshot(
            sourceKey: "allDue",
            remainingCardIDs: [UUID(), UUID()],
            initialCount: initial,
            answeredCount: answered,
            againCount: 3,
            goodCount: 8,
            elapsed: 300,
            savedAt: savedAt ?? now
        )
    }

    func testRoundTrip() {
        let saved = snapshot()
        StudySessionStore.save(saved, defaults: defaults)

        XCTAssertEqual(StudySessionStore.load(for: "allDue", now: now, defaults: defaults), saved)
    }

    func testPositionReadsAsCardTwelveOutOfTwentyTwo() {
        XCTAssertEqual(snapshot().position, 12)
    }

    func testAnotherSourceIsIgnored() {
        StudySessionStore.save(snapshot(), defaults: defaults)

        XCTAssertNil(StudySessionStore.load(for: "course:1234", now: now, defaults: defaults))
    }

    func testAStaleSessionIsNotProposedAgain() {
        StudySessionStore.save(snapshot(), defaults: defaults)

        let later = now.addingTimeInterval(StudySessionStore.expiry + 60)
        XCTAssertNil(StudySessionStore.load(for: "allDue", now: later, defaults: defaults))
    }

    func testSavingAnEmptyQueueClearsTheSnapshot() {
        StudySessionStore.save(snapshot(), defaults: defaults)

        var empty = snapshot()
        empty.remainingCardIDs = []
        StudySessionStore.save(empty, defaults: defaults)

        XCTAssertNil(StudySessionStore.load(for: "allDue", now: now, defaults: defaults))
    }
}
