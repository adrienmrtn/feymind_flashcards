import SwiftUI
import UIKit

/// Les cinq pages, balayables horizontalement. La barre d'onglets est dessinée
/// par chaque page racine, ce qui la fait disparaître dès qu'un écran de détail
/// est poussé ; le balayage est alors aussi désactivé.
struct RootTabView: View {
    @State private var router = TabRouter()

    init() {
        Self.configureAppearance()
    }

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selection) {
            ForEach(RootTab.allCases) { tab in
                tabContent(for: tab)
                    .tag(tab)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background {
            TabPagingScrollBridge(isEnabled: router.allowsPaging)
        }
        .environment(router)
        .animation(.easeOut(duration: 0.22), value: router.selection)
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
