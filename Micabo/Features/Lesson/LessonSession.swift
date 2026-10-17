import Foundation
import Observation
import SwiftData

/// **Une leçon ouverte** : son chemin, sa progression, et ce qu'on peut y faire.
///
/// Le plan et la progression sont décodés une fois et gardés ici, pas relus depuis un corps de
/// vue. Chaque écriture (un cercle coché, un temps ajouté, une question ratée) passe par cet
/// objet, qui date le cours pour la synchro et rafraîchit ce que l'écran montre.
@MainActor
@Observable
final class LessonSession {
    let course: Course
    private(set) var plan: LessonPath?
    private(set) var steps: [PathStep] = []
    private(set) var circles: [PathCircle] = []
    private(set) var progress = LessonProgress()

    init(course: Course) {
        self.course = course
        reload()
    }

    /// Relit le cours : à l'ouverture, après une conversion, quand un thème arrive.
    func reload() {
        plan = course.lessonPath
        steps = course.pathSteps(plan: plan)
        circles = steps.compactMap(\.circle)
        var progress = course.progress
        progress.done = PathLayout.migrated(done: progress.done, circles: circles, finished: progress.finishedAt != nil)
        self.progress = progress
    }

    // MARK: Où on en est

    var current: PathCircle? { PathLayout.current(in: circles, done: progress.done) }

    func state(of circle: PathCircle) -> PathCircle.State {
        PathLayout.state(of: circle, in: circles, done: progress.done)
    }

    var doneCount: Int { circles.filter { progress.done.contains($0.id) }.count }
    var totalCount: Int { circles.count }

    var percent: Int {
        totalCount == 0 ? 0 : Int((Double(doneCount) / Double(totalCount) * 100).rounded())
    }

    var isFinished: Bool { progress.finishedAt != nil }

    /// Le thème d'un cercle Notes, ou le premier thème d'un quiz.
    func chapter(at index: Int) -> Chapter? {
        let chapters = course.orderedChapters
        return chapters.indices.contains(index) ? chapters[index] : nil
    }

    /// Ce qu'un cercle attend encore avant de s'ouvrir.
    enum Readiness: Equatable {
        case ready
        /// Ses notes s'écrivent.
        case writing
        /// L'écriture a échoué : « Réessayer ».
        case failed
    }

    func readiness(of circle: PathCircle) -> Readiness {
        switch circle.kind {
        case .notes(let theme):
            return readiness(ofTheme: theme)
        case .quiz(_, let themes), .final(let themes):
            // Un quiz attend ses thèmes ; sans questions du tout (une leçon convertie hors
            // ligne), il se passe d'un appui plutôt que de bloquer le chemin.
            let states = themes.map(readiness(ofTheme:))
            if states.contains(.writing) { return .writing }
            if states.contains(.failed) && quizQuestions(themes: themes).isEmpty { return .failed }
            return .ready
        case .intro:
            return .ready
        }
    }

    private func readiness(ofTheme index: Int) -> Readiness {
        switch chapter(at: index)?.status {
        case .pending: .writing
        case .failed: .failed
        default: .ready
        }
    }

    // MARK: Les questions

    /// Les questions des thèmes donnés, thème par thème (la première est celle de fin).
    func quizQuestions(themes: [Int]) -> [[QuizQuestion]] {
        themes.compactMap { chapter(at: $0)?.quiz?.questions }.filter { !$0.isEmpty }
    }

    /// **Les questions d'un Checkpoint ou du Quiz final**, du plus simple au plus exigeant.
    ///
    /// Un Checkpoint pose cinq questions sur son palier et deux sur les paliers d'avant :
    /// revenir sur ce qu'on a vu plus tôt est ce qui le fait tenir. Le Quiz final reprend
    /// toute la leçon, deux questions par thème.
    func circleQuiz(_ circle: PathCircle) -> [QuizQuestion] {
        let attempt = progress.quizScores[circle.id] == nil ? 0 : 1 + progress.done.count
        let seed = LessonPicking.seed(course.id.uuidString, circle.id, String(attempt))
        switch circle.kind {
        case .quiz(_, let themes):
            let current = LessonPicking.quiz(
                themes: quizQuestions(themes: themes),
                missed: progress.missed,
                count: LessonPicking.circleQuizCount,
                seed: seed
            )
            let earlier = Array(0..<(themes.min() ?? 0))
            let review = LessonPicking.quiz(
                themes: quizQuestions(themes: earlier),
                missed: progress.missed,
                count: LessonPicking.checkpointReviewCount,
                seed: seed &+ 1
            ).filter { question in !current.contains { $0.id == question.id } }
            return LessonPicking.progressive(current + review)
        case .final(let themes):
            return LessonPicking.progressive(LessonPicking.quiz(
                themes: quizQuestions(themes: themes),
                missed: progress.missed,
                count: LessonPicking.finalQuizCount(themes: themes.count),
                seed: seed
            ))
        case .intro, .notes:
            return []
        }
    }

