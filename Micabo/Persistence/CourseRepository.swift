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
    /// Enregistre un cours fiché, sans ses cartes.
    ///
    /// Depuis que l'import produit d'abord une fiche, c'est ici que s'arrête le parcours
    /// d'import : les cartes viennent plus tard, si l'utilisateur les demande.
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
            contextText: clean.contextText.nilIfBlank ?? (clean.sheet?.plainText() ?? ""),
            sheet: clean.sheet,
            coverImageData: coverImageData
        )
        course.fingerprint = CourseFingerprint.make(from: rawText)
        context.insert(course)

        try context.save()
        return course
    }

    /// Crée un **paquet de cartes** : un cours sans document et sans fiche.
    ///
    /// Tout passait par un import, donc par une fiche, et il n'y avait aucun moyen de
    /// simplement se faire un paquet de vocabulaire ou de dates. Un paquet est un cours comme
    /// un autre pour le reste de l'app — il se révise, il compte dans la file du jour, il
    /// entre dans un plan d'examen — il n'a simplement rien à ficher.
    ///
    /// Le texte est facultatif : collé, il sert de matière au modèle pour écrire les
    /// premières cartes ; absent, le paquet démarre vide et se remplit à la main.
    @discardableResult
    static func makeDeck(
        title: String,
        subject: String? = nil,
        rawText: String = "",
        in context: ModelContext
    ) throws -> Course {
        let cleanTitle = TextSanitizer.clean(title).nilIfBlank ?? "Nouveau paquet"
        let cleanSubject = subject.flatMap { TextSanitizer.clean($0).nilIfBlank }
        let index = abs(cleanTitle.hashValue) % MicaboColor.courseAccents.count
        let text = TextSanitizer.normalizeExtractedText(rawText)

        let course = Course(
            title: cleanTitle,
            subject: cleanSubject,
            summary: "",
            emoji: CourseEmoji.resolve(proposed: nil, subject: cleanSubject, title: cleanTitle),
            accentHex: MicaboColor.courseAccents[index].hexString,
            source: .deck,
            rawText: text,
            contextText: text
        )
        // Pas d'empreinte : deux paquets du même nom ne sont pas un doublon, et rien n'a été
        // importé qu'on risquerait d'importer deux fois.
        context.insert(course)

        try context.save()
        return course
    }

    /// Remplace la fiche d'un cours existant : c'est le chemin de « Refaire la fiche », et
    /// celui d'un cours importé avant que la fiche n'existe.
    ///
    /// Le titre, la matière et l'emoji ne sont pas retouchés. Un cours renommé à la main
    /// ne doit pas reprendre le nom que le modèle lui trouve au second passage.
    @discardableResult
    static func updateSheet(
        of course: Course,
        with generated: GeneratedCourse,
        in context: ModelContext
    ) throws -> Course {
        let clean = generated.sanitized()
        guard let sheet = clean.sheet, !sheet.isEmpty else {
            throw AIServiceError.invalidResponse
        }

        course.apply(sheet)
        course.contextText = clean.contextText.nilIfBlank ?? sheet.plainText()
        if course.summary.isEmpty {
            course.summary = clean.summary
        }
        course.updatedAt = Date()

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
            // Le trou est normalisé avant le nettoyage : celui-ci mange les tirets bas
            // avec le reste du balisage, et emporterait le blanc avec eux.
            let rawFront = candidate.resolvedKind == .cloze
                ? ClozeGap.normalize(candidate.front)
                : candidate.front
            let front = TextSanitizer.clean(rawFront)
            let back = TextSanitizer.clean(candidate.back)
            guard !front.isEmpty, !back.isEmpty else { continue }

            let card = Flashcard(
                front: front,
                back: back,
                hint: candidate.hint.map(TextSanitizer.clean)?.nilIfBlank,
                position: startPosition,
                course: course
            )
            applyFormat(of: candidate, to: card)

            context.insert(card)
            inserted.append(card)
            startPosition += 1
        }

        course.updatedAt = Date()
        try context.save()
        return inserted
    }

    /// Applique le format annoncé par la génération, en refusant ce qui ne tient pas
    /// debout : un texte à trou sans trou, ou un QCM sans propositions distinctes,
    /// redevient une carte recto verso. La question et la réponse, elles, restent
    /// bonnes : on ne jette pas la carte pour un format raté.
    private static func applyFormat(of candidate: GeneratedFlashcard, to card: Flashcard) {
        switch candidate.resolvedKind {
        case .cloze:
            guard ClozeGap.isPresent(in: card.front) else { return }
            card.kind = .cloze

        case .choice:
            let choices = (candidate.choices ?? [])
                .map(TextSanitizer.clean)
                .filter { !$0.isEmpty }
            var unique: [String] = []
            for choice in choices where !unique.contains(choice) {
                unique.append(choice)
            }

            // L'index annoncé prime ; s'il est absent ou faux, la proposition qui
            // reprend le verso fait l'affaire.
            let declared = candidate.answerIndex.flatMap { index -> Int? in
                unique.indices.contains(index) ? index : nil
            }
            let matched = unique.firstIndex { $0.caseInsensitiveCompare(card.back) == .orderedSame }
            guard unique.count >= 2, let index = declared ?? matched else { return }

            card.choices = unique
            card.correctChoiceIndex = index
            card.kind = .choice

        case .basic, .occlusion:
            break
        }
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
