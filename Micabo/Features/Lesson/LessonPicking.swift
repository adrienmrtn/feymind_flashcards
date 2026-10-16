import Foundation
import SwiftData

/// **Quelles questions, quelles cartes** — le tirage des cercles Quiz et Flashcards, et du
/// quiz complet (navbar, examen blanc). Voir `docs/refonte-parcours.md` § 5.4 et § 5.6.
///
/// Tout est pur et reproductible : le même tirage sort pour la même graine, ce qui rend une
/// reprise stable (on retrouve ses questions) et les tests exacts. La graine change d'une
/// tentative à l'autre : un quiz relancé ne repose pas les mêmes questions dans le même ordre.
enum LessonPicking {
    /// Le Checkpoint d'un palier : cinq questions sur le palier…
    static let circleQuizCount = 5
    /// … et deux sur les paliers d'avant, pour ne pas les oublier (l'entrelacement).
    static let checkpointReviewCount = 2
    /// Le quiz complet et l'examen blanc : dix questions.
    static let fullQuizCount = 10

    /// Le Quiz final : deux questions par thème, entre huit et douze.
    static func finalQuizCount(themes: Int) -> Int {
        min(12, max(8, themes * 2))
    }

    /// Du plus simple au plus exigeant, sans changer l'ordre entre questions de même difficulté.
    static func progressive(_ questions: [QuizQuestion]) -> [QuizQuestion] {
        questions.enumerated()
            .sorted { ($0.element.difficulty, $0.offset) < ($1.element.difficulty, $1.offset) }
            .map(\.element)
    }
    /// Le cercle Flashcards : dix cartes.
    static let circleCardCount = 10

    /// **Les questions d'un quiz.** Les ratées d'abord (les plus récentes en tête), puis les
    /// questions de réserve tirées en alternant les thèmes, pour qu'aucun ne soit oublié ; les
    /// questions de fin ne servent que si la réserve ne suffit pas.
    ///
    /// - Parameters:
    ///   - themes: par thème couvert, ses questions (la première est celle de fin).
    ///   - missed: les questions ratées, des plus anciennes aux plus récentes.
    static func quiz(
        themes: [[QuizQuestion]],
        missed: [String],
        count: Int,
        seed: UInt64
    ) -> [QuizQuestion] {
        var generator = SeededGenerator(seed: seed)
        let all = themes.flatMap { $0 }.filter(\.isValid)
        var picked: [QuizQuestion] = []
        var used = Set<String>()

        for id in missed.reversed() where picked.count < count {
            if let question = all.first(where: { $0.id == id }), !used.contains(id) {
                picked.append(question)
                used.insert(id)
            }
        }

        func roundRobin(_ pools: [[QuizQuestion]]) {
            var shuffled = pools.map { $0.filter { !used.contains($0.id) && $0.isValid }.shuffled(using: &generator) }
            var progressed = true
            while picked.count < count && progressed {
                progressed = false
                for index in shuffled.indices where picked.count < count {
                    guard !shuffled[index].isEmpty else { continue }
                    let question = shuffled[index].removeFirst()
                    picked.append(question)
                    used.insert(question.id)
                    progressed = true
                }
            }
        }

        roundRobin(themes.map { Array($0.dropFirst()) })
        roundRobin(themes.map { Array($0.prefix(1)) })
        return picked
    }

    /// Ce que le tirage des cartes sait d'une carte, sans SwiftData.
    struct CardCandidate: Equatable {
        var id: UUID
        /// Une question de quiz ratée, devenue carte : elle passe en premier.
        var isMissedQuestion: Bool
        var isDue: Bool
        var isNew: Bool
        var position: Int
    }

    /// **Les dix cartes du cercle Flashcards** : les questions ratées d'abord, puis les cartes
    /// dues, puis les neuves dans l'ordre de la leçon, puis un tirage du reste.
    static func cards(_ candidates: [CardCandidate], count: Int, seed: UInt64) -> [UUID] {
        var generator = SeededGenerator(seed: seed)
        var picked: [UUID] = []
        var used = Set<UUID>()
        func take(_ list: [CardCandidate]) {
            for candidate in list where picked.count < count && !used.contains(candidate.id) {
                picked.append(candidate.id)
                used.insert(candidate.id)
            }
        }
        take(candidates.filter(\.isMissedQuestion).sorted { $0.position > $1.position })
        take(candidates.filter { $0.isDue && !$0.isNew }.shuffled(using: &generator))
        take(candidates.filter(\.isNew).sorted { $0.position < $1.position })
        take(candidates.shuffled(using: &generator))
        return picked
    }

    /// Une graine qui change à chaque tentative, stable pour une même tentative.
    static func seed(_ parts: String...) -> UInt64 {
        StableHash.of(parts.joined(separator: "|"))
    }
}

/// SplitMix64 : un générateur reproductible, pour des tirages qu'on peut rejouer (les quiz
/// d'une leçon, et les cours de démonstration du mode débogage).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// **Ce que la leçon écrit sur les cartes** : une note de flashcard, et la carte que devient
/// une question ratée.
enum LessonReview {
    /// Note une carte comme la session de révision le fait : SM-2, puis le journal (qui nourrit
    /// aussi le classement de la semaine).
    static func rate(_ card: Flashcard, _ rating: ReviewRating, now: Date = Date()) {
        let before = CardScheduling(card: card)
        let outcome = SM2Scheduler.schedule(snapshot: before.snapshot, rating: rating, now: now)
        var after = before
        after.apply(outcome, at: now)
        after.restore(on: card)
        let log = ReviewLog(
            reviewedAt: now,
            rating: rating,
            stateBefore: before.state,
            previousIntervalDays: before.intervalDays,
            newIntervalDays: outcome.intervalDays,
            easeAfter: outcome.easeFactor
        )
        card.logs = (card.logs ?? []) + [log]
    }

    /// **Une question ratée devient une flashcard à revoir demain.** Une carte QCM, rattachée
    /// au thème de la question ; ratée une seconde fois, la même carte revient demain au lieu
    /// d'en créer une autre.
    @discardableResult
    static func cardForMissed(
        _ question: QuizQuestion,
        chapter: Chapter?,
        course: Course,
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Flashcard {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        if let existing = course.cards.first(where: { $0.front == question.prompt && ($0.kind == .choice || $0.kind == .basic) }) {
            if existing.dueDate > tomorrow { existing.dueDate = tomorrow }
            existing.updatedAt = now
            return existing
        }
        let card: Flashcard
        switch question.kind {
        case .choice, .truefalse, .gap:
            card = Flashcard(front: question.prompt, back: question.why, position: course.cards.count, course: course)
            card.kind = .choice
            card.choices = question.choices
            card.correctChoiceIndex = question.answer
        case .order, .match:
            // Un ordre ou une association se révise en recto verso : la question, et au dos la
            // bonne réponse en clair, puis pourquoi.
            let back = [question.answerText, question.why].filter { !$0.isEmpty }.joined(separator: "\n\n")
            card = Flashcard(front: question.prompt, back: back, position: course.cards.count, course: course)
        }
        card.chapter = chapter
        // Ratée dans un quiz, la carte est déjà « en cours » : elle compte dans « à réviser »
        // dès demain, au lieu d'attendre sa première séance comme une carte neuve.
        card.state = .learning
        card.dueDate = tomorrow
        context.insert(card)
        return card
    }
}
