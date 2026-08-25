import SwiftUI

/// Barre d'onglets dessinée une seule fois par `RootTabView`, à l'extérieur des pages :
/// elle reste immobile pendant qu'elles se remplacent. C'est le routeur qui la retire sur
/// les écrans poussés. Depuis que le balayage entre onglets a disparu, c'est **le seul
/// moyen de changer de page** : elle ne peut donc pas se permettre d'être discrète.
///
/// **Elle est en verre, et elle flotte.** C'était une bande pleine largeur collée au bas de
/// l'écran, avec un flou noyé sous un aplat crème à 72 % : autant dire un bandeau opaque, et
/// un bandeau opaque qui touche ce qu'une page ancre au-dessus de lui donne un bouton qu'on
/// croit coupé. La barre est maintenant une pastille posée à distance des bords, sur un flou
/// franc et un filet clair, avec sa propre ombre : on voit passer le contenu dessous, donc on
/// voit qu'elle est au-dessus, et l'air qu'elle laisse est déclaré (`MicaboLayout.tabBarGap`)
/// plutôt que deviné.
///
/// Sa hauteur est fixée par `MicaboLayout.tabBarHeight` et non mesurée sur ses libellés :
/// c'est cette hauteur que les pages réservent, et une réserve qui varie est une réserve
/// qu'on finit par manquer.
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
        .frame(height: MicaboLayout.tabBarHeight)
        .background {
            // Le verre, en trois couches et pas une : le flou du système, une teinte crème
            // très diluée pour que la barre reste dans la palette du papier, et un filet
            // clair qui lui donne son bord. Un flou seul prend la couleur de ce qui passe
            // dessous et disparaît sur un fond clair.
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(MicaboColor.canvas.opacity(0.3))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.1), radius: 18, x: 0, y: 8)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboLayout.tabBarGap)
    }
}

extension View {
    /// Signale au routeur si cette page a un écran poussé, pour retirer la barre du bas.
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
