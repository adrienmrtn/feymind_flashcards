import SwiftData
import XCTest
@testable import Micabo

@MainActor
final class HomeStatsTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func lesson(_ title: String, themes: Int, in context: ModelContext) -> Course {
        let course = Course(title: title)
        context.insert(course)
        for index in 0..<themes {
            context.insert(Chapter(position: index, title: "Thème \(index + 1)", course: course))
        }
        course.setLessonPath(LessonPath(
            icon: "livre-ouvert",
            intro: LessonPath.Intro(lines: [], minutes: 10),
            takeaways: [],
            groups: PathLayout.groups(themeCount: themes).map { LessonPath.Group(name: "", themes: $0) },
            status: .ready
        ))
        return course
    }

    /// Le temps s'additionne sur toutes les leçons ; une leçon compte quand elle est terminée ;
    /// une carte, quand son prochain rappel est à plus de sept jours.
    func testTheThreeNumbersAreMeasured() throws {
        let context = try makeContext()
        let now = Date()
        let first = lesson("A", themes: 2, in: context)
        first.updateProgress { progress in
            progress.addTime(1_800, to: .notes)
            progress.addTime(600, to: .quiz)
            progress.finishedAt = now
        }
        let second = lesson("B", themes: 3, in: context)
        second.updateProgress { $0.addTime(1_200, to: .flashcards) }

        let learned = Flashcard(front: "Q", back: "R", position: 0, course: second)
        learned.dueDate = now.addingTimeInterval(10 * 24 * 3600)
        learned.stateRaw = CardState.review.rawValue
        let soon = Flashcard(front: "Q2", back: "R", position: 1, course: second)
        soon.dueDate = now.addingTimeInterval(2 * 24 * 3600)
        soon.stateRaw = CardState.review.rawValue
        context.insert(learned)
        context.insert(soon)
        try context.save()

        let stats = HomeStats(courses: [first, second], now: now)
        XCTAssertEqual(stats.seconds, 3_600)
        XCTAssertEqual(stats.learnedLessons, 1)
        XCTAssertEqual(stats.learnedCards, 1)
    }

    func testTimeReadsInMinutesThenHours() {
        XCTAssertEqual(HomeStats(seconds: 12 * 60).formattedTime(locale: .fr), "12 min")
        XCTAssertEqual(HomeStats(seconds: 5_400).formattedTime(locale: .fr), "1,5 h")
        XCTAssertEqual(HomeStats(seconds: 5_400).formattedTime(locale: .en), "1.5 h")
        XCTAssertEqual(HomeStats(seconds: 3_600).formattedTime(locale: .fr), "1 h")
        XCTAssertEqual(HomeStats(seconds: 14 * 3_600 + 100).formattedTime(locale: .fr), "14 h")
    }

    /// « Reprendre » montre la dernière leçon ouverte, et le cercle où elle attend.
    func testResumePointsAtTheLastOpenedLessonAndItsCurrentCircle() throws {
        let context = try makeContext()
        let old = lesson("Ancienne", themes: 2, in: context)
        old.lastOpenedAt = Date().addingTimeInterval(-3_600)
        let recent = lesson("Récente", themes: 2, in: context)
        recent.lastOpenedAt = Date()
        recent.updateProgress { $0.done = ["intro", "notes:0"] }
        let never = lesson("Jamais ouverte", themes: 2, in: context)
        never.lastOpenedAt = nil
        try context.save()

        let picked = try XCTUnwrap(ResumeTarget.pick(from: [old, recent, never]))
        XCTAssertEqual(picked.0.id, recent.id)
        XCTAssertEqual(picked.1.circleNumber, 3)
        XCTAssertEqual(picked.1.circleTitle, "Thème 2")
        XCTAssertGreaterThan(picked.1.percent, 0)
        XCTAssertNil(ResumeTarget.pick(from: [never]))
    }
}
