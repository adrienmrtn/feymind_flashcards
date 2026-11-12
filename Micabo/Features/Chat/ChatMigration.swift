import Foundation
import SwiftData

/// **Les conversations d'avant le lot 11 rejoignent l'historique**, une fois : les fils de
/// « Demande à Mika » (un par matière, `TutorMessage`) et les conversations de leçon (un fichier
/// JSON par leçon). Les originaux restent où ils sont ; seul un drapeau dit que c'est fait.
@MainActor
enum ChatMigration {
    static let doneKey = "micabo.chat11.migrated"

    static func runIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard, lessonsDirectory: URL = MikaConversationStore.lessonsDirectory) {
        guard !defaults.bool(forKey: doneKey) else { return }
        defaults.set(true, forKey: doneKey)
        importTutorThreads(in: context)
        importLessonConversations(from: lessonsDirectory, in: context)
        try? context.save()
    }

    /// Un fil par matière, devenu une conversation titrée du nom de la matière.
    static func importTutorThreads(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<TutorMessage>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let bySubject = Dictionary(grouping: all, by: \.subjectRaw)
        for subject in SolverSubject.allCases {
            guard let messages = bySubject[subject.rawValue], !messages.isEmpty else { continue }
            let first = messages[0].createdAt
            let thread = ChatStore.createThread(origin: .legacy, in: context, now: first)
            thread.title = subject.label
            thread.titleIsCustom = true
            for message in messages {
                ChatStore.append(message.role, text: message.text, exerciseID: message.exerciseID, to: thread, in: context, now: message.createdAt)
            }
        }
    }

    /// Les conversations de leçon, liées à leur leçon quand elle existe encore.
    static func importLessonConversations(from directory: URL, in context: ModelContext) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            guard let courseID = UUID(uuidString: file.deletingPathExtension().lastPathComponent) else { continue }
            let conversation = MikaConversationStore.load(from: file)
            guard let first = conversation.messages.first else { continue }
            let target = courseID
            var descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            let course = try? context.fetch(descriptor).first
            let thread = ChatStore.createThread(origin: .lesson, courseID: course?.id, courseTitle: course?.title ?? conversation.attachment?.title, in: context, now: first.createdAt)
            for message in conversation.messages {
                let stored = ChatStore.append(message.role, text: message.text, card: message.card, to: thread, in: context, now: message.createdAt)
                stored.cardAdded = message.cardAdded
            }
        }
    }
}
