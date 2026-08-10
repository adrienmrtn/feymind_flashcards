import SwiftUI
import UIKit

/// Les cinq pages. Barre d'onglets native du système ; sélection partagée via `TabRouter`
/// pour permettre un basculement programmatique (ex. « Tout voir »).
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
                .tabItem { Label(RootTab.today.label, systemImage: RootTab.today.systemImage) }

            CoursesListView()
                .tag(RootTab.courses)
                .tabItem { Label(RootTab.courses.label, systemImage: RootTab.courses.systemImage) }

            DashboardView()
                .tag(RootTab.dashboard)
                .tabItem { Label(RootTab.dashboard.label, systemImage: RootTab.dashboard.systemImage) }

            LibraryView()
                .tag(RootTab.library)
                .tabItem { Label(RootTab.library.label, systemImage: RootTab.library.systemImage) }

            ProfileView()
                .tag(RootTab.profile)
                .tabItem { Label(RootTab.profile.label, systemImage: RootTab.profile.systemImage) }
        }
        .tint(FeyColor.accent)
        .environment(router)
    }

    private static func configureAppearance() {
        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = UIColor(FeyColor.canvas)
        navigationBar.shadowColor = .clear
        navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(FeyColor.ink),
            .font: UIFont(name: "HankenGrotesk-SemiBold", size: 16)
                ?? UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
    }
}
