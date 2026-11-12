import Foundation
import SwiftData
import UIKit

// MARK: - Ce qui se garde

/// **Une conversation avec Mika** (lot 11) : une question tapée, des photos, des relances, et
/// une place dans l'historique. Elle peut être liée à une leçon (Mika a ses notes sous les yeux)
/// ou à un exercice scanné (Mika relit l'énoncé et sa solution).
///
/// Ajoutée **en fin de schéma**, tous les champs avec une valeur par défaut : SwiftData migre
/// en ajoutant la table, les bases existantes ne bougent pas. Le lien aux messages passe par
/// `threadID` et non par une relation : un message se lit, se compte et se supprime sans
/// charger le fil entier, et la migration reste la plus légère possible.
@Model
final class ChatThread {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Le titre : écrit tout seul à la première question, ou choisi par l'élève.
    var title: String = ""
    /// Vrai quand l'élève l'a renommée : le titre automatique ne la touche plus.
    var titleIsCustom: Bool = false
    /// La dernière réponse (ou question), à plat, pour la ligne de l'historique et la recherche.
    var preview: String = ""
    var messageCount: Int = 0
    var originRaw: String = ChatOrigin.home.rawValue
    var courseID: UUID?
    var courseTitle: String?
    var exerciseID: UUID?

    init(origin: ChatOrigin, courseID: UUID? = nil, courseTitle: String? = nil, exerciseID: UUID? = nil, now: Date = Date()) {
        self.id = UUID()
        self.createdAt = now
        self.updatedAt = now
        self.originRaw = origin.rawValue
        self.courseID = courseID
        self.courseTitle = courseTitle
        self.exerciseID = exerciseID
    }

    var origin: ChatOrigin { ChatOrigin(rawValue: originRaw) ?? .home }
}

/// Un message d'une conversation : le texte, les photos (des noms de fichiers sur le
/// téléphone, jamais envoyées), ce que l'appareil y a lu, et la carte que Mika a proposée.
@Model
final class ChatMessage {
    var id: UUID = UUID()
    var threadID: UUID = UUID()
    var createdAt: Date = Date()
    var roleRaw: String = MikaTurn.Role.user.rawValue
    var text: String = ""
    /// Les fichiers des photos, séparés par `ChatMessage.separator`.
    var photoNamesRaw: String = ""
    /// Le texte lu sur chaque photo, dans le même ordre, séparé de même.
    var photoTextsRaw: String = ""
    var cardFront: String?
    var cardBack: String?
    var cardAdded: Bool = false
    /// L'exercice scanné que ce message porte (son énoncé, ou la réponse de Mika).
    var exerciseID: UUID?

    static let separator = "\u{1E}"

    init(threadID: UUID, role: MikaTurn.Role, text: String, photoNames: [String] = [], photoTexts: [String] = [], card: GeneratedFlashcard? = nil, exerciseID: UUID? = nil, createdAt: Date = Date()) {
        self.id = UUID()
        self.threadID = threadID
        self.createdAt = createdAt
        self.roleRaw = role.rawValue
        self.text = text
        self.photoNamesRaw = photoNames.joined(separator: Self.separator)
        self.photoTextsRaw = photoTexts.joined(separator: Self.separator)
        self.cardFront = card?.front
        self.cardBack = card?.back
        self.exerciseID = exerciseID
    }

    var role: MikaTurn.Role { MikaTurn.Role(rawValue: roleRaw) ?? .user }
    var photoNames: [String] { photoNamesRaw.isEmpty ? [] : photoNamesRaw.components(separatedBy: Self.separator) }
    var photoTexts: [String] { photoTextsRaw.isEmpty ? [] : photoTextsRaw.components(separatedBy: Self.separator) }
    var card: GeneratedFlashcard? {
        guard let cardFront, let cardBack, !cardFront.isEmpty, !cardBack.isEmpty else { return nil }
        return GeneratedFlashcard(front: cardFront, back: cardBack)
    }
}

