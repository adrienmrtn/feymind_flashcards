import SwiftUI

// MARK: - La charte du parcours

/// **Les couleurs du parcours d'accueil : celles de l'app.**
///
/// Le parcours avait sa charte (blanc pur, encre, violet électrique) ; il prend maintenant
/// les jetons de l'app (`MicaboColor`) : l'ivoire du papier, des cartes blanches, l'encre, le
/// bleu de l'accent. Du parcours à la première leçon, on reste dans le même monde. Les noms
/// restent ceux d'avant pour ne rien casser des 35 écrans qui les lisent : `white` est le
/// fond de page, `card` une carte, `accent` le bleu.
enum OnboardingPalette {
    /// Le fond des pages : l'ivoire de l'app.
    static let white = MicaboColor.canvas
    static let ink = MicaboColor.ink
    /// Une carte de réponse, un bloc : blanche, sur l'ivoire.
    static let card = MicaboColor.surface
    /// Un cran plus marqué : le bouton éteint, la piste de la jauge.
    static let cardStrong = MicaboColor.track
    /// Le bleu de l'app, seul accent.
    static let accent = MicaboColor.accent
    /// Le même bleu, dilué : un choix fait, un chiffre mis en avant.
    static let accentWash = MicaboColor.accentSoft
    /// Le gris du sous-titre et des légendes.
    static let gray = MicaboColor.inkSecondary
    static let grayLight = MicaboColor.inkTertiary
    /// Le vert et le rouge des graphes, ceux des réponses dans l'app.
    static let chartGood = MicaboColor.correct
    static let chartBad = MicaboColor.wrong
    /// **Le même vert, pour ce qui est gratuit** : « Essaie 3 jours gratuitement ».
    static let free = chartGood
    /// L'or des étoiles.
    static let star = Color(hex: 0xF5B942)

    /// Le dégradé des mots mis en avant : le bleu de l'accent vers le violet des mots-clés,
    /// celui du titre de Home.
    static let mikaGradient: [Color] = [MicaboColor.accent, MicaboColor.keyword]

    // MARK: Les tailles de texte

    /// Le titre d'un écran : la graisse des titres de l'app (`MicaboFont.display`).
    static func title(_ size: CGFloat = 34) -> Font { MicaboFont.display(size) }
    /// Une réponse : 17 points, medium.
    static let option = MicaboFont.ui(17, weight: .medium)
    /// Le sous-titre : 13 points, gris.
    static let subtitle = MicaboFont.ui(13, weight: .regular)
    /// Le bouton.
    static let button = MicaboFont.ui(17, weight: .semibold)
}

/// Fond d'un écran du parcours.
///
/// **Tout est blanc**, et le cas sombre ne subsiste que pour les composants partagés qui
/// savent s'inverser : rien dans le parcours ne l'emploie plus.
enum OnboardingSurface {
    case canvas
    case ink
    /// Conservés pour les appels existants ; tous deux se rendent en blanc.
    case accentSoft
    case sage

    var background: Color {
        switch self {
        case .ink: OnboardingPalette.ink
        default: OnboardingPalette.white
        }
    }

    var isDark: Bool {
        self == .ink
    }

    var title: Color {
        isDark ? OnboardingPalette.white : OnboardingPalette.ink
    }

    var prose: Color {
        isDark ? OnboardingPalette.white.opacity(0.7) : OnboardingPalette.gray
    }

    var eyebrow: Color {
        isDark ? OnboardingPalette.white.opacity(0.7) : OnboardingPalette.accent
    }

    /// La jauge est bleue, comme les barres de progression de l'app.
    var progressTint: Color {
        isDark ? OnboardingPalette.white : MicaboColor.accent
    }

    var progressTrack: Color {
        isDark ? OnboardingPalette.white.opacity(0.22) : OnboardingPalette.cardStrong
    }

    /// Le bouton est d'encre. Sur l'encre, il s'inverse.
    var buttonTint: Color {
        isDark ? OnboardingPalette.white : OnboardingPalette.ink
    }

    var buttonForeground: Color {
        isDark ? OnboardingPalette.ink : OnboardingPalette.white
    }

