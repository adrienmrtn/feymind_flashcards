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
        /// Décidée à l'import : un cours qu'on sait privé doit l'être dès sa création, et non
        /// à partir du moment où l'on pense à le refermer.
        visibility: CourseVisibility = .standard,
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
        course.visibility = visibility
        course.fingerprint = CourseFingerprint.make(from: rawText)
        context.insert(course)

        try context.save()
        return course
    }

    /// Reprend le cours de quelqu'un d'autre dans « Mes cours ».
    ///
    /// Trois décisions, et chacune se paye si on la prend à l'envers :
    ///
    /// - **Un nouvel identifiant.** L'identifiant local devient la clé primaire distante :
    ///   garder celui de l'auteur ferait écrire une ligne qui lui appartient, et le
    ///   cloisonnement la refuserait — au mieux. Le cours repris est un cours à soi, pas une
    ///   référence vers le sien.
    /// - **Privé par défaut.** Reprendre un cours ne donne pas le droit de le rediffuser sous
    ///   son propre nom. Il reste dans l'app de celui qui l'a repris, et c'est à lui de décider
    ///   ensuite s'il le repartage.
    /// - **Les cartes viennent avec**, mais **neuves**. On copie le contenu — question,
    ///   réponse, format — et on remet l'état de répétition à zéro. Ce que l'auteur savait
    ///   mal reste chez lui.
    @discardableResult
    static func adopt(
        _ shared: SharedCourseRecord,
        from author: String?,
        cards: [SharedCardRecord] = [],
        in context: ModelContext
    ) throws -> Course {
        let title = TextSanitizer.clean(shared.title).nilIfBlank ?? "Cours repris"
        let index = title.hashValue.magnitude % UInt(MicaboColor.courseAccents.count)

        let course = Course(
            title: title,
            subject: shared.subject.flatMap { TextSanitizer.subject($0).nilIfBlank },
            summary: TextSanitizer.clean(shared.summary),
            emoji: CourseEmoji.resolve(
                proposed: shared.emoji,
                subject: shared.subject,
                title: title
            ),
            accentHex: shared.accent_hex?.nilIfBlank
                ?? MicaboColor.courseAccents[Int(index)].hexString,
            source: .library,
            // Le nom de l'auteur prend la place du nom de fichier : c'est ce que l'écran du
            // cours affiche en provenance, et un cours repris doit dire d'où il vient.
            sourceFileName: author.map { Username.display($0) },
            rawText: shared.raw_text,
            contextText: shared.context_text,
            sheet: CourseSheet.decode(from: shared.sheet?.data),
            isFromLibrary: true
        )
        course.visibility = .private
        course.fingerprint = CourseFingerprint.make(from: shared.raw_text)
        context.insert(course)
        attach(cards, to: course, in: context)

        try context.save()
        return course
    }

    /// Recopie le contenu des cartes partagées, en laissant l'apprentissage à zéro.
    /// Les cartes déjà présentes (même recto) ne sont pas doublées.
    @discardableResult
    static func attach(
        _ cards: [SharedCardRecord],
        to course: Course,
        in context: ModelContext
    ) -> [Flashcard] {
        guard !cards.isEmpty else { return [] }

        let existingFronts = Set(course.cards.map(\.front))
        var groups: [UUID: UUID] = [:]
        var position = (course.cards.map(\.position).max() ?? -1) + 1
        var inserted: [Flashcard] = []

        for remote in cards.sorted(by: { $0.position < $1.position }) {
            let front = TextSanitizer.clean(remote.front)
            let back = TextSanitizer.clean(remote.back)
            guard !front.isEmpty, !back.isEmpty else { continue }
            guard !existingFronts.contains(front) else { continue }

            let card = Flashcard(
                front: front,
                back: back,
                hint: remote.hint.map(TextSanitizer.clean)?.nilIfBlank,
                position: position,
                course: course
            )
            card.kind = CardKind(rawValue: remote.kind) ?? .basic
            card.choices = remote.choices.map(TextSanitizer.clean).filter { !$0.isEmpty }
            card.correctChoiceIndex = remote.correct_choice_index
            card.maskX = remote.mask_x
            card.maskY = remote.mask_y
            card.maskWidth = remote.mask_width
            card.maskHeight = remote.mask_height
            card.isReversed = remote.is_reversed
            if let oldGroup = remote.group_id {
                if groups[oldGroup] == nil { groups[oldGroup] = UUID() }
                card.groupID = groups[oldGroup]
            }

            context.insert(card)
            inserted.append(card)
            position += 1
        }

        if !inserted.isEmpty {
            course.updatedAt = Date()
        }
        return inserted
    }

    /// Le cours repris est-il déjà là ?
    ///
    /// Reprendre deux fois le même cours est le geste le plus facile à faire par erreur : il ne
    /// coûte qu'un appui, et l'écran ne dit rien tant qu'on ne l'a pas fait. On compare
    /// l'empreinte, comme pour un import.
    ///
    /// **Et le titre quand il n'y a pas d'empreinte.** `CourseFingerprint.make` rend une chaîne
    /// vide en dessous de quatre-vingts caractères utiles : un paquet de cartes partagé, ou un
    /// cours très court, n'en a donc pas, et se serait laissé reprendre indéfiniment. Le titre
    /// est un repère plus faible, mais il vaut mieux qu'aucun.
    static func adopted(_ shared: SharedCourseRecord, in context: ModelContext) -> Course? {
        let fingerprint = CourseFingerprint.make(from: shared.raw_text)

        if !fingerprint.isEmpty {
            let descriptor = FetchDescriptor<Course>(
                predicate: #Predicate { $0.fingerprint == fingerprint }
            )
            if let found = try? context.fetch(descriptor).first { return found }
        }

        let title = TextSanitizer.clean(shared.title).nilIfBlank ?? shared.title
        guard !title.isEmpty else { return nil }

        let descriptor = FetchDescriptor<Course>(
            predicate: #Predicate { $0.isFromLibrary && $0.title == title }
        )
        return try? context.fetch(descriptor).first
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
        /// Décidée à la création. Un paquet n'a pas de fiche, donc pas d'écran où l'on
        /// pourrait le refermer après coup : sans ce choix ici, il resterait public à vie.
        visibility: CourseVisibility = .standard,
        in context: ModelContext
    ) throws -> Course {
        let cleanTitle = TextSanitizer.clean(title).nilIfBlank ?? "Nouveau paquet"
        let cleanSubject = subject.flatMap { TextSanitizer.subject($0).nilIfBlank }
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
        course.visibility = visibility
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
        CloudTombstones.mark(CloudTable.courses, id: course.id)
        for card in course.cards {
            CloudTombstones.mark(CloudTable.flashcards, id: card.id)
        }
        context.delete(course)
        try context.save()
    }

    static func delete(_ card: Flashcard, in context: ModelContext) throws {
        CloudTombstones.mark(CloudTable.flashcards, id: card.id)
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
