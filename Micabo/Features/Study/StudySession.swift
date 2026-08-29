import Foundation
import Observation
import SwiftData

enum StudySource {
    case course(Course)
    case allDue
    case cards([Flashcard])

    /// Clé de reprise. Une sélection ponctuelle de cartes ne se reprend pas : on ne
    /// saurait pas la reconstituer de façon fiable au lancement suivant.
    var persistenceKey: String? {
        switch self {
        case .allDue:
            return "allDue"
        case .course(let course):
            return "course:\(course.id.uuidString)"
        case .cards:
            return nil
        }
    }
}

/// Deux façons de réviser, et il ne faut pas les confondre : la session normale écrit
/// dans le planning, l'entraînement libre n'y touche pas.
enum StudyMode {
    case scheduled
    case practice

    var affectsSchedule: Bool { self == .scheduled }
}

/// Pilote une session de révision : file d'attente, réponses, statistiques.
@Observable
final class StudySession {
    struct Entry {
        var card: Flashcard
        /// Instant à partir duquel la carte peut réapparaître dans la session.
        var availableAt: Date
    }

    /// Ce qu'il faut pour revenir exactement à l'état d'avant la dernière action.
    private struct UndoStep {
        let card: Flashcard
        let scheduling: CardScheduling
        /// Le journal déjà posé sur le disque, à supprimer si on l'annule après un `flush`.
        var log: ReviewLog?
        /// Le journal encore en mémoire, à retirer si on l'annule avant le `flush`.
        var pendingLogID: UUID?
        let pending: [Entry]
        let answered: [Flashcard]
        let answeredCount: Int
        let ratingCounts: [ReviewRating: Int]
        let graduatedCount: Int
    }

    /// Une note qui n'a pas encore touché SwiftData. Elle vit ici jusqu'au `flush`.
    private struct PendingLog {
        let id = UUID()
        let card: Flashcard
        let reviewedAt: Date
        let rating: ReviewRating
        let stateBefore: CardState
        let previousIntervalDays: Double
        let newIntervalDays: Double
        let easeAfter: Double
    }

    /// Une carte replanifiée à moins de dix minutes revient dans la même session.
    /// Aligné sur `LEARN_AHEAD_SECONDS` de `@micabo/core` : 20 min, comme Anki.
    static let learnAheadWindow: TimeInterval = 20 * 60

    private(set) var pending: [Entry] = []
    private(set) var current: Flashcard?
    private(set) var isRevealed = false
    private(set) var initialCount = 0
    private(set) var answeredCount = 0
    /// Combien de fois chaque note a été donnée.
    ///
    /// Le détail était perdu : on comptait « à revoir » d'un côté et tout le reste de
    /// l'autre, ce qui rangeait « difficile » avec « facile » et rendait le bilan de fin de
    /// session muet sur la seule chose qu'on veut y lire, l'endroit où ça a coincé.
    private(set) var ratingCounts: [ReviewRating: Int] = [:]
    /// Cartes passées en révision pendant la session : ce qui a été appris, et pas seulement
    /// revu. C'est le chiffre qui donne à une session le sentiment d'avoir servi.
    private(set) var graduatedCount = 0
    private(set) var startedAt = Date()
    private(set) var isFinished = false
    private(set) var mode: StudyMode = .scheduled
    private(set) var didStart = false

    private var context: ModelContext?
    private var sourceKey: String?
    /// `autosave` du contexte, remis comme on l'a trouvé en quittant la session.
    private var previousAutosave: Bool?
    /// Planning tenu en mémoire : une note ne touche SwiftData qu'au `flush`.
    private var live: [UUID: CardScheduling] = [:]
    private var pendingLogs: [PendingLog] = []
    private var undoStack: [UndoStep] = []
    /// Les cartes notées, dans l'ordre. Servent au bilan de fin de session, qui lit leur
    /// échéance pour dire quand le travail de la session revient.
    private var answered: [Flashcard] = []
    /// Les examens en cours. Ils décident de l'ordre de la file et plafonnent les
    /// intervalles : sans eux, la première note donnée renverrait la carte au delà du jour J.
    private var deadlines: ExamDeadlines = .empty

