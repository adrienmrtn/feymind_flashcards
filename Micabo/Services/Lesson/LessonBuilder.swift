import Foundation
import Observation
import SwiftData
import UIKit

/// **Ce que l'élève demande** : un sujet tapé, ou des supports mis à plat, et une date
/// d'examen éventuelle.
struct LessonCreation {
    var lessonID = UUID()
    var topic: String?
    var text: String = ""
    var images: [Data] = []
    /// text, pdf, photo, audio, youtube, docx, mixed — voir `LessonSourceKind`.
    var source: LessonSourceKind = .topic
    var sourceName: String?
    var coverImage: Data?
    var examDate: Date?
    /// La leçon du parcours d'accueil : c'est la leçon offerte, même depuis un support importé
    /// (`begin_lesson`, migration `lesson_onboarding`).
    var onboarding = false
}

/// D'où vient une leçon. La valeur brute part au serveur, qui en tire la porte du gratuit.
enum LessonSourceKind: String, CaseIterable {
    case topic
    case text
    case pdf
    case photo
    case audio
    case youtube
    case docx
    case mixed

    /// Le gratuit écrit une leçon depuis un sujet ou un texte collé, et c'est tout.
    var isImport: Bool { self != .topic && self != .text }

    var courseSource: CourseSource {
        switch self {
        case .topic, .text, .audio, .mixed: .text
        case .pdf: .pdf
        case .photo: .photo
        case .youtube: .youtube
        case .docx: .docx
        }
    }
}

/// **Construit les leçons, et les écrit pendant qu'on les lit.**
///
/// Une leçon naît en deux temps (`docs/refonte-parcours.md` § 9.1). Le plan d'abord, en une
/// dizaine de secondes : la leçon est créée, son chemin s'affiche et l'Intro se lit. Puis chaque
/// thème, quatre à la fois : son cercle Notes passe de « en préparation » à « prêt » quand ses
/// notes, ses questions et ses flashcards arrivent. Un thème qui échoue affiche « Réessayer » ;
/// les autres restent utilisables.
///
/// Le travail vit ici, et pas dans un écran : on peut quitter le chemin, ouvrir une autre leçon,
/// revenir — les thèmes continuent de s'écrire. Une app fermée en route reprend les thèmes
/// restés en préparation à la prochaine ouverture de la leçon (`resumeIfNeeded`).
@MainActor
@Observable
final class LessonBuilder {
    /// Les quatre étapes de l'écran de génération, reliées au vrai travail.
    enum Stage: Int, CaseIterable, Comparable {
        /// « Je lis tes supports » : le plan est demandé.
        case reading
        /// « Je découpe les thèmes » : le plan est arrivé, la leçon est créée.
        case cutting
        /// « J'écris tes notes » : les thèmes sont lancés.
        case writing
        /// « Je prépare tes questions » : le premier thème est arrivé.
        case questions

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Combien de thèmes s'écrivent en même temps.
    static let parallelThemes = 4

    private let service: LessonGenerating
    private let audience: () -> LessonAudience

    /// Les thèmes en cours d'écriture, par identifiant de chapitre.
    private(set) var writing: Set<UUID> = []
    /// Les leçons en cours de conversion, par identifiant de cours.
    private(set) var converting: Set<UUID> = []

    init(
        service: LessonGenerating = SupabaseLessonService(),
        audience: @escaping () -> LessonAudience = { .current }
    ) {
        self.service = service
        self.audience = audience
    }

    // MARK: - Créer

