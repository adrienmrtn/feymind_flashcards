import SwiftUI

/// Barre d'onglets, dessinée par `RootTabView` par-dessus le carrousel : posée
/// dans une page, elle suivrait le doigt pendant le balayage. Les pages racines
/// n'en gardent qu'une copie masquée, qui réserve sa hauteur.
struct MicaboTabBar: View {
    @Environment(TabRouter.self) private var router: TabRouter?

    var body: some View {
        if let router {
            bar(router)
        }
    }

    private func bar(_ router: TabRouter) -> some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases) { tab in
                Button {
                    Haptics.selection()
                    withAnimation(.easeOut(duration: 0.28)) {
                        router.selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: .regular))
                        Text(tab.label)
                            .font(MicaboFont.hanken(10, weight: .medium))
                    }
                    .foregroundStyle(tab == router.selection ? MicaboColor.accent : MicaboColor.inkTertiary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(tab == router.selection ? .isSelected : [])
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(MicaboColor.canvas.opacity(0.55))
                .overlay(alignment: .top) {
                    Rectangle().fill(MicaboColor.stroke).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

extension View {
    /// Réserve, sous le contenu d'une page racine, la hauteur exacte de la barre
    /// d'onglets que `RootTabView` dessine par-dessus. Une copie masquée sert de
    /// gabarit : elle suit la police et la taille dynamique sans constante à tenir
    /// à jour. Cette réserve vit dans le `NavigationStack`, donc elle s'efface
    /// avec la page dès qu'un écran de détail est poussé.
    func micaboTabBarClearance() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MicaboTabBar()
                .hidden()
        }
    }

    /// Signale au routeur si cette page a un écran poussé : le balayage est alors
    /// coupé et la barre d'onglets se retire.
    func reportsNavigationDepth(for tab: RootTab, depth: Int) -> some View {
        modifier(NavigationDepthReporter(tab: tab, depth: depth))
    }
}

private struct NavigationDepthReporter: ViewModifier {
    @Environment(TabRouter.self) private var router: TabRouter?
    let tab: RootTab
    let depth: Int

    func body(content: Content) -> some View {
        content
            .onAppear { router?.setDepth(depth, for: tab) }
            .onChange(of: depth) { _, newValue in
                router?.setDepth(newValue, for: tab)
            }
    }
}
