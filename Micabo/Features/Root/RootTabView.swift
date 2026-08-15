import SwiftUI
import UIKit

/// Les cinq pages, balayables comme un carrousel natif. La barre d'onglets est
/// posée par-dessus le carrousel, et non dans les pages : le balayage fait donc
/// défiler les pages seules, la barre ne bouge pas. Chaque page racine réserve sa
/// hauteur (`micaboTabBarClearance`) et signale sa profondeur de navigation, ce qui
/// retire la barre et coupe le balayage dès qu'un écran de détail est poussé.
struct RootTabView: View {
    @State private var router = TabRouter()

    init() {
        FontLoader.registerFonts()
        Self.configureAppearance()
    }

    var body: some View {
        @Bindable var router = router

        ZStack(alignment: .bottom) {
            TabView(selection: $router.selection) {
                TodayView()
                    .tag(RootTab.today)

                CoursesListView()
                    .tag(RootTab.courses)

                DashboardView()
                    .tag(RootTab.dashboard)

                LibraryView()
                    .tag(RootTab.library)

                ProfileView()
                    .tag(RootTab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(MicaboColor.canvas)
            .background {
                TabPagingScrollBridge(isEnabled: router.isAtRoot)
            }

            if router.isAtRoot {
                MicaboTabBar()
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.25), value: router.isAtRoot)
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
