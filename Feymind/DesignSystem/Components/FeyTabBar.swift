import SwiftUI

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
                        withAnimation(.easeOut(duration: 0.22)) {
                            router.selection = tab
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 21, weight: .regular))
                            Text(tab.label)
                                .font(FeyFont.hanken(10, weight: .medium))
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
