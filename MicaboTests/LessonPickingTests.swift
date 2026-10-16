import SwiftData
import XCTest
@testable import Micabo

/// Le tirage des quiz et des cartes d'une leçon.
final class LessonPickingTests: XCTestCase {
    /// Un thème : sa question de fin, puis trois de réserve.
    private func theme(_ name: String) -> [QuizQuestion] {
        (0..<4).map {
            QuizQuestion(id: "\(name):\($0)", prompt: "\(name) \($0) ?", choices: ["a", "b", "c", "d"], answer: 0, why: ".")
        }
    }

    func testACircleQuizTakesFiveReserveQuestionsFromBothThemes() {
        let picked = LessonPicking.quiz(themes: [theme("A"), theme("B")], missed: [], count: 5, seed: 1)
        XCTAssertEqual(picked.count, 5)
        XCTAssertEqual(Set(picked.map(\.id)).count, 5, "jamais deux fois la même")
        XCTAssertFalse(picked.contains { $0.id.hasSuffix(":0") }, "la réserve suffit : pas de question de fin")
        XCTAssertGreaterThanOrEqual(picked.filter { $0.id.hasPrefix("A") }.count, 2, "les deux thèmes sont couverts")
        XCTAssertGreaterThanOrEqual(picked.filter { $0.id.hasPrefix("B") }.count, 2)
    }

    func testMissedQuestionsComeFirstMostRecentOnTop() {
        let picked = LessonPicking.quiz(
            themes: [theme("A"), theme("B")],
            missed: ["A:2", "B:3", "Z:1"],
            count: 5,
            seed: 7
        )
        XCTAssertEqual(Array(picked.prefix(2).map(\.id)), ["B:3", "A:2"])
    }

    func testTheFullQuizFallsBackOnFinalQuestionsWhenTheReserveIsShort() {
        let short = [Array(theme("A").prefix(2)), Array(theme("B").prefix(2))]
        let picked = LessonPicking.quiz(themes: short, missed: [], count: 10, seed: 3)
        XCTAssertEqual(picked.count, 4, "tout ce qu'il y a, et rien de plus")
    }

    func testTheSameSeedGivesTheSameQuizAndAnotherSeedUsuallyNot() {
        let themes = [theme("A"), theme("B"), theme("C")]
        let first = LessonPicking.quiz(themes: themes, missed: [], count: 5, seed: 42).map(\.id)
        XCTAssertEqual(first, LessonPicking.quiz(themes: themes, missed: [], count: 5, seed: 42).map(\.id))
        let others = (0..<10).map { LessonPicking.quiz(themes: themes, missed: [], count: 5, seed: UInt64($0)).map(\.id) }
        XCTAssertTrue(others.contains { $0 != first }, "un quiz relancé change")
    }

    func testCardsPreferMissedThenDueThenNew() {
        let ids = (0..<14).map { _ in UUID() }
        var candidates = ids.enumerated().map { index, id in
            LessonPicking.CardCandidate(id: id, isMissedQuestion: false, isDue: false, isNew: false, position: index)
        }
        candidates[13].isMissedQuestion = true
        candidates[5].isDue = true
        candidates[0].isNew = true
        candidates[1].isNew = true

        let picked = LessonPicking.cards(candidates, count: 10, seed: 1)
        XCTAssertEqual(picked.count, 10)
        XCTAssertEqual(picked[0], ids[13])
        XCTAssertEqual(picked[1], ids[5])
        XCTAssertEqual(Array(picked[2...3]), [ids[0], ids[1]])
        XCTAssertEqual(Set(picked).count, 10)
    }

    // MARK: - Ce que la leçon écrit sur les cartes

    @MainActor
    func testAMissedQuestionBecomesAChoiceCardDueTomorrowOnlyOnce() throws {
        let container = try ModelContainer(
            for: Course.self, Chapter.self, Flashcard.self, ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "Leçon")
        context.insert(course)
        let question = QuizQuestion(id: "t:1", prompt: "Qui ?", choices: ["a", "b", "c", "d"], answer: 2, why: "Parce que.")
        let now = Date()

        let card = LessonReview.cardForMissed(question, chapter: nil, course: course, in: context, now: now)
        XCTAssertEqual(card.kind, .choice)
        XCTAssertEqual(card.choices, question.choices)
        XCTAssertEqual(card.correctChoiceIndex, 2)
        XCTAssertGreaterThan(card.dueDate, now)
        XCTAssertLessThanOrEqual(card.dueDate, now.addingTimeInterval(2 * 86_400))

        let again = LessonReview.cardForMissed(question, chapter: nil, course: course, in: context, now: now)
        XCTAssertEqual(again.id, card.id)
        XCTAssertEqual(course.cards.count, 1)
    }

    @MainActor
    func testRatingACardSchedulesItAndLogsTheReview() throws {
        let container = try ModelContainer(
            for: Course.self, Chapter.self, Flashcard.self, ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "Leçon")
        context.insert(course)
        let card = Flashcard(front: "Q", back: "R", course: course)
        context.insert(card)
        let now = Date()

        LessonReview.rate(card, .easy, now: now)

        XCTAssertEqual(card.state, .review, "« Facile » diplôme une carte neuve")
        XCTAssertGreaterThan(card.dueDate, now.addingTimeInterval(86_400))
        XCTAssertEqual(card.logs?.count, 1)
        XCTAssertEqual(card.logs?.first?.rating, .easy)
    }
}
