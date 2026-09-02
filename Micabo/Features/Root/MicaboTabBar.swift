import SwiftUI

/// Barre d'onglets dessinée une seule fois par `RootTabView`, à l'extérieur des pages :
/// elle reste immobile pendant qu'elles se remplacent. C'est le routeur qui la retire sur
/// les écrans poussés. Depuis que le balayage entre onglets a disparu, c'est **le seul
/// moyen de changer de page** : elle ne peut donc pas se permettre d'être discrète.
///
/// **Elle est opaque, et elle est collée au bas.** Plus de verre, plus de pastille qui
/// flotte : c'est un `UITabBar` classique — une bande pleine largeur, un filet du dessus,
/// le fond de la page qui continue sous l'indicateur d'accueil. L'air qu'elle laisse
/// au-dessus d'elle (`MicaboLayout.tabBarGap`) sert aux boutons de page, pas à la faire
/// léviter.
///
/// Sa hauteur est fixée par `MicaboLayout.tabBarHeight` et non mesurée sur ses libellés :
/// c'est cette hauteur que les pages réservent, et une réserve qui varie est une réserve
/// qu'on finit par manquer.
struct MicaboTabBar: View {
    @Environment(TabRouter.self) private var router: TabRouter?
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        if let router {
            bar(router)
        }
    }

    private func bar(_ router: TabRouter) -> some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases) { tab in
                let label = tab.label(t: { i18n?.t($0) ?? L10n.t($0, locale: .resolved()) })
                Button {
                    // Sans `withAnimation` : animer `selection` faisait fondre les quatre
                    // pages, et l'onglet touché n'était lisible qu'après 280 ms.
                    router.selection = tab
                } label: {
                    let isSelected = tab == router.selection
                    VStack(spacing: 5) {
                        Image(systemName: isSelected ? tab.selectedSystemImage : tab.systemImage)
                            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        Text(label)
                            .font(MicaboFont.hanken(10, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isSelected ? MicaboColor.accent : MicaboColor.inkTertiary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                .accessibilityLabel(label)
                .accessibilityAddTraits(tab == router.selection ? .isSelected : [])
            }
        }
        .frame(height: MicaboLayout.tabBarHeight)
        .background(MicaboColor.canvas)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MicaboColor.stroke)
                .frame(height: 1 / 3)
        }
        .background(MicaboColor.canvas.ignoresSafeArea(edges: .bottom))
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
    /// C'est le seul endroit où cette place peut être réservée. La barre est dessinée par
    /// la racine, à l'extérieur des pages, et **un `safeAreaInset` ne franchit pas la
    /// frontière d'un `NavigationStack`** : à l'intérieur d'une page, le bas de la zone
    /// sûre est celui de la fenêtre, l'indicateur d'accueil et rien d'autre. Sans cette
    /// réserve, le « + », « Réviser N cartes » et la rangée « Amis » se posent exactement
    /// là où la barre est peinte, et passent dessous.
    ///
    /// On a cru un temps que le `TabView` avait déjà perdu la hauteur de la barre, parce
    /// que les boutons flottaient trop haut. Ce n'était pas l'inset de la racine : c'était
    /// la barre système, dont iOS réservait encore la hauteur dans chaque page. Elle est
    /// masquée onglet par onglet depuis, et ce creux fantôme a disparu — mais la barre de
    /// Micabo, elle, reste à réserver ici.
    ///
    /// L'accessoire décide de sa propre largeur : le bouton de session prend toute la
    /// laisse, le « + » se cale à droite.
    func tabBarClearance<Accessory: View>(@ViewBuilder accessory: () -> Accessory) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                accessory()

                // La barre, et l'air au-dessus d'elle. Ce creux ne prend pas les appuis :
                // il recouvre la barre, et une surface transparente qui les avale rendrait
                // les onglets inertes.
                Color.clear
                    .frame(height: MicaboLayout.tabBarSpace)
                    .allowsHitTesting(false)
            }
        }
    }

    /// La même réserve, pour une page qui n'ancre rien en bas : sans elle, sa dernière
    /// rangée passe sous la barre.
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
