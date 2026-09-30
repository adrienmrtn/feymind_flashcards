import Foundation
import Observation

// MARK: - La conversation

/// Un message de la conversation, tel qu'il se garde : le texte, et la carte que Mika a
/// proposée avec, s'il y en a une, et si elle a déjà été rangée.
struct MikaMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: MikaTurn.Role
    var text: String
    var cardFront: String?
    var cardBack: String?
    var cardAdded = false
    var createdAt = Date()

    var card: GeneratedFlashcard? {
        guard let cardFront, let cardBack else { return nil }
        return GeneratedFlashcard(front: cardFront, back: cardBack)
    }
}

/// **La pièce jointe de la conversation : un cours de la bibliothèque, ou un document lu
/// sur l'appareil.** Une seule à la fois, et du texte seulement : le texte d'un cours est
/// déjà sur l'appareil, celui d'un document est lu par l'app avant de partir, et aucune
/// image ne voyage. C'est ce qui garde Mika bon marché.
struct MikaAttachment: Codable, Equatable {
    enum Kind: String, Codable {
        case course
        case document
    }

    var kind: Kind
    var title: String
    var text: String
    /// Le cours joint, quand c'en est un : c'est là que les cartes de Mika se rangent.
    var courseID: UUID?
    var emoji: String?
}

/// Ce qui se garde d'un lancement à l'autre : une seule conversation, et sa pièce jointe.
struct MikaConversation: Codable, Equatable {
    var messages: [MikaMessage] = []
    var attachment: MikaAttachment?
}

