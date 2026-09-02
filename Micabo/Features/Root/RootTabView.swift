import SwiftUI
import UIKit

/// Les pages de l'app, avec **Réviser** à côté de **Examens**, et la barre du bas qui les
/// commande.
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
/// Le `TabView` système garde les piles déjà ouvertes sans dessiner quatre pages superposées.
/// L'ancien `ZStack` à opacité zéro laissait chaque `@Query`, chaque calendrier et chaque
/// statistique vivre derrière l'écran actif ; une écriture SwiftData réveillait tout.
struct RootTabView: View {
    @State private var router = TabRouter()

    init() {
        Self.configureAppearance()
    }

    var body: some View {
        @Bindable var router = router

        return ZStack {
            MicaboColor.canvas
                .ignoresSafeArea()

            TabView(selection: $router.selection) {
                CoursesListView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(RootTab.courses)
                TodayView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(RootTab.today)
                ExamsView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(RootTab.exams)
                ProfileView()
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if router.isAtRoot {
                MicaboTabBar()
            }
        }
        // La languette du cadeau est posée ici, hors des pages, pour la même raison que
        // la barre : son décompte ne doit pas repartir de zéro à chaque changement
        // d'onglet. Elle se colle au bord droit, au-dessus de la barre et des boutons.
        .overlay {
            DiscountBadgeHost(
                bottomInset: router.isAtRoot
                    ? MicaboLayout.tabBarSpace + MicaboSpacing.sm
                    : MicaboLayout.bottomBarClearance
            )
        }
        .tint(MicaboColor.accent)
        .environment(router)
    }

    private static var didConfigureAppearance = false

    private static func configureAppearance() {
        guard !didConfigureAppearance else { return }
        didConfigureAppearance = true

        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = UIColor(MicaboColor.canvas)
        navigationBar.shadowColor = .clear
        navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(MicaboColor.ink),
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
    }
}