    /// Éteint, il est gris clair et garde son texte blanc : c'est le bouton de Cal AI, et il
    /// se lit comme « pas encore », pas comme « cassé ».
    var disabledButtonTint: Color {
        isDark ? OnboardingPalette.white.opacity(0.3) : MicaboColor.inkTertiary.opacity(0.45)
    }
}

/// **Le mouvement du parcours d'accueil, en un seul endroit.**
///
/// Une seule règle : **rien ne rebondit.** Un élément arrive par un fondu de deux dixièmes
/// de seconde ; une page arrive par un glissement qui se pose sans dépasser. Les ressorts,
/// les montées de quatorze points, le titre qui s'écrit mot à mot partout, la mascotte qui
/// sursaute : tout ça donnait un parcours qui tremble et qui a l'air d'un jeu.
///
/// Les noms sont gardés pour les écrans qui les appellent ; toutes les courbes sont des
/// fondus courts, et `rise` est nul.
enum OnboardingMotion {
    /// Entrée d'un élément à l'ouverture d'un écran : le ressort doux de l'app.
    static let enter = Animation.spring(duration: 0.55, bounce: 0.25)
    /// La course d'un élément qui entre : il monte de quatorze points, comme dans l'app.
    static let rise: CGFloat = 14
    /// Réaction à un appui.
    static let tap = Animation.easeOut(duration: 0.15)
    /// La réaction d'une réponse qu'on choisit : un petit ressort.
    static let select = Animation.spring(duration: 0.3, bounce: 0.35)
    /// Un élément qui change de forme sous les yeux.
    static let shift = Animation.easeInOut(duration: 0.3)
    /// Passage d'un état à l'autre **dans** un écran. Les pages, elles, glissent :
    /// voir `slide`.
    static let page = Animation.easeInOut(duration: 0.2)
    /// Décalage entre deux éléments qui entrent à la suite.
    static let stagger = 0.05
    /// Le décalage dans une liste de réponses.
    static let rowStagger = 0.035
}

private struct OnboardingSurfaceKey: EnvironmentKey {
    static let defaultValue = OnboardingSurface.canvas
}

extension EnvironmentValues {
    /// Lu par les boutons du parcours pour s'inverser sur fond sombre.
    var onboardingSurface: OnboardingSurface {
        get { self[OnboardingSurfaceKey.self] }
        set { self[OnboardingSurfaceKey.self] = newValue }
    }
}

private struct OnboardingCheerKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// **Ce qu'une réponse dit à Mika** : posé par le gabarit, appelé par les rangées, les
    /// cases et les pastilles de choix. Mika, au pied de la page, s'en réjouit.
    var onboardingCheer: () -> Void {
        get { self[OnboardingCheerKey.self] }
        set { self[OnboardingCheerKey.self] = newValue }
    }
}

/// **Mika au pied de la page**, debout à gauche du rond, à la hauteur du pouce : il fait
/// coucou en arrivant, attend, puis saute de joie à chaque réponse. Il est un peu plus grand
/// que le rond, posé sur la même ligne : il accompagne, il ne cache rien.
struct OnboardingFooterMika: View {
    var cheers: Int

    static let size: CGFloat = 78

    @State private var mood: MikaMood = .wave
    @State private var hop = false
    @State private var settle: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MikaMascot(mood: mood, size: Self.size, reactsToTap: true)
            .frame(width: Self.size, height: Self.size)
            .offset(y: hop ? -10 : 0)
            .accessibilityHidden(true)
            .onAppear { calm(after: 2.2) }
            .onChange(of: cheers) { _, _ in
                mood = .happy
                if !reduceMotion {
                    withAnimation(.spring(duration: 0.22, bounce: 0.6)) { hop = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation(.spring(duration: 0.35, bounce: 0.4)) { hop = false }
                    }
                }
                calm(after: 1.6)
            }
    }

    private func calm(after seconds: Double) {
        settle?.cancel()
        settle = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            mood = .idle
        }
    }
}