    /// Écrit le plan, crée la leçon et lance ses thèmes. Rend la leçon dès que le premier
    /// thème est arrivé — ou dès que tous ont échoué : l'Intro se lit de toute façon.
    func create(
        _ request: LessonCreation,
        in context: ModelContext,
        onStage: @escaping (Stage) -> Void = { _ in }
    ) async throws -> Course {
        let background = BackgroundWork(name: "lesson-plan")
        defer { background.end() }

        onStage(.reading)
        let audience = audience().preparing(request.examDate.map { Self.examLine(name: nil, date: $0) })
        let result: LessonPlanResult
        do {
            result = try await service.plan(LessonPlanRequest(
                lessonID: request.lessonID,
                topic: request.topic,
                text: request.text,
                images: request.images,
                source: request.source.rawValue,
                sourceName: request.sourceName,
                onboarding: request.onboarding,
                audience: audience
            ))
        } catch {
            throw LessonServiceError.from(error)
        }

        onStage(.cutting)
        let course = insertLesson(request, plan: result, language: audience.language, in: context)
        try? context.save()
        CourseLedger.noteChange()

        onStage(.writing)
        let firstThemeArrived = AsyncSignal()
        Task { @MainActor in
            await self.writeThemes(of: course, in: context, onFirst: { firstThemeArrived.fire() })
            firstThemeArrived.fire()
        }
        await firstThemeArrived.wait()
        onStage(.questions)
        return course
    }

    /// La leçon telle que le plan la décrit : le cours, ses thèmes en préparation, son examen.
    private func insertLesson(
        _ request: LessonCreation,
        plan result: LessonPlanResult,
        language: String,
        in context: ModelContext
    ) -> Course {
        let plan = result.plan
        let previousTone = Self.lastTone(in: context)
        let course = Course(
            id: request.lessonID,
            title: plan.title,
            subject: plan.subject.nilIfBlank.map(TextSanitizer.subject),
            source: request.source.courseSource,
            sourceFileName: request.sourceName,
            rawText: request.text,
            contextText: result.contextText,
            coverImageData: request.coverImage
        )
        course.emoji = ""
        course.iconID = plan.icon
        course.toneRaw = LessonTone.next(after: previousTone).rawValue
        course.languageRaw = language
        course.fingerprint = CourseFingerprint.make(from: request.text)
        course.lastOpenedAt = Date()
        course.pathData = LessonPath(
            icon: plan.icon,
            intro: plan.intro,
            takeaways: plan.takeaways,
            groups: plan.groups,
            shortened: plan.shortened,
            singleQuiz: plan.singleQuiz,
            status: .generating,
            symbols: PathSymbol.unique(plan.themes.map { $0.symbol ?? "" }),
            points: plan.themes.map { $0.points ?? [] }
        ).encoded()
        context.insert(course)

        for (index, theme) in plan.themes.enumerated() {
            let chapter = Chapter(position: index, title: theme.title, course: course)
            chapter.iconID = theme.icon
            chapter.statusRaw = ThemeStatus.pending.rawValue
            context.insert(chapter)
        }

        if let date = request.examDate {
            _ = try? ExamRepository.create(
                name: plan.title,
                date: date,
                courseIDs: [course.id],
                intensity: .standard,
                in: context
            )
        }
        return course
    }

    /// Le ton de la dernière leçon créée, pour que la suivante n'ait pas le même.
    private static func lastTone(in context: ModelContext) -> LessonTone? {
        var descriptor = FetchDescriptor<Course>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let last = try? context.fetch(descriptor).first, !last.toneRaw.isEmpty else { return nil }
        return LessonTone(raw: last.toneRaw)
    }

    // MARK: - Écrire les thèmes

    /// Écrit les thèmes en préparation (ou en échec, quand `retryFailed`), quatre à la fois.
    func writeThemes(
        of course: Course,
        in context: ModelContext,
        retryFailed: Bool = false,
        onFirst: (() -> Void)? = nil
    ) async {
        let background = BackgroundWork(name: "lesson-themes")
        defer { background.end() }

        let wanted: Set<ThemeStatus> = retryFailed ? [.pending, .failed] : [.pending]
        let chapters = course.orderedChapters.filter { wanted.contains($0.status) && !writing.contains($0.id) }
        guard !chapters.isEmpty else {
            finishIfComplete(course, in: context)
            return
        }
        for chapter in chapters { writing.insert(chapter.id) }

        let titles = course.orderedChapters.map(\.title)
        let path = course.lessonPath
        let base = ThemeJob.Base(
            lessonID: course.id,
            lessonTitle: course.title,
            themes: titles,
            context: course.contextText,
            subject: course.subject,
            audience: audience().preparing(Self.examLine(for: course, in: context)),
            points: path?.points ?? [],
            objectives: path?.intro.lines ?? [],
            source: LessonSourceKind(courseSource: course.source).rawValue
        )

        var notified = false
        await withTaskGroup(of: (UUID, Result<LessonThemeResult, Error>).self) { group in
            var queue = chapters.makeIterator()
            func launch() {
                guard let chapter = queue.next() else { return }
                let job = ThemeJob(base: base, chapterID: chapter.id, index: chapter.position)
                let service = self.service
                group.addTask {
                    do {
                        return (job.chapterID, .success(try await service.theme(job.request)))
                    } catch {
                        return (job.chapterID, .failure(error))
                    }
                }
            }
            for _ in 0..<Self.parallelThemes { launch() }
            while let (chapterID, result) = await group.next() {
                if let chapter = course.orderedChapters.first(where: { $0.id == chapterID }) {
                    applyTheme(result, to: chapter, of: course, in: context)
                }
                writing.remove(chapterID)
                if !notified {
                    notified = true
                    onFirst?()
                }
                launch()
            }
        }
        finishIfComplete(course, in: context)
    }

