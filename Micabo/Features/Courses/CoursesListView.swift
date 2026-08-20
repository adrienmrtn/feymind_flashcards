import SwiftData
import SwiftUI

/// Tous les cours importés, plus ceux repris depuis la bibliothèque.
/// Mise en page : sur-titre compteur, grand titre, recherche, filtres,
/// puis une liste posée à même le fond et séparée par des filets.
struct CoursesListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .recent
    @State private var subjectFilter: String?
    @State private var path: [Course] = []
    @State private var showImportChoice = false
    @State private var pendingImport: ImportKind?
    @State private var activeImport: ImportKind?

    enum SortOrder: String, CaseIterable, Identifiable {
        case due
        case recent
        case alphabetical

        var id: String { rawValue }

        var label: String {
            switch self {
            case .recent: "Récents"
            case .alphabetical: "A à Z"
            case .due: "À réviser"
            }
        }
    }

    private var subjects: [String] {
        Set(courses.compactMap { $0.subject?.nilIfBlank }).sorted()
    }

    private var filtered: [Course] {
        var base = searchText.isEmpty
            ? courses
            : courses.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || ($0.subject ?? "").localizedCaseInsensitiveContains(searchText)
                    || $0.summary.localizedCaseInsensitiveContains(searchText)
            }

        if let subjectFilter {
            base = base.filter { $0.subject?.nilIfBlank == subjectFilter }
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

    private var cardCount: Int {
        courses.reduce(0) { $0 + $1.cards.count }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                    header
                        .padding(.horizontal, MicaboSpacing.screen)

                    if !courses.isEmpty {
                        MicaboSearchField(text: $searchText, placeholder: "Rechercher un cours ou une carte")
                            .padding(.horizontal, MicaboSpacing.screen)

                        filterRow
                    }

                    content
                        .padding(.top, courses.isEmpty ? MicaboSpacing.md : 0)
                }
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .micaboTabBar()
            .reportsPaging(for: .courses, depth: path.count)
            .navigationDestination(for: Course.self) { course in
                FlashcardsView(course: course)
            }
        }
        .sheet(isPresented: $showImportChoice, onDismiss: launchPendingImport) {
            ImportChoiceSheet { kind in
                pendingImport = kind
                showImportChoice = false
            }
            .presentationDetents([.height(540)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .fullScreenCover(item: $activeImport) { kind in
            ImportView(kind: kind) { course in
                activeImport = nil
                path = [course]
            }
        }
    }

    private var header: some View {
        MicaboScreenHeader(title: "Cours", eyebrow: countLabel) {
            MicaboCircleButton(systemImage: "plus", size: 44, accessibilityTitle: "Importer un cours") {
                showImportChoice = true
            }
        }
        .padding(.top, MicaboSpacing.xs)
    }

    private var countLabel: String {
        guard !courses.isEmpty else { return "Aucun cours" }
        let coursesLabel = "\(courses.count) cours"
        let cardsLabel = "\(cardCount) carte\(cardCount > 1 ? "s" : "")"
        return "\(coursesLabel) · \(cardsLabel)"
    }

    /// Tri puis matières, dans une seule bande qui défile.
    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MicaboSpacing.xs) {
                ForEach(SortOrder.allCases) { order in
                    MicaboSelectChip(title: order.label, isSelected: order == sortOrder && subjectFilter == nil) {
                        Haptics.selection()
                        withAnimation(.easeOut(duration: 0.2)) {
                            sortOrder = order
                            subjectFilter = nil
                        }
                    }
                }

                ForEach(subjects, id: \.self) { subject in
                    MicaboSelectChip(title: subject, isSelected: subjectFilter == subject) {
                        Haptics.selection()
                        withAnimation(.easeOut(duration: 0.2)) {
                            subjectFilter = subjectFilter == subject ? nil : subject
                        }
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
                title: "Aucun cours pour l'instant",
                message: "Importez un PDF, des photos, un Word ou collez du texte : Micabo en tire vos premières cartes.",
                actionTitle: "Importer un cours"
            ) {
                showImportChoice = true
            }
            .padding(.horizontal, MicaboSpacing.screen)
        } else if filtered.isEmpty {
            MicaboEmptyState(
                systemImage: "magnifyingglass",
                title: "Aucun résultat",
                message: "Essayez un autre mot-clé, ou retirez le filtre de matière."
            )
            .padding(.horizontal, MicaboSpacing.screen)
        } else {
            let items = filtered
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, course in
                    MicaboRow.course(course) {
                        path.append(course)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation {
                                try? CourseRepository.delete(course, in: modelContext)
                            }
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }

                    if index < items.count - 1 {
                        MicaboHairline(inset: MicaboSpacing.md, onCanvas: true)
                            .padding(.trailing, MicaboSpacing.xxs)
                    }
                }
            }
            .padding(.horizontal, MicaboSpacing.xxs)
        }
    }

    private func launchPendingImport() {
        guard let kind = pendingImport else { return }
        pendingImport = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            activeImport = kind
        }
    }
}
