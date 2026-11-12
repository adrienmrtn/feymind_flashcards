import SwiftUI
import UIKit

/// Les cinq pages de l'app — **Home**, **Leçons**, **Calendrier**, **Concentration**,
/// **Profil** — et la barre du bas qui les commande (`RootTab.tabs`).
///
/// **On ne balaye plus d'une page à l'autre.** Le carrousel qui vivait ici était un
/// `TabView` en style page : les écrans montés côte à côte, qui suivaient le doigt. Ça
/// coûtait cher pour ce que ça donnait. Un défilement horizontal qui traîne sur un tiers de
/// geste rend chaque écran mou ; il entrait en conflit avec tout ce qui se balaye à
/// l'intérieur d'une page ; et il fallait un bricolage qui parcourait toute la hiérarchie
/// UIKit à chaque passe de mise en page pour le couper dès qu'un écran de détail était
/// poussé. Les onglets s'atteignent maintenant par la barre du bas.
///
/// **Le changement de page est immédiat.** Un fondu de 220 ms sur quatre `NavigationStack`
/// animait tout l'arbre — listes, calendrier, fiche — et chaque onglet arrivait en retard.
/// Le `TabView` système garde les piles déjà ouvertes sans dessiner cinq pages superposées.
/// L'ancien `ZStack` à opacité zéro laissait chaque `@Query`, chaque calendrier et chaque
/// statistique vivre derrière l'écran actif ; une écriture SwiftData réveillait tout.
struct RootTabView: View {
    @State private var router: TabRouter

    /// Le routeur se donne de l'extérieur dans le banc d'essai, qui change d'onglet et mesure
    /// (`PerfBenchTests`) ; l'app laisse la valeur par défaut.
    init(router: TabRouter = TabRouter()) {
        _router = State(initialValue: router)
        Self.configureChrome()
    }

    var body: some View {
        @Bindable var router = router

        return ZStack {
            MicaboColor.canvas
                .ignoresSafeArea()

            // **Chaque page est posée une fois** (`RootPage`) : cette racine se relit à chaque
            // changement d'onglet et à chaque écran poussé (elle lit `selection` et la
            // profondeur), et elle reconstruisait alors les cinq pages, que SwiftUI devait
            // comparer une à une. Une page ne dépend de rien que la racine lui donne : elle ne
            // se redessine plus que pour ce qu'elle lit elle-même.
            TabView(selection: $router.selection) {
                RootPage { HomeView() }
                    .equatable()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(RootTab.today)
                RootPage { CoursesListView() }
                    .equatable()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(RootTab.decks)
                RootPage { CalendarView() }
                    .equatable()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(RootTab.calendar)
                RootPage { FocusView() }
                    .equatable()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(RootTab.focus)
                RootPage { ProfileView() }
                    .equatable()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(RootTab.profile)
            }
            // La barre UIKit ne se montre jamais : Micabo garde sa barre, posée juste
            // dessous. Le style standard ne permet pas le balayage horizontal qui faisait
            // auparavant traîner les pages sous le doigt. L'attribut est aussi sur
            // chaque onglet : sur le `TabView` seul, iOS 18 réserve encore sa hauteur.
            .toolbar(.hidden, for: .tabBar)
        }
        // La barre du bas est posée à l'extérieur des pages : elles passent dessous, elle
        // ne bouge pas d'un pixel. Elle s'efface dès qu'un écran de détail est poussé.
        //
        // Cet inset la **place**, il ne réserve rien : chaque page est un `NavigationStack`,
        // et un `safeAreaInset` ne franchit pas cette frontière. La place est réservée page
        // par page, par `tabBarClearance`, qui est aussi ce qui pose leurs boutons du bas
        // au-dessus de la barre au lieu de dessous.
        // **L'app s'ouvre sur Home après le parcours** : la leçon qu'il vient d'écrire y
        // attend dans « Reprendre », un appui l'ouvre sur son chemin. La remise ne sert plus
        // à choisir l'onglet ; Leçons la consomme. Voir `FirstDeckHandoff`.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if router.isAtRoot {
                MicaboTabBar()
            }
        }
        .tint(MicaboColor.accent)
        .environment(router)
    }

    /// Une fois par lancement : la racine est reconstruite à chaque passe de `RootView`.
    private static let chrome: Void = {
        applyChrome()
    }()

    private static func configureChrome() {
        _ = chrome
    }

    private static func applyChrome() {
        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = UIColor(MicaboColor.canvas)
        navigationBar.shadowColor = .clear
        navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(MicaboColor.ink),
            .font: MicaboFont.uiDisplayFont(16, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
    }
}

/// **Une page d'onglet, que la racine ne fait jamais redessiner.**
///
/// Les cinq pages ne reçoivent rien de la racine : ni valeur, ni liaison. Deux `RootPage` sont
/// donc toujours égales, et `.equatable()` dit à SwiftUI de ne pas relire leur contenu quand la
/// racine se relit. Ce que la page lit elle-même (sa base, l'environnement, ses états) la fait
/// toujours redessiner : seule la relecture venue d'en haut s'arrête ici.
private struct RootPage<Content: View>: View, Equatable {
    @ViewBuilder var content: () -> Content

    static func == (lhs: RootPage<Content>, rhs: RootPage<Content>) -> Bool {
        true
    }

    var body: some View {
        content()
    }
}
