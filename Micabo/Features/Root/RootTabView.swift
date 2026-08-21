import SwiftUI
import UIKit

/// Les trois pages, balayables comme un carrousel natif, avec **Réviser** au milieu.
///
/// La barre d'onglets est posée à ce niveau, hors du carrousel : elle ne balaye pas
/// avec les pages, elle les regarde passer. Elle s'efface en revanche dès qu'un écran
/// de détail est poussé, et le balayage est alors coupé lui aussi.
struct RootTabView: View {
    @State private var router = TabRouter()

    init() {
        FontLoader.registerFonts()
        Self.configureAppearance()
    }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selection) {
            CoursesListView()
                .tag(RootTab.courses)

            TodayView()
                .tag(RootTab.today)

            ProfileView()
                .tag(RootTab.profile)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(MicaboColor.canvas)
        .background {
            TabPagingScrollBridge(isEnabled: router.isAtRoot)
        }
        // La barre du bas est posée ici, à l'extérieur du carrousel : les pages glissent
        // sous elle, elle ne bouge pas d'un pixel. Elle s'efface dès qu'un écran de
        // détail est poussé, où le balayage est de toute façon coupé.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if router.isAtRoot {
                MicaboTabBar()
            }
        }
        .tint(MicaboColor.accent)
        .environment(router)
        .animation(.easeOut(duration: 0.28), value: router.selection)
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