/// **L'icône 3D d'une question**, posée sur son halo : elle arrive en ressort puis flotte
/// doucement, comme les objets des écrans de Mika.
struct OnboardingHeroIcon: View {
    let icon: MicaboIcon

    /// **Soixante-seize points, pas plus** : les icônes 3D sont dessinées en 256 pixels, soit
    /// 85 points nets sur un écran Retina. Au-delà, l'image s'étire et devient floue.
    static let size: CGFloat = 76
    /// La hauteur de son cadre : l'icône et l'air de son flottement.
    static var height: CGFloat { size * 1.25 }

    private var size: CGFloat { Self.size }

    @State private var shown = false
    @State private var up = false
    @Environment(\.onboardingStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isShown = shown || still
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [MicaboColor.accent.opacity(0.2), MicaboColor.accent.opacity(0)], center: .center, startRadius: 2, endRadius: size * 0.9))
                .frame(width: size * 1.8, height: size * 1.8)
            MicaboIconView(icon: icon, size: size)
                .shadow(color: MicaboColor.accent.opacity(0.22), radius: 18, y: 10)
                .offset(y: up ? -5 : 4)
        }
        .frame(height: Self.height)
        .scaleEffect(isShown ? 1 : 0.4)
        .opacity(isShown ? 1 : 0)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.spring(duration: 0.55, bounce: 0.45).delay(0.05)) { shown = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(0.6)) { up = true }
        }
    }
}

/// Échappatoire d'un écran de question, posée en haut à droite de l'écran.
///
/// Elle n'existe que là où la réponse est réellement facultative : un écran sans issue se
/// quitte en quittant l'app, et on ne le retrouve jamais.
struct OnboardingSkip {
    var title: String?
    /// Ce que le lecteur d'écran annonce.
    var accessibilityLabel: String?
    var action: () -> Void
}

// MARK: - La page

/// Mise en page commune à tous les écrans du parcours : la place de la barre du haut,
/// titre, sous-titre, contenu, puis une zone d'action ancrée en bas.
///
/// Un écran de ce parcours tient en **un titre de deux lignes en 34 points, une ligne
/// grise au plus, et une seule chose à regarder.** C'est la forme de Cal AI, écran après
/// écran, et c'est la forme qu'on lit en deux secondes.
///
/// **La barre du haut n'est pas dedans.** Elle est posée par-dessus les pages, hors du
/// glissement (`OnboardingTopBar`) ; le gabarit ne fait que lui laisser sa place, sur les
/// écrans qui la montrent. Hors du parcours — la création d'un deck emploie le même
/// gabarit — il n'y a pas de barre, donc pas de place à laisser.
struct OnboardingScaffold<Content: View, Footer: View>: View {
    var eyebrow: String?
    var title: String
    var subtitle: String?
    var titleSize: CGFloat = 34
    var contentSpacing: CGFloat = MicaboSpacing.xl
    var scrolls: Bool = true
    /// Conservé pour les appels existants : le titre ne s'écrit plus mot à mot.
    var animatesTitle: Bool = false
    /// Donne au contenu toute la hauteur restante au lieu de le tasser sous le titre.
    var expandsContent: Bool = false
    var surface: OnboardingSurface = .canvas
    /// Interdit jusqu'au défilement de secours, pour les écrans qui portent un geste.
    var locksScrolling: Bool = false
    var skip: OnboardingSkip?
    /// Le titre se centre sur les écrans qui n'ont qu'une phrase et une image.
    var centered: Bool = false
    var content: () -> Content
    var footer: () -> Footer

