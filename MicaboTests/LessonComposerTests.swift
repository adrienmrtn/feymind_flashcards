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

    /// **Une leçon, une réservation** : « Réessayer », ou l'écran de génération refermé puis
    /// rouvert, reprennent l'identifiant que le serveur a réservé (`begin_lesson`). Seule une
    /// leçon arrivée, ou une demande d'une autre nature, en tire un neuf.
    func testTheLessonIDSurvivesUntilTheLessonArrives() {
        let composer = LessonComposer()
        composer.draft = "La guerre froide"
        let first = composer.reserveLessonID(for: .topic)
        XCTAssertEqual(composer.reserveLessonID(for: .topic), first, "Un second essai reprend la même réservation")

        let pdf = composer.reserveLessonID(for: .pdf)
        XCTAssertNotEqual(pdf, first, "Une autre source, une autre leçon")
        XCTAssertEqual(composer.reserveLessonID(for: .pdf), pdf)

        composer.lessonDelivered()
        let next = composer.reserveLessonID(for: .pdf)
        XCTAssertNotEqual(next, pdf, "La leçon est arrivée : la suivante en est une autre")

        composer.reset()
        XCTAssertNotEqual(composer.reserveLessonID(for: .pdf), next)
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

    /// Une leçon offerte, depuis un sujet, un texte **ou un import** (`docs/refonte-knowunity.md`
    /// § 7) ; une fois servie, les imports sont Pro ; un cours à soi consomme l'offre, pas un
    /// cours de démonstration ni un paquet fait à la main.
    func testTheFreeGateMirrorsTheServer() throws {
        let context = try makeContext()
        let sample = Course(title: "Démo", source: .sample)
        let deck = Course(title: "Vocabulaire", source: .deck)
        let library = Course(title: "Bibliothèque", isFromLibrary: true)
        for course in [sample, deck, library] { context.insert(course) }

        XCTAssertNil(LessonAllowance.gate(isPro: false, source: .topic, courses: [sample, deck, library]))
        XCTAssertNil(LessonAllowance.gate(isPro: false, source: .text, courses: []))
        // La leçon offerte peut venir d'un import : elle part avec `onboarding: true`.
        XCTAssertNil(LessonAllowance.gate(isPro: false, source: .pdf, courses: []))
        XCTAssertNil(LessonAllowance.gate(isPro: false, source: .audio, courses: [sample, deck, library]))
        XCTAssertTrue(LessonAllowance.sendsAsFreeLesson(isPro: false, source: .youtube, courses: []))
        XCTAssertFalse(LessonAllowance.sendsAsFreeLesson(isPro: false, source: .topic, courses: []))
        XCTAssertFalse(LessonAllowance.sendsAsFreeLesson(isPro: true, source: .pdf, courses: []))

        let own = Course(title: "Mon cours", source: .pdf)
        context.insert(own)
        XCTAssertEqual(LessonAllowance.gate(isPro: false, source: .topic, courses: [own]), .secondCourse)
        XCTAssertEqual(LessonAllowance.gate(isPro: false, source: .pdf, courses: [own]), .generateCourse)
        XCTAssertEqual(LessonAllowance.gate(isPro: false, source: .audio, courses: [own]), .generateCourse)
        XCTAssertFalse(LessonAllowance.sendsAsFreeLesson(isPro: false, source: .photo, courses: [own]))
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

    // MARK: - La leçon verrouillée

    /// **La règle ne change pas, le moment du paywall si.** La leçon offerte et Pro partent
    /// toujours ; une fois l'offre servie, un sujet seul ouvre son paywall tout de suite, des
    /// supports lus passent par l'aperçu verrouillé (et le paywall `lessonReady`).
    func testTheLockedPreviewOnlyCatchesReadSupportsAfterTheFreeLesson() throws {
        let context = try makeContext()
        let sample = Course(title: "Démo", source: .sample)
        context.insert(sample)

        // La leçon offerte n'a pas servi : tout part, l'écran de création est inchangé.
        for source in LessonSourceKind.allCases {
            XCTAssertEqual(LessonAllowance.sendRoute(isPro: false, source: source, courses: [sample]), .create, source.rawValue)
        }

        let own = Course(title: "Mon cours", source: .pdf)
        context.insert(own)
        // Pro : tout part.
        for source in LessonSourceKind.allCases {
            XCTAssertEqual(LessonAllowance.sendRoute(isPro: true, source: source, courses: [own]), .create, source.rawValue)
            XCTAssertNil(LessonAllowance.immediatePaywall(isPro: true, source: source, courses: [own]))
        }
        // Offre servie : un sujet seul, paywall immédiat, celui d'avant.
        XCTAssertEqual(LessonAllowance.sendRoute(isPro: false, source: .topic, courses: [own]), .paywall(.secondCourse))
        XCTAssertEqual(LessonAllowance.immediatePaywall(isPro: false, source: .topic, courses: [own]), .secondCourse)
        // Des supports lus : l'aperçu, et aucun paywall avant l'écran de création.
        for source in LessonSourceKind.allCases where source != .topic {
            XCTAssertEqual(LessonAllowance.sendRoute(isPro: false, source: source, courses: [own]), .lockedPreview, source.rawValue)
            XCTAssertNil(LessonAllowance.immediatePaywall(isPro: false, source: source, courses: [own]), source.rawValue)
        }
        // La porte, elle, n'a pas bougé (le serveur refuserait la leçon).
        XCTAssertEqual(LessonAllowance.gate(isPro: false, source: .pdf, courses: [own]), .generateCourse)
    }

    /// Plus de couronne ni de paywall sur un import : le lire est gratuit et se fait sur
    /// l'appareil.
    func testImportsAreNeverLocked() {
        for kind in LessonComposer.Kind.allCases {
            XCTAssertFalse(LessonAllowance.locksImport(kind, isPro: false, freeLessonLeft: false), kind.rawValue)
            XCTAssertFalse(LessonAllowance.locksImport(kind, isPro: false, freeLessonLeft: true), kind.rawValue)
            XCTAssertFalse(LessonAllowance.locksImport(kind, isPro: true, freeLessonLeft: false), kind.rawValue)
        }
    }

    /// **L'aperçu ne dit que ce qui a été lu** : les supports, les pages d'un PDF ou de
    /// photos, les mots, la première vraie ligne pour titre, et les lignes suivantes à flouter.
    func testTheReadSummaryComesFromWhatWasRead() {
        let pdf = ImportedDocument(
            text: "12\n\nLa Guerre froide (1947-1991)\nUn monde coupé en deux blocs.\n---\nLa doctrine Truman, 1947.\nLe plan Marshall.\nLe blocus de Berlin.\nLa crise de Cuba.",
            pageImages: [],
            coverImage: nil,
            pageCount: 7,
            fileName: "histoire.pdf",
            source: .pdf,
            extractionNote: nil
        )
        let video = ImportedDocument(
            text: "bonjour à tous aujourd'hui on parle de la guerre froide",
            pageImages: [],
            coverImage: nil,
            pageCount: 1,
            fileName: "La guerre froide en 10 minutes",
            source: .youtube,
            extractionNote: nil
        )

        let summary = LessonReadSummary(documents: [pdf, video])
        XCTAssertEqual(summary.supports, 2)
        XCTAssertEqual(summary.pages, 7, "La vidéo n'a pas de pages")
        XCTAssertEqual(summary.title, "La Guerre froide (1947-1991)", "« 12 » et « --- » ne sont pas des lignes")
        XCTAssertEqual(summary.previewLines.first, "Un monde coupé en deux blocs.")
        XCTAssertEqual(summary.previewLines.count, LessonReadSummary.previewLineCount)
        XCTAssertEqual(
            summary.words,
            LessonReadSummary.wordCount(pdf.text) + LessonReadSummary.wordCount(video.text)
        )
        XCTAssertEqual(LessonReadSummary.wordCount("Le plan Marshall — 1947 !"), 4, "Un tiret seul n'est pas un mot")

        // Une vidéo d'abord : son titre, pas la première ligne de sa transcription.
        let videoFirst = LessonReadSummary(documents: [video])
        XCTAssertEqual(videoFirst.title, "La guerre froide en 10 minutes")
        XCTAssertEqual(videoFirst.pages, 0)

        // Rien de lisible : le nom du fichier.
        let blank = ImportedDocument(text: "12\n--", pageImages: [], coverImage: nil, pageCount: 2, fileName: "scan.jpg", source: .photo, extractionNote: nil)
        XCTAssertEqual(LessonReadSummary(documents: [blank]).title, "scan.jpg")
        XCTAssertTrue(LessonReadSummary(documents: [blank]).previewLines.isEmpty)
    }

    /// Le paywall de la leçon lue a sa phrase, dans chaque langue.
    func testTheLessonReadyPaywallHasItsHeadline() {
        XCTAssertEqual(PaywallTrigger.lessonReady.rawValue, "lessonReady")
        for locale in UiLocale.allCases {
            XCTAssertNotNil(IosI18nCatalogs.table(for: locale.rawValue)["ios.conv.paywallLessonReady"], locale.rawValue)
        }
    }
}
