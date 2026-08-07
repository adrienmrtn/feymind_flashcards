import SwiftUI
import UIKit

/// Les cinq pages. La barre d'onglets est dessinée par chaque page racine,
/// ce qui la fait disparaître dès qu'un écran de détail est poussé.
struct RootTabView: View {
    @State private var router = TabRouter()

    init() {
        Self.configureAppearance()
    }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selection) {
            TodayView()
                .tag(RootTab.today)
                .toolbar(.hidden, for: .tabBar)

            CoursesListView()
                .tag(RootTab.courses)
                .toolbar(.hidden, for: .tabBar)

            DashboardView()
                .tag(RootTab.dashboard)
                .toolbar(.hidden, for: .tabBar)

            LibraryView()
                .tag(RootTab.library)
                .toolbar(.hidden, for: .tabBar)

            ProfileView()
                .tag(RootTab.profile)
                .toolbar(.hidden, for: .tabBar)
        }
        .environment(router)
    }

    private static func configureAppearance() {
        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = UIColor(FeyColor.canvas)
        navigationBar.shadowColor = .clear
        navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(FeyColor.ink),
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
    }
}
