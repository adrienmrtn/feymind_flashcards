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

/// **L'historique des conversations** (lot 11) : rangées par jour, la plus récente d'abord,
/// une recherche simple, et pour chacune reprendre, renommer, supprimer (glisser ou appui long).
struct ChatHistoryView: View {
    var currentID: UUID?
    let onOpen: (UUID) -> Void
    var onNew: () -> Void = {}
    var onClose: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ChatThread.updatedAt, order: .reverse) private var threads: [ChatThread]
    @State private var query = ""
    @State private var renaming: ChatThread?
    @State private var newTitle = ""
    @State private var deleting: ChatThread?

    var body: some View {
        ChatHistoryContent(
            rows: ChatStore.search(threads, query: query).map(ChatHistoryRow.init),
            totalCount: threads.count,
            currentID: currentID,
            query: $query,
            onOpen: onOpen,
            onNew: onNew,
            onClose: onClose ?? { dismiss() },
            onRename: { id in
                guard let thread = threads.first(where: { $0.id == id }) else { return }
                newTitle = thread.title
                renaming = thread
            },
            onDelete: { id in deleting = threads.first { $0.id == id } }
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

/// L'historique dessiné, sans base : la barre du haut, la recherche, les sections.
struct ChatHistoryContent: View {
    let rows: [ChatHistoryRow]
    var totalCount: Int
    var currentID: UUID?
    @Binding var query: String
    let onOpen: (UUID) -> Void
    var onNew: () -> Void = {}
    var onClose: () -> Void = {}
    var onRename: (UUID) -> Void = { _ in }
    var onDelete: (UUID) -> Void = { _ in }
    var now = Date()
    var still = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if totalCount == 0 {
                empty
            } else {
                search
                if still {
                    list.frame(maxHeight: .infinity, alignment: .top).clipped()
                } else {
                    ScrollView { list }
                        .scrollDismissesKeyboard(.interactively)
                }
            }
        }
        .background(V3Color.bg.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(V3Font.text(.body, weight: .bold))
                    .foregroundStyle(V3Color.ink)
                    .frame(width: 44, height: 44)
                    .background(V3Color.surface, in: Circle())
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
            .accessibilityLabel(Text(L10n.t("ios.cal.close", locale: .resolved())))
            Text(L10n.t("ios.chat11.history.title", locale: .resolved()))
                .font(V3Font.h2)
                .foregroundStyle(V3Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button(action: onNew) {
                Label(L10n.t("ios.chat11.new", locale: .resolved()), systemImage: "square.and.pencil")
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.ctaInk)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(V3Color.cta, in: Capsule())
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(V3Color.ink3)
            if still {
                Text(query.isEmpty ? L10n.t("ios.chat11.history.search", locale: .resolved()) : query)
                    .foregroundStyle(query.isEmpty ? V3Color.ink3 : V3Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(text: $query, prompt: Text(L10n.t("ios.chat11.history.search", locale: .resolved())).foregroundStyle(V3Color.ink3)) {
                    Text(L10n.t("ios.chat11.history.search", locale: .resolved()))
                }
                .foregroundStyle(V3Color.ink)
                .tint(V3Color.accent)
                .submitLabel(.search)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(V3Color.ink3)
                    }
                    .accessibilityLabel(Text(L10n.t("app.common.cancel", locale: .resolved())))
                }
            }
        }
        .font(V3Font.text(.body, weight: .medium))
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(V3Color.surface, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.bottom, 8)
    }

    private var list: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            if rows.isEmpty {
                Text(L10n.t("ios.chat11.history.noResult", locale: .resolved()))
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink2)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity)
            }
            let groups = ChatHistorySection.group(rows, date: \.date, now: now)
            ForEach(groups.indices, id: \.self) { index in
                let section = groups[index].0
                let items = groups[index].1
                Text(section.title())
                    .font(V3Font.eyebrow)
                    .foregroundStyle(V3Color.ink3)
                    .textCase(.uppercase)
                    .padding(.top, 14)
                    .padding(.leading, 4)
                    .accessibilityAddTraits(.isHeader)
                ForEach(items) { row in
                    rowView(row)
                }
            }
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.bottom, 24)
    }

    private func rowView(_ row: ChatHistoryRow) -> some View {
        Button { onOpen(row.id) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: row.origin.symbol)
                    .font(V3Font.text(.subheadline, weight: .bold))
                    .foregroundStyle(tone(row.origin))
                    .frame(width: 38, height: 38)
                    .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusBadge, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.title.isEmpty ? L10n.t("ios.chat11.title.untitled", locale: .resolved()) : row.title)
                            .font(V3Font.option)
                            .foregroundStyle(V3Color.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(time(row.date))
                            .font(V3Font.caption)
                            .foregroundStyle(V3Color.ink3)
                            .lineLimit(1)
                    }
                    if let course = row.courseTitle {
                        Label(course, systemImage: "book.fill")
                            .font(V3Font.caption)
                            .foregroundStyle(V3Color.accentBright)
                            .lineLimit(1)
                    }
                    if !row.preview.isEmpty {
                        Text(row.preview)
                            .font(V3Font.support)
                            .foregroundStyle(V3Color.ink2)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card(selected: row.id == currentID, radius: V3Metric.radiusInner)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .contextMenu {
            Button { onRename(row.id) } label: {
                Label(L10n.t("ios.chat11.rename.action", locale: .resolved()), systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete(row.id) } label: {
                Label(L10n.t("app.common.delete", locale: .resolved()), systemImage: "trash")
            }
        }
        .accessibilityAction(named: Text(L10n.t("ios.chat11.rename.action", locale: .resolved()))) { onRename(row.id) }
        .accessibilityAction(named: Text(L10n.t("app.common.delete", locale: .resolved()))) { onDelete(row.id) }
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)
            MikaMascot(mood: .sleep, size: 150)
                .accessibilityHidden(true)
            Text(L10n.t("ios.chat11.history.empty", locale: .resolved()))
                .font(V3Font.h2)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("ios.chat11.history.emptyBody", locale: .resolved()))
                .font(V3Font.body)
                .foregroundStyle(V3Color.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 20)
            V3Button(L10n.t("ios.chat11.history.start", locale: .resolved()), systemImage: "bubble.left.fill", action: onNew)
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.bottom, 16)
    }

    private func tone(_ origin: ChatOrigin) -> Color {
        switch origin {
        case .camera: V3Color.iconPink
        case .lesson: V3Color.iconBlue
        case .card: V3Color.iconLilac
        case .quiz: V3Color.iconGreen
        case .scan: V3Color.iconOrange
        case .home, .legacy: V3Color.iconYellow
        }
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: UiLocale.resolved().bcp47)
        if Calendar.current.isDate(date, inSameDayAs: now) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        } else {
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
        }
        return formatter.string(from: date)
    }
}

/// **L'historique en plein écran**, ouvert depuis la Home ou le scanner : une conversation
/// choisie (ou une nouvelle) s'ouvre par-dessus, dans la même pile.
struct ChatHub: View {
    var onMakeLesson: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var path: [ChatLaunch] = []

    var body: some View {
        NavigationStack(path: $path) {
            ChatHistoryView(
                onOpen: { id in path.append(ChatLaunch(origin: .home, threadID: id)) },
                onNew: { path.append(ChatLaunch(origin: .home)) },
                onClose: { dismiss() }
            )
            .navigationDestination(for: ChatLaunch.self) { launch in
                ChatScreen(launch: launch, onMakeLesson: onMakeLesson, onClose: { path.removeLast() }, closeSymbol: "chevron.backward")
                    .enablesSwipeBack()
            }
        }
    }
}
