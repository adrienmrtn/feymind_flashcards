import Foundation
import Observation
import SwiftData

// MARK: - Ce qu'on demande à Mika

/// **Les demandes du scanner, dans la langue de l'élève.**
///
/// Tout passe par `mika-chat`, sans fonction nouvelle : l'énoncé part en document joint (du
/// texte lu sur l'appareil, jamais une image), et la consigne en message de l'élève. La
/// consigne est écrite **dans la langue de l'app** : la fonction répond dans la langue du
/// dernier message, et une consigne en français ferait répondre en français un élève allemand.
/// Les balises (`[STEP]`, `[ANSWER]`…) restent en anglais dans toutes les langues : c'est ce que
/// `SolverParser` lit.
enum SolverPrompts {
    private static func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        L10n.t(key, locale: .resolved(), vars: vars)
    }

    static func solve() -> String { t("ios.solve.prompt.solve") }

    static func explain(step: Int, text: String) -> String {
        t("ios.solve.prompt.explain", ["n": "\(step)", "step": String(text.prefix(600))])
    }

    static func practice() -> String { t("ios.solve.prompt.practice") }

    static func check(answer: String) -> String {
        t("ios.solve.prompt.check", ["answer": String(answer.prefix(500))])
    }

    static var exerciseTitle: String { t("ios.solve.attach.exercise") }
    static var practiceTitle: String { t("ios.solve.attach.practice") }
    static var answerLabel: String { t("ios.solve.answer") }
    static var expectedLabel: String { t("ios.solve.attach.expected") }

    /// L'énoncé, et la solution quand il y en a une : ce que Mika relit pour expliquer une
    /// étape ou répondre dans le fil de la matière.
    static func document(statement: String, solution: SolverSolution?) -> String {
        var text = statement
        if let solution {
            text += "\n\n" + t("ios.solve.attach.solution") + "\n" + solution.transcript(answerLabel: answerLabel)
        }
        return String(text.prefix(MikaLimits.attachmentCharacters))
    }
}

// MARK: - Une séance de résolution

/// **Un exercice, de l'énoncé lu à l'exercice d'entraînement corrigé.**
///
/// Chaque appel à Mika passe par **la même porte** que le chat (`MikaQuota`) : une question
/// offerte à vie, puis le paywall `mika` ; pour un abonné, le plafond du jour. La question
/// offerte ne se consomme qu'une fois la réponse arrivée. L'XP suit la règle du scanner :
/// `exerciseSolved` à la première solution d'un exercice, `mikaAnswer` ensuite.
@Observable
@MainActor
final class SolverSession {
    enum Phase: Equatable {
        /// L'énoncé est lu : l'élève le vérifie, puis demande la solution.
        case review
        case solving
        case solved
        /// La porte est fermée : l'énoncé reste, la solution attend Pro.
        case locked
        case failed(String)
    }

    let exercise: SolvedExercise
    private(set) var phase: Phase
    private(set) var solution: SolverSolution?
    /// Les étapes dont l'explication est en route.
    private(set) var helping: Set<Int> = []
    private(set) var helpFailures: [Int: String] = [:]
    private(set) var practiceLoading = false
    private(set) var checking = false
    private(set) var practiceFailure: String?
    /// Le plafond du jour d'un abonné, quand il vient de refuser.
    private(set) var notice: String?
    var paywall: PaywallTrigger?
    /// Vrai quand l'élève a choisi la matière lui-même : la réponse de Mika ne la change plus.
    var subjectChosen = false

    let quota: MikaQuota
    private let xp: XPStore?

    init(exercise: SolvedExercise, quota: MikaQuota = MikaQuota(), xp: XPStore? = .shared) {
        self.exercise = exercise
        self.quota = quota
        self.xp = xp
        let solution = exercise.solution
        self.solution = solution
        if exercise.solutionRaw != nil {
            phase = .solved
        } else {
            phase = .review
        }
    }

    // MARK: Ce que l'écran lit

    var steps: [SolverStep] { solution?.steps ?? [] }
    var revealed: Int { min(max(exercise.revealedSteps, steps.isEmpty ? 0 : 1), steps.count) }
    var hasMoreSteps: Bool { revealed < steps.count }
    var showsAnswer: Bool { solution != nil && !hasMoreSteps }
    var help: [Int: String] { exercise.help }
    var practice: SolverPractice? { exercise.practice }
    /// La réponse de Mika qui n'a pas pu se découper en étapes : l'écran l'affiche telle quelle.
    var plainReply: String? {
        guard solution == nil, let raw = exercise.solutionRaw else { return nil }
        return SolverParser.untagged(raw)
    }