    /// Le quiz complet (navbar, examen blanc) : dix questions sur toute la leçon. Change à
    /// chaque lancement.
    func fullQuiz(attempt: Int) -> [QuizQuestion] {
        LessonPicking.quiz(
            themes: quizQuestions(themes: Array(course.orderedChapters.indices)),
            missed: progress.missed,
            count: LessonPicking.fullQuizCount,
            seed: LessonPicking.seed(course.id.uuidString, "full", String(attempt))
        )
    }

    /// Le thème d'une question, retrouvé par son identifiant (`<thème>:<rang>`).
    func chapter(ofQuestion id: String) -> Chapter? {
        let prefix = id.split(separator: ":").first.map(String.init) ?? ""
        return course.orderedChapters.first { $0.id.uuidString == prefix }
    }

    // MARK: Les cartes

    /// Les dix cartes du cercle Flashcards.
    func circleCards(now: Date = Date()) -> [Flashcard] {
        let cards = course.cards.filter { !$0.isSuspended }
        let missedPrompts = Set(progress.missed.compactMap { id in
            chapter(ofQuestion: id)?.quiz?.questions.first { $0.id == id }?.prompt
        })
        let candidates = cards.map { card in
            LessonPicking.CardCandidate(
                id: card.id,
                isMissedQuestion: card.kind == .choice && missedPrompts.contains(card.front),
                isDue: card.dueDate <= now,
                isNew: card.state == .new,
                position: card.position
            )
        }
        let ids = LessonPicking.cards(
            candidates,
            count: LessonPicking.circleCardCount,
            seed: LessonPicking.seed(course.id.uuidString, "cards", String(progress.done.count))
        )
        let byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    /// Une séance de révision : les cartes dues d'abord, puis des nouvelles, quinze au plus.
    static let newCardsPerSession = 15

    func studyQueue(now: Date = Date()) -> [Flashcard] {
        let active = course.cards.filter { !$0.isSuspended }
        let due = active.filter { $0.state != .new && $0.dueDate <= now }.sorted { $0.dueDate < $1.dueDate }
        let fresh = active.filter { $0.state == .new }.sorted { $0.position < $1.position }.prefix(Self.newCardsPerSession)
        return Array((due + fresh).prefix(30))
    }

    /// Les cartes de la leçon à revoir aujourd'hui.
    func dueCards(now: Date = Date()) -> [Flashcard] {
        course.cards
            .filter { !$0.isSuspended && $0.state != .new && $0.dueDate <= now }
            .sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: Écrire

    /// Coche une étape. Le Quiz final coche aussi la leçon : elle passe en « apprise ».
    ///
    /// Une étape finie allume aussi la journée de la série (`StudyStreak`) : lire ses notes
    /// jusqu'au bout est une vraie séance, même sans une seule carte notée.
    func complete(_ circle: PathCircle, in context: ModelContext) {
        StudyStreak.record()
        course.updateProgress { progress in
            progress.done.insert(circle.id)
            progress.inCircle = 0
            if case .final = circle.kind, progress.finishedAt == nil {
                progress.finishedAt = Date()
            }
        }
        try? context.save()
        reload()
    }

    /// **Recommencer la leçon** : le chemin repart de l'Intro. Les flashcards gardent leur
    /// rythme (elles se révisent à part) ; le temps passé reste compté.
    func reset(in context: ModelContext) {
        course.updateProgress { progress in
            progress.done = []
            progress.inCircle = 0
            progress.quizScores = [:]
            progress.missed = []
            progress.finishedAt = nil
        }
        try? context.save()
        reload()
    }

    /// Où on en est dans le cercle en cours : l'anneau autour de lui.
    func setInCircle(_ value: Double, in context: ModelContext) {
        let clamped = min(1, max(0, value))
        guard abs(clamped - progress.inCircle) >= 0.05 else { return }
        course.updateProgress { $0.inCircle = clamped }
        try? context.save()
        progress = course.progress
    }

    func addTime(_ seconds: TimeInterval, to activity: LessonActivity, in context: ModelContext) {
        guard seconds >= 1 else { return }
        course.updateProgress { $0.addTime(seconds, to: activity) }
        try? context.save()
        progress = course.progress
    }

    /// Une réponse à un QCM. Ratée, la question devient une flashcard à revoir demain.
    ///
    /// Juste ou fausse, elle compte pour la série : on a travaillé, même si l'étape n'est pas
    /// allée à son terme.
    func answered(_ question: QuizQuestion, right: Bool, in context: ModelContext) {
        StudyStreak.record()
        course.updateProgress { progress in
            if right { progress.noteRight(question.id) } else { progress.noteMissed(question.id) }
        }
        if !right {
            LessonReview.cardForMissed(question, chapter: chapter(ofQuestion: question.id), course: course, in: context)
        }
        try? context.save()
        progress = course.progress
    }

    func recordQuiz(_ circleID: String, right: Int, total: Int, in context: ModelContext) {
        course.updateProgress { $0.quizScores[circleID] = [right, total] }
        try? context.save()
        progress = course.progress
    }

    func markOpened(in context: ModelContext) {
        course.lastOpenedAt = Date()
        try? context.save()
    }
}