    /// Vrai dès la première note donnée : c'est ce qui active le bouton d'annulation.
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// La session a démarré mais n'a rien trouvé à réviser.
    var isEmpty: Bool {
        didStart && initialCount == 0
    }

    var counts: StudyCounts {
        StudyCounts(
            newCards: pending.filter { scheduling(of: $0.card).state == .new }.count,
            learning: pending.filter {
                let state = scheduling(of: $0.card).state
                return state == .learning || state == .relearning
            }.count,
            review: pending.filter { scheduling(of: $0.card).state == .review }.count
        )
    }

    var progress: Double {
        guard initialCount > 0 else { return 0 }
        return min(1, Double(answeredCount) / Double(max(initialCount, answeredCount + pending.count)))
    }

    func count(of rating: ReviewRating) -> Int {
        ratingCounts[rating] ?? 0
    }

    var againCount: Int {
        count(of: .again)
    }

    var goodCount: Int {
        answeredCount - againCount
    }

    var accuracy: Double {
        guard answeredCount > 0 else { return 0 }
        return Double(answeredCount - againCount) / Double(answeredCount)
    }

    var elapsed: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    /// Délai avant que la première carte de la session ne revienne.
    ///
    /// C'est la question qu'on se pose en refermant l'app, et elle n'avait pas de réponse :
    /// une session « terminée » dont trois cartes reviennent dans dix minutes n'est pas
    /// terminée de la même façon qu'une session dont tout repart à quatre jours. Nul en
    /// entraînement libre, où rien n'a été replanifié.
    func nextReturn(from now: Date = Date()) -> TimeInterval? {
        guard mode.affectsSchedule else { return nil }
        let upcoming = answered
            .map { scheduling(of: $0) }
            .filter { !$0.isSuspended && $0.dueDate > now }
            .map(\.dueDate)
            .min()
        return upcoming.map { $0.timeIntervalSince(now) }
    }