    // MARK: L'énoncé

    func setSubject(_ subject: SolverSubject) {
        exercise.subject = subject
        subjectChosen = true
        touch()
    }

    /// L'énoncé corrigé par l'élève. Une solution déjà là ne correspond plus : elle s'efface,
    /// et « Résoudre » repart de l'énoncé corrigé.
    func setStatement(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != exercise.statement else { return }
        exercise.statement = String(clean.prefix(MikaLimits.attachmentCharacters))
        if exercise.solutionRaw != nil {
            exercise.solutionRaw = nil
            exercise.revealedSteps = 0
            exercise.help = [:]
            exercise.practice = nil
            solution = nil
        }
        if phase != .locked { phase = .review }
        touch()
    }

    // MARK: Résoudre

    func solve(isPro: Bool, service: any AIService, context: ModelContext?) async {
        guard phase != .solving else { return }
        notice = nil
        store(in: context)
        guard open(isPro: isPro, lockingSolution: true) else { return }

        phase = .solving
        let request = MikaChatRequest(
            turns: [MikaTurn(role: .user, text: SolverPrompts.solve())],
            attachment: MikaAttachmentPayload(title: SolverPrompts.exerciseTitle, text: exercise.statement),
            language: Self.language,
            level: Self.level
        )
        do {
            let reply = try await service.chat(request)
            exercise.solutionRaw = reply.reply
            let parsed = SolverParser.parse(reply.reply)
            solution = parsed
            if let subject = parsed?.subject, !subjectChosen {
                exercise.subject = subject
            }
            exercise.revealedSteps = 1
            exercise.help = [:]
            exercise.practice = nil
            answered(isPro: isPro, reason: exercise.rewarded ? .mikaAnswer : .exerciseSolved)
            exercise.rewarded = true
            phase = .solved
            postToThread(context: context)
            touch()
            try? context?.save()
            Analytics.track(.solverSolved, [
                "subject": .text(exercise.subject.rawValue),
                "structured": .flag(parsed?.isStructured ?? false),
                "steps": .number(Double(parsed?.steps.count ?? 0)),
                "source": .text(exercise.sourceRaw),
            ])
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    /// Un abonné qui revient du paywall : la solution part toute seule.
    func unlocked(service: any AIService, context: ModelContext?) async {
        guard phase == .locked else { return }
        phase = .review
        await solve(isPro: true, service: service, context: context)
    }

    func revealNext() {
        guard hasMoreSteps else { return }
        exercise.revealedSteps = revealed + 1
        Haptics.tick()
        touch()
    }

    func revealAll() {
        exercise.revealedSteps = steps.count
        touch()
    }

    // MARK: « Je ne comprends pas cette étape »

    func explain(step index: Int, isPro: Bool, service: any AIService) async {
        guard steps.indices.contains(index), !helping.contains(index) else { return }
        notice = nil
        guard open(isPro: isPro, lockingSolution: false) else { return }
        helping.insert(index)
        helpFailures[index] = nil
        defer { helping.remove(index) }
        let step = steps[index]
        let request = MikaChatRequest(
            turns: [MikaTurn(role: .user, text: SolverPrompts.explain(step: index + 1, text: [step.title, step.body].filter { !$0.isEmpty }.joined(separator: " : ")))],
            attachment: MikaAttachmentPayload(
                title: SolverPrompts.exerciseTitle,
                text: SolverPrompts.document(statement: exercise.statement, solution: solution)
            ),
            language: Self.language,
            level: Self.level
        )
        do {
            let reply = try await service.chat(request)
            var help = exercise.help
            help[index] = SolverParser.untagged(reply.reply)
            exercise.help = help
            answered(isPro: isPro, reason: .mikaAnswer)
            touch()
            Analytics.track(.solverStepHelp, ["subject": .text(exercise.subject.rawValue), "step": .number(Double(index + 1))])
        } catch {
            helpFailures[index] = Self.message(for: error)
        }
    }

    // MARK: L'exercice similaire

    func startPractice(isPro: Bool, service: any AIService) async {
        guard !practiceLoading else { return }
        notice = nil
        guard open(isPro: isPro, lockingSolution: false) else { return }
        practiceLoading = true
        practiceFailure = nil
        defer { practiceLoading = false }
        let request = MikaChatRequest(
            turns: [MikaTurn(role: .user, text: SolverPrompts.practice())],
            attachment: MikaAttachmentPayload(title: SolverPrompts.exerciseTitle, text: exercise.statement),
            language: Self.language,
            level: Self.level
        )
        do {
            let reply = try await service.chat(request)
            guard let practice = SolverParser.practice(reply.reply) else { throw AIServiceError.invalidResponse }
            exercise.practice = practice
            answered(isPro: isPro, reason: .mikaAnswer)
            touch()
        } catch {
            practiceFailure = Self.message(for: error)
        }
    }

    func check(answer: String, isPro: Bool, service: any AIService) async {
        guard var practice = exercise.practice, !checking else { return }
        let attempt = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !attempt.isEmpty else { return }
        notice = nil
        guard open(isPro: isPro, lockingSolution: false) else { return }
        checking = true
        practiceFailure = nil
        defer { checking = false }
        var document = practice.exercise
        if let expected = practice.expected {
            document += "\n\n\(SolverPrompts.expectedLabel) : \(expected)"
        }
        let request = MikaChatRequest(
            turns: [MikaTurn(role: .user, text: SolverPrompts.check(answer: attempt))],
            attachment: MikaAttachmentPayload(title: SolverPrompts.practiceTitle, text: document),
            language: Self.language,
            level: Self.level
        )
        do {
            let reply = try await service.chat(request)
            let read = SolverParser.verdict(reply.reply)
            practice.attempt = attempt
            practice.verdict = read.verdict
            practice.feedback = read.text
            exercise.practice = practice
            answered(isPro: isPro, reason: .mikaAnswer)
            if read.verdict == .right { Haptics.success() } else { Haptics.warning() }
            touch()
            Analytics.track(.solverPracticeChecked, [
                "subject": .text(exercise.subject.rawValue),
                "result": .text(read.verdict?.rawValue ?? "unknown"),
            ])
        } catch {
            practiceFailure = Self.message(for: error)
        }
    }

    func showPracticeAnswer() {
        guard var practice = exercise.practice else { return }
        practice.showsAnswer = true
        exercise.practice = practice
        touch()
    }

    /// Un autre exercice : l'ancien s'efface, le suivant se demande.
    func clearPractice() {
        exercise.practice = nil
        practiceFailure = nil
        touch()
    }

    // MARK: La porte

    /// Vrai si la question peut partir. Sinon, le paywall ou le plafond, et rien n'est envoyé.
    private func open(isPro: Bool, lockingSolution: Bool) -> Bool {
        switch quota.gate(isPro: isPro) {
        case .allowed:
            return true
        case .paywall:
            if lockingSolution { phase = .locked }
            paywall = .mika
            Analytics.track(.mikaBlocked, ["reason": .text("paywall")])
            return false
        case .dailyCapReached:
            notice = L10n.t("lesson.mika.capReached", locale: .resolved())
            Haptics.warning()
            Analytics.track(.mikaBlocked, ["reason": .text("cap")])
            return false
        }
    }

    private func answered(isPro: Bool, reason: XPReason) {
        quota.noteAnswered()
        xp?.award(reason)
        Analytics.track(.mikaAsked, ["pro": .flag(isPro), "attached": .flag(true)])
    }

    // MARK: Ce qui se garde

    private func store(in context: ModelContext?) {
        guard let context, exercise.modelContext == nil else { return }
        context.insert(exercise)
        try? context.save()
    }

    private func touch() {
        exercise.updatedAt = Date()
        try? exercise.modelContext?.save()
    }

    /// **L'exercice arrive dans le fil de sa matière** : l'énoncé, puis la réponse de Mika.
    /// Résolu à nouveau (un énoncé corrigé), il remplace sa première arrivée.
    private func postToThread(context: ModelContext?) {
        guard let context else { return }
        let id = exercise.id
        let target: UUID? = id
        let previous = (try? context.fetch(FetchDescriptor<TutorMessage>(predicate: #Predicate { $0.exerciseID == target }))) ?? []
        for message in previous {
            context.delete(message)
        }
        let now = Date()
        context.insert(TutorMessage(subject: exercise.subject, role: .user, text: exercise.statement, exerciseID: id, createdAt: now))
        let summary = solution?.answer ?? solution?.steps.first?.body ?? SolverParser.untagged(exercise.solutionRaw ?? "")
        context.insert(TutorMessage(subject: exercise.subject, role: .mika, text: summary, exerciseID: id, createdAt: now.addingTimeInterval(1)))
    }

    // MARK: La langue, le niveau

    /// Mika répond dans la langue de l'app.
    static var language: ContentLanguage {
        ContentLanguage(rawValue: UiLocale.resolved().rawValue) ?? DeckSetup.defaultLanguage()
    }

    static var level: StudyLevel? {
        OnboardingPreferences.educationStage?.level
    }

    static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