/// **D'où vient une conversation** : une valeur fixe, pour l'icône de l'historique et les
/// statistiques (jamais le texte).
enum ChatOrigin: String, CaseIterable, Codable {
    /// La barre de la Home, une question tapée.
    case home
    /// L'appareil photo de la barre, ou des photos.
    case camera
    /// La tuile Mika d'une leçon.
    case lesson
    /// « Demander à Mika » depuis une carte.
    case card
    /// « Demander à Mika » depuis une question de quiz.
    case quiz
    /// Un exercice du scanner.
    case scan
    /// Une conversation reprise d'avant le lot 11 (un fil par matière, une conversation de leçon).
    case legacy

    var symbol: String {
        switch self {
        case .home, .legacy: "bubble.left.and.text.bubble.right.fill"
        case .camera: "camera.fill"
        case .lesson: "book.fill"
        case .card: "rectangle.on.rectangle.angled"
        case .quiz: "checklist"
        case .scan: "viewfinder"
        }
    }
}

// MARK: - Le titre

/// **Le titre automatique** : la première question, coupée au mot ; sinon les photos ; sinon
/// la leçon. Une fonction pure : elle se teste sans base.
enum ChatTitle {
    static let maxLength = 48

    static func make(question: String, photoCount: Int, courseTitle: String?, locale: UiLocale = .resolved()) -> String {
        let flat = question
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !flat.isEmpty {
            return shortened(firstSentence(of: flat))
        }
        if photoCount > 0 {
            return photoCount == 1
                ? L10n.t("ios.chat11.title.photo", locale: locale)
                : L10n.t("ios.chat11.title.photos", locale: locale, vars: ["count": "\(photoCount)"])
        }
        if let courseTitle, !courseTitle.isEmpty { return shortened(courseTitle) }
        return L10n.t("ios.chat11.title.untitled", locale: locale)
    }

    /// La première phrase, quand elle est assez longue pour dire quelque chose.
    static func firstSentence(of text: String) -> String {
        let enders: Set<Character> = [".", "?", "!", "؟", "。"]
        if let index = text.firstIndex(where: { enders.contains($0) }) {
            let sentence = String(text[...index]).trimmingCharacters(in: .whitespaces)
            if sentence.count >= 12 { return sentence }
        }
        return text
    }

    /// Coupé au dernier mot qui tient, avec « … ».
    static func shortened(_ text: String, limit: Int = maxLength) -> String {
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit))
        let cut = head.lastIndex(of: " ").map { String(head[..<$0]) } ?? head
        let trimmed = cut.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-")).trimmingCharacters(in: .whitespaces)
        return (trimmed.isEmpty ? head : trimmed) + "…"
    }
}

// MARK: - Le document joint

/// **Ce que Mika lit en plus de la conversation**, en un seul document de 16 000 caractères au
/// plus — ce que `mika-chat` accepte aujourd'hui (`_shared/mika.ts`) : le texte lu sur les
/// photos récentes (« Photo 1 », « Photo 2 »…, les plus récentes d'abord servies), puis la
/// leçon ou l'exercice liés, coupés à ce qui reste.
enum ChatDocument {
    struct Photo: Equatable {
        var number: Int
        var text: String
    }

    static func payload(photos: [Photo], contextTitle: String?, contextText: String?, locale: UiLocale = .resolved()) -> MikaAttachmentPayload? {
        let limit = MikaLimits.attachmentCharacters
        var kept: [(number: Int, block: String)] = []
        var used = 0
        // Les plus récentes d'abord : si tout ne tient pas, ce sont les anciennes qui tombent.
        for photo in photos.sorted(by: { $0.number > $1.number }) {
            let clean = photo.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            let label = L10n.t("ios.chat11.doc.photo", locale: locale, vars: ["n": "\(photo.number)"])
            let room = limit - used - 2
            guard room > label.count + 20 else { break }
            let piece = String("\(label)\n\(clean)".prefix(room))
            kept.append((photo.number, piece))
            used += piece.count + 2
        }
        // Les blocs des photos remis dans l'ordre de leurs numéros.
        var blocks = kept.sorted { $0.number < $1.number }.map(\.block)
        if let contextText, !contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let room = limit - used - 2
            if room > 200 {
                let header = contextTitle.map { "\($0)\n" } ?? ""
                blocks.append(String((header + contextText).prefix(room)))
            }
        }
        guard !blocks.isEmpty else { return nil }
        let title = contextTitle ?? L10n.t("ios.chat11.doc.photosTitle", locale: locale)
        let text = String(blocks.joined(separator: "\n\n").prefix(limit))
        return MikaAttachmentPayload(title: title, text: text)
    }
}