    @Environment(OnboardingModel.self) private var model: OnboardingModel?
    @Environment(\.onboardingStep) private var step: OnboardingStep?

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        titleSize: CGFloat = 34,
        contentSpacing: CGFloat = MicaboSpacing.xl,
        scrolls: Bool = true,
        animatesTitle: Bool = false,
        expandsContent: Bool = false,
        surface: OnboardingSurface = .canvas,
        locksScrolling: Bool = false,
        skip: OnboardingSkip? = nil,
        centered: Bool = false,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.titleSize = titleSize
        self.contentSpacing = contentSpacing
        self.scrolls = scrolls
        self.animatesTitle = animatesTitle
        self.expandsContent = expandsContent
        self.surface = surface
        self.locksScrolling = locksScrolling
        self.skip = skip
        self.centered = centered
        self.content = content
        self.footer = footer
    }

    /// Mika au pied de la page, à côté du rond : sur les écrans de questions, ni centrés ni
    /// sombres. Il fait coucou en arrivant, et se réjouit à chaque réponse.
    private var showsMika: Bool {
        // Dans le parcours seulement : la création d'un deck emploie le même gabarit.
        model != nil && !centered && !surface.isDark && titleSize >= 26
    }

    /// **Dans le parcours, tout est centré**, comme les écrans de Mika : l'icône 3D, le
    /// titre, puis les réponses. La création d'un deck garde sa mise en page.
    private var isCentered: Bool { centered || model != nil }

    /// L'icône de la page, dans le parcours.
    private var heroIcon: MicaboIcon? {
        guard model != nil else { return nil }
        return (step ?? model?.step)?.heroIcon
    }

    /// Le nombre de réponses données sur cette page.
    @State private var cheers = 0

    /// Les sous-titres ne s'affichent plus dans le parcours ; la création d'un deck, qui
    /// emploie le même gabarit, garde les siens.
    private var showsSubtitle: Bool { model == nil }

    /// La place de la barre du haut : seulement dans le parcours, et sur les écrans qui la
    /// montrent. L'étape est celle de la page, pas celle du modèle : pendant un glissement,
    /// la page qui part garde la sienne.
    private var chromeInset: Bool {
        (step ?? model?.step)?.showsChrome ?? false
    }

    /// La hauteur visible de la page, entre la barre du haut et le pied.
    @State private var viewport: CGFloat = 0
    /// **La plus grande hauteur vue** : le clavier rétrécit la page, il ne doit pas faire
    /// disparaître l'icône au moment où il monte.
    @State private var roomiest: CGFloat = 0
    /// La hauteur naturelle de la composition, telle qu'elle est dessinée.
    @State private var natural: CGFloat = 0

    /// La place que prend l'icône 3D au-dessus du titre : son cadre, son air, l'espacement.
    private static var heroBlock: CGFloat { OnboardingHeroIcon.height + 6 + 10 }

    /// **L'icône ne se montre que si tout tient avec elle.** Sur un petit écran, ou sous un
    /// titre de trois lignes en allemand, elle s'efface d'elle-même : c'est elle qui cède la
    /// place, jamais le bouton ni une réponse. La hauteur sans l'icône se déduit de celle
    /// mesurée, avec ou sans elle : la décision ne bascule pas d'un rendu à l'autre.
    private var showsHero: Bool {
        guard heroIcon != nil, roomiest > 0, natural > 0 else { return false }
        let bare = natural - (heroShown ? Self.heroBlock : 0)
        return bare + Self.heroBlock <= roomiest
    }

    @State private var heroShown = false

    /// **Trente et un points au plus dans le parcours** : à trente-quatre, une question en
    /// allemand ou en turc prenait trois lignes et poussait les réponses sous le pied.
    private var shownTitleSize: CGFloat { model != nil ? min(titleSize, 31) : titleSize }

    /// Hors du parcours, un écran sans défilement donne au contenu toute la hauteur (la
    /// création d'un deck, comme avant).
    private var stretchesContent: Bool { expandsContent && model == nil && !scrolls }

    /// Dans le parcours, un écran à roue ou à scène garde sa hauteur naturelle et se centre
    /// dans la page ; les listes, elles, partent du haut.
    private var centersVertically: Bool { expandsContent && model != nil }

    var body: some View {
        page
            // **Le pied est épinglé en bas, quoi qu'il arrive.** Il était posé sous la page
            // dans une pile : une page trop haute le poussait sous le bord de l'écran. Ici la
            // page défile dessous, et sa dernière ligne remonte entièrement au-dessus de lui.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MicaboBottomBar(background: surface.background) {
                    footer()
                        .onboardingAppear(index: 4)
                }
                // Le fond du pied descend jusqu'au bord de l'écran : sans ça, ce qui défile
                // se voyait sous l'indicateur d'accueil, en dessous du bouton.
                .background {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 28)
                        surface.background
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .environment(\.onboardingCheer, { cheers += 1 })
            .onboardingChromeInset(chromeInset)
            // Le pied monte au-dessus du clavier sur les écrans qui en prennent un — le prénom,
            // la recherche d'un pays, le courriel du compte — et reste où il est quand la page
            // part. Hors du parcours, le modificateur ne fait rien : le système s'en charge.
            .onboardingKeyboardLift()
            // **Le fond monte jusqu'au bord de l'écran, en haut aussi.** Arrêté à la zone sûre, il
            // laissait la barre d'état à la page du dessous pendant un glissement : le voile posé
            // sur celle-ci y restait visible — un petit rectangle gris en haut à gauche, à chaque
            // transition — jusqu'à ce que la page arrivée l'ait recouvert.
            .background(surface.background.ignoresSafeArea())
            .environment(\.onboardingSurface, surface)
            .onChange(of: showsHero) { _, shows in
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) { heroShown = shows }
            }
    }

    /// **Une seule mise en page, qui défile toujours si elle ne tient pas.** La composition
    /// prend au moins toute la hauteur visible : les écrans à roue ou à scène s'y centrent,
    /// les listes partent du haut ; et quand elle dépasse, elle défile au lieu de déborder.
    private var page: some View {
        ScrollView {
            VStack(spacing: 0) {
                if centersVertically {
                    Spacer(minLength: 0)
                }

                composition
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        natural = height
                    }

                if !stretchesContent {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: viewport > 0 ? viewport : nil, alignment: .top)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDisabled(locksScrolling && natural <= viewport + 1)
        .onGeometryChange(for: CGFloat.self) { proxy in
            max(0, proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom)
        } action: { height in
            viewport = height
            roomiest = max(roomiest, height)
        }
    }

    /// L'icône, le titre, le contenu : à leur hauteur naturelle dans le parcours.
    @ViewBuilder
    private var composition: some View {
        if stretchesContent {
            stack.frame(maxHeight: .infinity, alignment: .top)
        } else {
            stack.fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stack: some View {
        VStack(alignment: isCentered ? .center : .leading, spacing: contentSpacing) {
            VStack(alignment: isCentered ? .center : .leading, spacing: 10) {
                if eyebrow != nil || skip != nil {
                    HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.sm) {
                        if let eyebrow {
                            Text(eyebrow.uppercased())
                                .font(MicaboFont.ui(11, weight: .semibold))
                                .tracking(1.6)
                                .foregroundStyle(surface.eyebrow)
                        }

                        Spacer(minLength: 0)

                        if let skip {
                            skipButton(skip)
                        }
                    }
                    .onboardingAppear(index: 0)
                }

                if let heroIcon, heroShown {
                    OnboardingHeroIcon(icon: heroIcon)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 6)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }

                // Le titre passe par le texte à chiffre coloré : un passage entre deux
                // astérisques doubles se peint du dégradé de l'app, ici comme sur Home.
                OnboardingAccentText(
                    template: title,
                    size: shownTitleSize,
                    alignment: isCentered ? .center : .leading,
                    color: surface.title
                )
                .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
                .onboardingAppear(index: 1)

                // Plus de sous-titre sous les questions : le titre suffit, et la ligne grise
                // se lisait comme du remplissage.
                if let subtitle, showsSubtitle {
                    Text(subtitle)
                        .font(OnboardingPalette.subtitle)
                        .foregroundStyle(surface.prose)
                        .lineSpacing(3)
                        .multilineTextAlignment(isCentered ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingAppear(index: 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)

            content()
                .frame(maxHeight: stretchesContent ? CGFloat.infinity : nil)
                .onboardingAppear(index: 3)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.md)
        .padding(.bottom, MicaboSpacing.lg)
        .frame(maxWidth: .infinity, alignment: isCentered ? .top : .topLeading)
    }

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Volontairement discret : c'est une sortie, pas une proposition.
    private func skipButton(_ skip: OnboardingSkip) -> some View {
        let title = skip.title ?? i18n.t("common.skip")
        return Button(action: skip.action) {
            Text(title)
                .font(MicaboFont.ui(13.5, weight: .semibold))
                .foregroundStyle(surface.isDark ? OnboardingPalette.white.opacity(0.72) : OnboardingPalette.gray)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(
                    surface.isDark ? OnboardingPalette.white.opacity(0.12) : OnboardingPalette.card,
                    in: Capsule()
                )
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .accessibilityLabel(skip.accessibilityLabel ?? title)
    }
}

extension OnboardingScaffold where Footer == EmptyView {
    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        titleSize: CGFloat = 34,
        contentSpacing: CGFloat = MicaboSpacing.lg,
        scrolls: Bool = true,
        animatesTitle: Bool = false,
        expandsContent: Bool = false,
        surface: OnboardingSurface = .canvas,
        locksScrolling: Bool = false,
        skip: OnboardingSkip? = nil,
        centered: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            titleSize: titleSize,
            contentSpacing: contentSpacing,
            scrolls: scrolls,
            animatesTitle: animatesTitle,
            expandsContent: expandsContent,
            surface: surface,
            locksScrolling: locksScrolling,
            skip: skip,
            centered: centered,
            content: content,
            footer: { EmptyView() }
        )
    }
}

// MARK: - Une page composée à la main

/// **Une page composée à la main, centrée dans la hauteur visible, qui défile si elle ne
/// tient pas.** Les écrans de Mika, du rappel, des fondateurs : leur composition se pose au
/// milieu de la page sur un grand téléphone, et défile sur un petit au lieu de pousser le
/// bouton sous le bord de l'écran.
struct OnboardingCenteredScroll<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var viewport: CGFloat = 0
    @Environment(\.onboardingStill) private var still

    var body: some View {
        // Le rendu figé (les rendus de la CI) n'a pas de défilement : `ImageRenderer` ne
        // dessine pas l'intérieur d'une ScrollView, et l'écran sortait vide.
        if still {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            scrolling
        }
    }

    private var scrolling: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: viewport > 0 ? viewport : nil)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self) { proxy in
            max(0, proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom)
        } action: { height in
            viewport = height
        }
    }
}

