import SwiftData
import SwiftUI

/// Onglet **Cours** : tout ce qui a été importé, avec recherche et filtres.
///
/// Il accueillera la bibliothèque en second rayon, « Découvrir », dès que
/// `LibraryAccess.isAvailable` passera à vrai. Tant qu'elle dort, le sélecteur de
/// rayon n'apparaît pas : un onglet qui ne mène à rien est un appui perdu.
struct CoursesListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .recent
    @State private var subjectFilter: String?
    @State private var shelf: Shelf = .mine
    @State private var path: [Course] = []
    @State private var showImportChoice = false
    @State private var pendingImport: ImportKind?
    @State private var activeImport: ImportKind?

    /// Les deux rayons de l'onglet.
    enum Shelf: String, CaseIterable, Identifiable {
        case mine
        case discover

        var id: String { rawValue }

        var label: String {
            switch self {
            case .mine: "Tes cours"
            case .discover: "Découvrir"
            }
        }
    }

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

                    if LibraryAccess.isAvailable {
                        shelfPicker
                            .padding(.horizontal, MicaboSpacing.screen)
                    }

                    shelfContent
                }
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, courses.isEmpty ? MicaboSpacing.xxl : MicaboLayout.bottomBarClearance)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            .overlay(alignment: .bottomTrailing) { importButton }
            .toolbar(.hidden, for: .navigationBar)
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
        MicaboScreenHeader(title: "Cours", eyebrow: countLabel)
            .padding(.top, MicaboSpacing.xs)
    }

    /// Le seul bouton flottant de l'app : en bas à droite, là où le pouce tombe, et
    /// posé au-dessus de la barre du bas. Quand la liste est vide, l'écran d'accueil
    /// porte déjà son propre appel à importer : deux boutons pour la même action
    /// feraient hésiter.
    @ViewBuilder
    private var importButton: some View {
        if !courses.isEmpty {
            MicaboCircleButton(
                systemImage: "plus",
                style: .dark,
                size: 56,
                accessibilityTitle: "Importer un cours"
            ) {
                showImportChoice = true
            }
            .padding(.trailing, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.md)
        }
    }

    private var countLabel: String {
        guard !courses.isEmpty else { return "Aucun cours" }
        return "\(MicaboCopy.courses(courses.count)) · \(MicaboCopy.cards(cardCount))"
    }

    private var shelfPicker: some View {
        HStack(spacing: MicaboSpacing.xs) {
            ForEach(Shelf.allCases) { value in
                MicaboSelectChip(title: value.label, isSelected: value == shelf) {
                    Haptics.selection()
                    withAnimation(.easeOut(duration: 0.2)) { shelf = value }
                }
            }
        }
    }

    @ViewBuilder
    private var shelfContent: some View {
        switch shelf {
        case .mine:
            myCourses
        case .discover:
            LibraryView()
                .padding(.horizontal, MicaboSpacing.screen)
        }
    }

    @ViewBuilder
    private var myCourses: some View {
        if !courses.isEmpty {
            MicaboSearchField(text: $searchText, placeholder: "Rechercher un cours ou une carte")
                .padding(.horizontal, MicaboSpacing.screen)

            filterRow
        }

        content
            .padding(.top, courses.isEmpty ? MicaboSpacing.md : 0)
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
                message: "Importe un PDF, des photos, un Word ou colle du texte : Micabo en tire tes premières cartes.",
                actionTitle: "Importer un cours"
            ) {
                showImportChoice = true
            }
            .padding(.horizontal, MicaboSpacing.screen)
        } else if filtered.isEmpty {
            MicaboEmptyState(
                systemImage: "magnifyingglass",
                title: "Aucun résultat",
                message: "Essaie un autre mot-clé, ou retire le filtre de matière."
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
