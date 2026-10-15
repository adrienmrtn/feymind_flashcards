import SwiftData
import XCTest
@testable import Micabo

@MainActor
final class LessonComposerTests: XCTestCase {
    private func document(_ text: String, name: String = "Cours", source: CourseSource = .pdf, images: Int = 0) -> ImportedDocument {
        ImportedDocument(
            text: text,
            pageImages: Array(repeating: Data([0xFF]), count: images),
            coverImage: images > 0 ? Data([0x01]) : nil,
            pageCount: 1,
            fileName: name,
            source: source,
            extractionNote: nil
        )
    }

    private let longText = String(repeating: "La photosynthèse transforme la lumière en énergie. ", count: 10)

    func testATypedTopicLeavesAsATopic() {
        let composer = LessonComposer()
        XCTAssertFalse(composer.canSend)
        composer.draft = "  La guerre froide "
        XCTAssertTrue(composer.canSend)
        let request = composer.creation()
        XCTAssertEqual(request.topic, "La guerre froide")
        XCTAssertEqual(request.source, .topic)
        XCTAssertEqual(request.text, "")
    }

    /// Un support en lecture bloque l'envoi ; lu, il part avec la consigne en tête.
    func testSupportsAreReadThenSentWithTheInstruction() throws {
        let composer = LessonComposer()
        let id = try XCTUnwrap(composer.begin(.pdf, title: "Bio.pdf"))
        XCTAssertTrue(composer.isReading)
        XCTAssertFalse(composer.canSend)

        composer.finish(id, with: document(longText, name: "Bio", images: 2))
        composer.draft = "les étapes"
        XCTAssertTrue(composer.canSend)
        XCTAssertEqual(composer.source, .pdf)

        let request = composer.creation(examDate: Date(timeIntervalSince1970: 0))
        XCTAssertNil(request.topic)
        XCTAssertEqual(request.source, .pdf)
        XCTAssertEqual(request.sourceName, "Bio")
        XCTAssertEqual(request.images.count, 2)
        XCTAssertNotNil(request.coverImage)
        XCTAssertNotNil(request.examDate)
        XCTAssertTrue(request.text.contains("les étapes"))
        XCTAssertTrue(request.text.contains("photosynthèse"))
    }

    func testSeveralKindsMakeAMixedLessonWithHeaders() throws {
        let composer = LessonComposer()
        let pdf = try XCTUnwrap(composer.begin(.pdf, title: "A"))
        composer.finish(pdf, with: document(longText, name: "Chapitre 1", source: .docx))
        XCTAssertEqual(composer.source, .docx, "un Word garde sa source")
        let text = try XCTUnwrap(composer.begin(.text, title: "B"))
        composer.finish(text, with: document(longText, name: "Notes", source: .text))

        let request = composer.creation()
        XCTAssertEqual(request.source, .mixed)
        XCTAssertNil(request.sourceName)
        XCTAssertTrue(request.text.contains("--- Chapitre 1 ---"))
        XCTAssertTrue(request.text.contains("--- Notes ---"))
    }

    func testAnUnreadableSupportFailsOnItsChipAndDoesNotCount() throws {
        let composer = LessonComposer()
        let id = try XCTUnwrap(composer.begin(.photo, title: "Photo"))
        composer.finish(id, with: document("trop court", source: .photo))
        guard case .failed = composer.supports.first?.state else { return XCTFail("la pastille doit échouer") }
        XCTAssertTrue(composer.readySupports.isEmpty)
        XCTAssertFalse(composer.canSend)
        composer.remove(id)
        XCTAssertTrue(composer.supports.isEmpty)
    }

    func testFiveSupportsAtMost() {
        let composer = LessonComposer()
        for index in 0..<LessonComposer.maximumSupports {
            XCTAssertNotNil(composer.begin(.text, title: "\(index)"))
        }
        XCTAssertFalse(composer.hasRoom)
        XCTAssertNil(composer.begin(.text, title: "de trop"))
    }

    // MARK: La porte du gratuit

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Une leçon offerte depuis un sujet ou un texte ; les imports sont Pro ; un cours à soi
    /// consomme l'offre, pas un cours de démonstration ni un paquet fait à la main.
    func testTheFreeGateMirrorsTheServer() throws {
        let context = try makeContext()
        let sample = Course(title: "Démo", source: .sample)
        let deck = Course(title: "Vocabulaire", source: .deck)
        let library = Course(title: "Bibliothèque", isFromLibrary: true)
        for course in [sample, deck, library] { context.insert(course) }

        XCTAssertNil(LessonAllowance.gate(isPro: false, source: .topic, courses: [sample, deck, library]))
        XCTAssertNil(LessonAllowance.gate(isPro: false, source: .text, courses: []))
        XCTAssertEqual(LessonAllowance.gate(isPro: false, source: .pdf, courses: []), .generateCourse)
        XCTAssertEqual(LessonAllowance.gate(isPro: false, source: .audio, courses: []), .generateCourse)

        let own = Course(title: "Mon cours", source: .pdf)
        context.insert(own)
        XCTAssertEqual(LessonAllowance.gate(isPro: false, source: .topic, courses: [own]), .secondCourse)
        XCTAssertNil(LessonAllowance.gate(isPro: true, source: .pdf, courses: [own]))
    }

    func testTranscriptionLocalesCarryARegion() {
        XCTAssertEqual(AudioTranscriber.locale(for: .fr).identifier, "fr-FR")
        XCTAssertEqual(AudioTranscriber.locale(for: .tr).identifier, "tr-TR")
    }

    func testTheGenerationStepsFollowTheBuilder() {
        XCTAssertEqual(GenerationSteps.key(for: .reading, hasSupports: true), "lesson.create.stageReading")
        XCTAssertEqual(GenerationSteps.key(for: .reading, hasSupports: false), "lesson.create.stageTopic")
        XCTAssertEqual(LessonBuilder.Stage.allCases.count, 4)
    }
}
