import SwiftData
import SwiftUI

/// Onglet **Paquets** : les cartes de tous les cours, et les paquets ouverts sans fiche.
///
/// C'est d'ici qu'on en crée un, vide ou depuis Anki. L'onglet Cours n'ouvre plus cette
/// porte : un cours part d'un document, un paquet part des cartes.
struct DecksListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(TabRouter.self) private var router: TabRouter?
    @Environment(CloudSync.self) private var sync: CloudSync?
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var searchText = ""
    @State private var path = NavigationPath()
    @State private var isCreatingDeck = false
    @State private var paywall: PaywallTrigger?
    @State private var deckPendingDelete: Course?
    @State private var census: [UUID: CourseStats] = [:]

    private var filtered: [Course] {
        searchText.isEmpty
            ? courses
            : courses.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || ($0.subject ?? "").localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                    MicaboScreenHeader(
                        title: i18n?.t("nav.decks") ?? "Paquets",
                        eyebrow: countLabel
                    )
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.top, MicaboSpacing.xs)

                    list
                }
                .padding(.bottom, MicaboSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            .tabBarClearance { addButton }
            .toolbar(.hidden, for: .navigationBar)
            .reportsNavigationDepth(for: .decks, depth: path.count)
            .returnsHome(path: $path)
            .navigationDestination(for: CourseCardsRoute.self) { route in
                FlashcardsView(course: route.course)
            }
        }
        .fullScreenCover(isPresented: $isCreatingDeck) {
            CreateDeckView { course in
                isCreatingDeck = false
                path = NavigationPath([CourseCardsRoute(course: course)])
            }
        }
        .micaboPaywall($paywall)
        .confirmationDialog(
            i18n?.t("app.decks.deleteQ") ?? "Supprimer ce paquet ?",
            isPresented: Binding(
                get: { deckPendingDelete != nil },
                set: { if !$0 { deckPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(i18n?.t("app.decks.deleteDeck") ?? "Supprimer le paquet", role: .destructive) {
                if let course = deckPendingDelete {
                    withAnimation {
                        try? CourseRepository.delete(course, in: modelContext)
                    }
                }
                deckPendingDelete = nil
            }
            Button(i18n?.t("app.common.cancel") ?? "Annuler", role: .cancel) { deckPendingDelete = nil }
        } message: {
            if let course = deckPendingDelete {
                Text(i18n?.t("app.decks.deleteMsg", [
                    "title": course.title,
                    "cards": MicaboCopy.cards(census[course.id]?.cardCount ?? course.cards.count)
                ]) ?? "\(course.title) et \(MicaboCopy.cards(course.cards.count)) disparaissent.")
            }
        }
        .task(id: "\(router?.selection == .decks)-\(censusKey)") {
            guard router?.selection == .decks || path.count > 0 else { return }
            census = LibraryCensus.load(in: modelContext, key: censusKey)
        }
        .onChange(of: path.count) { _, depth in
            if depth == 0, router?.selection == .decks {
                census = LibraryCensus.load(in: modelContext, key: censusKey)
            }
        }
    }

    private var countLabel: String {
        guard !courses.isEmpty else { return i18n?.t("app.decks.none") ?? "Aucun paquet" }
        return MicaboCopy.cards(LibraryCensus.totalCards(in: census))
    }

    @ViewBuilder
    private var addButton: some View {
        if !courses.isEmpty {
            MicaboCircleButton(
                systemImage: "plus",
                style: .dark,
                size: 56,
                accessibilityTitle: i18n?.t("app.decks.addTitle") ?? "Ouvrir un paquet"
            ) {
                requestCreate()
            }
            .padding(.trailing, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var list: some View {
        if !courses.isEmpty {
            MicaboSearchField(
                text: $searchText,
                placeholder: i18n?.t("app.decks.search") ?? "Rechercher un paquet"
            )
            .padding(.horizontal, MicaboSpacing.screen)
        }

        content
            .padding(.top, courses.isEmpty ? MicaboSpacing.md : 0)
    }

    @ViewBuilder
    private var content: some View {
        if courses.isEmpty {
            MicaboEmptyState(
                systemImage: "rectangle.on.rectangle.angled",
                title: i18n?.t("app.decks.emptyTitle") ?? "Aucun paquet",
                message: i18n?.t("app.decks.emptyBody") ?? "Ouvre-en un pour commencer, vide ou depuis Anki.",
                actionTitle: i18n?.t("app.decks.addTitle") ?? "Ouvrir un paquet"
            ) {
                requestCreate()
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
                        path.append(CourseCardsRoute(course: course))
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deckPendingDelete = course
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

    private var censusKey: String {
        let stamp = courses.first?.updatedAt.timeIntervalSince1970 ?? 0
        let day = MicaboCalendar.shared.startOfDay(for: Date()).timeIntervalSince1970
        return "decks-\(courses.count)-\(stamp)-\(day)-\(sync?.epoch ?? 0)"
    }

    private var canImport: Bool {
        pro?.canImportCourse(existingCourses: courses) ?? true
    }

    private func requestCreate() {
        guard canImport else {
            paywall = .secondCourse
            return
        }
        isCreatingDeck = true
    }
}
