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

    /// Pose ce que la page ancre en bas, juste au-dessus de la barre d'onglets.
    /// À appliquer au contenu défilant d'une page racine, à l'intérieur de son
    /// `NavigationStack`.
    ///
    /// La barre est hors des pages : l'inset de la racine raccourcit le `TabView`,
    /// donc le bas géométrique d'une page **est** le haut de la barre. Il ne faut
    /// plus réserver `tabBarHeight` ici — c'est ce creux en trop qui laissait le
    /// « + », « Réviser N cartes » et « Ajouter un examen » trop hauts.
    ///
    /// Le `NavigationStack` rétablit quand même la zone sûre de la fenêtre, y
    /// compris l'indicateur d'accueil, qui vit sous la barre, hors du `TabView`.
    /// Sans l'ignorer, ce repos-doigt fantôme remonte encore les boutons. On
    /// n'étend pas sous la barre : le `TabView` s'arrête déjà au-dessus d'elle.
    ///
    /// L'accessoire décide de sa propre largeur : le bouton de session prend
    /// toute la laisse, le « + » se cale à droite.
    func tabBarClearance<Accessory: View>(@ViewBuilder accessory: () -> Accessory) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                accessory()

                Color.clear
                    .frame(height: MicaboLayout.tabBarGap)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// La même pose, pour une page qui n'ancre rien en bas : sans elle, sa
    /// dernière rangée se colle à la barre.
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
