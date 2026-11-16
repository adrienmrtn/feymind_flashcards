import SwiftData
import SwiftUI

/// Une conversation, telle que l'historique la montre.
struct ChatHistoryRow: Identifiable, Equatable {
    var id: UUID
    var title: String
    var preview: String
    var date: Date
    var origin: ChatOrigin
    var courseTitle: String?

    init(id: UUID = UUID(), title: String, preview: String, date: Date, origin: ChatOrigin, courseTitle: String? = nil) {
        self.id = id
        self.title = title
        self.preview = preview
        self.date = date
        self.origin = origin
        self.courseTitle = courseTitle
    }

    init(_ thread: ChatThread) {
        self.init(id: thread.id, title: thread.title, preview: thread.preview, date: thread.updatedAt, origin: thread.origin, courseTitle: thread.courseTitle)
    }
}

/// **L'historique des conversations, branché** : la base, la recherche, renommer et supprimer.
///
/// Un seul écran d'historique dans l'app (lot 12) : c'est le contenu du tiroir de la Home
/// (`ChatDrawerContent`), posé ici en page — pour le bouton « historique » d'une conversation et
/// pour le scanner. Le tiroir et cette page lisent les mêmes conversations, de la même façon.
struct ChatHistoryView: View {
    var currentID: UUID?
    let onOpen: (UUID) -> Void
    var onNew: () -> Void = {}
    var onClose: (() -> Void)?
    /// Le tiroir de la Home : l'engrenage des réglages en tête, à la place de la croix.
    var onSettings: (() -> Void)?

    init(currentID: UUID? = nil, onOpen: @escaping (UUID) -> Void, onNew: @escaping () -> Void = {}, onClose: (() -> Void)? = nil, onSettings: (() -> Void)? = nil) {
        self.currentID = currentID
        self.onOpen = onOpen
        self.onNew = onNew
        self.onClose = onClose
        self.onSettings = onSettings
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ChatThread.updatedAt, order: .reverse) private var threads: [ChatThread]
    @State private var query = ""
    @State private var renaming: ChatThread?
    @State private var newTitle = ""
    @State private var deleting: ChatThread?

    var body: some View {
        ChatDrawerContent(
            rows: ChatStore.search(threads, query: query).map(ChatHistoryRow.init),
            totalCount: threads.count,
            name: HomeGreeting.firstName(OnboardingPreferences.displayName),
            currentID: currentID,
            query: $query,
            onOpen: onOpen,
            onNew: onNew,
            onRename: { id in
                guard let thread = threads.first(where: { $0.id == id }) else { return }
                newTitle = thread.title
                renaming = thread
            },
            onDelete: { id in deleting = threads.first { $0.id == id } },
            onSettings: onSettings,
            onClose: onSettings == nil ? (onClose ?? { dismiss() }) : nil
        )
        .toolbar(.hidden, for: .navigationBar)
        .task { ChatMigration.runIfNeeded(in: modelContext) }
        .onAppear { Analytics.track(.chatHistoryOpened, ["count": .number(Double(threads.count))]) }
        .alert(
            L10n.t("ios.chat11.rename.title", locale: .resolved()),
            isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
        ) {
            TextField(L10n.t("ios.chat11.rename.placeholder", locale: .resolved()), text: $newTitle)
            Button(L10n.t("app.common.save", locale: .resolved())) {
                if let renaming { ChatStore.rename(renaming, to: newTitle, in: modelContext) }
                renaming = nil
            }
            Button(L10n.t("app.common.cancel", locale: .resolved()), role: .cancel) { renaming = nil }
        }
        .confirmationDialog(
            L10n.t("ios.chat11.delete.title", locale: .resolved()),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.t("app.common.delete", locale: .resolved()), role: .destructive) {
                if let deleting { ChatStore.delete(deleting, in: modelContext) }
                deleting = nil
            }
        } message: {
            Text(L10n.t("ios.chat11.delete.message", locale: .resolved()))
        }
    }
}
