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
        /// Le journal écrit par la note, à supprimer si on l'annule.
        var log: ReviewLog?
        let pending: [Entry]
        let answered: [Flashcard]
        let answeredCount: Int
        let ratingCounts: [ReviewRating: Int]
        let graduatedCount: Int
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
    /// Actions faites depuis la dernière écriture sur le disque : notes, annulations, cartes
    /// mises de côté. Le compte sert de seuil, pas de statistique.
    private var unwritten = 0
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
            newCards: pending.filter { $0.card.state == .new }.count,
            learning: pending.filter { $0.card.state == .learning || $0.card.state == .relearning }.count,
            review: pending.filter { $0.card.state == .review }.count
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
            .filter { !$0.isSuspended }
            .map(\.dueDate)
            .filter { $0 > now }
            .min()
        return upcoming.map { $0.timeIntervalSince(now) }
    }

    /// Combien de cartes de la session repassent dans la journée. Ce sont celles qui n'ont
    /// pas encore tenu : les annoncer évite de croire le travail fini.
    func returningToday(from now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> Int {
        guard mode.affectsSchedule else { return 0 }
        let endOfDay = calendar.startOfDay(for: now).addingTimeInterval(24 * 3_600)
        return answered.filter { !$0.isSuspended && $0.dueDate > now && $0.dueDate < endOfDay }.count
    }

    /// Aperçus Anki SM-2 sous les boutons (1 min / 6 min / 10 min / 4 j sur une neuve). En entraînement libre,
    /// aucune échéance ne bouge : les aperçus n'auraient rien à annoncer.
    var previewLabels: [ReviewRating: String] {
        guard mode.affectsSchedule, let current else { return [:] }
        return SM2Scheduler.previewLabels(
            for: SM2CardSnapshot(card: current),
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
            scheduling: CardScheduling(card: card),
            log: nil,
            pending: pending,
            answered: answered,
            answeredCount: answeredCount,
            ratingCounts: ratingCounts,
            graduatedCount: graduatedCount
        )

        if mode.affectsSchedule {
            let logsBefore = Set((card.logs ?? []).map(\.id))
            let stateBefore = card.state
            // La note est calculée par SM-2, puis rabattue sur la date de l'examen quand la
            // carte en dépend : c'est ce qui l'empêche de repartir au delà du jour J.
            let outcome = SM2Scheduler
                .schedule(snapshot: SM2CardSnapshot(card: card), rating: rating, now: now)
                .clamped(to: deadlines.deadline(for: card), now: now)
            card.apply(outcome, at: now)

            // Pas de `save()` ici : c'est ce qui rendait l'appui pâteux. Voir `write(force:)`.
            // Le journal que la note vient d'écrire est dans la relation, en mémoire, donc on
            // le retrouve sans passer par le disque.
            step.log = (card.logs ?? []).first { !logsBefore.contains($0.id) }

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
        }
        step.scheduling.restore(on: step.card)

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
            scheduling: CardScheduling(card: card),
            log: nil,
            pending: pending,
            answered: answered,
            answeredCount: answeredCount,
            ratingCounts: ratingCounts,
            graduatedCount: graduatedCount
        )

        if mode.affectsSchedule {
            card.isSuspended = true
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
            // La file est vide : plus personne n'attend une carte, donc c'est le moment
            // d'écrire ce qui restait en mémoire.
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

    /// Nombre d'actions gardées en mémoire avant de toucher le disque.
    private static let writeEvery = 5

    /// **Ce qui se passe après une note, et surtout ce qui ne se passe plus.**
    ///
    /// Chaque note enregistrait sur le disque : un `save()` SwiftData, donc une transaction
    /// SQLite, sur le fil principal, à l'intérieur du bloc d'animation qui faisait entrer la
    /// carte suivante. L'animation ne pouvait pas démarrer avant que l'écriture soit finie, et
    /// c'est exactement le poil de latence qu'on sentait entre l'appui et la carte d'après.
    ///
    /// Le `save()` était même deux fois coûteux, et la seconde est la plus lourde : il publie
    /// les changements au contexte, donc **les trois pages d'onglets rafraîchissent leurs
    /// requêtes** — elles restent montées toutes les trois — et chacune recompte ses séries,
    /// ses files et ses histogrammes sur tout l'historique. Quatre notes par seconde
    /// déclenchaient douze recalculs.
    ///
    /// Les actions s'accumulent donc en mémoire et partent par paquets. Ce qu'on risque est
    /// borné et se répare tout seul : une app tuée avant l'écriture perd les notes du paquet
    /// en cours, et les cartes concernées se retrouvent simplement dues à la prochaine
    /// session. En échange, l'appui est instantané. La sortie de session et le passage en
    /// arrière-plan forcent l'écriture, ce qui couvre tous les cas où l'on quitte pour de bon.
    private func write() {
        writeSnapshot()

        guard mode.affectsSchedule else { return }
        unwritten += 1
        guard unwritten >= Self.writeEvery else { return }

        // Après l'image, pas dedans : l'animation de la carte suivante a le temps de partir
        // avant que le disque soit touché.
        DispatchQueue.main.async { [weak self] in
            self?.flush()
        }
    }

    /// Écrit maintenant. À appeler quand on quitte la session, ou quand l'app passe en
    /// arrière-plan : à ces deux instants, personne n'attend l'image suivante.
    func flush() {
        guard unwritten > 0 || context?.hasChanges == true else { return }
        unwritten = 0
        try? context?.save()
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
