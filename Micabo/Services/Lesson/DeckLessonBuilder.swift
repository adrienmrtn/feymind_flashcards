import Foundation
import SwiftData

/// **Un paquet de flashcards collé**, tel que Quizlet l'exporte : un terme, une tabulation,
/// sa définition, une carte par ligne (`docs/supports.md`).
///
/// L'export de Quizlet laisse choisir les séparateurs ; on reconnaît les courants (tabulation,
/// tiret entouré d'espaces, deux-points, point-virgule, virgule) en prenant celui que portent
/// le plus de lignes. Une ligne sans séparateur prolonge la définition précédente : une
/// définition sur plusieurs lignes reste une seule carte.
enum FlashcardPaste {
    struct Card: Equatable {
        var front: String
        var back: String
    }

    struct Result: Equatable {
        var cards: [Card]
        /// Les lignes qui ne faisaient pas une carte (un terme sans définition).
        var skipped: Int
    }

    static let cardLimit = 2_000

    /// Les séparateurs essayés, du plus sûr au plus ambigu.
    static let separators = ["\t", " - ", " – ", " — ", " : ", ": ", ";", " = ", " → ", ","]

    static func parse(_ text: String) -> Result {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        let filled = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let separator = Self.separator(for: filled) else {
            return Result(cards: [], skipped: filled.count)
        }

        var cards: [Card] = []
        var skipped = 0
        var pendingTerm: String?
        // « vert: » : le séparateur collé au bout, sans définition derrière.
        let bare = separator.trimmingCharacters(in: .whitespaces)
        for line in filled {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !bare.isEmpty, trimmed.hasSuffix(bare), line.range(of: separator) == nil {
                skipped += 1
                continue
            }
            if let range = line.range(of: separator) {
                if pendingTerm != nil {
                    // Un terme resté seul juste avant : il n'avait pas de définition.
                    skipped += 1
                    pendingTerm = nil
                }
                let front = clean(String(line[..<range.lowerBound]))
                let back = clean(String(line[range.upperBound...]))
                if front.isEmpty && back.isEmpty { continue }
                if front.isEmpty || back.isEmpty {
                    skipped += 1
                    continue
                }
                cards.append(Card(front: front, back: back))
                if cards.count >= cardLimit { break }
            } else if var last = cards.popLast() {
                // La suite d'une définition sur plusieurs lignes.
                last.back += "\n" + clean(line)
                cards.append(last)
            } else {
                pendingTerm = clean(line)
            }
        }
        if pendingTerm != nil { skipped += 1 }
        return Result(cards: cards, skipped: skipped)
    }

    /// Le séparateur que porte le plus de lignes ; à égalité, le premier de la liste.
    static func separator(for lines: [String]) -> String? {
        var best: (separator: String, count: Int)?
        for candidate in separators {
            let count = lines.filter { line in
                guard let range = line.range(of: candidate) else { return false }
                return !line[..<range.lowerBound].trimmingCharacters(in: .whitespaces).isEmpty
            }.count
            guard count > 0 else { continue }
            // Une tabulation gagne dès qu'elle est là : c'est le format d'export par défaut.
            if candidate == "\t" { return candidate }
            if count > (best?.count ?? 0) { best = (candidate, count) }
        }
        return best?.separator
    }

    private static func clean(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Les guillemets qu'un export CSV pose autour d'un champ.
        if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "\"\"", with: "\"")
        }
        return value
    }
}

/// **Un paquet de flashcards devient une leçon, sur le téléphone** (`docs/supports.md`).
///
/// Rien ne passe par le modèle : les cartes sont déjà écrites, il n'y a qu'à les ranger. Elles
/// sont réparties en parties d'une douzaine ; chaque partie reçoit des notes (le glossaire de
/// ses cartes), un quiz tiré des cartes elles-mêmes (la bonne définition parmi celles des
/// autres cartes), et ses flashcards, prêtes à réviser dès aujourd'hui. Le chemin, les
/// checkpoints et le Quiz final se calculent comme pour une leçon écrite par Mika.
///
/// Le cours est un paquet (`CourseSource.deck`) : il ne consomme pas la leçon offerte
/// (`LessonAllowance.hasUsedFreeLesson`).
enum DeckLessonBuilder {
    /// Une carte à ranger.
    struct Card: Equatable {
        var front: String
        var back: String
    }

    /// Une partie du paquet, prête à devenir un thème.
    struct Part: Equatable {
        var title: String
        var cards: [Card]
        var notes: ThemeNotes
        var questions: [GeneratedQuestion]
    }

    static let cardsPerPart = 12
    static let maximumParts = 12
    static let questionsPerPart = 8

