import Foundation
import Observation
import SwiftData

/// **« Demande à Mika », hors leçon : un fil par matière.**
///
/// Les messages vivent dans la base (`TutorMessage`), sur le téléphone seulement, et partent
/// vers `mika-chat` comme ceux de la leçon : les huit derniers tours, et un document joint —
/// le dernier exercice scanné du fil quand il est dans ces tours (son énoncé et la solution de
/// Mika), sinon la matière du fil. La porte est celle de Mika (`MikaQuota`), et chaque réponse
/// rapporte `mikaAnswer`.
@Observable
@MainActor
final class TutorChat {
    let subject: SolverSubject
    var draft = ""
    private(set) var thinking = false
    private(set) var failure: String?
    private(set) var notice: String?
    var paywall: PaywallTrigger?

    let quota: MikaQuota
    private let xp: XPStore?

    init(subject: SolverSubject, quota: MikaQuota = MikaQuota(), xp: XPStore? = .shared) {
        self.subject = subject
        self.quota = quota
        self.xp = xp
    }

    /// Le fil, du plus ancien au plus récent.
    static func messages(of subject: SolverSubject, in context: ModelContext) -> [TutorMessage] {
        let raw = subject.rawValue
        let descriptor = FetchDescriptor<TutorMessage>(
            predicate: #Predicate { $0.subjectRaw == raw },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    var canRetry: Bool { failure != nil && !thinking }

    /// Envoie ce qui est dans le champ (ou une suggestion), si la porte est ouverte.
    func send(_ text: String? = nil, isPro: Bool, service: any AIService, context: ModelContext) async {
        let message = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !thinking else { return }
        notice = nil
        switch quota.gate(isPro: isPro) {
        case .allowed:
            break
        case .paywall:
            paywall = .mika
            Analytics.track(.mikaBlocked, ["reason": .text("paywall")])
            return
        case .dailyCapReached:
            notice = L10n.t("lesson.mika.capReached", locale: .resolved())
            Analytics.track(.mikaBlocked, ["reason": .text("cap")])
            return
        }
        if text == nil { draft = "" }
        failure = nil
        context.insert(TutorMessage(subject: subject, role: .user, text: String(message.prefix(MikaLimits.messageCharacters))))
        try? context.save()
        Analytics.track(.tutorAsked, ["subject": .text(subject.rawValue)])
        await ask(isPro: isPro, service: service, context: context)
    }

    func retry(isPro: Bool, service: any AIService, context: ModelContext) async {
        guard canRetry else { return }
        failure = nil
        await ask(isPro: isPro, service: service, context: context)
    }

    private func ask(isPro: Bool, service: any AIService, context: ModelContext) async {
        thinking = true
        defer { thinking = false }
        let request = Self.request(for: Self.messages(of: subject, in: context), subject: subject, context: context)
        do {
            let reply = try await service.chat(request)
            context.insert(TutorMessage(subject: subject, role: .mika, text: reply.reply))
            try? context.save()
            quota.noteAnswered()
            xp?.award(.mikaAnswer)
            Haptics.tick()
            Analytics.track(.mikaAsked, ["pro": .flag(isPro), "attached": .flag(true)])
        } catch {
            failure = SolverSession.message(for: error)
        }
    }

    /// **La demande, à partir du fil** : les derniers tours (un exercice scanné y figure par son
    /// énoncé et la réponse de Mika), et le document joint.
    static func request(for messages: [TutorMessage], subject: SolverSubject, context: ModelContext?) -> MikaChatRequest {
        let recent = Array(messages.suffix(MikaLimits.turns))
        let turns = recent.map { message -> MikaTurn in
            var text = message.text
            if message.exerciseID != nil, message.role == .user {
                text = SolverPrompts.exerciseTitle + " : " + text
            }
            return MikaTurn(role: message.role, text: String(text.prefix(MikaLimits.messageCharacters)))
        }
        var attachment = MikaAttachmentPayload(
            title: subject.label,
            text: L10n.t("ios.solve.tutor.context", locale: .resolved(), vars: ["subject": subject.label])
        )
        if let id = recent.last(where: { $0.exerciseID != nil })?.exerciseID, let context {
            let target = id
            let descriptor = FetchDescriptor<SolvedExercise>(predicate: #Predicate { $0.id == target })
            if let exercise = try? context.fetch(descriptor).first {
                attachment = MikaAttachmentPayload(
                    title: SolverPrompts.exerciseTitle,
                    text: SolverPrompts.document(statement: exercise.statement, solution: exercise.solution)
                )
            }
        }
        return MikaChatRequest(turns: turns, attachment: attachment, language: SolverSession.language, level: SolverSession.level)
    }
}
