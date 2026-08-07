import Foundation
import SwiftData

enum CourseRepository {
    /// Enregistre un cours analysé, sans ses cartes.
    @discardableResult
    static func save(
        _ generated: GeneratedCourse,
        source: CourseSource,
        rawText: String,
        fileName: String? = nil,
        coverImageData: Data? = nil,
        accentIndex: Int? = nil,
        in context: ModelContext
    ) throws -> Course {
        let clean = generated.sanitized()
        let index = accentIndex ?? abs(clean.title.hashValue) % FeyColor.courseAccents.count
        let accent = FeyColor.courseAccents[index % FeyColor.courseAccents.count]

        let course = Course(
            title: clean.title.nilIfBlank ?? "Nouveau cours",
            subject: clean.subject?.nilIfBlank,
            summary: clean.summary,
            emoji: clean.emoji?.nilIfBlank ?? "📘",
            accentHex: accent.hexString,
            source: source,
            sourceFileName: fileName,
            rawText: rawText,
            contextText: clean.contextText,
            coverImageData: coverImageData
        )
        context.insert(course)

        try context.save()
        return course
    }

    @discardableResult
    static func addFlashcards(
        _ generated: [GeneratedFlashcard],
        to course: Course,
        in context: ModelContext
    ) throws -> [Flashcard] {
        var startPosition = (course.cards.map(\.position).max() ?? -1) + 1
        var inserted: [Flashcard] = []

        for candidate in generated {
            let front = TextSanitizer.clean(candidate.front)
            let back = TextSanitizer.clean(candidate.back)
            guard !front.isEmpty, !back.isEmpty else { continue }

            let card = Flashcard(
                front: front,
                back: back,
                hint: candidate.hint.map(TextSanitizer.clean)?.nilIfBlank,
                position: startPosition,
                course: course
            )
            context.insert(card)
            inserted.append(card)
            startPosition += 1
        }

        course.updatedAt = Date()
        try context.save()
        return inserted
    }

    static func delete(_ course: Course, in context: ModelContext) throws {
        context.delete(course)
        try context.save()
    }

    static func delete(_ card: Flashcard, in context: ModelContext) throws {
        context.delete(card)
        try context.save()
    }

    static func allCourses(in context: ModelContext) -> [Course] {
        let descriptor = FetchDescriptor<Course>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func allCards(in context: ModelContext) -> [Flashcard] {
        (try? context.fetch(FetchDescriptor<Flashcard>())) ?? []
    }

    /// Cartes dues, toutes matières confondues.
    static func dueCards(in context: ModelContext, now: Date = Date()) -> [Flashcard] {
        StudyQueueBuilder.build(from: allCards(in: context), now: now, limits: .unlimited)
    }
}