    /// Relance un thème en échec.
    func retry(_ chapter: Chapter, in context: ModelContext) async {
        guard let course = chapter.course, !writing.contains(chapter.id) else { return }
        chapter.status = .pending
        try? context.save()
        await writeThemes(of: course, in: context)
    }

    /// Une leçon rouverte dont des thèmes sont restés en préparation (app fermée en route) :
    /// on les relance.
    func resumeIfNeeded(_ course: Course, in context: ModelContext) {
        guard course.isLesson else { return }
        let stalled = course.orderedChapters.contains { $0.status == .pending && !writing.contains($0.id) }
        guard stalled else { return }
        Task { await writeThemes(of: course, in: context) }
    }

    func isWriting(_ chapter: Chapter) -> Bool { writing.contains(chapter.id) }

    private func applyTheme(
        _ result: Result<LessonThemeResult, Error>,
        to chapter: Chapter,
        of course: Course,
        in context: ModelContext
    ) {
        switch result {
        case .success(let theme):
            chapter.setNotes(theme.notes)
            chapter.setQuiz(ThemeQuiz(questions: theme.questions.enumerated().map { index, question in
                question.question(id: "\(chapter.id.uuidString):\(index)")
            }))
            Self.addCards(theme.flashcards, to: chapter, of: course, in: context)
            chapter.status = .ready
        case .failure:
            chapter.status = .failed
        }
        course.updatedAt = Date()
        try? context.save()
    }

    private func finishIfComplete(_ course: Course, in context: ModelContext) {
        guard var path = course.lessonPath, path.status == .generating else { return }
        let statuses = course.orderedChapters.map(\.status)
        guard !statuses.contains(.pending) else { return }
        path.status = .ready
        course.setLessonPath(path)
        try? context.save()
    }

    /// Les flashcards d'un thème : recto/verso ou à trou, rattachées au thème, à réviser dès
    /// aujourd'hui.
    static func addCards(_ cards: [GeneratedCard], to chapter: Chapter, of course: Course, in context: ModelContext) {
        var position = course.cards.count
        for generated in cards {
            let front = generated.kind == "cloze" ? ClozeGap.normalize(generated.front) : generated.front
            let card = Flashcard(front: front, back: generated.back, position: position, course: course)
            if generated.kind == "cloze", ClozeGap.isPresent(in: front) {
                card.kindRaw = CardKind.cloze.rawValue
            }
            card.chapter = chapter
            context.insert(card)
            position += 1
        }
    }

    // MARK: - De nouvelles questions