    /// Combien de cartes de la session repassent dans la journée. Ce sont celles qui n'ont
    /// pas encore tenu : les annoncer évite de croire le travail fini.
    func returningToday(from now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> Int {
        guard mode.affectsSchedule else { return 0 }
        let endOfDay = calendar.startOfDay(for: now).addingTimeInterval(24 * 3_600)
        return answered.filter {
            let plan = scheduling(of: $0)
            return !plan.isSuspended && plan.dueDate > now && plan.dueDate < endOfDay
        }.count
    }

    /// Aperçus Anki SM-2 sous les boutons (1 min / 6 min / 10 min / 4 j sur une neuve). En entraînement libre,
    /// aucune échéance ne bouge : les aperçus n'auraient rien à annoncer.
    var previewLabels: [ReviewRating: String] {
        guard mode.affectsSchedule, let current else { return [:] }
        return SM2Scheduler.previewLabels(
            for: scheduling(of: current).snapshot,
            deadline: deadlines.deadline(for: current)
        )
    }

    /// Vrai quand la carte affichée dépend d'un examen : la session peut le signaler.
    var isCurrentUnderExamDeadline: Bool {
        guard let current else { return false }
        return deadlines.covers(current)
    }

    /// Le nom de l'examen qui comprime la carte affichée. Nil hors mode examen.
    var currentExamName: String? {
        guard let current else { return nil }
        return deadlines.examName(for: current)
    }

    // MARK: - Cycle de vie

    func start(
        with cards: [Flashcard],
        context: ModelContext,
        mode: StudyMode = .scheduled,
        sourceKey: String? = nil,
        now: Date = Date(),
        limits: StudyQueueBuilder.Limits? = nil
    ) {
        guard !didStart else { return }
        didStart = true

        self.context = context
        self.mode = mode
        self.sourceKey = mode.affectsSchedule ? sourceKey : nil
        beginQuietWrites()
        self.deadlines = mode.affectsSchedule ? ExamDeadlines.active(in: context, now: now) : .empty
        startedAt = now

        let usable: [Flashcard]
        switch mode {
        case .scheduled:
            usable = StudyQueueBuilder.build(
                from: cards,
                now: now,
                limits: limits ?? .daily(),
                deadlines: deadlines
            )
        case .practice:
            // Tout le cours, dans l'ordre des cartes : on s'entraîne, on ne rattrape rien.
            usable = cards
                .filter { !$0.isSuspended }
                .sorted { ($0.position, $0.createdAt) < ($1.position, $1.createdAt) }
        }

        pending = queue(from: usable, now: now)
        initialCount = pending.count
        advance(now: now)
        writeSnapshot()
    }

    /// Reprend une session interrompue à la carte près.
    func resume(
        _ snapshot: StudySessionSnapshot,
        cards: [Flashcard],
        context: ModelContext,
        now: Date = Date()
    ) {
        guard !didStart else { return }
        didStart = true

        self.context = context
        mode = .scheduled
        sourceKey = snapshot.sourceKey
        beginQuietWrites()
        deadlines = ExamDeadlines.active(in: context, now: now)
        // La durée affichée en fin de session reste celle du temps réellement passé.
        startedAt = now.addingTimeInterval(-snapshot.elapsed)

        let byID = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let restored = snapshot.remainingCardIDs
            .compactMap { byID[$0] }
            .filter { !$0.isSuspended }

        pending = restored.enumerated().map { index, card in
            let availableAt: Date
            if let saved = snapshot.remainingAvailableAts, index < saved.count {
                availableAt = saved[index]
            } else {
                availableAt = now.addingTimeInterval(Double(index) - Double(restored.count))
            }
            return Entry(card: card, availableAt: availableAt)
        }
        initialCount = max(snapshot.initialCount, snapshot.answeredCount + pending.count)
        answeredCount = snapshot.answeredCount
        ratingCounts = snapshot.ratingCounts
        graduatedCount = snapshot.graduatedCount ?? 0

        advance(now: now)
        writeSnapshot()
    }

    /// Conserve l'ordre reçu : `advance()` trie par disponibilité, on échelonne donc les
    /// instants d'un rien pour que la file ne se réorganise pas dans le dos du planificateur.
    private func queue(from cards: [Flashcard], now: Date) -> [Entry] {
        cards.enumerated().map { index, card in
            Entry(card: card, availableAt: now.addingTimeInterval(Double(index) - Double(cards.count)))
        }
    }

    func reveal() {
        guard current != nil else { return }
        isRevealed = true
    }

    func answer(_ rating: ReviewRating, now: Date = Date()) {
        guard let card = current else { return }

        var step = UndoStep(
            card: card,
            scheduling: scheduling(of: card),
            log: nil,
            pendingLogID: nil,
            pending: pending,
            answered: answered,
            answeredCount: answeredCount,
            ratingCounts: ratingCounts,
            graduatedCount: graduatedCount
        )

        if mode.affectsSchedule {
            let before = scheduling(of: card)
            let stateBefore = before.state
            // La note est calculée par SM-2, puis rabattue sur la date de l'examen quand la
            // carte en dépend : c'est ce qui l'empêche de repartir au delà du jour J.
            // Rien n'est écrit sur la carte SwiftData : un `apply` notifie toutes les
            // `@Query` encore montées derrière la session, et c'est ce qui faisait
            // ramer chaque carte.
            let outcome = SM2Scheduler
                .schedule(snapshot: before.snapshot, rating: rating, now: now)
                .clamped(to: deadlines.deadline(for: card), now: now)
            var after = before
            after.apply(outcome, at: now)
            live[card.id] = after

            let pendingLog = PendingLog(
                card: card,
                reviewedAt: now,
                rating: rating,
                stateBefore: stateBefore,
                previousIntervalDays: before.intervalDays,
                newIntervalDays: outcome.intervalDays,
                easeAfter: outcome.easeFactor
            )
            pendingLogs.append(pendingLog)
            step.pendingLogID = pendingLog.id

            if outcome.state == .review, stateBefore != .review {
                graduatedCount += 1
            }

            if outcome.dueDate.timeIntervalSince(now) <= Self.learnAheadWindow {
                pending.append(Entry(card: card, availableAt: outcome.dueDate))
            }
        } else if rating == .again {
            // En entraînement libre, une carte ratée revient à la fin du tour,
            // tout de suite : on n'attend pas un palier d'apprentissage.
            pending.append(Entry(card: card, availableAt: now))
        }

        undoStack.append(step)

        answeredCount += 1
        ratingCounts[rating, default: 0] += 1
        // Une carte réapprise dans la même session ne compte qu'une fois : ce qui intéresse
        // le bilan est l'échéance finale, pas le nombre de passages.
        if !answered.contains(where: { $0.id == card.id }) {
            answered.append(card)
        }

        current = nil
        isRevealed = false
        advance(now: now)
        write()
    }

    /// Revient sur la dernière action et remet la carte exactement dans son état d'avant.
    func undo() {
        guard let step = undoStack.popLast() else { return }

        if let log = step.log {
            context?.delete(log)
            step.scheduling.restore(on: step.card)
        }
        if let pendingLogID = step.pendingLogID {
            pendingLogs.removeAll { $0.id == pendingLogID }
        }
        live[step.card.id] = step.scheduling

        pending = step.pending
        answered = step.answered
        answeredCount = step.answeredCount
        ratingCounts = step.ratingCounts
        graduatedCount = step.graduatedCount
        isFinished = false
        current = step.card
        // La réponse était sous les yeux au moment de la note : on la laisse visible.
        isRevealed = true
        write()
    }

    /// Repousse la carte courante à la fin de la file sans la noter.
    func skip(now: Date = Date()) {
        guard let card = current else { return }
        pending.append(Entry(card: card, availableAt: now))
        current = nil
        isRevealed = false
        advance(now: now)
        write()
    }

    /// Met la carte de côté : elle sort de la session et ne reviendra pas tant qu'on ne
    /// la réactive pas. Annulable comme une note.
    func setAsideCurrent() {
        guard let card = current else { return }

        let step = UndoStep(
            card: card,
            scheduling: scheduling(of: card),
            log: nil,
            pendingLogID: nil,
            pending: pending,
            answered: answered,
            answeredCount: answeredCount,
            ratingCounts: ratingCounts,
            graduatedCount: graduatedCount
        )

        if mode.affectsSchedule {
            var plan = scheduling(of: card)
            plan.isSuspended = true
            live[card.id] = plan
        }

        undoStack.append(step)
        current = nil
        isRevealed = false
        advance()
        write()
    }

    /// À appeler après une modification de la carte affichée, pour que la file reste juste.
    ///
    /// Écrit tout de suite : on ne revient pas d'une feuille d'édition dans l'urgence, et
    /// personne n'attend l'image suivante.
    func cardWasEdited() {
        flush()
    }

    /// Sert la carte qui revient le plus tôt, **même si son palier n'est pas écoulé**.
    ///
    /// **Personne n'attend devant un compte à rebours.** Le palier existe pour espacer deux
    /// passages quand il y a autre chose à faire, pas pour immobiliser quelqu'un qui a fini
    /// son paquet. Les cartes déjà dues passent d'abord, puisqu'elles sont les plus
    /// anciennes ; une carte d'apprentissage seule au monde est servie sans délai. C'est la
    /// limite d'anticipation d'Anki, sans l'écran d'attente.
    ///
    /// « Tout est à jour » n'arrive donc que lorsque la file est vide.
    func advance(now: Date = Date()) {
        // Déjà une carte sous les yeux : un second appel ne doit pas l'écarter de la file.
        guard current == nil else { return }

        isRevealed = false

        guard !pending.isEmpty else {
            isFinished = true
            // La file est vide : le bilan a besoin des échéances déjà posées.
            flush()
            return
        }

        pending.sort { $0.availableAt < $1.availableAt }
        current = pending.removeFirst().card
        isFinished = false
    }

    /// Cartes affichées en arrière-plan de la pile.
    func upcoming(_ limit: Int) -> [Flashcard] {
        pending
            .sorted { $0.availableAt < $1.availableAt }
            .prefix(limit)
            .map(\.card)
    }

    // MARK: - Écriture

    /// **Ce qui se passe après une note, et surtout ce qui ne se passe plus.**
    ///
    /// Une note écrivait la carte et son journal dans SwiftData tout de suite. Même sans
    /// `save()`, le contexte notifie les `@Query` : les quatre onglets restent montés
    /// derrière la session, et chacun recomptait ses files et ses historiques. L'appui
    /// attendait cette vague, carte après carte.
    ///
    /// Le planning vit donc en mémoire. SwiftData n'est touché qu'au `flush` : sortie de
    /// session, arrière-plan, ou file vide. Une app tuée avant ça reprend la file depuis
    /// les réglages ; les notes non posées restent dues, et se reverront.
    private func write() {
        writeSnapshot()
    }

    /// Écrit maintenant. À appeler quand on quitte la session, ou quand l'app passe en
    /// arrière-plan : à ces deux instants, personne n'attend l'image suivante.
    func flush() {
        guard mode.affectsSchedule else { return }
        applyPendingWrites()
        guard context?.hasChanges == true else { return }
        try? context?.save()
    }

    /// Remet l'écriture automatique et pose ce qui restait. À appeler en quittant.
    func end() {
        flush()
        restoreAutosave()
    }

    private func scheduling(of card: Flashcard) -> CardScheduling {
        live[card.id] ?? CardScheduling(card: card)
    }

    private func beginQuietWrites() {
        guard let context, previousAutosave == nil else { return }
        previousAutosave = context.autosaveEnabled
        context.autosaveEnabled = false
    }

    private func restoreAutosave() {
        guard let context, let previousAutosave else { return }
        context.autosaveEnabled = previousAutosave
        self.previousAutosave = nil
    }

    /// Pose sur les cartes ce qui a été décidé en mémoire, puis les journaux.
    private func applyPendingWrites() {
        for (id, plan) in live {
            guard let card = card(id: id) else { continue }
            plan.restore(on: card)
        }

        for item in pendingLogs {
            let log = ReviewLog(
                reviewedAt: item.reviewedAt,
                rating: item.rating,
                stateBefore: item.stateBefore,
                previousIntervalDays: item.previousIntervalDays,
                newIntervalDays: item.newIntervalDays,
                easeAfter: item.easeAfter
            )
            item.card.logs = (item.card.logs ?? []) + [log]
            if let index = undoStack.firstIndex(where: { $0.pendingLogID == item.id }) {
                undoStack[index].log = log
                undoStack[index].pendingLogID = nil
            }
        }

        live.removeAll()
        pendingLogs.removeAll()
    }

    private func card(id: UUID) -> Flashcard? {
        if current?.id == id { return current }
        if let found = answered.first(where: { $0.id == id }) { return found }
        if let found = pending.first(where: { $0.card.id == id }) { return found }
        return undoStack.last(where: { $0.card.id == id })?.card
    }

    // MARK: - Reprise

    /// Écrit l'état de la file après chaque action. Un petit JSON dans les réglages : c'est
    /// assez léger pour rester à chaque note, là où le planning part par paquets.
    ///
    /// L'entraînement libre ne se reprend pas : il ne laisse aucune trace, c'est tout
    /// l'intérêt.
    private func writeSnapshot() {
        guard mode.affectsSchedule, let sourceKey else { return }

        let remainingEntries: [Entry] =
            (current.map { [Entry(card: $0, availableAt: Date())] } ?? []) + pending
        let remaining = remainingEntries.map(\.card.id)
        guard !isFinished, !remaining.isEmpty else {
            StudySessionStore.clear()
            return
        }

        StudySessionStore.save(
            StudySessionSnapshot(
                sourceKey: sourceKey,
                remainingCardIDs: remaining,
                remainingAvailableAts: remainingEntries.map(\.availableAt),
                initialCount: initialCount,
                answeredCount: answeredCount,
                againCount: againCount,
                goodCount: goodCount,
                elapsed: elapsed,
                savedAt: Date(),
                hardCount: count(of: .hard),
                easyCount: count(of: .easy),
                graduatedCount: graduatedCount
            )
        )
    }
}
