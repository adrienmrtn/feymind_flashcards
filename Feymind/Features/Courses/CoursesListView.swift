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
                        .padding(.horizontal, FeySpacing.screen)

                    if !courses.isEmpty {
                        SearchField(text: $searchText)
                            .padding(.horizontal, FeySpacing.screen)

                        sortPicker

                        content
                            .padding(.horizontal, FeySpacing.screen)
                    } else {
                        content
                            .padding(.horizontal, FeySpacing.screen)
                    }
                }
                .padding(.top, FeySpacing.xs)
                .padding(.bottom, FeySpacing.xl)
            }
            .feyScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Course.self) { course in
                FlashcardsView(course: course)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(courses.isEmpty ? "Aucun cours" : "\(courses.count) cours")
                .font(FeyFont.hanken(13, weight: .medium))
                .foregroundStyle(FeyColor.inkTertiary)

            Text("Mes cours")
                .font(FeyFont.hanken(26, weight: .bold))
                .foregroundStyle(FeyColor.ink)
                .tracking(-0.4)
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
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous)
                .strokeBorder(Color(hex: 0xE6E0D5), lineWidth: 1)
        }
    }
}
