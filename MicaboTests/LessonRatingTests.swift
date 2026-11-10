import XCTest
@testable import Micabo

/// **« Cette leçon t'a aidé ? »** : une fois par leçon, après la première étape de contenu,
/// et ce que l'avis emporte dans `lesson_rated`.
final class LessonRatingTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "micabo.tests.lessonRating"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func circle(_ kind: PathCircle.Kind, _ number: Int) -> PathCircle {
        PathCircle(kind: kind, number: number, title: "Étape \(number)", icon: .cards)
    }

    func testOncePerLessonAndPerMoment() {
        let lesson = UUID()
        XCTAssertTrue(LessonRating.shouldOffer(lesson, at: .firstCircle, in: defaults))
        LessonRating.markOffered(lesson, at: .firstCircle, in: defaults)
        XCTAssertFalse(LessonRating.shouldOffer(lesson, at: .firstCircle, in: defaults))
        // Ignorée après la première étape, elle revient une fois à « Leçon terminée ».
        XCTAssertTrue(LessonRating.shouldOffer(lesson, at: .finished, in: defaults))

        // Une réponse donnée : plus jamais, nulle part.
        LessonRating.markRated(lesson, in: defaults)
        XCTAssertFalse(LessonRating.shouldOffer(lesson, at: .finished, in: defaults))
        XCTAssertTrue(LessonRating.shouldOffer(UUID(), at: .finished, in: defaults))
    }

    func testOnlyTheFirstContentCircleAsks() {
        let intro = circle(.intro, 1)
        let notes = circle(.notes(theme: 0), 2)
        let notes2 = circle(.notes(theme: 1), 3)
        let quiz = circle(.quiz(group: 0, themes: [0, 1]), 4)
        let circles = [intro, notes, notes2, quiz]

        XCTAssertFalse(LessonRating.isFirstContentCircle(intro, doneBefore: [], circles: circles), "L'Intro n'apprend rien")
        XCTAssertTrue(LessonRating.isFirstContentCircle(notes, doneBefore: [intro.id], circles: circles))
        XCTAssertFalse(LessonRating.isFirstContentCircle(notes2, doneBefore: [intro.id, notes.id], circles: circles))
        XCTAssertFalse(LessonRating.isFirstContentCircle(notes, doneBefore: [intro.id, notes.id], circles: circles), "Refaite, ce n'est plus la première")
    }

    func testWhatTheRatingCarries() {
        let lesson = UUID()
        let created = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 11, day: 3, hour: 12).date!
        let props = LessonRating.properties(
            lessonID: lesson,
            value: .down,
            reasons: [.wrongLanguage, .tooLong],
            comment: String(repeating: "a", count: 300),
            moment: .finished,
            source: "pdf",
            promptVersion: "lesson-v4.2.0",
            pathVersion: 1,
            created: created,
            language: .de,
            level: "lycee"
        )
        func text(_ key: String) -> String? {
            if case .text(let value) = props[key] { return value }
            return nil
        }
        XCTAssertEqual(text("lesson_id"), lesson.uuidString.lowercased())
        XCTAssertEqual(text("rating"), "down")
        XCTAssertEqual(text("reasons"), "too_long,wrong_language", "Dans l'ordre des pastilles")
        XCTAssertEqual(text("comment")?.count, LessonRating.commentLimit)
        XCTAssertEqual(text("prompt_version"), "lesson-v4.2.0")
        XCTAssertEqual(text("source"), "pdf")
        XCTAssertEqual(text("app_language"), "de")
        XCTAssertEqual(text("level"), "lycee")
        XCTAssertEqual(text("moment"), "finished")
        XCTAssertEqual(text("created"), "2026-11-03")

        // Un 👍 ne porte ni raisons ni mot.
        let up = LessonRating.properties(
            lessonID: lesson, value: .up, reasons: [.errors], comment: "bien", moment: .firstCircle,
            source: "topic", promptVersion: nil, pathVersion: nil, created: created, language: .fr, level: nil
        )
        XCTAssertNil(up["reasons"])
        XCTAssertNil(up["comment"])
        if case .text(let version) = up["prompt_version"] { XCTAssertEqual(version, "inconnue") } else { XCTFail() }
    }

    func testTheGenerationLogKeepsTheServerVersion() {
        let lesson = UUID()
        XCTAssertNil(LessonGenerationLog.entry(for: lesson, in: defaults))
        LessonGenerationLog.record(lessonID: lesson, source: "youtube", promptVersion: "lesson-v4.2.0", in: defaults)
        XCTAssertEqual(LessonGenerationLog.entry(for: lesson, in: defaults), .init(source: "youtube", promptVersion: "lesson-v4.2.0"))

        XCTAssertEqual(LessonGenerationLog.promptVersion(in: ["meta": ["promptVersion": "lesson-v5"]]), "lesson-v5")
        XCTAssertNil(LessonGenerationLog.promptVersion(in: ["plan": [:]]))
    }

    /// Les phrases de la carte, dans chaque langue.
    func testTheCardSpeaksEveryLanguage() {
        let keys = ["ios.conv.rate.question", "ios.conv.rate.why", "ios.conv.rate.send", "ios.conv.rate.thanks"]
            + LessonRating.Reason.allCases.map(\.titleKey)
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in keys {
                XCTAssertNotNil(table[key], "\(locale.rawValue) \(key)")
            }
        }
    }
}
