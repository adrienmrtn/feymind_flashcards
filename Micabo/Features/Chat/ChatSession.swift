import Foundation
import Observation
import SwiftData
import UIKit

// MARK: - Ce qui ouvre une conversation

/// **Comment une conversation s'ouvre** : d'où (pour l'icône et les statistiques), sur quel
/// fil (une reprise), liée à quelle leçon ou à quel exercice, avec quoi dans le champ, et si
/// l'appareil photo s'ouvre tout de suite.
struct ChatLaunch: Identifiable, Hashable {
    var id = UUID()
    var origin: ChatOrigin = .home
    /// Un fil à reprendre (l'historique) ; `nil` : une nouvelle conversation, créée au premier envoi.
    var threadID: UUID?
    var courseID: UUID?
    var exerciseID: UUID?
    /// Ce qui se pose dans le champ, sans partir (« Explique-moi cette carte : … »).
    var prefill: String?
    /// Ce qui part tout de suite (la question tapée sur la Home).
    var autoSend: String?
    /// L'appareil photo en rafale s'ouvre dès l'arrivée.
    var opensCamera = false

    /// La conversation d'une leçon : la dernière reprise, sinon une nouvelle.
    static func lesson(_ courseID: UUID, origin: ChatOrigin = .lesson, prefill: String? = nil) -> ChatLaunch {
        ChatLaunch(origin: origin, courseID: courseID, prefill: prefill)
    }
}

/// Un message tel que l'écran le dessine.
struct ChatBubble: Identifiable, Equatable {
    var id: UUID
    var role: MikaTurn.Role
    var text: String
    var photoNames: [String] = []
    var card: GeneratedFlashcard?
    var cardAdded = false
    var exerciseID: UUID?

    init(id: UUID = UUID(), role: MikaTurn.Role, text: String, photoNames: [String] = [], card: GeneratedFlashcard? = nil, cardAdded: Bool = false, exerciseID: UUID? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.photoNames = photoNames
        self.card = card
        self.cardAdded = cardAdded
        self.exerciseID = exerciseID
    }

    init(_ message: ChatMessage) {
        self.init(id: message.id, role: message.role, text: message.text, photoNames: message.photoNames, card: message.card, cardAdded: message.cardAdded, exerciseID: message.exerciseID)
    }
}

/// Une photo prise ou choisie, pas encore envoyée : sa vignette, et où en est sa lecture.
struct ChatPendingPhoto: Identifiable, Equatable {
    enum State: Equatable {
        case reading
        case read(String)
        /// L'appareil n'y a rien lu : elle part quand même si la question est tapée.
        case unreadable
    }

    var id = UUID()
    var image: UIImage
    var state: State = .reading

    var text: String {
        if case .read(let text) = state { return text }
        return ""
    }
}

// MARK: - La conversation

/// **La conversation avec Mika** (lot 11) : une question tapée, une ou plusieurs photos, des
/// relances, gardée dans l'historique.
///
/// - **Les photos sont lues sur le téléphone** (Vision) dès qu'elles arrivent ; leur texte part
///   dans le document joint de `mika-chat`, ce que le serveur déployé accepte. Les images ne
///   voyagent pas.
/// - **Un message = une question Mika**, photos comprises : la porte est `MikaQuota`, la même
///   que partout (une question offerte, puis Pro ; un plafond par jour pour un abonné), et la
///   question ne se compte qu'une fois la réponse arrivée.
/// - Le fil n'existe dans l'historique qu'au premier envoi : ouvrir le chat et repartir ne
///   laisse pas de conversation vide.
@Observable
@MainActor
final class ChatSession {
    static let maxPhotos = 6

    private(set) var thread: ChatThread? = nil
    private(set) var bubbles: [ChatBubble] = []
    var draft = ""
    private(set) var pending: [ChatPendingPhoto] = []
    private(set) var thinking = false
    private(set) var failure: String? = nil
    /// Le plafond du jour d'un abonné vient de refuser.
    private(set) var capReached = false
    /// La question offerte est passée : la limite se dit dans le fil, avec la porte du paywall.
    private(set) var limitReached = false
    var paywall: PaywallTrigger? = nil

