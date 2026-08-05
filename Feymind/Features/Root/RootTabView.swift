import SwiftUI

/// Les cinq pages : le tableau de bord est au centre, deux onglets de chaque côté.
struct RootTabView: View {
    @State private var selection: Tab = .dashboard

    enum Tab: Int, Hashable {
        case today
        case courses
        case dashboard
        case library
        case profile
    }

    init() {
        Self.configureAppearance()
    }

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tag(Tab.today)
                .tabItem { Label("Réviser", systemImage: "square.stack.3d.up.fill") }

            CoursesListView()
                .tag(Tab.courses)
                .tabItem { Label("Mes cours", systemImage: "books.vertical.fill") }

            DashboardView()
                .tag(Tab.dashboard)
                .tabItem { Label("Accueil", systemImage: "house.fill") }

            LibraryView()
                .tag(Tab.library)
                .tabItem { Label("Bibliothèque", systemImage: "globe.europe.africa.fill") }

            ProfileView()
                .tag(Tab.profile)
                .tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }
        }
        .tint(FeyColor.accent)
    }

    private static func configureAppearance() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithDefaultBackground()
        tabBar.backgroundColor = UIColor(FeyColor.canvas).withAlphaComponent(0.94)
        tabBar.shadowColor = UIColor(FeyColor.stroke)
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let navigationBar = UINavigationBarAppearance()
        navigationBar.configureWithOpaqueBackground()
        navigationBar.backgroundColor = UIColor(FeyColor.canvas)
        navigationBar.shadowColor = .clear
        navigationBar.titleTextAttributes = [
            .foregroundColor: UIColor(FeyColor.ink),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigationBar.largeTitleTextAttributes = [
            .foregroundColor: UIColor(FeyColor.ink),
            .font: UIFont.systemFont(ofSize: 32, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = navigationBar
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBar
        UINavigationBar.appearance().compactAppearance = navigationBar
    }
}
