import SwiftUI

enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case today
    case courses
    case dashboard
    case library
    case profile

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .today: "Réviser"
        case .courses: "Mes cours"
        case .dashboard: "Accueil"
        case .library: "Bibliothèque"
        case .profile: "Profil"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "arrow.triangle.2.circlepath"
        case .courses: "books.vertical"
        case .dashboard: "house"
        case .library: "book"
        case .profile: "person"
        }
    }
}

/// Onglet actif, partagé par les cinq pages.
@Observable
final class TabRouter {
    var selection: RootTab = .dashboard
}

/// Barre d'onglets fixe, en pied d'écran : icône + libellé, l'onglet actif en accent.
/// Reste absente des aperçus, où aucun routeur n'est fourni.
struct FeyTabBar: View {
    @Environment(TabRouter.self) private var router: TabRouter?

    var body: some View {
        if let router {
            bar(router)
        }
    }

    private func bar(_ router: TabRouter) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(FeyColor.surface.opacity(0.7))
                .overlay(alignment: .top) {
                    Rectangle().fill(FeyColor.stroke).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)

            HStack(spacing: 0) {
                ForEach(RootTab.allCases) { tab in
                    Button {
                        router.selection = tab
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 21, weight: .regular))
                            Text(tab.label)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(tab == router.selection ? FeyColor.accent : FeyColor.inkTertiary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.label)
                }
            }
            .padding(.top, FeySpacing.xs)
        }
        .frame(height: FeyLayout.tabBarHeight)
        .animation(.easeOut(duration: 0.18), value: router.selection)
    }
}

extension View {
    /// Pose la barre d'onglets au bas du contenu d'une page racine.
    /// À appliquer à l'intérieur du `NavigationStack` pour qu'elle disparaisse sur les écrans poussés.
    func feyTabBar() -> some View {
        overlay(alignment: .bottom) {
            FeyTabBar()
        }
    }
}