    let origin: ChatOrigin
    private(set) var courseID: UUID? = nil
    private(set) var courseTitle: String? = nil
    private var courseText: String? = nil
    private var courseLanguage: ContentLanguage? = nil
    private(set) var exerciseID: UUID? = nil
    private var exerciseDocument: String? = nil

    let quota: MikaQuota
    private let xp: XPStore?
    private let photos: ChatPhotoStore
    private let recognize: (UIImage) async -> String

    init(
        launch: ChatLaunch,
        context: ModelContext?,
        quota: MikaQuota = MikaQuota(),
        xp: XPStore? = .shared,
        photos: ChatPhotoStore = .shared,
        recognize: @escaping (UIImage) async -> String = ChatSession.readOnDevice
    ) {
        self.origin = launch.origin
        self.quota = quota
        self.xp = xp
        self.photos = photos
        self.recognize = recognize
        self.courseID = launch.courseID
        self.exerciseID = launch.exerciseID
        if let prefill = launch.prefill { draft = prefill }
        guard let context else { return }
        if let id = launch.threadID, let found = ChatStore.thread(id, in: context) {
            adopt(found, in: context)
        } else if launch.origin == .lesson, let courseID = launch.courseID, let found = ChatStore.latestThread(forCourse: courseID, in: context) {
            adopt(found, in: context)
        } else if let exerciseID = launch.exerciseID, let found = ChatStore.thread(forExercise: exerciseID, in: context) {
            adopt(found, in: context)
        }
        loadContext(in: context)
    }

    /// Une conversation dessinée telle quelle (les rendus) : sans base ni réseau.
    init(preview bubbles: [ChatBubble], title: String? = nil, courseTitle: String? = nil, pending: [ChatPendingPhoto] = [], draft: String = "", thinking: Bool = false, failure: String? = nil, limitReached: Bool = false, capReached: Bool = false) {
        self.origin = .home
        self.quota = MikaQuota()
        self.xp = nil
        self.photos = .shared
        self.recognize = { _ in "" }
        self.bubbles = bubbles
        self.courseTitle = courseTitle
        self.courseID = courseTitle == nil ? nil : UUID()
        self.pending = pending
        self.draft = draft
        self.thinking = thinking
        self.failure = failure
        self.limitReached = limitReached
        self.capReached = capReached
        self.previewTitle = title
    }

    private var previewTitle: String? = nil

    // MARK: Ce que l'écran lit

    var title: String {
        if let thread, !thread.title.isEmpty { return thread.title }
        return previewTitle ?? "Mika"
    }

    var isEmpty: Bool { bubbles.isEmpty }
    var isReading: Bool { pending.contains { $0.state == .reading } }
    var hasRoomForPhotos: Bool { pending.count < Self.maxPhotos }
    var canSend: Bool {
        guard !thinking, !isReading else { return false }
        return !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pending.isEmpty
    }

    var canRetry: Bool { failure != nil && bubbles.last?.role == .user && !thinking }

