import SwiftUI

/// Barre d'onglets dessinée une seule fois par `RootTabView`, à l'extérieur du
/// carrousel : elle reste immobile pendant qu'on balaye d'une page à l'autre.
/// C'est le routeur qui la retire sur les écrans poussés.
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
                    let isSelected = tab == router.selection
                    VStack(spacing: 5) {
                        Image(systemName: isSelected ? tab.selectedSystemImage : tab.systemImage)
                            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                            .contentTransition(.symbolEffect(.replace))
                        Text(tab.label)
                            .font(MicaboFont.hanken(10, weight: isSelected ? .semibold : .medium))
                    }
                    .foregroundStyle(isSelected ? MicaboColor.accent : MicaboColor.inkTertiary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(tab == router.selection ? .isSelected : [])
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(MicaboColor.canvas.opacity(0.72))
                .overlay(alignment: .top) {
                    Rectangle().fill(MicaboColor.hairlineOnCanvas).frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

extension View {
    /// Signale au routeur si cette page a un écran poussé, pour couper le balayage
    /// et retirer la barre du bas.
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
