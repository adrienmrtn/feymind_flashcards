import SwiftUI

/// Barre d'onglets dessinée par chaque page racine, pour qu'elle disparaisse
/// dès qu'un écran de détail est poussé. Le `TabView` page fournit le balayage.
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
    /// Pose la barre d'onglets sous le contenu d'une page racine, à l'intérieur
    /// du `NavigationStack` pour qu'elle disparaisse sur les écrans poussés.
    func micaboTabBar() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MicaboTabBar()
        }
    }

    /// Signale au routeur si cette page a un écran poussé, pour couper le balayage.
    func reportsPaging(for tab: RootTab, depth: Int) -> some View {
        modifier(PagingDepthReporter(tab: tab, depth: depth))
    }
}

private struct PagingDepthReporter: ViewModifier {
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
