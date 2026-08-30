import SwiftData
import XCTest
@testable import Micabo

final class ScreenshotSeedTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var defaults: UserDefaults!
    private let suite = "micabo.tests.screenshotSeed"

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            Exam.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        context = nil
        container = nil
    }

    func testSeedOpensTheAppAndFillsAStorefrontDay() throws {
        ScreenshotSeed.openApp(defaults: defaults)
        ScreenshotSeed.seed(in: context, defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: OnboardingPreferences.Key.completed))
        XCTAssertTrue(defaults.bool(forKey: AccountGate.skippedKey))

        let courses = try context.fetch(FetchDescriptor<Course>())
        XCTAssertEqual(Set(courses.map(\.title)), [
            "La photosynthèse",
            "Les fonctions affines",
            "La Révolution de 1789",
        ])
        XCTAssertFalse(courses.contains { $0.source == .sample })

        let due = courses.flatMap(\.dueCards)
        XCTAssertEqual(due.count, 12)

        let exams = try context.fetch(FetchDescriptor<Exam>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(exams.map(\.name), ["Devoir de SVT", "Contrôle de maths"])
        XCTAssertEqual(exams[0].countdownLabel(), "J-3")

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
        XCTAssertEqual(StudyStats.streak(reviewDates: logs.map(\.reviewedAt)), 12)

        ScreenshotSeed.seed(in: context, defaults: defaults)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).count, 3)
    }
}
