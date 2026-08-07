import SwiftData
import SwiftUI

/// Troisième page : tous les cours importés, plus ceux repris depuis la bibliothèque.
struct CoursesListView: View {
    @Environment(\.modelContext) private var modelContext

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
            Group {
                if courses.isEmpty {
                    ScrollView {
                        FeyEmptyState(
                            systemImage: "books.vertical.fill",
                            title: "Votre bibliothèque est vide",
                            message: "Les cours que vous importez depuis l'accueil apparaîtront ici."
                        )
                        .padding(.top, FeySpacing.xxl)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: FeySpacing.md) {
                            sortPicker

                            if !imported.isEmpty {
                                section(title: "Mes imports", courses: imported)
                            }

                            if !fromLibrary.isEmpty {
                                section(title: "Depuis la bibliothèque", courses: fromLibrary)
                            }

                            if filtered.isEmpty {
                                FeyEmptyState(
                                    systemImage: "magnifyingglass",
                                    title: "Aucun résultat",
                                    message: "Essayez un autre mot-clé."
                                )
                            }
                        }
                        .padding(.horizontal, FeySpacing.screen)
                        .padding(.top, FeySpacing.xs)
                        .padding(.bottom, FeySpacing.xl)
                    }
                }
            }
            .feyScreenBackground()
            .navigationTitle("Mes cours")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Rechercher un cours")
            .navigationDestination(for: Course.self) { course in
                FlashcardsView(course: course)
            }
        }
    }

    private var sortPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FeySpacing.xs) {
                ForEach(SortOrder.allCases) { order in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { sortOrder = order }
                    } label: {
                        Text(order.label)
                            .font(FeyFont.caption)
                            .foregroundStyle(order == sortOrder ? .white : FeyColor.inkSecondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(order == sortOrder ? FeyColor.accent : FeyColor.surfaceMuted, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func section(title: String, courses list: [Course]) -> some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            FeySectionHeader(title: title, subtitle: "\(list.count) cours")

            ForEach(list) { course in
                Button {
                    path.append(course)
                } label: {
                    CourseCard(course: course)
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
