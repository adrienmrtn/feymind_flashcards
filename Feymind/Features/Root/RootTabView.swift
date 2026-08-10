import SwiftUI
import UIKit

/// Les cinq pages, dans la barre d'onglets native du système (icône + libellé,
/// teintée avec l'accent de l'app). Chaque page gère elle-même sa barre de
/// navigation ; seule la barre d'onglets, elle, reste du ressort du système.
struct RootTabView: View {
    @State private var selection: RootTab = .dashboard

    init() {
        Self.configureAppearance()
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(RootTab.allCases) { tab in
                tabContent(for: tab)
                    .tag(tab)
                    .tabItem {
                        Label(tab.label, systemImage: tab.systemImage)
                    }
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: RootTab) -> some View {
        switch tab {
        case .today: TodayView()
        case .courses: CoursesListView()
        case .dashboard: DashboardView()
        case .library: LibraryView()
        case .profile: ProfileView()
        }
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