    /// « En faire une leçon » : hors leçon, et quand il y a une question à en tirer.
    var lessonTopic: String? {
        guard courseID == nil, bubbles.contains(where: { $0.role == .mika }) else { return nil }
        let question = bubbles.first(where: { $0.role == .user && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.text
        let topic = (question ?? thread?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return topic.isEmpty ? nil : String(topic.prefix(300))
    }

    // MARK: Les photos

    /// Des photos arrivent (l'appareil, la photothèque) : elles se lisent tout de suite, une à
    /// une. Au-delà de six, les suivantes sont laissées de côté.
    func add(photos images: [UIImage]) {
        for image in images where pending.count < Self.maxPhotos {
            let photo = ChatPendingPhoto(image: image)
            pending.append(photo)
            let read = recognize
            Task { [weak self] in
                let text = await read(image)
                self?.finishReading(photo.id, text: text)
            }
        }
    }

    func finishReading(_ id: UUID, text: String) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let clean = TextSanitizer.normalizeExtractedText(text).trimmingCharacters(in: .whitespacesAndNewlines)
        pending[index].state = clean.count >= 4 ? .read(String(clean.prefix(MikaLimits.attachmentCharacters))) : .unreadable
    }

    func remove(photo id: UUID) {
        pending.removeAll { $0.id == id }
    }

    // MARK: Envoyer

    /// Envoie la question tapée et les photos en attente, si la porte est ouverte.
    func send(_ text: String? = nil, isPro: Bool, service: any AIService, context: ModelContext?) async {
        let message = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        let photosToSend = text == nil ? pending : []
        guard !thinking, !isReading, !message.isEmpty || !photosToSend.isEmpty else { return }
        failure = nil
        capReached = false
        switch quota.gate(isPro: isPro) {
        case .allowed:
            limitReached = false
        case .paywall:
            limitReached = true
            paywall = .mika
            Analytics.track(.mikaBlocked, ["reason": .text("paywall")])
            return
        case .dailyCapReached:
            capReached = true
            Haptics.warning()
            Analytics.track(.mikaBlocked, ["reason": .text("cap")])
            return
        }

        if text == nil {
            draft = ""
            pending = []
        }
        let names = photosToSend.compactMap { photos.save($0.image) }
        let texts = photosToSend.map(\.text)
        let clipped = String(message.prefix(MikaLimits.messageCharacters))
        if let context {
            let thread = self.thread ?? ChatStore.createThread(origin: origin, courseID: courseID, courseTitle: courseTitle, exerciseID: exerciseID, in: context)
            self.thread = thread
            let stored = ChatStore.append(.user, text: clipped, photoNames: names, photoTexts: names.count == texts.count ? texts : [], to: thread, in: context)
            bubbles.append(ChatBubble(stored))
            storedTexts[stored.id] = texts
        } else {
            let bubble = ChatBubble(role: .user, text: clipped, photoNames: names)
            bubbles.append(bubble)
            storedTexts[bubble.id] = texts
        }
        Analytics.track(.chatSent, [
            "origin": .text(origin.rawValue),
            "photos": .number(Double(photosToSend.count)),
            "linked": .flag(courseID != nil || exerciseID != nil),
        ])
        await ask(isPro: isPro, service: service, context: context)
    }

    func retry(isPro: Bool, service: any AIService, context: ModelContext?) async {
        guard canRetry else { return }
        failure = nil
        await ask(isPro: isPro, service: service, context: context)
    }

    /// Le texte lu sur les photos de chaque message de l'élève, gardé pour les relances.
    private var storedTexts: [UUID: [String]] = [:]

    private func ask(isPro: Bool, service: any AIService, context: ModelContext?) async {
        thinking = true
        defer { thinking = false }
        do {
            let reply = try await service.chat(request())
            guard reply.isUsable else { throw AIServiceError.invalidResponse }
            if let context, let thread {
                let stored = ChatStore.append(.mika, text: reply.reply, card: reply.card, to: thread, in: context)
                bubbles.append(ChatBubble(stored))
            } else {
                bubbles.append(ChatBubble(role: .mika, text: reply.reply, card: reply.card))
            }
            quota.noteAnswered()
            xp?.award(.mikaAnswer)
            Haptics.tick()
            Analytics.track(.mikaAsked, ["pro": .flag(isPro), "attached": .flag(courseID != nil || hasPhotos)])
        } catch {
            failure = SolverSession.message(for: error)
        }
    }

    private var hasPhotos: Bool { bubbles.contains { !$0.photoNames.isEmpty } }

    /// **La demande** : les huit derniers tours (une question faite de photos seules dit « Explique-
    /// moi ce qu'il y a sur la photo »), et le document joint — le texte des photos de ces tours,
    /// puis la leçon ou l'exercice.
    func request() -> MikaChatRequest {
        let recent = Array(bubbles.suffix(MikaLimits.turns))
        let turns = recent.map { bubble -> MikaTurn in
            var text = bubble.text
            if bubble.role == .user, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = L10n.t(bubble.photoNames.count > 1 ? "ios.chat11.ask.photos" : "ios.chat11.ask.photo", locale: .resolved())
            }
            return MikaTurn(role: bubble.role, text: String(text.prefix(MikaLimits.messageCharacters)))
        }
        var numbered: [ChatDocument.Photo] = []
        var number = 0
        for bubble in bubbles where bubble.role == .user {
            let texts = storedTexts[bubble.id] ?? []
            for index in bubble.photoNames.indices.isEmpty ? texts.indices : bubble.photoNames.indices {
                number += 1
                guard recent.contains(where: { $0.id == bubble.id }) else { continue }
                numbered.append(ChatDocument.Photo(number: number, text: index < texts.count ? texts[index] : ""))
            }
        }
        let attachment = ChatDocument.payload(
            photos: numbered,
            contextTitle: exerciseDocument != nil ? SolverPrompts.exerciseTitle : courseTitle,
            contextText: exerciseDocument ?? courseText
        )
        return MikaChatRequest(turns: turns, attachment: attachment, language: language, level: OnboardingPreferences.educationStage?.level)
    }

    /// La langue de la leçon liée, sinon celle de l'interface.
    private var language: ContentLanguage {
        courseLanguage ?? SolverSession.language
    }

    // MARK: Le fil

    /// Reprend une conversation de l'historique.
    func open(_ id: UUID, in context: ModelContext) {
        guard let found = ChatStore.thread(id, in: context) else { return }
        reset()
        adopt(found, in: context)
        loadContext(in: context)
    }

    /// Une nouvelle conversation, sur la même leçon s'il y en a une.
    func startOver() {
        reset()
        thread = nil
        bubbles = []
    }

    private func reset() {
        draft = ""
        pending = []
        failure = nil
        capReached = false
        limitReached = false
        storedTexts = [:]
    }

    private func adopt(_ found: ChatThread, in context: ModelContext) {
        thread = found
        courseID = found.courseID ?? courseID
        courseTitle = found.courseTitle ?? courseTitle
        exerciseID = found.exerciseID ?? exerciseID
        let messages = ChatStore.messages(of: found.id, in: context)
        bubbles = messages.map(ChatBubble.init)
        for message in messages where !message.photoTexts.isEmpty {
            storedTexts[message.id] = message.photoTexts
        }
    }

    /// La leçon ou l'exercice liés, relus dans la base.
    private func loadContext(in context: ModelContext) {
        if let courseID {
            let target = courseID
            var descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            if let course = try? context.fetch(descriptor).first {
                let attachment = LessonMikaView.attachment(for: course)
                courseTitle = course.title
                courseText = attachment.text
                courseLanguage = course.language
            }
        }
        if let exerciseID {
            let target = exerciseID
            var descriptor = FetchDescriptor<SolvedExercise>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            if let exercise = try? context.fetch(descriptor).first {
                exerciseDocument = SolverPrompts.document(statement: exercise.statement, solution: exercise.solution)
            }
        }
    }

    // MARK: Les passerelles

    /// La carte proposée par Mika rejoint une leçon : celle de la conversation, ou celle choisie.
    @discardableResult
    func addCard(of bubbleID: UUID, to course: Course, in context: ModelContext) -> Bool {
        guard let index = bubbles.firstIndex(where: { $0.id == bubbleID }),
              !bubbles[index].cardAdded,
              let card = bubbles[index].card,
              let inserted = try? CourseRepository.addFlashcards([card], to: course, in: context),
              !inserted.isEmpty
        else { return false }
        bubbles[index].cardAdded = true
        let target = bubbleID
        var descriptor = FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        if let message = try? context.fetch(descriptor).first {
            message.cardAdded = true
            try? context.save()
        }
        Haptics.success()
        Analytics.track(.mikaCardAdded)
        Analytics.track(.chatGateway, ["kind": .text("card")])
        return true
    }

    // MARK: La lecture

    /// Le texte d'une photo, lu sur l'appareil dans la langue de l'app d'abord.
    nonisolated static func readOnDevice(_ image: UIImage) async -> String {
        let preferred = await MainActor.run { [UiLocale.resolved().bcp47] }
        return await OnDeviceOCR.recognizeExercise(in: SolverImage.normalized(image, maxDimension: 2400), preferred: preferred)
    }
}