    /// **Un lot de nouvelles questions d'entraînement**, écrit par Mika loin de celles déjà
    /// posées et surtout sur les thèmes ratés. Les questions rejoignent la réserve de leur
    /// thème : les quiz suivants les tirent aussi. Rend celles du lot, à jouer tout de suite.
    func practice(_ course: Course, in context: ModelContext, count: Int = 10) async throws -> [QuizQuestion] {
        let chapters = course.orderedChapters
        let indexByChapter = Dictionary(uniqueKeysWithValues: chapters.enumerated().map { ($1.id.uuidString, $0) })
        let progress = course.progress
        let focus = Array(Set(progress.missed.compactMap { id in
            indexByChapter[id.split(separator: ":").first.map(String.init) ?? ""]
        })).sorted()
        let avoid = chapters.flatMap { $0.quiz?.questions.map(\.prompt) ?? [] }
        let request = LessonPracticeRequest(
            lessonID: course.id,
            lessonTitle: course.title,
            subject: course.subject,
            themes: chapters.map { .init(title: $0.title, notes: Self.flatNotes(of: $0)) },
            focus: focus,
            avoid: Array(avoid.suffix(80)),
            count: count,
            audience: audience().preparing(Self.examLine(for: course, in: context))
        )
        let generated: [GeneratedQuestion]
        do {
            generated = try await service.practice(request)
        } catch {
            throw LessonServiceError.from(error)
        }

        let stamp = String(Int(Date().timeIntervalSince1970) % 1_000_000, radix: 36)
        var added: [QuizQuestion] = []
        for (number, item) in generated.enumerated() {
            let index = item.theme ?? 0
            guard chapters.indices.contains(index) else { continue }
            let chapter = chapters[index]
            var quiz = chapter.quiz ?? ThemeQuiz(questions: [])
            let question = item.question(id: "\(chapter.id.uuidString):p\(stamp)\(number)")
            guard question.isValid else { continue }
            quiz.questions.append(question)
            chapter.setQuiz(quiz)
            added.append(question)
        }
        course.updatedAt = Date()
        try? context.save()
        return added
    }

    // MARK: - L'examen blanc

    /// Combien de questions pour une durée : une et demie par minute, entre six et trente.
    static func examQuestionCount(minutes: Int) -> Int {
        min(30, max(6, Int((Double(minutes) / 1.5).rounded())))
    }

    /// **Une copie d'examen blanc** sur ces leçons, écrite par Mika au format de l'examen visé.
    /// Rien n'est enregistré : la copie se joue tout de suite, seul son résultat reste.
    func examPaper(
        title: String,
        exam: Exam?,
        courses: [Course],
        minutes: Int,
        in context: ModelContext
    ) async throws -> ExamPaper {
        let courses = Array(courses.filter(\.isLesson).prefix(8))
        guard !courses.isEmpty else { throw LessonServiceError.failed(L10n.t("lesson.exam.noLessons", locale: .resolved())) }
        let paperID = UUID()
        let chapters = courses.map { Array($0.orderedChapters.prefix(14)) }
        let request = LessonExamRequest(
            paperID: paperID,
            title: title,
            minutes: minutes,
            count: Self.examQuestionCount(minutes: minutes),
            lessons: zip(courses, chapters).map { course, chapters in
                .init(title: course.title, subject: course.subject, themes: chapters.map { .init(title: $0.title, notes: Self.flatNotes(of: $0)) })
            },
            audience: audience().preparing(exam.map { Self.examLine(name: $0.name, date: $0.date) })
        )
        let generated: GeneratedExam
        do {
            generated = try await service.exam(request)
        } catch {
            throw LessonServiceError.from(error)
        }

        var items: [ExamPaper.Item] = []
        for (number, item) in generated.questions.enumerated() {
            let lesson = item.lesson.flatMap { courses.indices.contains($0) ? $0 : nil } ?? 0
            let theme = item.theme.flatMap { chapters[lesson].indices.contains($0) ? $0 : nil } ?? 0
            let question = item.question(id: "\(paperID.uuidString):\(number)")
            guard question.isValid else { continue }
            items.append(.init(question: question, lesson: lesson, theme: theme))
        }
        return ExamPaper(
            id: paperID,
            examID: exam?.id,
            title: generated.title.nilIfBlank ?? title,
            minutes: minutes,
            createdAt: Date(),
            lessons: zip(courses, chapters).map { .init(courseID: $0.id, title: $0.title, chapterIDs: $1.map(\.id)) },
            items: items
        )
    }

