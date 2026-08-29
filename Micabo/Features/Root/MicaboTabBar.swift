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
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
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
        // Sur un téléphone à bouton, la zone sûre du bas est nulle : sans ces quatre points,
        // la pastille vient buter contre le bord de l'écran, ce qui est tout le contraire de
        // flotter. L'ombre, elle, va plus loin que ça et se fait couper : c'est ce qu'on
        // veut, quatre points de plus se paieraient sur la hauteur réservée aux pages.
        .padding(.bottom, MicaboSpacing.xxs)
    }
}

extension View {
    /// Signale au routeur si cette page a un écran poussé, pour retirer la barre du bas.
    func reportsNavigationDepth(for tab: RootTab, depth: Int) -> some View {
        modifier(NavigationDepthReporter(tab: tab, depth: depth))
    }

    /// Vide la pile de cette page quand quelqu'un demande à revenir à l'accueil.
    ///
    /// À appliquer sur la racine de chaque onglet, à côté de `reportsNavigationDepth`. Sans
    /// elle, `TabRouter.goHome()` changerait d'onglet en laissant les piles ouvertes
    /// derrière lui.
    func returnsHome(path: Binding<NavigationPath>) -> some View {
        modifier(HomeReturnListener(path: path))
    }

    /// **Réserve la place de la barre d'onglets, et pose au-dessus d'elle ce que la page
    /// ancre en bas.** À appliquer au contenu défilant d'une page racine, à l'intérieur de
    /// son `NavigationStack`.
    ///
    /// Ce n'est pas une commodité, c'est le seul endroit où cette place peut être réservée.
    /// La barre est dessinée par la racine, à l'extérieur des pages, par un `safeAreaInset` —
    /// et **un `safeAreaInset` ne franchit pas la frontière d'un `NavigationStack`**, qui
    /// rétablit sa zone sûre depuis la fenêtre. L'inset de la racine ne réservait donc rien
    /// du tout à l'intérieur des pages : le « + » de Cours et le bouton de session de
    /// Réviser se posaient au bas de leur zone sûre, c'est-à-dire exactement là où la barre
    /// est peinte, et passaient dessous. Le premier appui de l'app était à moitié cliquable.
    ///
    /// On a longtemps cru que passer de l'`overlay` au `safeAreaInset` côté racine réglait
    /// la question. Les deux tombent au même endroit, et c'est pour cette raison que le
    /// symptôme n'avait pas bougé : ce qui manquait n'était pas le bon modificateur, c'était
    /// la réservation, **de l'autre côté de la frontière**.
    ///
    /// L'accessoire décide de sa propre largeur : le bouton de session prend toute la
    /// laisse, le « + » se cale à droite.
    func tabBarClearance<Accessory: View>(@ViewBuilder accessory: () -> Accessory) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                accessory()

                // La hauteur de la barre, en creux. Elle ne prend pas les appuis : elle
                // recouvre la barre, et une surface transparente qui les avale rendrait les
                // onglets inertes.
                Color.clear
                    .frame(height: MicaboLayout.tabBarSpace)
                    .allowsHitTesting(false)
            }
        }
    }

    /// La même réserve, pour une page qui n'ancre rien en bas : sans elle, sa dernière
    /// rangée se lit à travers le verre de la barre.
    func tabBarClearance() -> some View {
        tabBarClearance { EmptyView() }
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

private struct HomeReturnListener: ViewModifier {
    @Environment(TabRouter.self) private var router: TabRouter?
    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        content
            .onChange(of: router?.homeRequests ?? 0) { _, _ in
                guard !path.isEmpty else { return }
                path = NavigationPath()
            }
    }
}