// MARK: - Entrée en fondu

/// Fait apparaître l'élément, décalé selon sa position dans l'écran. Un fondu, et rien
/// d'autre : ni montée, ni échelle.
private struct OnboardingAppear: ViewModifier {
    let index: Int
    var stagger: Double = OnboardingMotion.stagger

    @State private var isVisible = false
    @Environment(\.onboardingStill) private var still

    func body(content: Content) -> some View {
        content
            .opacity(isVisible || still ? 1 : 0)
            .offset(y: isVisible || still ? 0 : OnboardingMotion.rise)
            .onAppear {
                withAnimation(OnboardingMotion.enter.delay(Double(index) * stagger)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func onboardingAppear(index: Int, stagger: Double = OnboardingMotion.stagger) -> some View {
        modifier(OnboardingAppear(index: index, stagger: stagger))
    }
}

// MARK: - Bouton à libellé

/// **Le bouton à libellé du parcours : une pilule d'encre de cinquante-six points, pleine
/// largeur**, texte blanc, et un gris clair tant qu'aucune réponse n'est donnée.
///
/// Il ne sert qu'aux boutons qui **disent** quelque chose — « Commencer », « Oui »,
/// « Commencer l'essai » — et aux écrans partagés avec le reste de l'app. Partout où le
/// bouton ne fait qu'avancer, c'est le rond fléché (`OnboardingArrowButton`).
struct OnboardingContinueButton: View {
    var title: String?
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var loadingTitle: String?
    /// Conservé pour les appels existants. Sans effet.
    var isShiny: Bool = false
    var action: () -> Void

    @Environment(\.onboardingSurface) private var surface
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            action()
        } label: {
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(surface.buttonForeground)
                }

                Text(isLoading ? (loadingTitle ?? i18n.t("ios.instant")) : (title ?? i18n.t("common.continue")))
                    .font(MicaboFont.ui(18, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(surface.buttonForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isEnabled ? surface.buttonTint : surface.disabledButtonTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .medium))
        .disabled(!isEnabled || isLoading)
        .animation(OnboardingMotion.select, value: isEnabled)
        .animation(OnboardingMotion.select, value: isLoading)
    }
}

// MARK: - Les réponses

/// Rangée de choix : **une carte blanche de l'app, un emoji, un libellé ; bleue quand elle
/// est choisie**, avec sa coche.
struct OnboardingChoiceRow: View {
    let title: String
    var emoji: String?
    var subtitle: String?
    var isSelected: Bool
    var fillsHeight: Bool = false
    /// Le rang de la rangée dans sa liste, quand elle doit entrer en cascade.
    var rank: Int?
    var action: () -> Void

    /// Soixante points de haut au minimum : une réponse doit se viser au pouce.
    private static let minHeight: CGFloat = 60

    @Environment(\.onboardingCheer) private var cheer

    var body: some View {
        Button {
            action()
            cheer()
        } label: {
            HStack(spacing: 14) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 22))
                        .frame(width: 42, height: 42)
                        .background(isSelected ? MicaboColor.surface : MicaboColor.surfaceSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MicaboFont.ui(17, weight: .bold))
                        .foregroundStyle(isSelected ? MicaboColor.accent : OnboardingPalette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(MicaboFont.ui(13, weight: .medium))
                            .foregroundStyle(OnboardingPalette.gray)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: MicaboSpacing.xs)

                OnboardingCheck(isOn: isSelected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(
                maxWidth: .infinity,
                minHeight: Self.minHeight,
                maxHeight: fillsHeight ? CGFloat.infinity : nil,
                alignment: .leading
            )
            .onboardingCard(selected: isSelected, radius: 18)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .animation(OnboardingMotion.select, value: isSelected)
        .modifier(OnboardingRowAppear(rank: rank))
    }
}

/// Liste de réponses qui occupe toute la hauteur qu'on lui laisse.
struct OnboardingAnswerList<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let spacing: CGFloat
    private let row: (Int, Item) -> Content

    init(_ items: [Item], spacing: CGFloat = 10, @ViewBuilder row: @escaping (Int, Item) -> Content) {
        self.items = items
        self.spacing = spacing
        self.row = row
    }

    var body: some View {
        // Chaque réponse à sa hauteur : étirées pour remplir la page, six réponses
        // poussaient le bouton sous le bord de l'écran dès que le titre prenait trois lignes.
        VStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { rank, item in
                row(rank, item)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Deux cases côte à côte, pour une question fermée à deux réponses.
struct OnboardingChoiceTile: View {
    let title: String
    var systemImage: String?
    var emoji: String?
    var subtitle: String?
    var isSelected: Bool
    var action: () -> Void

    @Environment(\.onboardingCheer) private var cheer

    var body: some View {
        Button {
            action()
            cheer()
        } label: {
            VStack(spacing: 10) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 30))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(isSelected ? MicaboColor.accent : OnboardingPalette.gray)
                }

                Text(title)
                    .font(MicaboFont.ui(17, weight: .bold))
                    .foregroundStyle(isSelected ? MicaboColor.accent : OnboardingPalette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(OnboardingPalette.subtitle)
                        .foregroundStyle(OnboardingPalette.gray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, MicaboSpacing.lg)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 132)
            .onboardingCard(selected: isSelected, radius: 20)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .animation(OnboardingMotion.select, value: isSelected)
    }
}

/// Pastille de choix, pour les questions à réponses courtes.
struct OnboardingChoiceChip: View {
    let title: String
    var emoji: String?
    let isSelected: Bool
    var action: () -> Void

    @Environment(\.onboardingCheer) private var cheer

    var body: some View {
        Button {
            action()
            cheer()
        } label: {
            HStack(spacing: 7) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 17))
                }

                Text(title)
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(isSelected ? MicaboColor.accent : OnboardingPalette.ink)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(isSelected ? MicaboColor.accentSoft : MicaboColor.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? MicaboColor.accent : MicaboColor.stroke, lineWidth: isSelected ? 2 : 1.5))
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .animation(OnboardingMotion.select, value: isSelected)
    }
}

