import CoreGraphics
import Foundation
import SwiftData

/// Une zone masquée en cours de tracé, avant qu'elle ne devienne une carte.
struct OcclusionZone: Identifiable, Equatable {
    let id: UUID
    /// Coordonnées relatives (0…1) dans l'image.
    var rect: CGRect
    var label: String

    init(id: UUID = UUID(), rect: CGRect, label: String = "") {
        self.id = id
        self.rect = rect
        self.label = label
    }
}

/// Empreinte d'un cours, pour reconnaître un chapitre déjà importé.
///
/// On ne compare pas les textes entiers : un même PDF réexporté change de quelques
/// espaces. On normalise (minuscules, sans accents, sans ponctuation, espaces réduits),
/// on prend le début du contenu et sa longueur arrondie.
enum CourseFingerprint {
    static func normalizedTitle(_ title: String) -> String {
        normalize(title)
    }

    static func make(from rawText: String) -> String {
        let normalized = normalize(rawText)
        guard normalized.count >= 80 else { return "" }
        let head = String(normalized.prefix(400))
        let lengthBucket = normalized.count / 500
        return "\(lengthBucket):\(head)"
    }

    private static func normalize(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.map { character -> Character in
            character.isLetter || character.isNumber ? character : " "
        }
        return String(allowed)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}

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
        let index = accentIndex ?? abs(clean.title.hashValue) % MicaboColor.courseAccents.count
        let accent = MicaboColor.courseAccents[index % MicaboColor.courseAccents.count]

        let course = Course(
            title: clean.title.nilIfBlank ?? "Nouveau cours",
            subject: clean.subject?.nilIfBlank,
            summary: clean.summary,
            emoji: CourseEmoji.resolve(proposed: clean.emoji, subject: clean.subject, title: clean.title),
            accentHex: accent.hexString,
            source: source,
            sourceFileName: fileName,
            rawText: rawText,
            contextText: clean.contextText,
            coverImageData: coverImageData
        )
        course.fingerprint = CourseFingerprint.make(from: rawText)
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

    /// Crée une carte par zone masquée d'un même schéma. Les cartes partagent l'image et
    /// un `groupID`, mais chacune se planifie pour elle-même.
    @discardableResult
    static func addOcclusionCards(
        _ zones: [OcclusionZone],
        image: Data,
        to course: Course,
        in context: ModelContext
    ) throws -> [Flashcard] {
        guard !zones.isEmpty else { return [] }

        var startPosition = (course.cards.map(\.position).max() ?? -1) + 1
        let group = UUID()
        var inserted: [Flashcard] = []

        for zone in zones {
            let label = TextSanitizer.clean(zone.label)
            guard !label.isEmpty, zone.rect.width > 0, zone.rect.height > 0 else { continue }

            let card = Flashcard(
                front: "Quelle zone est masquée ?",
                back: label,
                position: startPosition,
                course: course
            )
            card.kind = .occlusion
            card.imageData = image
            card.maskRect = zone.rect
            card.groupID = group

            context.insert(card)
            inserted.append(card)
            startPosition += 1
        }

        course.updatedAt = Date()
        try context.save()
        return inserted
    }

    /// Crée le sens inverse des cartes qui n'en ont pas encore : la carte d'origine et sa
    /// jumelle partagent un `groupID` mais gardent chacune leur propre planification.
    @discardableResult
    static func addReverseCards(for course: Course, in context: ModelContext) throws -> [Flashcard] {
        let existing = course.cards
        let alreadyReversed = Set(existing.filter(\.isReversed).compactMap(\.groupID))

        var startPosition = (existing.map(\.position).max() ?? -1) + 1
        var inserted: [Flashcard] = []

        for card in existing.filter({ !$0.isReversed }) {
            guard card.kind == .basic else { continue }
            if let group = card.groupID, alreadyReversed.contains(group) { continue }

            let group = card.groupID ?? UUID()
            card.groupID = group

            let reverse = Flashcard(
                front: card.back,
                back: card.front,
                hint: nil,
                position: startPosition,
                course: course
            )
            reverse.isReversed = true
            reverse.groupID = group
            reverse.audioData = card.audioData

            context.insert(reverse)
            inserted.append(reverse)
            startPosition += 1
        }

        course.updatedAt = Date()
        try context.save()
        return inserted
    }

    /// Cours déjà importé qui ressemble à celui qu'on s'apprête à créer.
    ///
    /// Deux signaux suffisent et se complètent : un titre identique une fois normalisé, ou
    /// une empreinte de contenu identique. La seconde attrape le même chapitre réimporté
    /// sous un autre nom de fichier.
    static func duplicate(
        title: String,
        rawText: String,
        in context: ModelContext
    ) -> Course? {
        let normalizedTitle = CourseFingerprint.normalizedTitle(title)
        let fingerprint = CourseFingerprint.make(from: rawText)

        return allCourses(in: context).first { course in
            if !fingerprint.isEmpty, course.fingerprint == fingerprint { return true }
            if !normalizedTitle.isEmpty, CourseFingerprint.normalizedTitle(course.title) == normalizedTitle { return true }
            return false
        }
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
