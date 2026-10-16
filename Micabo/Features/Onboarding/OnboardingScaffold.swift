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

    /// Le dégradé des mots mis en avant : le bleu de l'accent, le violet des mots-clés.
    static let mikaGradient: [Color] = [MicaboColor.accent, MicaboColor.keyword, Color(hex: 0xD946A6)]

    // MARK: Les tailles de texte

    /// Le titre d'un écran : 34 points, gras.
    static func title(_ size: CGFloat = 34) -> Font { MicaboFont.ui(size, weight: .bold) }
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
    /// Entrée d'un élément à l'ouverture d'un écran : un fondu de 200 ms.
    static let enter = Animation.easeOut(duration: 0.2)
    /// La course d'un élément qui entre. Nulle : on ne glisse pas.
    static let rise: CGFloat = 0
    /// Réaction à un appui.
    static let tap = Animation.easeOut(duration: 0.15)
    /// La réaction d'une réponse qu'on choisit.
    static let select = Animation.easeOut(duration: 0.2)
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

    /// Mika à côté du titre : sur les écrans de questions, ni centrés ni sombres.
    private var showsMika: Bool {
        !centered && !surface.isDark && titleSize >= 26
    }

    /// La place de la barre du haut : seulement dans le parcours, et sur les écrans qui la
    /// montrent. L'étape est celle de la page, pas celle du modèle : pendant un glissement,
    /// la page qui part garde la sienne.
    private var chromeInset: Bool {
        (step ?? model?.step)?.showsChrome ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            if scrolls {
                ScrollView {
                    stack(inScrollView: true)
                }
                .scrollIndicators(.hidden)
            } else if expandsContent || locksScrolling {
                stack(inScrollView: false)
            } else {
                fittedStack
            }

            MicaboBottomBar(background: surface.background) {
                footer()
                    .onboardingAppear(index: 4)
            }
        }
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
    }

    /// Une composition figée **qui défile quand même si elle ne tient pas.**
    private var fittedStack: some View {
        GeometryReader { proxy in
            ScrollView {
                stack(inScrollView: false, minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func stack(inScrollView: Bool, minHeight: CGFloat? = nil) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: contentSpacing) {
            VStack(alignment: centered ? .center : .leading, spacing: 10) {
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

                // Le titre passe par le texte à chiffre coloré : un passage entre deux
                // astérisques doubles se peint en couleur, ici comme sur les preuves. Mika
                // l'accompagne sur les écrans de questions, comme dans l'app.
                HStack(alignment: .top, spacing: 10) {
                    OnboardingAccentText(
                        template: title,
                        size: titleSize,
                        alignment: centered ? .center : .leading,
                        color: surface.title
                    )
                    if showsMika {
                        Spacer(minLength: 0)
                        MikaMascot(mood: .idle, size: 64, reactsToTap: true)
                            .padding(.top, -6)
                            .accessibilityHidden(true)
                    }
                }
                .onboardingAppear(index: 1)

                if let subtitle {
                    Text(subtitle)
                        .font(OnboardingPalette.subtitle)
                        .foregroundStyle(surface.prose)
                        .lineSpacing(3)
                        .multilineTextAlignment(centered ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingAppear(index: 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)

            content()
                .frame(maxHeight: expandsContent && !inScrollView ? CGFloat.infinity : nil)
                .onboardingAppear(index: 3)

            if !inScrollView, !expandsContent {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.md)
        .padding(.bottom, inScrollView ? MicaboSpacing.lg : 0)
        .frame(
            maxWidth: .infinity,
            minHeight: minHeight,
            maxHeight: (inScrollView || minHeight != nil) ? nil : .infinity,
            alignment: centered ? .top : .topLeading
        )
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

// MARK: - Entrée en fondu

/// Fait apparaître l'élément, décalé selon sa position dans l'écran. Un fondu, et rien
/// d'autre : ni montée, ni échelle.
private struct OnboardingAppear: ViewModifier {
    let index: Int
    var stagger: Double = OnboardingMotion.stagger

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
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

/// Rangée de choix : **une carte grise, un emoji, un libellé ; noire avec le texte blanc
/// quand elle est choisie.** Pas de coche, pas de filet : la couleur dit tout.
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

    var body: some View {
        Button(action: action) {
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
        VStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { rank, item in
                row(rank, item)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    var body: some View {
        Button(action: action) {
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

    var body: some View {
        Button(action: action) {
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
            scrolls: items.count > 6,
            expandsContent: items.count <= 6
        ) {
            OnboardingAnswerList(items) { rank, item in
                OnboardingChoiceRow(
                    title: label(item),
                    emoji: emoji(item),
                    isSelected: selection == item,
                    fillsHeight: items.count <= 6,
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
            scrolls: items.count > 6,
            expandsContent: items.count <= 6
        ) {
            OnboardingAnswerList(items) { rank, item in
                OnboardingChoiceRow(
                    title: label(item),
                    emoji: emoji(item),
                    isSelected: selection.contains(item),
                    fillsHeight: items.count <= 6,
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
