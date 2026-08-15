import SwiftData
import SwiftUI

/// Tous les cours importés, plus ceux repris depuis la bibliothèque.
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
                VStack(alignment: .leading, spacing: 18) {
                    header
                        .padding(.horizontal, MicaboSpacing.screen)

                    if !courses.isEmpty {
                        SearchField(text: $searchText)
                            .padding(.horizontal, MicaboSpacing.screen)

                        sortPicker

                        content
                            .padding(.horizontal, MicaboSpacing.screen)
                    } else {
                        content
                            .padding(.horizontal, MicaboSpacing.screen)
                    }
                }
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboSpacing.xl)
            }
            .micaboScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .micaboTabBarClearance()
            .reportsNavigationDepth(for: .courses, depth: path.count)
            .navigationDestination(for: Course.self) { course in
                FlashcardsView(course: course)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(courses.isEmpty ? "Aucun cours" : "\(courses.count) cours")
                .font(MicaboFont.hanken(13, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)

            Text("Mes cours")
                .font(MicaboFont.hanken(26, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.4)
        }
        .padding(.top, MicaboSpacing.xs)
    }

    private var sortPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MicaboSpacing.xs) {
                ForEach(SortOrder.allCases) { order in
                    MicaboSelectChip(title: order.label, isSelected: order == sortOrder) {
                        withAnimation(.easeOut(duration: 0.2)) { sortOrder = order }
                    }
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var content: some View {
        if courses.isEmpty {
            MicaboEmptyState(
                systemImage: "books.vertical",
                title: "Votre liste est vide",
                message: "Les cours que vous importez depuis l'accueil apparaîtront ici."
            )
        } else if filtered.isEmpty {
            MicaboEmptyState(
                systemImage: "magnifyingglass",
                title: "Aucun résultat",
                message: "Essayez un autre mot-clé."
            )
        } else {
            VStack(spacing: 14) {
                ForEach(filtered) { course in
                    Button {
                        path.append(course)
                    } label: {
                        CourseRow(course: course, showsChevron: true)
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
}

/// Champ de recherche — coins 12 pt, bordure fine (maquette `.field`).
private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)

            TextField("Rechercher un cours", text: $text)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.ink)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous)
                .strokeBorder(Color(hex: 0xE6E0D5), lineWidth: 1)
        }
    }
}
