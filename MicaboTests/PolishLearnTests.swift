import SwiftData
import XCTest
@testable import Micabo

/// **Lot 6, « Apprendre et réviser »** : les règles de la charte qu'un test peut tenir.
///
/// - Une seule famille de courbes (`LearnMotion` → `MicaboMotion`) dans les écrans de la leçon,
///   des flashcards, du quiz, de l'examen blanc, du tuteur, du scanner et de l'import ; aucune
///   boucle infinie hors d'une attente.
/// - Le bouton plein d'une leçon dit ce qu'on fait maintenant, dans l'ordre du chemin.
/// - Les noms d'examen proposés suivent le système scolaire de l'élève.
@MainActor
final class PolishLearnTests: XCTestCase {
    // MARK: - Les mouvements

    /// Les dossiers du lot : chacun de leurs fichiers est relu.
    private static let folders = ["Lesson", "Course", "Courses", "Deck", "Exams", "Library", "Mika", "Solver", "Import"]

    func testOnlyMicaboMotionCurvesInLearnScreens() throws {
        let features = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo/Features", isDirectory: true)
        let forbidden = try NSRegularExpression(pattern: #"\.(spring|easeOut|easeInOut|easeIn|linear)\(|\.(snappy|bouncy|smooth)\b|withAnimation \{|withAnimation\(\)|\.animation\(\.default"#)
        var read = 0
        var offenders: [String] = []
        for folder in Self.folders {
            let directory = features.appendingPathComponent(folder, isDirectory: true)
            guard let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in files where url.pathExtension == "swift" && url.lastPathComponent != "LearnMotion.swift" {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                read += 1
                for (number, line) in text.components(separatedBy: "\n").enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("///") else { continue }
                    // Une attente réseau ou une lecture de photo peut boucler : la ligne le dit.
                    if line.hasSuffix("// attente") { continue }
                    let range = NSRange(line.startIndex..., in: line)
                    if forbidden.firstMatch(in: line, range: range) != nil || line.contains("repeatForever") {
                        offenders.append("\(folder)/\(url.lastPathComponent):\(number + 1)")
                    }
                }
            }
        }
        guard read > 0 else { throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur") }
        XCTAssertGreaterThan(read, 40, "la lecture des sources a raté des fichiers")
        XCTAssertEqual(offenders, [], "une courbe hors de MicaboMotion, ou une boucle infinie hors d'une attente")
    }

    func testLearnMotionResolvesToMicaboMotion() {
        // Sans « Réduire les animations » dans le simulateur, chaque courbe est celle de Micabo.
        guard !LearnMotion.reduceMotion else { return }
        XCTAssertEqual(LearnMotion.standard, MicaboMotion.standard)
        XCTAssertEqual(LearnMotion.quick, MicaboMotion.quick)
        XCTAssertEqual(LearnMotion.gentle, MicaboMotion.gentle)
        XCTAssertEqual(LearnMotion.celebrate, MicaboMotion.celebrate)
    }

    // MARK: - Ce qu'on fait maintenant

    private func lesson(done: [String], pending: Set<Int> = []) throws -> (ModelContainer, LessonSession) {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let course = Course(title: "La guerre froide", subject: "Histoire")
        context.insert(course)
        for index in 0..<3 {
            let chapter = Chapter(position: index, title: "Thème \(index + 1)", course: course)
            chapter.statusRaw = (pending.contains(index) ? ThemeStatus.pending : ThemeStatus.ready).rawValue
            context.insert(chapter)
        }
        course.setLessonPath(LessonPath(
            icon: MicaboIcon.globe.rawValue,
            intro: LessonPath.Intro(lines: ["Un", "Deux"], minutes: 15),
            takeaways: [],
            groups: [LessonPath.Group(name: "", themes: [0, 1, 2])],
            status: .ready
        ))
        course.updateProgress { $0.done = Set(done) }
        try context.save()
        return (container, LessonSession(course: course))
    }

    func testNextActionStartsThenResumesTheCurrentStep() throws {
        let (fresh, start) = try lesson(done: [])
        _ = fresh
        guard case .start(let first) = LessonNextAction.resolve(session: start, dueCount: 0) else {
            return XCTFail("une leçon neuve commence")
        }
        XCTAssertEqual(first.id, start.circles.first?.id)

        let (going, resumed) = try lesson(done: ["intro", "notes:0"])
        _ = going
        guard case .resume(let current) = LessonNextAction.resolve(session: resumed, dueCount: 4) else {
            return XCTFail("une leçon commencée continue, même avec des cartes dues")
        }
        XCTAssertEqual(current.id, resumed.current?.id)
        XCTAssertTrue(LessonNextAction.resume(current).title.contains(String(current.number)))
    }

    func testNextActionWaitsWhileMikaWritesTheStep() throws {
        let (container, session) = try lesson(done: ["intro"], pending: [0])
        _ = container
        let next = LessonNextAction.resolve(session: session, dueCount: 0)
        guard case .writing = next else { return XCTFail("l'étape s'écrit encore : \(next)") }
        XCTAssertFalse(next.isEnabled)
    }

    func testFinishedLessonReviewsItsCardsThenPractices() throws {
        let (container, session) = try lesson(done: [])
        _ = container
        session.course.updateProgress { progress in
            progress.done = Set(session.circles.map(\.id))
            progress.finishedAt = Date()
        }
        session.reload()
        XCTAssertNil(session.current)
        XCTAssertEqual(LessonNextAction.resolve(session: session, dueCount: 6), .review(6))
        XCTAssertEqual(LessonNextAction.resolve(session: session, dueCount: 0), .practice)
    }

    func testEveryNextActionHasItsWordsInEveryLanguage() {
        let circle = PathCircle(kind: .notes(theme: 0), number: 4, title: "Berlin", icon: .flag)
        let actions: [LessonNextAction] = [.start(circle), .resume(circle), .writing(circle), .retry(circle), .review(3), .practice]
        for locale in UiLocale.allCases {
            let defaults = UserDefaults.standard
            let previous = defaults.string(forKey: UiLocale.storageKey)
            defaults.set(locale.rawValue, forKey: UiLocale.storageKey)
            for action in actions {
                let title = action.title
                XCTAssertFalse(title.isEmpty, "\(locale.rawValue) \(action)")
                XCTAssertFalse(title.contains("ios.pol.") || title.contains("{"), "\(locale.rawValue) : \(title)")
            }
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) } else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }
    }

    // MARK: - Les noms d'examen

    func testExamPlaceholderFollowsTheSchoolSystem() {
        let fr = ExamNaming.placeholder(country: .fr, trackID: "fr.lyceeGeneral", yearID: "fr.terminale", tier: nil, locale: .fr)
        XCTAssertTrue(fr.contains("Bac"), fr)

        let college = ExamNaming.placeholder(country: .fr, trackID: "fr.college", yearID: "fr.3e", tier: nil, locale: .fr)
        XCTAssertTrue(college.localizedCaseInsensitiveContains("brevet"), college)
        XCTAssertFalse(college.contains("Bac"), college)

        let de = ExamNaming.placeholder(country: .de, trackID: "de.gymnasium", yearID: "de.klasse12", tier: nil, locale: .de)
        XCTAssertTrue(de.contains("Abitur"), de)
        XCTAssertFalse(de.contains("Bac"), de)

        let us = ExamNaming.placeholder(country: .us, trackID: "us.high", yearID: "us.hs11", tier: nil, locale: .en)
        XCTAssertTrue(us.contains("SAT"), us)
        XCTAssertFalse(us.contains("Bac"), us)

        let university = ExamNaming.placeholder(country: .fr, trackID: "fr.universite", yearID: nil, tier: nil, locale: .fr)
        XCTAssertFalse(university.contains("Bac"), university)
        XCTAssertFalse(university.isEmpty)
    }

    func testExamPlaceholderFallsBackWithoutASchoolSystem() {
        let none = ExamNaming.placeholder(country: .other, trackID: nil, yearID: nil, tier: nil, locale: .en)
        XCTAssertEqual(none, L10n.t("lesson.exam.namePlaceholder", locale: .en))
    }

    /// La note d'un examen blanc suit le barème du pays : jamais « /20 » pour un Américain ou
    /// un Allemand.
    func testMockGradeNeverShowsTwentyOutsideCountriesThatGradeOnTwenty() {
        for country in [SchoolingCountry.de, .us, .uk, .ch, .se, .it] {
            XCTAssertFalse(ExamGrade.label(0.7, country: country, locale: .en).contains("/20"), country.rawValue)
        }
        XCTAssertTrue(ExamGrade.label(0.7, country: .fr, locale: .fr).hasSuffix("/20"))
    }
}
