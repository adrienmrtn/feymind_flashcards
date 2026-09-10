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
    @Query private var folders: [CourseFolder]

    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .recent
    @State private var subjectFilter: String?
    /// Un cours mène à sa fiche, un `CourseCardsRoute` à ses cartes : deux destinations
    /// pour le même cours, donc un chemin hétérogène.
    @State private var path = NavigationPath()
    @State private var showImportChoice = false
    @State private var pendingImport: ImportKind?
    @State private var activeImport: ImportKind?
    @State private var paywall: PaywallTrigger?
    @State private var coursePendingDelete: Course?
    /// Totaux par cours, lus **une fois**. Le corps ne touche plus `course.cards`.
    @State private var census: [UUID: CourseStats] = [:]
    /// Le dossier ouvert, ou `nil` à la racine.
    @State private var openFolder: UUID?
    /// Ce qu'on est en train de ranger, quand le sélecteur est ouvert.
    @State private var moving: MovingItem?
    @State private var folderPendingDelete: CourseFolder?
    @State private var renamingFolder: CourseFolder?
    @State private var folderName = ""
    @State private var namingNewFolder = false
    /// Le dossier survolé par un glisser en cours. Il sert à le montrer, et à savoir qu'un
    /// lâcher vient d'avoir lieu.
    @State private var dropTarget: UUID?
    /// Quand le dernier lâcher a eu lieu.
    ///
    /// Une rangée de dossier est un **bouton**, et lâcher quelque chose dessus déclenche son
    /// appui juste après le dépôt. Le dossier s'ouvrait donc dans la foulée : le cours venait
    /// d'y entrer, on se retrouvait dedans, et de l'extérieur les deux avaient disparu de la
    /// liste. C'est exactement ce que le glisser-déposer semblait faire.
    @State private var lastDrop = Date.distantPast

    /// Ce qu'on déplace : un cours, ou un dossier avec tout ce qu'il contient.
    private enum MovingItem: Identifiable {
        case course(Course)
        case folder(CourseFolder)

        var id: UUID {
            switch self {
            case .course(let course): course.id
            case .folder(let folder): folder.id
            }
        }
    }

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

    private var sheets: [Course] {
        courses.filter { $0.source != .deck }
    }

    private var subjects: [String] {
        Set(sheets.compactMap { $0.subject?.nilIfBlank }).sorted()
    }

    /// Ce qu'on liste.
    ///
    /// **Une recherche traverse les dossiers.** Chercher « Krebs » et ne rien trouver parce
    /// que le cours est rangé deux niveaux plus bas serait le contraire d'un rangement : on
    /// range pour retrouver, pas pour cacher. Sans recherche, on ne voit que le niveau ouvert.
    private var filtered: [Course] {
        let scope = searchText.isEmpty
            ? sheets.filter { $0.folderID == openFolder || (openFolder == nil && !isKnownFolder($0.folderID)) }
            : sheets

        var base = searchText.isEmpty
            ? scope
            : scope.filter {
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

    /// Vrai quand l'identifiant désigne un dossier qui existe encore. Un cours rangé dans un
    /// dossier effacé ailleurs revient à la racine plutôt que de disparaître.
    private func isKnownFolder(_ id: UUID?) -> Bool {
        guard let id else { return false }
        return folders.contains { $0.id == id }
    }

    /// L'arborescence, recomposée à chaque rendu. C'est la même fonction que le site.
    private var library: (tree: [FolderTree], loose: [Course]) {
        CourseLibrary.build(folders: folders, courses: sheets)
    }

    /// Le chemin jusqu'au dossier ouvert : c'est le fil d'Ariane, et le bouton de remontée.
    private var trail: [CourseFolder] {
        CourseLibrary.path(folders, to: openFolder)
    }

    /// Les dossiers posés au niveau ouvert.
    private var foldersHere: [FolderTree] {
        guard let openFolder else { return library.tree }
        return node(openFolder, in: library.tree)?.children ?? []
    }

    private func node(_ id: UUID, in tree: [FolderTree]) -> FolderTree? {
        for branch in tree {
            if branch.folder.id == id { return branch }
            if let found = node(id, in: branch.children) { return found }
        }
        return nil
    }

    private var cardCount: Int? {
        guard !census.isEmpty else { return nil }
        return sheets.reduce(0) { $0 + (census[$1.id]?.cardCount ?? 0) }
    }

    /// Le compilateur n'arrive pas à typer d'un seul coup la pile, les feuilles et les
    /// dialogues. Chaque morceau se type de son côté, comme `WelcomeDeck` vis-à-vis de
    /// l'écran d'accueil.
    var body: some View {
        lifecycle
    }

    private var lifecycle: some View {
        dialogs
            .task(id: censusTaskID, refreshCensusIfVisible)
            .onChange(of: path.count, handlePathDepth)
            .onChange(of: router?.courseImportRequests ?? 0, handleImportRequest)
    }

    private var dialogs: some View {
        covers
            .alert(newFolderTitle, isPresented: $namingNewFolder, actions: newFolderActions)
            .alert(renameTitle, isPresented: renamingPresented, actions: renameActions)
            .confirmationDialog(
                deleteFolderTitle,
                isPresented: folderDeletePresented,
                titleVisibility: .visible,
                actions: folderDeleteActions,
                message: folderDeleteMessage
            )
            .micaboPaywall($paywall)
            .confirmationDialog(
                deleteCourseTitle,
                isPresented: courseDeletePresented,
                titleVisibility: .visible,
                actions: courseDeleteActions,
                message: courseDeleteMessage
            )
    }

    private var covers: some View {
        stack
            .sheet(isPresented: $showImportChoice, onDismiss: launchPendingImport, content: importChoice)
            .fullScreenCover(item: $activeImport, content: importCover)
            .sheet(item: $moving, content: folderPicker)
    }

    private var stack: some View {
        NavigationStack(path: $path) {
            libraryScroll
                .toolbar(.hidden, for: .navigationBar)
                .reportsNavigationDepth(for: .courses, depth: path.count)
                .returnsHome(path: $path)
                .navigationDestination(for: Course.self, destination: openCourse)
                .navigationDestination(for: CourseCardsRoute.self, destination: openCards)
                // Reprendre un cours partagé atterrit sur **sa** fiche, dans sa propre pile :
                // le chemin est remplacé, donc le retour ramène à la liste de ses cours et
                // non à la bibliothèque. Un cours qu'on vient de s'approprier n'est plus un
                // cours partagé.
                .navigationDestination(for: SharedCourseRoute.self, destination: openShared)
        }
    }

    private var libraryScroll: some View {
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
        if !sheets.isEmpty {
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
        guard !sheets.isEmpty else { return i18n?.t("app.courses.none") ?? "Aucun cours" }
        if let cardCount {
            return "\(MicaboCopy.courses(sheets.count)) · \(MicaboCopy.cards(cardCount))"
        }
        return MicaboCopy.courses(sheets.count)
    }

    @ViewBuilder
    private var myCourses: some View {
        if !sheets.isEmpty {
            MicaboSearchField(text: $searchText, placeholder: i18n?.t("app.courses.search") ?? "Rechercher un cours ou une carte")
                .padding(.horizontal, MicaboSpacing.screen)

            folderTrail

            filterRow
        }

        content
            .padding(.top, sheets.isEmpty ? MicaboSpacing.md : 0)
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
        if sheets.isEmpty {
            emptyLibrary
        } else if filtered.isEmpty {
            noResults
        } else {
            libraryList
        }
    }

    private var emptyLibrary: some View {
        MicaboEmptyState(
            systemImage: "books.vertical",
            title: i18n?.t("app.courses.emptyTitle") ?? "Aucun cours",
            message: i18n?.t("app.courses.emptyBody") ?? "Importe un polycopié pour commencer.",
            actionTitle: i18n?.t("ios.importAction") ?? "Importer"
        ) {
            requestImport()
        }
        .padding(.horizontal, MicaboSpacing.screen)
    }

    private var noResults: some View {
        MicaboEmptyState(
            systemImage: "magnifyingglass",
            title: i18n?.t("app.courses.noResults") ?? "Aucun résultat",
            message: i18n?.t("app.courses.noResultsBody") ?? "Essaie un autre mot."
        )
        .padding(.horizontal, MicaboSpacing.screen)
    }

    /// Les dossiers du niveau ouvert, sauf pendant une recherche : une recherche traverse.
    private var listedFolders: [FolderTree] {
        searchText.isEmpty ? foldersHere : []
    }

    private var libraryList: some View {
        let items = filtered
        return LazyVStack(spacing: 0) {
            ForEach(listedFolders) { branch in
                folderRow(branch)
            }

            ForEach(Array(items.enumerated()), id: \.element.id) { index, course in
                courseRow(course, isLast: index == items.count - 1)
            }
        }
        .padding(.horizontal, MicaboSpacing.xxs)
    }

    @ViewBuilder
    private func folderRow(_ branch: FolderTree) -> some View {
        let isTargeted = dropTarget == branch.folder.id

        MicaboRow.folder(branch.folder, total: branch.total) {
            // Un lâcher n'est pas un appui : voir `lastDrop`, armé dès le survol.
            guard Date().timeIntervalSince(lastDrop) > 0.6 else { return }
            withAnimation(.easeOut(duration: 0.2)) { openFolder = branch.folder.id }
        }
        .contextMenu { folderMenu(branch.folder) }
        // Le dossier visé se colore pendant le survol. Sans ça, on lâche à l'aveugle : rien
        // ne dit lequel des quatre dossiers de l'écran va recevoir le cours.
        .background(
            isTargeted ? MicaboColor.accentSoft : Color.clear,
            in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
        )
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        // Le glisser-déposer existe aussi sur le téléphone, pour qui le connaît :
        // une rangée se prend et se lâche sur un dossier. Ce n'est pas la voie
        // principale - « Déplacer vers » l'est - mais elle ne coûte rien.
        .dropDestination(for: String.self) { items, _ in
            dropTarget = nil
            lastDrop = Date()
            return drop(items, into: branch.folder.id)
        } isTargeted: { targeted in
            // **Le survol arme le garde, pas seulement le lâcher.** Un doigt qui survole cette
            // rangée transporte déjà quelque chose : c'est vrai bien avant que le lâcher
            // n'arrive. Ne poser `lastDrop` que dans le lâcher laissait passer le cas qui a
            // remis le bug debout - le système fait parfois suivre l'appui **avant** l'action
            // de dépôt, et le garde arrivait alors trop tard : le dossier s'ouvrait, on
            // voyait son intérieur vide, et de l'extérieur le cours et le dossier avaient
            // tous les deux disparu.
            if targeted { lastDrop = Date() }
            dropTarget = targeted ? branch.folder.id : nil
        }

        MicaboHairline(inset: MicaboSpacing.md, onCanvas: true)
            .padding(.trailing, MicaboSpacing.xxs)
    }

    @ViewBuilder
    private func courseRow(_ course: Course, isLast: Bool) -> some View {
        MicaboRow.course(course, stats: census[course.id]) {
            path.append(course)
        }
        .draggable(CourseDrag.payload(for: course))
        .contextMenu { courseMenu(course) }

        if !isLast {
            MicaboHairline(inset: MicaboSpacing.md, onCanvas: true)
                .padding(.trailing, MicaboSpacing.xxs)
        }
    }

    @ViewBuilder
    private func courseMenu(_ course: Course) -> some View {
        Button {
            moving = .course(course)
        } label: {
            Label(
                i18n?.t("app.folders.moveTo") ?? "Déplacer vers",
                systemImage: "folder"
            )
        }
        Button(role: .destructive) {
            coursePendingDelete = course
        } label: {
            Label(i18n?.t("app.common.delete") ?? "Supprimer", systemImage: "trash")
        }
    }

    /// Ce qu'on peut faire d'un dossier : y entrer, le renommer, le déplacer, le supprimer.
    @ViewBuilder
    private func folderMenu(_ folder: CourseFolder) -> some View {
        Button {
            renamingFolder = folder
            folderName = folder.name
        } label: {
            Label(i18n?.t("app.folders.rename") ?? "Renommer", systemImage: "pencil")
        }
        Button {
            moving = .folder(folder)
        } label: {
            Label(i18n?.t("app.folders.moveTo") ?? "Déplacer vers", systemImage: "folder")
        }
        Button(role: .destructive) {
            folderPendingDelete = folder
        } label: {
            Label(i18n?.t("app.common.delete") ?? "Supprimer", systemImage: "trash")
        }
    }

    /// Le fil d'Ariane, et la barre où l'on crée un dossier.
    @ViewBuilder
    private var folderTrail: some View {
        HStack(spacing: MicaboSpacing.xs) {
            if openFolder != nil {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        openFolder = trail.count > 1 ? trail[trail.count - 2].id : nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text(
                            trail.count > 1
                                ? trail[trail.count - 2].name
                                : (i18n?.t("app.folders.root") ?? "Mes cours")
                        )
                        .font(MicaboFont.hanken(14, weight: .medium))
                    }
                    .foregroundStyle(MicaboColor.inkSecondary)
                }
                // Lâcher un cours ici le sort du dossier : c'est le `..` d'un gestionnaire
                // de fichiers, et le même geste que sur le site.
                .dropDestination(for: String.self) { items, _ in
                    lastDrop = Date()
                    return drop(items, into: trail.count > 1 ? trail[trail.count - 2].id : nil)
                }

                if let current = trail.last {
                    Text(current.name)
                        .font(MicaboFont.hanken(14, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button {
                folderName = ""
                namingNewFolder = true
            } label: {
                Label(
                    i18n?.t("app.folders.new") ?? "Nouveau dossier",
                    systemImage: "folder.badge.plus"
                )
                .font(MicaboFont.hanken(13.5, weight: .medium))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(MicaboColor.accent)
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
    }

    // MARK: - Feuilles et dialogues

    private func importChoice() -> some View {
        ImportChoiceSheet(
            onSelect: { kind in
                pendingImport = kind
                showImportChoice = false
            }
        )
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MicaboRadius.sheet)
    }

    private func importCover(_ kind: ImportKind) -> some View {
        ImportView(kind: kind) { course in
            activeImport = nil
            // Un import se termine sur la fiche : c'est le résultat, et c'est ce qu'on
            // veut lire avant de décider si on en fait des cartes.
            path = NavigationPath([course])
        }
    }

    private func folderPicker(_ item: MovingItem) -> some View {
        FolderPickerSheet(
            movingFolder: movingFolderID(of: item),
            current: currentFolderID(of: item),
            onPick: { target in applyMove(item, to: target) }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MicaboRadius.sheet)
    }

    private func openCourse(_ course: Course) -> some View {
        CourseSheetView(course: course)
    }

    private func openCards(_ route: CourseCardsRoute) -> some View {
        FlashcardsView(course: route.course)
    }

    private func openShared(_ route: SharedCourseRoute) -> some View {
        SharedCourseView(route: route) { adopted in
            path = NavigationPath([adopted])
        }
    }

    private func movingFolderID(of item: MovingItem) -> UUID? {
        if case .folder(let folder) = item { return folder.id }
        return nil
    }

    private func currentFolderID(of item: MovingItem) -> UUID? {
        switch item {
        case .course(let course): course.folderID
        case .folder(let folder): folder.parentID
        }
    }

    private func applyMove(_ item: MovingItem, to target: UUID?) {
        switch item {
        case .course(let course): move(course, to: target)
        case .folder(let folder): move(folder, to: target)
        }
    }

    private var newFolderTitle: String {
        i18n?.t("app.folders.new") ?? "Nouveau dossier"
    }

    private var renameTitle: String {
        i18n?.t("app.folders.rename") ?? "Renommer"
    }

    private var deleteFolderTitle: String {
        i18n?.t("app.folders.deleteQ") ?? "Supprimer ce dossier ?"
    }

    private var deleteCourseTitle: String {
        i18n?.t("app.courses.deleteQ") ?? "Supprimer ce cours ?"
    }

    private var folderNamePlaceholder: String {
        i18n?.t("app.folders.namePlaceholder") ?? "Nom du dossier"
    }

    private var renamingPresented: Binding<Bool> {
        Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { renamingFolder = nil } }
        )
    }

    private var folderDeletePresented: Binding<Bool> {
        Binding(
            get: { folderPendingDelete != nil },
            set: { if !$0 { folderPendingDelete = nil } }
        )
    }

    private var courseDeletePresented: Binding<Bool> {
        Binding(
            get: { coursePendingDelete != nil },
            set: { if !$0 { coursePendingDelete = nil } }
        )
    }

    @ViewBuilder
    private func newFolderActions() -> some View {
        TextField(folderNamePlaceholder, text: $folderName)
        Button(i18n?.t("app.common.cancel") ?? "Annuler", role: .cancel) { folderName = "" }
        Button(i18n?.t("app.folders.create") ?? "Créer") { createFolder() }
    }

    @ViewBuilder
    private func renameActions() -> some View {
        TextField(folderNamePlaceholder, text: $folderName)
        Button(i18n?.t("app.common.cancel") ?? "Annuler", role: .cancel) { renamingFolder = nil }
        Button(i18n?.t("app.common.save") ?? "Enregistrer") { saveRenamedFolder() }
    }

    private func saveRenamedFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let folder = renamingFolder, !name.isEmpty {
            folder.name = name
            folder.updatedAt = Date()
            try? modelContext.save()
        }
        renamingFolder = nil
    }

    @ViewBuilder
    private func folderDeleteActions() -> some View {
        Button(i18n?.t("app.folders.delete") ?? "Supprimer", role: .destructive) {
            if let folder = folderPendingDelete {
                withAnimation { deleteFolder(folder) }
            }
            folderPendingDelete = nil
        }
        Button(i18n?.t("app.common.cancel") ?? "Annuler", role: .cancel) { folderPendingDelete = nil }
    }

    private func folderDeleteMessage() -> some View {
        Text(i18n?.t("app.folders.deleteMsg") ?? "Ce qu'il contient remonte d'un cran, rien n'est supprimé.")
    }

    @ViewBuilder
    private func courseDeleteActions() -> some View {
        Button(i18n?.t("app.courses.deleteCourse") ?? "Supprimer le cours", role: .destructive) {
            if let course = coursePendingDelete {
                withAnimation {
                    try? CourseRepository.delete(course, in: modelContext)
                }
            }
            coursePendingDelete = nil
        }
        Button(i18n?.t("app.common.cancel") ?? "Annuler", role: .cancel) { coursePendingDelete = nil }
    }

    @ViewBuilder
    private func courseDeleteMessage() -> some View {
        if let course = coursePendingDelete {
            Text(courseDeleteCopy(course))
        }
    }

    private func courseDeleteCopy(_ course: Course) -> String {
        let cards = MicaboCopy.cards(census[course.id]?.cardCount ?? course.cards.count)
        return i18n?.t("app.courses.deleteMsg", [
            "title": course.title,
            "cards": cards
        ]) ?? "\(course.title) et \(MicaboCopy.cards(course.cards.count)) disparaissent."
    }

    private var censusTaskID: String {
        "\(router?.selection == .courses)-\(censusKey)"
    }

    private func refreshCensusIfVisible() async {
        guard router?.selection == .courses || path.count > 0 else { return }
        census = LibraryCensus.load(in: modelContext, key: censusKey)
    }

    private func handlePathDepth(_: Int, _ depth: Int) {
        if depth == 0, router?.selection == .courses {
            census = LibraryCensus.load(in: modelContext, key: censusKey)
        }
    }

    private func handleImportRequest(_ oldValue: Int, _ newValue: Int) {
        guard newValue > oldValue else { return }
        // Le prochain tour de boucle : la feuille doit s'ouvrir après que Cours
        // soit déjà l'onglet visible, pas pendant le même rendu.
        Task { @MainActor in
            requestImport()
        }
    }

    // MARK: - Ranger

    /// Le lâcher : on ne transporte qu'un identifiant, et on retrouve ce qu'il désigne.
    ///
    /// L'identifiant est **préfixé**. Une rangée qu'on glisse peut arriver au lâcher sous
    /// plusieurs formes - le texte qu'on transportait, celui que le système a cru bon
    /// d'ajouter - et un identifiant nu ne se distingue pas d'une chaîne quelconque : le
    /// dépôt échouait alors en silence, sans qu'on sache s'il n'avait pas été vu ou s'il
    /// avait été refusé.
    private func drop(_ items: [String], into target: UUID?) -> Bool {
        guard let id = items.compactMap(CourseDrag.identifier(in:)).first else { return false }

        if let course = sheets.first(where: { $0.id == id }) {
            move(course, to: target)
            Haptics.success()
            return true
        }
        if let folder = folders.first(where: { $0.id == id }) {
            move(folder, to: target)
            Haptics.success()
            return true
        }
        return false
    }

    private func move(_ course: Course, to folder: UUID?) {
        guard course.folderID != folder else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            course.folderID = folder
            course.updatedAt = Date()
        }
        try? modelContext.save()
    }

    private func move(_ folder: CourseFolder, to parent: UUID?) {
        guard folder.parentID != parent,
              CourseLibrary.canMove(folders, folder: folder.id, into: parent)
        else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            folder.parentID = parent
            folder.updatedAt = Date()
        }
        try? modelContext.save()
    }

    private func createFolder() {
        let name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        folderName = ""
        guard !name.isEmpty else { return }
        let folder = CourseFolder(parentID: openFolder, name: name)
        modelContext.insert(folder)
        try? modelContext.save()
    }

    /// Supprimer un dossier **rend son contenu d'un cran**, il ne l'emporte pas. Un clic de
    /// trop sur « Physique » ne doit pas effacer le semestre.
    private func deleteFolder(_ folder: CourseFolder) {
        let parent = folder.parentID
        for course in courses where course.folderID == folder.id {
            course.folderID = parent
            course.updatedAt = Date()
        }
        for child in folders where child.parentID == folder.id {
            child.parentID = parent
            child.updatedAt = Date()
        }
        if openFolder == folder.id { openFolder = parent }
        CloudTombstones.mark(CloudTable.courseFolders, id: folder.id)
        modelContext.delete(folder)
        try? modelContext.save()
    }

    /// Change quand la liste des cours, le jour ou une synchro bougent. Les notes
    /// d'une session, elles, se voient au retour sur la liste (`path.count == 0`).
    private var censusKey: String {
        let stamp = courses.first?.updatedAt.timeIntervalSince1970 ?? 0
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
            activeImport = kind
        }
    }
}
