import SwiftData
import SwiftUI

/// Tous les cours importés, plus ceux repris depuis la bibliothèque.
struct CoursesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TabRouter.self) private var router: TabRouter?

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .recent
    @State private var path: [Course] = []

    enum SortOrder: String, CaseIterable, Identifiable {
        case recent
        case alphabetical
        case due

        var id: String { rawValue }

        var label: String {
            switch self {
            case .recent: "Récents"
            case .alphabetical: "A à Z"
            case .due: "À réviser"
            }
        }
    }

    private var imported: [Course] {
        filtered.filter { !$0.isFromLibrary }
    }

    private var fromLibrary: [Course] {
        filtered.filter(\.isFromLibrary)
    }

    private var filtered: [Course] {
        let base = searchText.isEmpty
            ? courses
            : courses.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || ($0.subject ?? "").localizedCaseInsensitiveContains(searchText)
                    || $0.summary.localizedCaseInsensitiveContains(searchText)
            }

        switch sortOrder {
        case .recent:
            return base
        case .alphabetical:
            return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .due:
            return base.sorted { $0.dueCards.count > $1.dueCards.count }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: FeySpacing.lg) {
                    header
                        .padding(.horizontal, FeySpacing.screen)

                    if !courses.isEmpty {
                        SearchField(text: $searchText)
                            .padding(.horizontal, FeySpacing.screen)

                        sortPicker
                    }

                    content
                        .padding(.horizontal, FeySpacing.screen)
                }
                .padding(.top, FeySpacing.xs)
                .padding(.bottom, FeyLayout.tabBarClearance)
            }
            .feyScreenBackground()
            .feyTabBar()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Course.self) { course in
                FlashcardsView(course: course)
            }
            .onAppear { router?.setNavigationDepth(path.count, for: .courses) }
            .onChange(of: path.count) { _, count in
                router?.setNavigationDepth(count, for: .courses)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(courses.isEmpty ? "Aucun cours" : "\(courses.count) cours")
                .font(FeyFont.caption)
                .foregroundStyle(FeyColor.inkTertiary)

            Text("Mes cours")
                .font(FeyFont.screenTitle)
                .foregroundStyle(FeyColor.ink)
                .tracking(FeyTracking.tight)
        }
        .padding(.top, FeySpacing.xs)
    }

    private var sortPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FeySpacing.xs) {
                ForEach(SortOrder.allCases) { order in
                    FeySelectChip(title: order.label, isSelected: order == sortOrder) {
                        withAnimation(.easeOut(duration: 0.2)) { sortOrder = order }
                    }
                }
            }
            .padding(.horizontal, FeySpacing.screen)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var content: some View {
        if courses.isEmpty {
            FeyEmptyState(
                systemImage: "books.vertical",
                title: "Votre liste est vide",
                message: "Les cours que vous importez depuis l'accueil apparaîtront ici."
            )
        } else if filtered.isEmpty {
            FeyEmptyState(
                systemImage: "magnifyingglass",
                title: "Aucun résultat",
                message: "Essayez un autre mot-clé."
            )
        } else {
            VStack(alignment: .leading, spacing: FeySpacing.lg) {
                if !imported.isEmpty {
                    section(title: "Mes imports", courses: imported)
                }
                if !fromLibrary.isEmpty {
                    section(title: "Depuis la bibliothèque", courses: fromLibrary)
                }
            }
        }
    }

    private func section(title: String, courses list: [Course]) -> some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            FeySectionHeader(title: title, subtitle: "\(list.count) cours")

            ForEach(list) { course in
                Button {
                    path.append(course)
                } label: {
                    CourseRow(course: course)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation {
                            try? CourseRepository.delete(course, in: modelContext)
                        }
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
        }
    }
}

/// Champ de recherche en pilule blanche.
private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: FeySpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FeyColor.inkTertiary)

            TextField("Rechercher un cours", text: $text)
                .font(FeyFont.body)
                .foregroundStyle(FeyColor.ink)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(FeyColor.inkTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, FeySpacing.md)
        .background(FeyColor.surface, in: Capsule())
    }
}
