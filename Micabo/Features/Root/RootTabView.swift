import SwiftUI
import UIKit

/// Les trois pages de l'app, avec **Réviser** au milieu, et la barre du bas qui les
/// commande.
///
/// **On ne balaye plus d'une page à l'autre.** Le carrousel qui vivait ici était un
/// `TabView` en style page : trois écrans montés côte à côte, qui suivaient le doigt. Ça
/// coûtait cher pour ce que ça donnait. Un défilement horizontal qui traîne sur un tiers de
/// geste rend chaque écran mou ; il entrait en conflit avec tout ce qui se balaye à
/// l'intérieur d'une page ; et il fallait un bricolage qui parcourait toute la hiérarchie
/// UIKit à chaque passe de mise en page pour le couper dès qu'un écran de détail était
/// poussé. Les onglets s'atteignent maintenant par la barre du bas, et le changement de page
/// est un fondu court.
///
/// Les trois pages restent **montées en même temps**, simplement masquées : c'est ce qui
/// permet à chacune de garder son défilement, sa recherche et sa pile de navigation quand on
/// la quitte et qu'on y revient.
struct RootTabView: View {
    @State private var router = TabRouter()

    init() {
        FontLoader.registerFonts()
        Self.configureAppearance()
    }

    var body: some View {
        ZStack {
            MicaboColor.canvas
                .ignoresSafeArea()

            page(.courses) { CoursesListView() }
            page(.today) { TodayView() }
            page(.profile) { ProfileView() }
        }
        // La barre du bas est posée à l'extérieur des pages : elles passent dessous, elle ne
        // bouge pas d'un pixel. Elle s'efface dès qu'un écran de détail est poussé.
        //
        // Cet inset la **place**, il ne réserve rien : chaque page est un `NavigationStack`,
        // et un `safeAreaInset` ne franchit pas cette frontière. La place est donc réservée
        // page par page, par `tabBarClearance`, qui est aussi ce qui pose leurs boutons du
        // bas au-dessus de la barre au lieu de dessous.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if router.isAtRoot {
                MicaboTabBar()
            }
        }
        .tint(MicaboColor.accent)
        .environment(router)
    }

    /// Une page masquée reste montée, mais ne prend ni les appuis ni le lecteur d'écran :
    /// sans ça, on toucherait un bouton invisible en visant celui d'à côté.
    @ViewBuilder
    private func page<Content: View>(_ tab: RootTab, @ViewBuilder content: () -> Content) -> some View {
        let isActive = router.selection == tab

        content()
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
            .zIndex(isActive ? 1 : 0)
            .animation(.easeOut(duration: 0.22), value: isActive)
    }

    private static func configureAppearance() {
        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = UIColor(MicaboColor.canvas)
        navigationBar.shadowColor = .clear
        navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(MicaboColor.ink),
            .font: UIFont(name: "HankenGrotesk-SemiBold", size: 16)
                ?? UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
    }
}