// MARK: - Les photos sur le téléphone

/// **Les photos d'une conversation**, en JPEG dans le dossier de l'app : elles ne partent
/// jamais, seul ce que l'appareil y a lu voyage.
struct ChatPhotoStore {
    var directory: URL

    static let shared = ChatPhotoStore(directory: {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("mika-chat-photos", isDirectory: true)
    }())

    /// Écrit la photo (réduite) et rend son nom ; `nil` si rien n'a pu s'écrire.
    @discardableResult
    func save(_ image: UIImage) -> String? {
        guard let data = ImagePrep.jpeg(image, maxDimension: 1600, quality: 0.7) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    func url(for name: String) -> URL { directory.appendingPathComponent(name) }

    func image(named name: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: name).path)
    }

    func delete(_ names: [String]) {
        for name in names where !name.isEmpty {
            try? FileManager.default.removeItem(at: url(for: name))
        }
    }

    /// Un compte qui s'en va : toutes les photos.
    func eraseAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}

// MARK: - Le magasin

/// **Lire et écrire les conversations.** Des fonctions sur un `ModelContext` : l'écran, le
/// scanner et les tests passent tous par ici.
enum ChatStore {
    static func threads(in context: ModelContext) -> [ChatThread] {
        let descriptor = FetchDescriptor<ChatThread>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func thread(_ id: UUID, in context: ModelContext) -> ChatThread? {
        let target = id
        var descriptor = FetchDescriptor<ChatThread>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func messages(of threadID: UUID, in context: ModelContext) -> [ChatMessage] {
        let target = threadID
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.threadID == target },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// La conversation la plus récente d'une leçon, pour la reprendre depuis la tuile Mika.
    static func latestThread(forCourse courseID: UUID, in context: ModelContext) -> ChatThread? {
        let target: UUID? = courseID
        var descriptor = FetchDescriptor<ChatThread>(
            predicate: #Predicate { $0.courseID == target },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func thread(forExercise exerciseID: UUID, in context: ModelContext) -> ChatThread? {
        let target: UUID? = exerciseID
        var descriptor = FetchDescriptor<ChatThread>(predicate: #Predicate { $0.exerciseID == target })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func hasAny(in context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<ChatThread>()
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    @discardableResult
    static func createThread(origin: ChatOrigin, courseID: UUID? = nil, courseTitle: String? = nil, exerciseID: UUID? = nil, in context: ModelContext, now: Date = Date()) -> ChatThread {
        let thread = ChatThread(origin: origin, courseID: courseID, courseTitle: courseTitle, exerciseID: exerciseID, now: now)
        context.insert(thread)
        return thread
    }

    /// Ajoute un message, et tient le fil à jour : sa date, son aperçu, son nombre de messages,
    /// et son titre tant que l'élève ne l'a pas choisi.
    @discardableResult
    static func append(
        _ role: MikaTurn.Role,
        text: String,
        photoNames: [String] = [],
        photoTexts: [String] = [],
        card: GeneratedFlashcard? = nil,
        exerciseID: UUID? = nil,
        to thread: ChatThread,
        in context: ModelContext,
        now: Date = Date()
    ) -> ChatMessage {
        let message = ChatMessage(threadID: thread.id, role: role, text: text, photoNames: photoNames, photoTexts: photoTexts, card: card, exerciseID: exerciseID, createdAt: now)
        context.insert(message)
        thread.updatedAt = now
        thread.messageCount += 1
        let flat = KeywordText.plain(text.replacingOccurrences(of: "\n", with: " ")).trimmingCharacters(in: .whitespaces)
        if !flat.isEmpty { thread.preview = String(flat.prefix(160)) }
        if role == .user, !thread.titleIsCustom, thread.title.isEmpty {
            thread.title = ChatTitle.make(question: text, photoCount: photoNames.count, courseTitle: thread.courseTitle)
        }
        try? context.save()
        return message
    }

    static func rename(_ thread: ChatThread, to title: String, in context: ModelContext) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        thread.title = String(clean.prefix(80))
        thread.titleIsCustom = true
        try? context.save()
    }

    /// Supprime la conversation, ses messages et ses photos.
    static func delete(_ thread: ChatThread, in context: ModelContext, photos: ChatPhotoStore = .shared) {
        let messages = Self.messages(of: thread.id, in: context)
        photos.delete(messages.flatMap(\.photoNames))
        for message in messages { context.delete(message) }
        context.delete(thread)
        try? context.save()
    }

    /// **La recherche simple** : le titre et l'aperçu, sans accents ni casse.
    static func search(_ threads: [ChatThread], query: String) -> [ChatThread] {
        let needle = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return threads }
        return threads.filter { fold($0.title).contains(needle) || fold($0.preview).contains(needle) || fold($0.courseTitle ?? "").contains(needle) }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// **Un exercice résolu par le scanner entre dans l'historique** : l'énoncé, puis la réponse
    /// de Mika. Résolu à nouveau (un énoncé corrigé), il remplace ses messages d'avant.
    static func recordExercise(id: UUID, statement: String, answer: String, in context: ModelContext, now: Date = Date()) {
        let thread = Self.thread(forExercise: id, in: context) ?? Self.createThread(origin: .scan, exerciseID: id, in: context, now: now)
        for message in messages(of: thread.id, in: context) where message.exerciseID == id {
            context.delete(message)
            thread.messageCount = max(0, thread.messageCount - 1)
        }
        if !thread.titleIsCustom { thread.title = "" }
        append(.user, text: statement, exerciseID: id, to: thread, in: context, now: now)
        append(.mika, text: answer, exerciseID: id, to: thread, in: context, now: now.addingTimeInterval(1))
    }

    /// Un compte qui s'en va (`LocalWipe`) : les conversations et leurs photos.
    static func eraseAll(in context: ModelContext, photos: ChatPhotoStore = .shared) {
        try? context.delete(model: ChatMessage.self)
        try? context.delete(model: ChatThread.self)
        try? context.save()
        photos.eraseAll()
    }
}

// MARK: - L'historique, par jour

/// Les sections de l'historique : aujourd'hui, hier, les sept derniers jours, puis par mois.
enum ChatHistorySection: Hashable {
    case today
    case yesterday
    case week
    case month(year: Int, month: Int)

    static func of(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> ChatHistorySection {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) { return .yesterday }
        let startOfToday = calendar.startOfDay(for: now)
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday), date >= weekAgo { return .week }
        let parts = calendar.dateComponents([.year, .month], from: date)
        return .month(year: parts.year ?? 0, month: parts.month ?? 0)
    }

    func title(locale: UiLocale = .resolved(), calendar: Calendar = .current) -> String {
        switch self {
        case .today: return L10n.t("ios.chat11.history.today", locale: locale)
        case .yesterday: return L10n.t("ios.chat11.history.yesterday", locale: locale)
        case .week: return L10n.t("ios.chat11.history.week", locale: locale)
        case .month(let year, let month):
            var parts = DateComponents()
            parts.year = year
            parts.month = month
            parts.day = 1
            let date = calendar.date(from: parts) ?? Date()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: locale.bcp47)
            formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
            return formatter.string(from: date).capitalized(with: Locale(identifier: locale.bcp47))
        }
    }

    /// Les fils rangés, dans l'ordre où ils arrivent (du plus récent au plus ancien).
    static func group<T>(_ items: [T], date: (T) -> Date, now: Date = Date(), calendar: Calendar = .current) -> [(ChatHistorySection, [T])] {
        var order: [ChatHistorySection] = []
        var buckets: [ChatHistorySection: [T]] = [:]
        for item in items {
            let section = of(date(item), now: now, calendar: calendar)
            if buckets[section] == nil { order.append(section) }
            buckets[section, default: []].append(item)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}
