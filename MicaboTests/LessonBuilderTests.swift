import SwiftData
import XCTest
@testable import Micabo

/// Un faux `generate-lesson` : un plan de quatre thèmes, des notes, quatre questions et trois
/// flashcards par thème — et un thème qui échoue quand on le lui demande.
private final class FakeLessonService: LessonGenerating, @unchecked Sendable {
    var failingThemes: Set<Int> = []
    var planError: Error?
    private(set) var themeCalls: [Int] = []
    private(set) var planRequests: [LessonPlanRequest] = []
    private let lock = NSLock()

    func plan(_ request: LessonPlanRequest) async throws -> LessonPlanResult {
        lock.lock()
        planRequests.append(request)
        lock.unlock()
        if let planError { throw planError }
        return LessonPlanResult(
            plan: .init(
                title: "La guerre froide",
                subject: "HISTOIRE",
                icon: "parchemin",
                themes: (0..<4).map { .init(title: "Thème \($0 + 1)", icon: "ampoule", symbol: $0 < 2 ? "flag" : nil, points: ["Notion \($0)"]) },
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
                + [GeneratedCard(kind: "cloze", front: "La ___ est rouge.", back: "pomme")]
        )
    }

    private(set) var practiceRequests: [LessonPracticeRequest] = []
    var practiceError: Error?

    func practice(_ request: LessonPracticeRequest) async throws -> [GeneratedQuestion] {
        lock.lock()
        practiceRequests.append(request)
        lock.unlock()
        if let practiceError { throw practiceError }
        return (0..<request.count).map {
            GeneratedQuestion(kind: "truefalse", prompt: "Nouvelle \($0)", choices: ["Vrai", "Faux"], answer: 0, why: ".", difficulty: 3, theme: $0 % max(1, request.themes.count))
        }
    }

    private(set) var examRequests: [LessonExamRequest] = []

    func exam(_ request: LessonExamRequest) async throws -> GeneratedExam {
        lock.lock()
        examRequests.append(request)
        lock.unlock()
        return GeneratedExam(
            title: "Blanc",
            questions: (0..<request.count).map {
                GeneratedQuestion(prompt: "Examen \($0)", choices: ["a", "b", "c", "d"], answer: 2, why: ".", theme: $0 % 3, lesson: $0 % 2)
            }
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
        XCTAssertEqual(course.cards.count, 16, "quatre flashcards par thème")
        let first = try XCTUnwrap(course.orderedChapters.first)
        XCTAssertEqual(first.notes?.oneLiner.hasPrefix("Idée"), true)
        XCTAssertEqual(first.quiz?.questions.count, 4)
        XCTAssertEqual(first.quiz?.final?.id, "\(first.id.uuidString):0")
        XCTAssertEqual(first.cards?.count, 4)
        let cloze = try XCTUnwrap(first.cards?.first { $0.kind == .cloze }, "une carte à trou garde sa forme")
        XCTAssertEqual(cloze.front, "La \(ClozeGap.marker) est rouge.")
        let symbols = try XCTUnwrap(course.lessonPath?.symbols)
        XCTAssertEqual(symbols.count, 4)
        XCTAssertEqual(Set(symbols).count, 4, "jamais deux fois le même pictogramme")
        XCTAssertEqual(symbols.first, "flag")
        XCTAssertEqual(course.lessonPath?.points?.first, ["Notion 0"])
        XCTAssertTrue(service.planRequests.first?.audience.exam.contains("un examen, le ") == true, "l'examen visé part avec le plan")
        XCTAssertEqual(course.pathSteps().compactMap(\.circle).count, 7)

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
        XCTAssertEqual(course.cards.count, 16)
    }

    func testNewPracticeQuestionsJoinTheirThemesAndAvoidTheOldOnes() async throws {
        let context = try makeContext()
        let service = FakeLessonService()
        let builder = builder(service)
        let course = try await builder.create(LessonCreation(topic: "x", source: .topic), in: context)
        await waitUntilDone(builder, course)
        let second = course.orderedChapters[1]
        course.updateProgress { $0.noteMissed("\(second.id.uuidString):2") }

        let fresh = try await builder.practice(course, in: context, count: 8)

        XCTAssertEqual(fresh.count, 8)
        XCTAssertTrue(fresh.allSatisfy { $0.kind == .truefalse && $0.difficulty == 3 })
        let request = try XCTUnwrap(service.practiceRequests.first)
        XCTAssertEqual(request.focus, [1], "les thèmes ratés d'abord")
        XCTAssertEqual(request.themes.count, 4)
        XCTAssertTrue(request.themes[0].notes.contains("Idée 0"), "les notes partent à plat")
        XCTAssertTrue(request.avoid.contains("Q0 ?"), "les questions déjà posées sont à éviter")
        XCTAssertEqual(course.orderedChapters[0].quiz?.questions.count, 6, "deux nouvelles questions rejoignent le premier thème")
        XCTAssertTrue(fresh.allSatisfy { $0.id.contains(":p") })
    }

    func testAMockExamCoversEveryLessonAndKeepsItsThemes() async throws {
        let context = try makeContext()
        let service = FakeLessonService()
        let builder = builder(service)
        let first = try await builder.create(LessonCreation(topic: "x", source: .topic), in: context)
        let second = try await builder.create(LessonCreation(topic: "y", source: .topic), in: context)
        await waitUntilDone(builder, first)
        await waitUntilDone(builder, second)
        let exam = try ExamRepository.create(
            name: "Bac blanc", date: Date().addingTimeInterval(20 * 86_400), courseIDs: [first.id, second.id], intensity: .standard, in: context
        )

        let paper = try await builder.examPaper(title: "Bac blanc", exam: exam, courses: [first, second], minutes: 30, in: context)

        let request = try XCTUnwrap(service.examRequests.first)
        XCTAssertEqual(request.count, 20, "une question et demie par minute")
        XCTAssertEqual(request.lessons.count, 2)
        XCTAssertEqual(request.lessons[0].themes.count, 4)
        XCTAssertTrue(request.audience.exam.contains("Bac blanc"), "l'examen visé part avec la copie")
        XCTAssertEqual(paper.items.count, 20)
        XCTAssertEqual(paper.examID, exam.id)
        XCTAssertEqual(Set(paper.items.map(\.lesson)), [0, 1])
        XCTAssertEqual(paper.lessons[1].chapterIDs, second.orderedChapters.map(\.id))
        XCTAssertEqual(Set(paper.items.map(\.id)).count, 20, "chaque question a son identifiant")

        var answers: [String: QuizAnswer] = [:]
        for item in paper.items.prefix(15) { answers[item.id] = QuizAnswer(right: true, picked: 2) }
        let result = paper.result(answers: answers, seconds: 600)
        XCTAssertEqual(result.correct, 15)
        XCTAssertEqual(result.total, 20, "une question sans réponse compte fausse")
        XCTAssertEqual(result.lessons.map(\.total), [10, 10])
    }

    func testAMockExamGradeIsReadInTheCountryScale() {
        let locale = UiLocale.fr
        XCTAssertEqual(ExamGrade.label(0.675, country: .fr, locale: locale), "13,5/20")
        XCTAssertEqual(ExamGrade.label(0.5, country: .de, locale: locale), "4,0")
        XCTAssertEqual(ExamGrade.label(1, country: .de, locale: locale), "1,0")
        XCTAssertEqual(ExamGrade.label(0.7, country: .ch, locale: locale), "4,5")
        XCTAssertEqual(ExamGrade.label(0.85, country: .us, locale: locale), "B")
        XCTAssertEqual(ExamGrade.label(0.78, country: .tr, locale: locale), "78 %")
        XCTAssertEqual(ExamGrade.label(0.75, country: .it, locale: locale), "7,5/10")
        XCTAssertEqual(ExamGrade.label(0.2, country: .uk, locale: locale), "U")
        XCTAssertTrue(ExamGrade.passes(0.5))
        XCTAssertFalse(ExamGrade.passes(0.45))
    }

    func testAnUsedFreePracticeOpensThePaywall() async throws {
        let context = try makeContext()
        let service = FakeLessonService()
        let builder = builder(service)
        let course = try await builder.create(LessonCreation(topic: "x", source: .topic), in: context)
        await waitUntilDone(builder, course)
        service.practiceError = SupabaseFunctionError.server(status: 402, message: "…", code: "pro_required")
        do {
            _ = try await builder.practice(course, in: context)
            XCTFail("le lot aurait dû être refusé")
        } catch let error as LessonServiceError {
            XCTAssertEqual(error, .proRequired)
            XCTAssertTrue(error.opensPaywall)
        }
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
    /// La leçon du parcours d'accueil part avec son drapeau : c'est lui qui laisse le serveur
    /// l'écrire depuis un PDF sans abonnement, une fois.
    func testTheOnboardingLessonTellsTheServerWhereItComesFrom() async throws {
        let context = try makeContext()
        let service = FakeLessonService()
        let setup = DeckSetup()
        setup.source = .materials
        let material = DeckMaterial()
        material.document = ImportedDocument(
            text: String(repeating: "La photosynthèse transforme la lumière. ", count: 20),
            pageImages: [Data([0xFF])],
            coverImage: Data([0x01]),
            pageCount: 3,
            fileName: "Chapitre 3",
            source: .pdf,
            extractionNote: nil
        )
        material.state = .ready
        setup.materials = [material, DeckMaterial()]

        let request = LessonCreation.onboarding(from: setup)
        XCTAssertTrue(request.onboarding)
        XCTAssertEqual(request.source, .pdf)
        XCTAssertEqual(request.sourceName, "Chapitre 3")
        XCTAssertEqual(request.images.count, 1)
        XCTAssertNotNil(request.coverImage)
        XCTAssertNil(request.topic)
        XCTAssertTrue(request.text.contains("photosynthèse"))

        let course = try await builder(service).create(request, in: context)
        XCTAssertTrue(course.isLesson)
        XCTAssertEqual(service.planRequests.first?.onboarding, true)
        XCTAssertEqual(service.planRequests.first?.source, "pdf")
    }

    /// Une leçon créée depuis Home ne porte pas le drapeau.
    func testAHomeLessonIsNotAnOnboardingLesson() async throws {
        let context = try makeContext()
        let service = FakeLessonService()
        _ = try await builder(service).create(LessonCreation(topic: "La guerre froide"), in: context)
        XCTAssertEqual(service.planRequests.first?.onboarding, false)
    }

    /// Le cours de démonstration entre en leçon, sans appel au modèle : ses chapitres font le
    /// chemin, ses QCM les quiz, et il ne consomme pas la leçon offerte.
    func testTheDemoCourseIsInstalledAsALesson() throws {
        for locale in UiLocale.allCases {
            let context = try makeContext()
            let demo = try XCTUnwrap(OnboardingDemoCatalog.courses(locale: locale).first, "\(locale)")
            let course = try OnboardingDemoCatalog.installLesson(demo, language: .fr, in: context)

            XCTAssertTrue(course.isLesson, "\(locale)")
            XCTAssertEqual(course.lessonPath?.status, .ready)
            XCTAssertEqual(course.source, .sample)
            XCTAssertNotNil(course.lastOpenedAt)
            XCTAssertFalse(course.orderedChapters.isEmpty)
            XCTAssertTrue(course.orderedChapters.allSatisfy { $0.status == .ready })
            XCTAssertFalse(course.pathSteps().isEmpty)
            XCTAssertFalse(LessonAllowance.hasUsedFreeLesson(courses: [course]))

            let expected = demo.cards.filter { $0.kind == .choice && $0.chapter < course.orderedChapters.count && $0.choices.count >= 2 }.count
            let questions = course.orderedChapters.reduce(0) { $0 + ($1.quiz?.questions.count ?? 0) }
            XCTAssertEqual(questions, expected, "\(locale)")
        }
    }
}