    /// Les parties : une seule jusqu'à douze cartes, puis des parts égales, douze au plus.
    static func parts(of cards: [Card], locale: UiLocale = .resolved()) -> [Part] {
        let usable = cards.filter { !$0.front.isEmpty && !$0.back.isEmpty }
        guard !usable.isEmpty else { return [] }
        let count = min(maximumParts, max(1, Int((Double(usable.count) / Double(cardsPerPart)).rounded(.up))))
        let size = Int((Double(usable.count) / Double(count)).rounded(.up))
        var parts: [Part] = []
        var start = 0
        var index = 0
        while start < usable.count {
            let slice = Array(usable[start..<min(usable.count, start + size)])
            let title = count == 1
                ? L10n.t("ios.sup.deck.allCards", locale: locale)
                : L10n.t("ios.sup.deck.part", locale: locale, vars: ["n": String(index + 1)])
            parts.append(Part(
                title: title,
                cards: slice,
                notes: notes(for: slice, locale: locale),
                questions: questions(for: slice, among: usable, seed: index)
            ))
            start += size
            index += 1
        }
        return parts
    }

    /// Le glossaire d'une partie : chaque carte en définition.
    static func notes(for cards: [Card], locale: UiLocale) -> ThemeNotes {
        ThemeNotes(
            oneLiner: L10n.t("ios.sup.deck.oneLiner", locale: locale, vars: ["count": String(cards.count)]),
            blocks: cards.map { NoteBlock.definition(term: $0.front, text: $0.back) },
            takeaways: []
        )
    }

    /// **Le quiz d'une partie, tiré des cartes** : pour chaque carte, sa définition parmi celles
    /// de trois autres cartes du paquet. Une carte sur deux se pose à l'envers (la définition,
    /// et le terme à retrouver). Sans trois autres réponses différentes, pas de question.
    static func questions(for cards: [Card], among all: [Card], seed: Int) -> [GeneratedQuestion] {
        var questions: [GeneratedQuestion] = []
        for (offset, card) in cards.prefix(questionsPerPart).enumerated() {
            let reversed = offset % 2 == 1
            let prompt = reversed ? card.back : card.front
            let answer = reversed ? card.front : card.back
            let pool = all
                .map { reversed ? $0.front : $0.back }
                .filter { normalized($0) != normalized(answer) }
            var distractors: [String] = []
            var seen: Set<String> = []
            // Un tirage stable : la même carte donne les mêmes propositions d'une ouverture à l'autre.
            let start = pool.isEmpty ? 0 : (seed * 7 + offset * 5 + 3) % pool.count
            for step in 0..<pool.count {
                let candidate = pool[(start + step * 3) % pool.count]
                let key = normalized(candidate)
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                distractors.append(candidate)
                if distractors.count == 3 { break }
            }
            guard distractors.count >= 3 else { continue }
            let position = (seed + offset) % 4
            var choices = distractors
            choices.insert(answer, at: position)
            questions.append(GeneratedQuestion(
                kind: QuizKind.choice.rawValue,
                prompt: prompt,
                choices: choices,
                answer: position,
                why: "\(card.front) : \(card.back)",
                difficulty: reversed ? 2 : 1
            ))
        }
        return questions
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Crée le paquet et sa leçon, et rend le cours. Tout est enregistré avant de rendre.
    @MainActor
    @discardableResult
    static func make(title: String, cards: [Card], in context: ModelContext) throws -> Course {
        let course = try CourseRepository.makeDeck(title: title, in: context)
        let split = Self.parts(of: cards)
        let pairs = cards.map { "\($0.front) : \($0.back)" }.joined(separator: "\n")
        course.rawText = String(pairs.prefix(LessonComposer.maximumCharacters))
        course.contextText = String(pairs.prefix(20_000))
        course.toneRaw = LessonTone.stable(for: course.id).rawValue
        if course.iconID.isEmpty {
            course.iconID = MicaboIcon.guess(subject: course.subject, title: course.title).rawValue
        }
        for (index, part) in split.enumerated() {
            let chapter = Chapter(position: index, title: part.title, course: course)
            chapter.iconID = MicaboIcon.cards.rawValue
            chapter.setNotes(part.notes)
            context.insert(chapter)
        }
        let conversion = LessonConversion(
            icon: course.iconID,
            intro: LessonPath.Intro(lines: [], minutes: max(5, cards.count / 4)),
            takeaways: [],
            groups: PathLayout.groups(themeCount: split.count).map { LessonPath.Group(name: "", themes: $0) },
            chapters: split.map { part in
                LessonConversion.Chapter(
                    icon: MicaboIcon.cards.rawValue,
                    questions: part.questions,
                    flashcards: part.cards.map { GeneratedCard(front: $0.front, back: $0.back) }
                )
            }
        )
        LessonBuilder.apply(conversion, to: course, in: context)
        course.updatedAt = Date()
        try context.save()
        CourseLedger.noteChange()
        CloudSync.nudge()
        return course
    }
}