/// L'entrée en cascade d'une rangée de réponse, ou rien quand elle n'a pas de rang.
private struct OnboardingRowAppear: ViewModifier {
    let rank: Int?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let rank {
            content.onboardingAppear(index: 3 + rank, stagger: OnboardingMotion.rowStagger)
        } else {
            content
        }
    }
}

// MARK: - Une question à une seule réponse

/// **Le gabarit de toutes les questions fermées du quiz** : un titre, des cartes grises,
/// le rond qui s'allume à la première réponse. Les rangées se partagent la page.
struct OnboardingSingleChoiceStep<Item: Identifiable & Hashable>: View {
    let title: String
    var subtitle: String?
    let items: [Item]
    let selection: Item?
    let label: (Item) -> String
    var emoji: (Item) -> String? = { _ in nil }
    let onSelect: (Item) -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: title,
            subtitle: subtitle,
            scrolls: true
        ) {
            OnboardingAnswerList(items) { rank, item in
                OnboardingChoiceRow(
                    title: label(item),
                    emoji: emoji(item),
                    isSelected: selection == item,
                    rank: rank
                ) {
                    onSelect(item)
                }
            }
        } footer: {
            OnboardingArrowButton(isEnabled: selection != nil, action: onContinue)
        }
    }
}

// MARK: - Une question à plusieurs réponses

