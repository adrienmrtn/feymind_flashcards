import SwiftUI

/// Barre d'onglets dessinée une seule fois par `RootTabView`, à l'extérieur des pages :
/// elle reste immobile pendant qu'elles se remplacent. C'est le routeur qui la retire sur
/// les écrans poussés.
///
/// **Cinq icônes, sans libellé** (V3.3, lot 10) — Accueil, Leçons, Calendrier, Focus, Profil :
/// maison, livres, calendrier, minuteur, personne. L'onglet actif est plein et clair (l'encre),
/// les autres en tertiaire. Les noms restent pour VoiceOver, et pour la visionneuse en très
/// grand texte (appui long). La barre a le fond du thème et descend jusqu'au bord de l'écran,
/// sous l'indicateur d'accueil. Elle a été une pilule de verre qui flottait sur son ombre : un
/// objet de plus à regarder, derrière lequel le contenu passait en transparence.
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
        HStack(spacing: 2) {
            ForEach(RootTab.tabs) { tab in
                // VoiceOver lit le nom entier de la page (« Concentration »), sauf pour l'accueil,
                // qui s'appelle « Accueil » dans la barre.
                let spoken = tab == .today ? tab.barLabel(t: { i18n.t($0) }) : tab.label(t: { i18n.t($0) })
                let isSelected = tab == router.selection
                Button {
                    // Sans `withAnimation` : animer `selection` faisait fondre les pages, et
                    // l'onglet touché n'était lisible qu'après 280 ms.
                    router.selection = tab
                } label: {
                    Image(systemName: isSelected ? tab.selectedSystemImage : tab.systemImage)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(isSelected ? V3Color.ink : V3Color.ink3)
                        .frame(maxWidth: .infinity)
                        .frame(height: MicaboLayout.tabBarHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                .accessibilityLabel(spoken)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                // En très grande taille de texte, un appui long montre l'onglet en grand,
                // comme dans la barre du système.
                .accessibilityShowsLargeContentViewer {
                    Image(systemName: tab.selectedSystemImage)
                    Text(spoken)
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: MicaboLayout.tabBarHeight)
        .frame(maxWidth: .infinity)
        .background {
            // Le fond de la page, jusqu'au bord bas de l'écran.
            MicaboColor.canvas
                .ignoresSafeArea(edges: .bottom)
        }
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