    /// Les notes d'un thème, mises à plat pour le modèle : l'idée, les blocs, « À retenir ».
    static func flatNotes(of chapter: Chapter) -> String {
        guard let notes = chapter.notes else { return "" }
        var lines = [notes.oneLiner]
        for block in notes.blocks {
            switch block {
            case .subtitle(let text): lines.append("## \(text)")
            case .paragraph(let text): lines.append(text)
            case .list(let items): lines.append(contentsOf: items.map { "- \($0)" })
            case .definition(let term, let text): lines.append("\(term) : \(text)")
            case .dates(let items): lines.append(contentsOf: items.map { "\($0.date) : \($0.text)" })
            case .formula(let latex, let caption): lines.append([latex, caption].compactMap { $0 }.joined(separator: " : "))
            case .example(let text): lines.append("Exemple : \(text)")
            }
        }
        lines.append(contentsOf: notes.takeaways.map { "À retenir : \($0)" })
        return lines.joined(separator: "\n").replacingOccurrences(of: "**", with: "")
    }

    // MARK: - L'examen visé

    /// L'examen, tel que la consigne le reprend : « Examen « La guerre froide », le 2027-06-15 ».
    /// La date est écrite à l'ISO : le serveur la lit dans toutes les langues.
    static func examLine(name: String?, date: Date) -> String {
        let day = date.formatted(.iso8601.year().month().day())
        let title = name?.nilIfBlank.map { "« \($0) »" } ?? ""
        return title.isEmpty ? "un examen, le \(day)" : "l'examen \(title), le \(day)"
    }

    /// L'examen à venir qui porte sur cette leçon, s'il y en a un.
    static func examLine(for course: Course, in context: ModelContext) -> String? {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Exam>(sortBy: [SortDescriptor(\.date)])
        guard let exam = (try? context.fetch(descriptor))?.first(where: { $0.date >= today && $0.courseIDs.contains(course.id) })
        else { return nil }
        return examLine(name: exam.name, date: exam.date)
    }

    // MARK: - Convertir un ancien cours

    /// **Un ancien cours devient une leçon**, à sa première ouverture. Ses chapitres deviennent
    /// les cercles Notes, tels quels ; le modèle ajoute ce qui manque : icônes, intro,
    /// conclusion, noms de paliers, questions, et des flashcards aux chapitres qui en ont moins
    /// de trois. Rien de ce que l'élève a déjà n'est réécrit.
    func convert(_ course: Course, in context: ModelContext) async throws {
        guard !course.isLesson, !converting.contains(course.id) else { return }
        converting.insert(course.id)
        defer { converting.remove(course.id) }
        let background = BackgroundWork(name: "lesson-convert")
        defer { background.end() }

        Self.prepareChapters(of: course, in: context)
        let chapters = course.orderedChapters
        guard !chapters.isEmpty else { return }

        let request = LessonConvertRequest(
            lessonID: course.id,
            title: course.title,
            subject: course.subject,
            chapters: chapters.map { chapter in
                LessonConvertRequest.Chapter(
                    title: chapter.title,
                    text: Self.convertText(of: chapter, in: course),
                    needsCards: chapter.cardCount < 3
                )
            },
            audience: audience()
        )
        let conversion: LessonConversion
        do {
            conversion = try await service.convert(request)
        } catch {
            throw LessonServiceError.from(error)
        }
        Self.apply(conversion, to: course, in: context)
        try? context.save()
    }

    /// Les chapitres d'un ancien cours : ceux de sa fiche, ou un seul quand il n'en a pas
    /// (un paquet de cartes sans fiche).
    static func prepareChapters(of course: Course, in context: ModelContext) {
        ChapterBuilder.migrate(course, in: context)
        ChapterBuilder.resplitIfFlat(course, in: context)
        guard course.orderedChapters.isEmpty else { return }
        let chapter = Chapter(position: 0, title: course.title, course: course)
        context.insert(chapter)
        for card in course.cards where card.chapter == nil {
            card.chapter = chapter
        }
    }

    /// Ce que le modèle lit d'un chapitre : son texte, sinon ses cartes.
    static func convertText(of chapter: Chapter, in course: Course) -> String {
        let text = chapter.plainText.nilIfBlank
            ?? chapter.orderedCards.prefix(30).map { "\($0.front) : \($0.back)" }.joined(separator: "\n").nilIfBlank
            ?? course.contextSnippet(limit: 3_000)
        return String(text.prefix(3_000))
    }

