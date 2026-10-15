import SwiftData
import XCTest
@testable import Micabo

/// Un faux `generate-lesson` : un plan de quatre thèmes, des notes, quatre questions et trois
/// flashcards par thème — et un thème qui échoue quand on le lui demande.
private final class FakeLessonService: LessonGenerating, @unchecked Sendable {
    var failingThemes: Set<Int> = []
    var planError: Error?
    private(set) var themeCalls: [Int] = []
    private let lock = NSLock()

    func plan(_ request: LessonPlanRequest) async throws -> LessonPlanResult {
        if let planError { throw planError }
        return LessonPlanResult(
            plan: .init(
                title: "La guerre froide",
                subject: "HISTOIRE",
                icon: "parchemin",
                themes: (0..<4).map { .init(title: "Thème \($0 + 1)", icon: "ampoule") },
                groups: [.init(name: "Les causes", themes: [0, 1]), .init(name: "Les suites", themes: [2, 3])],
                intro: .init(lines: ["Un", "Deux", "Trois"], minutes: 25),
                takeaways: ["A", "B", "C", "D", "E"],
                shortened: false,
                singleQuiz: false
            ),
            contextText: request.text
        )
    }

    func theme(_ request: LessonThemeRequest) async throws -> LessonThemeResult {
        lock.lock()
        themeCalls.append(request.themeIndex)
        let fails = failingThemes.contains(request.themeIndex)
        lock.unlock()
        if fails { throw LessonServiceError.failed("panne") }
        return LessonThemeResult(
            notes: ThemeNotes(oneLiner: "Idée \(request.themeIndex)", blocks: [.paragraph("Texte.")], takeaways: ["R"]),
            questions: (0..<4).map {
                GeneratedQuestion(prompt: "Q\($0) ?", choices: ["a", "b", "c", "d"], answer: 1, why: "Parce que.")
            },
            flashcards: (0..<3).map { GeneratedCard(front: "Recto \($0)", back: "Verso \($0)") }
        )
    }

    func convert(_ request: LessonConvertRequest) async throws -> LessonConversion {
        LessonConversion(
            icon: "globe",
            intro: .init(lines: ["Un"], minutes: 15),
            takeaways: ["A"],
            groups: PathLayout.groups(themeCount: request.chapters.count).map { .init(name: "Palier", themes: $0) },
            chapters: request.chapters.map { chapter in
                LessonConversion.Chapter(
                    icon: "puzzle",
                    questions: [GeneratedQuestion(prompt: "Q ?", choices: ["a", "b", "c", "d"], answer: 0, why: ".")],
                    flashcards: chapter.needsCards ? [GeneratedCard(front: "R", back: "V")] : []
                )
            }
        )
    }
}