/// **Le gabarit des questions ouvertes à plusieurs réponses** : les mêmes rangées, qui se
/// cochent et se décochent, et le rond qui s'allume dès la première.
struct OnboardingMultiChoiceStep<Item: Identifiable & Hashable>: View {
    let title: String
    var subtitle: String?
    let items: [Item]
    let selection: Set<Item>
    let label: (Item) -> String
    var emoji: (Item) -> String? = { _ in nil }
    let onToggle: (Item) -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            title: title,
            subtitle: subtitle,
            scrolls: true
        ) {
            OnboardingAnswerList(items) { rank, item in
                OnboardingChoiceRow(
                    title: label(item),
                    emoji: emoji(item),
                    isSelected: selection.contains(item),
                    rank: rank
                ) {
                    onToggle(item)
                }
            }
        } footer: {
            OnboardingArrowButton(isEnabled: !selection.isEmpty, action: onContinue)
        }
    }
}

// MARK: - Les étoiles

/// Cinq étoiles, or.
struct OnboardingStars: View {
    var size: CGFloat = 14
    var spacing: CGFloat = 4

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<5, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(OnboardingPalette.star)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(i18n.t("ios.starsA11y"))
    }
}

// MARK: - Les cartes du parcours, comme celles de l'app

/// La coche ronde d'une réponse : vide, puis pleine de bleu quand on la choisit.
struct OnboardingCheck: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isOn ? MicaboColor.accent : MicaboColor.stroke, lineWidth: 2)
                .background(Circle().fill(isOn ? MicaboColor.accent : .clear))
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(MicaboColor.onInk)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 24, height: 24)
        .animation(.spring(duration: 0.3, bounce: 0.4), value: isOn)
    }
}

private struct OnboardingCardStyle: ViewModifier {
    let selected: Bool
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(selected ? MicaboColor.accentSoft : MicaboColor.surface, in: shape)
            .overlay(shape.strokeBorder(selected ? MicaboColor.accent : MicaboColor.stroke, lineWidth: selected ? 2 : 1.5))
            .background(shape.fill(selected ? MicaboColor.accent.opacity(0.35) : MicaboColor.stroke).offset(y: 3))
            .contentShape(shape)
    }
}

extension View {
    /// Une réponse du parcours : une carte blanche bordée, à relief, bleue quand elle est
    /// choisie. La même que les réponses des quiz de l'app.
    func onboardingCard(selected: Bool, radius: CGFloat = 18) -> some View {
        modifier(OnboardingCardStyle(selected: selected, radius: radius))
    }
}
