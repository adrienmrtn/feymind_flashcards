import SwiftData
import SwiftUI

/// Onglet **Cours** : tout ce qui a été importé, avec recherche et filtres.
///
/// Les cours des amis se voient encore sur leur profil, si leur visibilité le
/// permet. Il n'y a plus de rayon « Découvrir ».
struct CoursesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(TabRouter.self) private var router: TabRouter?
    @Environment(CloudSync.self) private var sync: CloudSync?
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .recent
    @State private var subjectFilter: String?
    /// Un cours mène à sa fiche, un `CourseCardsRoute` à ses cartes : deux destinations
    /// pour le même cours, donc un chemin hétérogène.
    @State private var path = NavigationPath()
    @State private var showImportChoice = false
    @State private var pendingImport: ImportKind?
    @State private var activeImport: ImportKind?
    /// Un paquet de cartes ne passe pas par l'écran d'import : il n'y a rien à lire.
    @State private var isCreatingDeck = false
    @State private var paywall: PaywallTrigger?
    @State private var coursePendingDelete: Course?
    /// Totaux par cours, lus **une fois**. Le corps ne touche plus `course.cards`.
    @State private var census: [UUID: CourseStats] = [:]

    enum SortOrder: String, CaseIterable, Identifiable {
        case due
        case recent
        case alphabetical

        var id: String { rawValue }

        func label(_ i18n: UiLocaleStore?) -> String {
            switch self {
            case .recent: i18n?.t("app.courses.sortRecent") ?? "Récents"
            case .alphabetical: i18n?.t("app.courses.sortAlpha") ?? "A à Z"
            case .due: i18n?.t("app.courses.sortDue") ?? "À réviser"
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
            return base.sorted { (census[$0.id]?.dueCount ?? 0) > (census[$1.id]?.dueCount ?? 0) }
        }
    }

    private var cardCount: Int? {
        census.isEmpty ? nil : LibraryCensus.totalCards(in: census)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                    header
                        .padding(.horizontal, MicaboSpacing.screen)

                    myCourses
                }
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            // Le « + » se pose juste au-dessus de la barre d'onglets —
            // voir `tabBarClearance`.
            .tabBarClearance { importButton }
            .toolbar(.hidden, for: .navigationBar)
            .reportsNavigationDepth(for: .courses, depth: path.count)
            .returnsHome(path: $path)
            .navigationDestination(for: Course.self) { course in
                CourseSheetView(course: course)
            }
            .navigationDestination(for: CourseCardsRoute.self) { route in
                FlashcardsView(course: route.course)
            }
            // Reprendre un cours partagé atterrit sur **sa** fiche, dans sa propre pile : le
            // chemin est remplacé, donc le retour ramène à la liste de ses cours et non à la
            // bibliothèque. Un cours qu'on vient de s'approprier n'est plus un cours partagé.
            .navigationDestination(for: SharedCourseRoute.self) { route in
                SharedCourseView(route: route) { adopted in
                    path = NavigationPath([adopted])
                }
            }
        }
        .sheet(isPresented: $showImportChoice, onDismiss: launchPendingImport) {
            ImportChoiceSheet(
                onSelect: { kind in
                    pendingImport = kind
                    showImportChoice = false
                }
            )
            .presentationDetents([.height(604)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .fullScreenCover(item: $activeImport) { kind in
            ImportView(kind: kind) { course in
                activeImport = nil
                // Un import se termine sur la fiche : c'est le résultat, et c'est ce qu'on
                // veut lire avant de décider si on en fait des cartes.
                path = NavigationPath([course])
            }
        }
        .fullScreenCover(isPresented: $isCreatingDeck) {
            CreateDeckView { course in
                isCreatingDeck = false
                // Un paquet se termine sur ses cartes : il n'a pas de fiche à lire.
                path = NavigationPath([CourseCardsRoute(course: course)])
            }
        }
        .micaboPaywall($paywall)
        .confirmationDialog(
            i18n?.t("app.courses.deleteQ") ?? "Supprimer ce cours ?",
            isPresented: Binding(
                get: { coursePendingDelete != nil },
                set: { if !$0 { coursePendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(i18n?.t("app.courses.deleteCourse") ?? "Supprimer le cours", role: .destructive) {
                if let course = coursePendingDelete {
                    withAnimation {
                        try? CourseRepository.delete(course, in: modelContext)
                    }
                }
                coursePendingDelete = nil
            }
            Button(i18n?.t("app.common.cancel") ?? "Annuler", role: .cancel) { coursePendingDelete = nil }
        } message: {
            if let course = coursePendingDelete {
                Text(i18n?.t("app.courses.deleteMsg", [
                    "title": course.title,
                    "cards": MicaboCopy.cards(course.cards.count)
                ]) ?? "\(course.title) et \(MicaboCopy.cards(course.cards.count)) disparaissent.")
            }
        }
        .task(id: censusKey) {
            census = LibraryCensus.load(in: modelContext)
        }
        .onChange(of: path.count) { _, depth in
            if depth == 0 { census = LibraryCensus.load(in: modelContext) }
        }
        .onChange(of: router?.courseImportRequests ?? 0) { oldValue, newValue in
            guard newValue > oldValue else { return }
            // Le prochain tour de boucle : la feuille doit s'ouvrir après que Cours
            // soit déjà l'onglet visible, pas pendant le même rendu.
            Task { @MainActor in
                requestImport()
            }
        }
    }

    private var header: some View {
        MicaboScreenHeader(title: i18n?.t("nav.courses") ?? "Cours", eyebrow: countLabel)
            .padding(.top, MicaboSpacing.xs)
    }

    /// Le seul bouton flottant de l'app : en bas à droite, là où le pouce tombe, et posé
    /// au-dessus de la barre du bas. Quand la liste est vide, l'écran d'accueil porte déjà
    /// son propre appel à importer : deux boutons pour la même action feraient hésiter.
    /// **Le « + » ne porte pas de cadenas**, même quand le cours suivant se paie.
    ///
    /// Un bouton verrouillé annonce un refus avant qu'on ait demandé quoi que ce soit : il
    /// transforme le seul geste de l'écran en porte fermée, et on cesse de le regarder. Il
    /// garde donc son signe, et c'est l'appui qui ouvre le paywall — on demande, on obtient
    /// une réponse, et la réponse dit ce qu'elle coûte.
    @ViewBuilder
    private var importButton: some View {
        if !courses.isEmpty {
            MicaboCircleButton(
                systemImage: "plus",
                style: .dark,
                size: 56,
                accessibilityTitle: i18n?.t("app.import.importCourse") ?? "Importer un cours"
            ) {
                requestImport()
            }
            .padding(.trailing, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var countLabel: String {
        guard !courses.isEmpty else { return i18n?.t("app.courses.none") ?? "Aucun cours" }
        if let cardCount {
            return "\(MicaboCopy.courses(courses.count)) · \(MicaboCopy.cards(cardCount))"
        }
        return MicaboCopy.courses(courses.count)
    }

    @ViewBuilder
    private var myCourses: some View {
        if !courses.isEmpty {
            MicaboSearchField(text: $searchText, placeholder: i18n?.t("app.courses.search") ?? "Rechercher un cours ou une carte")
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
                    MicaboSelectChip(title: order.label(i18n), isSelected: order == sortOrder && subjectFilter == nil) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            sortOrder = order
                            subjectFilter = nil
                        }
                    }
                }

                ForEach(subjects, id: \.self) { subject in
                    MicaboSelectChip(title: subject, isSelected: subjectFilter == subject) {
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
                title: i18n?.t("app.courses.emptyTitle") ?? "Aucun cours",
                message: i18n?.t("app.courses.emptyBody") ?? "Importe un polycopié pour commencer.",
                actionTitle: i18n?.t("ios.importAction") ?? "Importer"
            ) {
                requestImport()
            }
            .padding(.horizontal, MicaboSpacing.screen)
        } else if filtered.isEmpty {
            MicaboEmptyState(
                systemImage: "magnifyingglass",
                title: i18n?.t("app.courses.noResults") ?? "Aucun résultat",
                message: i18n?.t("app.courses.noResultsBody") ?? "Essaie un autre mot."
            )
            .padding(.horizontal, MicaboSpacing.screen)
        } else {
            let items = filtered
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, course in
                    MicaboRow.course(course, stats: census[course.id]) {
                        path.append(course)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            coursePendingDelete = course
                        } label: {
                            Label(i18n?.t("app.common.delete") ?? "Supprimer", systemImage: "trash")
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

    /// Change quand la liste des cours, le jour ou une synchro bougent. Les notes
    /// d'une session, elles, se voient au retour sur la liste (`path.count == 0`).
    private var censusKey: String {
        let stamp = courses.map(\.updatedAt).max()?.timeIntervalSince1970 ?? 0
        let day = MicaboCalendar.shared.startOfDay(for: Date()).timeIntervalSince1970
        return "\(courses.count)-\(stamp)-\(day)-\(sync?.epoch ?? 0)"
    }

    private var canImport: Bool {
        pro?.canImportCourse(existingCourses: courses) ?? true
    }

    /// Le premier cours est offert, le deuxième s'achète.
    ///
    /// Le contrôle est ici plutôt que dans l'écran d'import : on refuse **avant** d'avoir
    /// fait choisir un PDF, sélectionner des photos et attendre une analyse. Un paywall qui
    /// tombe après le travail est un paywall qui fait désinstaller.
    private func requestImport() {
        guard canImport else {
            paywall = .secondCourse
            return
        }
        showImportChoice = true
    }

    private func launchPendingImport() {
        guard let kind = pendingImport else { return }
        pendingImport = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if kind.producesSheet {
                activeImport = kind
            } else {
                isCreatingDeck = true
            }
        }
    }
}