/// **Le fichier de la conversation**, dans le dossier de l'app. Un fichier et pas la base :
/// une conversation ne se synchronise pas, ne se partage pas, et n'a pas de raison de
/// faire changer le schéma.
enum MikaConversationStore {
    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("mika-conversation.json")
    }

    static func load(from url: URL = defaultURL) -> MikaConversation {
        guard let data = try? Data(contentsOf: url) else { return MikaConversation() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(MikaConversation.self, from: data)) ?? MikaConversation()
    }

    static func save(_ conversation: MikaConversation, to url: URL = defaultURL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(conversation) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

// MARK: - Ce que Mika laisse demander

/// **La porte de Mika.** Une question offerte, puis Premium ; pour un abonné, un plafond
/// par jour qu'on ne voit pas tant qu'on ne l'atteint pas. Les nombres sont dans
/// `MikaAllowance`, les mêmes que le serveur.
///
/// La question offerte ne se consomme qu'une fois la réponse arrivée : une panne de réseau
/// ne doit pas brûler la seule question de quelqu'un.
struct MikaQuota {
    enum Gate: Equatable {
        case allowed
        case paywall
        case dailyCapReached
    }

    enum Key {
        static let freeUsed = "micabo.mika.freeQuestionUsed"
        static let day = "micabo.mika.day"
        static let dayCount = "micabo.mika.dayCount"
    }

    var defaults: UserDefaults = .standard
    var now: () -> Date = Date.init
    var calendar: Calendar = .current

    var hasFreeQuestion: Bool {
        !defaults.bool(forKey: Key.freeUsed) && MikaAllowance.freeQuestions > 0
    }

    /// Les questions répondues aujourd'hui.
    var askedToday: Int {
        defaults.string(forKey: Key.day) == stamp() ? defaults.integer(forKey: Key.dayCount) : 0
    }

    func gate(isPro: Bool) -> Gate {
        if isPro {
            return askedToday < MikaAllowance.proMessagesPerDay ? .allowed : .dailyCapReached
        }
        return hasFreeQuestion ? .allowed : .paywall
    }

    /// Une réponse est arrivée : la question offerte est passée, et le jour en compte une
    /// de plus.
    func noteAnswered() {
        defaults.set(true, forKey: Key.freeUsed)
        let today = stamp()
        let count = defaults.string(forKey: Key.day) == today ? defaults.integer(forKey: Key.dayCount) : 0
        defaults.set(today, forKey: Key.day)
        defaults.set(count + 1, forKey: Key.dayCount)
    }

    /// Le jour, dans le calendrier de l'élève : le plafond se remet à minuit chez lui.
    private func stamp() -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: now())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

// MARK: - Le modèle de l'écran

/// **La conversation avec Mika, et ce qu'on peut en faire.**
///
/// Un seul fil, gardé sur l'appareil. Envoyer passe d'abord par la porte (`MikaQuota`) ;
/// si elle est ouverte, le message part avec les huit derniers tours et la pièce jointe,
/// et la réponse s'ajoute d'un bloc. Une panne laisse le message de l'élève en place, avec
/// « réessayer » : la question n'est pas perdue, et elle n'a pas été comptée.
@Observable
@MainActor
final class MikaChat {
    private(set) var conversation: MikaConversation
    var draft = ""
    private(set) var isThinking = false
    private(set) var failure: String?
    /// Vrai quand le plafond du jour vient de refuser : c'est le seul moment où il s'écrit.
    private(set) var capReached = false

    let quota: MikaQuota
    private let store: (MikaConversation) -> Void

    init(
        conversation: MikaConversation = MikaConversationStore.load(),
        quota: MikaQuota = MikaQuota(),
        store: @escaping (MikaConversation) -> Void = { MikaConversationStore.save($0) }
    ) {
        self.conversation = conversation
        self.quota = quota
        self.store = store
    }

    var messages: [MikaMessage] { conversation.messages }
    var attachment: MikaAttachment? { conversation.attachment }
    var isEmpty: Bool { conversation.messages.isEmpty }

    /// Les derniers tours, dans les termes de la fonction, chacun borné.
    var turns: [MikaTurn] {
        conversation.messages.suffix(MikaLimits.turns).map { message in
            MikaTurn(role: message.role, text: String(message.text.prefix(MikaLimits.messageCharacters)))
        }
    }

    /// Vrai quand la réponse à la dernière question n'est pas arrivée.
    var canRetry: Bool {
        failure != nil && messages.last?.role == .user && !isThinking
    }

    // MARK: Envoyer

    /// Envoie ce qui est dans le champ, si la porte est ouverte. Rend la porte — c'est
    /// l'écran qui montre le paywall ou le plafond, pas le modèle — ou **rien** quand il n'y
    /// avait rien à envoyer : un champ vide, ou Mika encore en train de répondre.
    @discardableResult
    func send(isPro: Bool, level: StudyLevel?, language: ContentLanguage, using service: any AIService) async -> MikaQuota.Gate? {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return nil }

        let gate = quota.gate(isPro: isPro)
        guard gate == .allowed else {
            capReached = gate == .dailyCapReached
            return gate
        }

        draft = ""
        failure = nil
        capReached = false
        conversation.messages.append(MikaMessage(role: .user, text: String(text.prefix(MikaLimits.messageCharacters))))
        persist()
        await ask(level: level, language: language, using: service)
        return .allowed
    }

    /// Redemande la réponse au dernier message, après une panne.
    func retry(level: StudyLevel?, language: ContentLanguage, using service: any AIService) async {
        guard canRetry else { return }
        failure = nil
        await ask(level: level, language: language, using: service)
    }

    private func ask(level: StudyLevel?, language: ContentLanguage, using service: any AIService) async {
        isThinking = true
        defer { isThinking = false }

        let request = MikaChatRequest(
            turns: turns,
            attachment: conversation.attachment.map { MikaAttachmentPayload(title: $0.title, text: $0.text) },
            language: language,
            level: level
        )

        do {
            let reply = try await service.chat(request)
            conversation.messages.append(MikaMessage(
                role: .mika,
                text: reply.reply,
                cardFront: reply.card?.front,
                cardBack: reply.card?.back
            ))
            quota.noteAnswered()
            persist()
            Haptics.tick()
        } catch {
            failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: La pièce jointe, la carte, le fil

    func attach(_ attachment: MikaAttachment) {
        conversation.attachment = attachment
        persist()
    }

    func detach() {
        conversation.attachment = nil
        persist()
    }

    /// Une nouvelle conversation : le fil et la pièce jointe s'effacent. La question
    /// offerte, elle, ne revient pas.
    func reset() {
        conversation = MikaConversation()
        draft = ""
        failure = nil
        capReached = false
        persist()
    }

    func markCardAdded(_ id: UUID) {
        guard let index = conversation.messages.firstIndex(where: { $0.id == id }) else { return }
        conversation.messages[index].cardAdded = true
        persist()
    }

    private func persist() {
        store(conversation)
    }
}
