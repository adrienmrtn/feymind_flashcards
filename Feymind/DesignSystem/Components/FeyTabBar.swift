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
        case .today: "rectangle.stack"
        case .courses: "books.vertical"
        case .dashboard: "house"
        case .library: "globe.europe.africa"
        case .profile: "person"
        }
    }
}

/// Onglet actif, partagé par les cinq pages.
@Observable
final class TabRouter {
    var selection: RootTab = .dashboard
}

/// Barre d'onglets flottante : pilule sombre, onglet actif dans un cercle blanc.
struct FeyTabBar: View {
    @Environment(TabRouter.self) private var router

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RootTab.allCases) { tab in
                Button {
                    router.selection = tab
                } label: {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(tab == router.selection ? FeyColor.ink : FeyColor.onInkMuted)
                        .frame(width: 46, height: 46)
                        .background {
                            if tab == router.selection {
                                Circle().fill(FeyColor.surface)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
            }
        }
        .padding(.horizontal, FeySpacing.xs)
        .frame(height: FeyLayout.tabBarHeight)
        .background(FeyColor.ink, in: Capsule())
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
        .padding(.bottom, FeySpacing.xs)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: router.selection)
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
