import SwiftUI
import UIKit

/// Les trois pages, balayables comme un carrousel natif. La barre d'onglets est
/// dessinée par chaque page racine : elle disparaît dès qu'un détail est poussé,
/// et le balayage est alors coupé.
struct RootTabView: View {
    @State private var router = TabRouter()

    init() {
        FontLoader.registerFonts()
        Self.configureAppearance()
    }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selection) {
            TodayView()
                .tag(RootTab.today)

            CoursesListView()
                .tag(RootTab.courses)

            ProfileView()
                .tag(RootTab.profile)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(MicaboColor.canvas)
        .background {
            TabPagingScrollBridge(isEnabled: router.allowsPaging)
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