@MainActor
final class LessonBuilderTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func builder(_ service: FakeLessonService) -> LessonBuilder {
        LessonBuilder(service: service, audience: {
            LessonAudience(level: "lycee", country: "fr", schoolStage: "Terminale", language: "fr")
        })
    }

    private func waitUntilDone(_ builder: LessonBuilder, _ course: Course) async {
        for _ in 0..<200 where !builder.writing.isEmpty || course.lessonPath?.status == .generating {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testALessonIsCreatedFromItsPlanThenFilledThemeByTheme() async throws {
        let context = try makeContext()
        let service = FakeLessonService()
        let builder = builder(service)
        var stages: [LessonBuilder.Stage] = []

        let course = try await builder.create(
            LessonCreation(topic: "La guerre froide", source: .topic, examDate: Date().addingTimeInterval(12 * 86_400)),
            in: context,
            onStage: { stages.append($0) }
        )

        XCTAssertEqual(stages, [.reading, .cutting, .writing, .questions])
        XCTAssertTrue(course.isLesson)
        XCTAssertEqual(course.title, "La guerre froide")
        XCTAssertEqual(course.subject, "Histoire", "la matière ne crie pas")
        XCTAssertEqual(course.icon, .scroll)
        XCTAssertFalse(course.toneRaw.isEmpty)
        XCTAssertEqual(course.orderedChapters.count, 4)

        await waitUntilDone(builder, course)
        XCTAssertEqual(course.orderedChapters.map(\.status), [.ready, .ready, .ready, .ready])
        XCTAssertEqual(course.lessonPath?.status, .ready)
        XCTAssertEqual(course.cards.count, 12, "trois flashcards par thème")
        let first = try XCTUnwrap(course.orderedChapters.first)
        XCTAssertEqual(first.notes?.oneLiner.hasPrefix("Idée"), true)
        XCTAssertEqual(first.quiz?.questions.count, 4)
        XCTAssertEqual(first.quiz?.final?.id, "\(first.id.uuidString):0")
        XCTAssertEqual(first.cards?.count, 3)
        XCTAssertEqual(course.pathSteps().compactMap(\.circle).count, 9)

        let exams = try context.fetch(FetchDescriptor<Exam>())
        XCTAssertEqual(exams.first?.courseIDs, [course.id], "la date d'examen devient un examen de la leçon")
    }

    func testAFailedThemeWaitsForRetryWhileTheOthersAreReady() async throws {
        let context = try makeContext()
        let service = FakeLessonService()
        service.failingThemes = [2]
        let builder = builder(service)

        let course = try await builder.create(LessonCreation(topic: "x", source: .topic), in: context)
        await waitUntilDone(builder, course)

        XCTAssertEqual(course.orderedChapters.map(\.status), [.ready, .ready, .failed, .ready])
        XCTAssertEqual(course.lessonPath?.status, .ready, "la leçon est prête, un cercle propose « Réessayer »")

        service.failingThemes = []
        await builder.retry(course.orderedChapters[2], in: context)
        XCTAssertEqual(course.orderedChapters[2].status, .ready)
        XCTAssertEqual(course.cards.count, 12)
    }

    func testTheFreeLimitComesBackAsAPaywallError() async throws {
        let context = try makeContext()
        let service = FakeLessonService()
        service.planError = SupabaseFunctionError.server(status: 402, message: "…", code: "free_limit")
        do {
            _ = try await builder(service).create(LessonCreation(topic: "x", source: .topic), in: context)
            XCTFail("la création aurait dû être refusée")
        } catch let error as LessonServiceError {
            XCTAssertEqual(error, .freeLimit)
            XCTAssertTrue(error.opensPaywall)
        }
        XCTAssertTrue(try context.fetch(FetchDescriptor<Course>()).isEmpty, "rien n'est créé sur un refus")
    }

    func testTwoLessonsInARowNeverShareATone() async throws {
        let context = try makeContext()
        let builder = builder(FakeLessonService())
        let first = try await builder.create(LessonCreation(topic: "a", source: .topic), in: context)
        try await Task.sleep(nanoseconds: 5_000_000)
        let second = try await builder.create(LessonCreation(topic: "b", source: .topic), in: context)
        XCTAssertNotEqual(first.tone, second.tone)
    }

    /// Un ancien cours devient une leçon sans perdre ses notes ni ses cartes.
    func testAnOldCourseIsConvertedWithoutRewritingIt() async throws {
        let context = try makeContext()
        let sheet = CourseSheet(blocks: [
            .heading(level: 1, text: "Les causes"),
            .paragraph(text: "Après 1945, deux blocs."),
            .heading(level: 1, text: "Les crises"),
            .paragraph(text: "Berlin, Cuba."),
        ])
        let course = Course(title: "Guerre froide", subject: "Histoire", sheet: sheet)
        context.insert(course)
        for index in 0..<3 {
            context.insert(Flashcard(front: "Q\(index)", back: "R", position: index, course: course))
        }
        try context.save()
        XCTAssertFalse(course.isLesson)

        try await builder(FakeLessonService()).convert(course, in: context)

        XCTAssertTrue(course.isLesson)
        XCTAssertEqual(course.orderedChapters.map(\.title), ["Les causes", "Les crises"])
        XCTAssertNotNil(course.orderedChapters.first?.decodedSheet(), "les notes d'origine restent")
        XCTAssertNil(course.orderedChapters.first?.notes)
        XCTAssertEqual(course.orderedChapters.first?.icon, .puzzle)
        XCTAssertEqual(course.orderedChapters.first?.quiz?.questions.count, 1)
        XCTAssertEqual(course.cards.count, 5, "une flashcard ajoutée à chacun des deux chapitres sans cartes")
        XCTAssertEqual(course.lessonPath?.status, .ready)
        XCTAssertEqual(course.tone, LessonTone.stable(for: course.id))
    }

    /// Un paquet de cartes sans fiche devient une leçon d'un seul thème, qui garde ses cartes.
    func testADeckWithoutSheetBecomesASingleThemeLesson() async throws {
        let context = try makeContext()
        let course = Course(title: "Vocabulaire", source: .deck)
        context.insert(course)
        context.insert(Flashcard(front: "dog", back: "chien", position: 0, course: course))
        try context.save()

        try await builder(FakeLessonService()).convert(course, in: context)

        XCTAssertEqual(course.orderedChapters.count, 1)
        XCTAssertEqual(course.cards.first?.chapter?.id, course.orderedChapters.first?.id)
        XCTAssertTrue(course.isLesson)
    }
    /// Hors ligne, un ancien cours s'ouvre quand même : ses chapitres font le chemin, sans
    /// questions, et ses cartes restent.
    func testAnOldCourseOpensOfflineWithoutTheModel() throws {
        let context = try makeContext()
        let sheet = CourseSheet(blocks: [
            .heading(level: 1, text: "Les causes"),
            .paragraph(text: "Après 1945, deux blocs."),
            .heading(level: 1, text: "Les crises"),
            .paragraph(text: "Berlin, Cuba."),
            .heading(level: 1, text: "La fin"),
            .paragraph(text: "1991."),
        ])
        let course = Course(title: "Guerre froide", subject: "Histoire", sheet: sheet)
        context.insert(course)
        context.insert(Flashcard(front: "Q", back: "R", position: 0, course: course))
        try context.save()

        builder(FakeLessonService()).convertOffline(course, in: context)

        XCTAssertTrue(course.isLesson)
        XCTAssertEqual(course.lessonPath?.status, .ready)
        XCTAssertEqual(course.icon, .scroll)
        XCTAssertEqual(course.lessonPath?.groups.map(\.themes), [[0, 1, 2]])
        XCTAssertEqual(course.orderedChapters.count, 3)
        XCTAssertTrue(course.orderedChapters.allSatisfy { $0.status == .ready && ($0.quiz?.questions ?? []).isEmpty })
        XCTAssertEqual(course.cards.count, 1)
        XCTAssertNotNil(course.orderedChapters.first?.decodedSheet())
    }
}