    /// **La conversion sans le modèle**, quand il ne répond pas (hors ligne, sans compte) : les
    /// chapitres deviennent les cercles Notes, les paliers se calculent, les icônes se devinent.
    /// Pas de questions : les cercles Quiz se passent, les cartes du cours font les Flashcards.
    /// L'élève n'est jamais bloqué devant son propre cours.
    func convertOffline(_ course: Course, in context: ModelContext) {
        guard !course.isLesson, !converting.contains(course.id) else { return }
        Self.prepareChapters(of: course, in: context)
        Self.apply(Self.offlineConversion(of: course), to: course, in: context)
        try? context.save()
    }

    static func offlineConversion(of course: Course) -> LessonConversion {
        let chapters = course.orderedChapters
        let icon = course.iconID.isEmpty ? MicaboIcon.guess(subject: course.subject, title: course.title).rawValue : course.iconID
        let words = chapters.reduce(0) { $0 + $1.plainText.split(whereSeparator: \.isWhitespace).count }
        return LessonConversion(
            icon: icon,
            intro: LessonPath.Intro(lines: [], minutes: max(5, words / 180 + chapters.count * 3)),
            takeaways: [],
            groups: PathLayout.groups(themeCount: chapters.count).map { LessonPath.Group(name: "", themes: $0) },
            chapters: chapters.map { chapter in
                LessonConversion.Chapter(
                    icon: chapter.iconID.isEmpty ? MicaboIcon.guess(subject: course.subject, title: chapter.title).rawValue : chapter.iconID,
                    questions: [],
                    flashcards: []
                )
            }
        )
    }

    static func apply(_ conversion: LessonConversion, to course: Course, in context: ModelContext) {
        let chapters = course.orderedChapters
        if course.iconID.isEmpty { course.iconID = conversion.icon }
        if course.toneRaw.isEmpty { course.toneRaw = LessonTone.stable(for: course.id).rawValue }
        for (index, chapter) in chapters.enumerated() {
            guard conversion.chapters.indices.contains(index) else { continue }
            let converted = conversion.chapters[index]
            chapter.iconID = converted.icon
            chapter.setQuiz(ThemeQuiz(questions: converted.questions.enumerated().map { number, question in
                question.question(id: "\(chapter.id.uuidString):\(number)")
            }))
            addCards(converted.flashcards, to: chapter, of: course, in: context)
            chapter.statusRaw = ThemeStatus.ready.rawValue
        }
        course.setLessonPath(LessonPath(
            icon: conversion.icon,
            intro: conversion.intro,
            takeaways: conversion.takeaways,
            groups: conversion.groups,
            status: .ready
        ))
    }
}

/// Un thème à écrire, sans référence au modèle de données : il traverse la tâche de fond.
private struct ThemeJob: Sendable {
    struct Base: Sendable {
        var lessonID: UUID
        var lessonTitle: String
        var themes: [String]
        var context: String
        var subject: String?
        var audience: LessonAudience
        var points: [[String]] = []
        var objectives: [String] = []
        var source: String = ""
    }

    var base: Base
    var chapterID: UUID
    var index: Int

    var request: LessonThemeRequest {
        LessonThemeRequest(
            lessonID: base.lessonID,
            lessonTitle: base.lessonTitle,
            themeIndex: index,
            themes: base.themes,
            context: base.context,
            subject: base.subject,
            audience: base.audience,
            points: base.points,
            objectives: base.objectives,
            source: base.source
        )
    }
}

/// Un signal qu'on attend une fois, et qu'on peut déclencher plusieurs fois sans effet.
@MainActor
final class AsyncSignal {
    private var fired = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func fire() {
        guard !fired else { return }
        fired = true
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }

    func wait() async {
        if fired { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

/// Un peu de temps pour finir quand l'app passe en arrière-plan : iOS laisse une trentaine de
/// secondes, assez pour qu'un plan ou un thème déjà parti arrive.
@MainActor
final class BackgroundWork {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.end()
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
