import SwiftUI

/// Barre d'onglets dessinée une seule fois par `RootTabView`, à l'extérieur des pages :
/// elle reste immobile pendant qu'elles se remplacent. C'est le routeur qui la retire sur
/// les écrans poussés.
///
/// **La pilule flottante de Micabo** (lot 11 ; maquettes `scratchpad/lot11/navbar/`, variante A
/// retenue). « On doit quand même être un peu différent de Knowunity » : cinq icônes nues sur
/// une barre pleine largeur, c'était leur barre. La nôtre est une pilule surface à filet, posée
/// au-dessus de la barre d'accueil, détachée des bords ; **l'onglet actif s'élargit et dit son
/// nom** en Sofia Sans Condensed, sur le lavis bleu — Accueil, Leçons, Calendrier, Focus,
/// Profil. Les autres restent des icônes (zone tactile de 48 pt). Un fondu du fond, sous la
/// pilule, garde lisible ce qui défile derrière.
///
/// Sa hauteur est fixée par `MicaboLayout.tabBarHeight` et non mesurée sur ses libellés :
/// c'est cette hauteur que les pages réservent (`tabBarClearance`), et une réserve qui varie
/// est une réserve qu'on finit par manquer. Le contenu d'une page ne passe donc jamais dessous :
/// il s'arrête au-dessus, seul le défilement le fait glisser derrière le fondu.
struct MicaboTabBar: View {
    @Environment(TabRouter.self) private var router: TabRouter?
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// La pilule elle-même ; l'air sous elle complète `MicaboLayout.tabBarHeight`.
    static let pillHeight: CGFloat = 60
    /// L'air entre la pilule et le bas de la zone sûre (le bord de l'écran sur un iPhone SE).
    static let bottomAir: CGFloat = MicaboLayout.tabBarHeight - pillHeight
    /// La hauteur d'un onglet : une zone tactile au-dessus des 44 pt demandés.
    static let tabHeight: CGFloat = 48

    var body: some View {
        if let router {
            bar(router)
        }
    }

    private func bar(_ router: TabRouter) -> some View {
        HStack(spacing: 2) {
            ForEach(RootTab.tabs) { tab in
                MicaboTabButton(
                    tab: tab,
                    title: tab.barLabel(t: { i18n.t($0) }),
                    spoken: tab == .today ? tab.barLabel(t: { i18n.t($0) }) : tab.label(t: { i18n.t($0) }),
                    isSelected: tab == router.selection
                ) {
                    // Sans `withAnimation` : animer `selection` faisait fondre les pages, et
                    // l'onglet touché n'était lisible qu'après 280 ms. Seule la pilule s'anime.
                    router.selection = tab
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: Self.pillHeight)
        .background(V3Color.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(V3Color.line, lineWidth: V3Metric.border))
        .animation(MicaboMotion.resolved(MicaboMotion.quick, reduceMotion: reduceMotion), value: router.selection)
        .padding(.horizontal, 16)
        .padding(.bottom, Self.bottomAir)
        .frame(height: MicaboLayout.tabBarHeight)
        .frame(maxWidth: .infinity)
        .background {
            // Le fondu du fond, jusqu'au bord bas de l'écran : ce qui défile derrière s'efface
            // avant d'atteindre la pilule.
            LinearGradient(
                stops: [
                    .init(color: V3Color.bg.opacity(0), location: 0),
                    .init(color: V3Color.bg, location: 0.45),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Un onglet de la pilule : l'icône seule, ou — quand il est actif — l'icône pleine et son nom
/// sur le lavis bleu.
struct MicaboTabButton: View {
    let tab: RootTab
    let title: String
    let spoken: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? tab.selectedSystemImage : tab.systemImage)
                    .font(.system(size: isSelected ? 21 : 23, weight: .semibold))
                if isSelected {
                    Text(title)
                        .font(Font.custom(V3Typeface.displayName(for: .heavy), fixedSize: 19))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: true, vertical: false)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(isSelected ? V3Color.accentBright : V3Color.ink3)
            .padding(.horizontal, isSelected ? 16 : 0)
            .frame(minWidth: 44, maxWidth: isSelected ? nil : .infinity)
            .frame(height: MicaboTabBar.tabHeight)
            .background {
                if isSelected {
                    Capsule().fill(V3Color.accentWash)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .layoutPriority(isSelected ? 1 : 0)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // En très grande taille de texte, un appui long montre l'onglet en grand, comme dans
        // la barre du système.
        .accessibilityShowsLargeContentViewer {
            Image(systemName: tab.selectedSystemImage)
            Text(spoken)
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
