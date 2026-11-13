import SwiftUI

// **Le gabarit de la création d'un deck** (`Features/Deck`), et les quelques jetons que
// d'autres écrans lisent encore (`OnboardingPalette` pour le paywall, `OnboardingSurface`
// pour le menu de langue).
//
// Ces briques étaient celles du parcours d'accueil d'avant. Le parcours V3 ne s'en sert
// plus : il est composé avec le système visuel V3 (`OnboardingKit`). Elles restent ici,
// réduites à ce que la création d'un deck emploie, tant que ces écrans-là ne sont pas refaits.

// MARK: - Les jetons

/// Les couleurs et les tailles de la création d'un deck : celles de l'app (`MicaboColor`).
enum OnboardingPalette {
    /// Le fond des pages.
    static let white = MicaboColor.canvas
    static let ink = MicaboColor.ink
    /// Une carte de réponse, un bloc.
    static let card = MicaboColor.surface
    /// Un cran plus marqué : le bouton éteint, la piste de la jauge.
    static let cardStrong = MicaboColor.track
    /// Le bleu de l'app, seul accent.
    static let accent = MicaboColor.accent
    static let accentWash = MicaboColor.accentSoft
    /// Le gris du sous-titre et des légendes.
    static let gray = MicaboColor.inkSecondary
    static let grayLight = MicaboColor.inkTertiary

    /// Le dégradé des mots mis en avant : le dégradé de marque.
    static let mikaGradient: [Color] = MicaboColor.brandGradient

    /// Le titre d'un écran.
    static func title(_ size: CGFloat = 34) -> Font { MicaboFont.display(size) }
    /// Une réponse.
    static let option = MicaboFont.ui(17, weight: .medium)
    /// Le sous-titre.
    static let subtitle = MicaboFont.ui(13, weight: .regular)
    /// Le bouton.
    static let button = MicaboFont.ui(17, weight: .semibold)
}

/// Le fond d'un écran. Tout est clair ; le cas sombre ne sert qu'aux composants qui savent
/// s'inverser (le menu de langue posé sur un fond plein).
enum OnboardingSurface {
    case canvas
    case ink

    var background: Color {
        self == .ink ? OnboardingPalette.ink : OnboardingPalette.white
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

    var buttonTint: Color {
        isDark ? OnboardingPalette.white : MicaboColor.accent
    }

    var buttonForeground: Color {
        isDark ? OnboardingPalette.ink : MicaboColor.onInk
    }

    var disabledButtonTint: Color {
        isDark ? OnboardingPalette.white.opacity(0.3) : MicaboColor.inkTertiary.opacity(0.45)
    }
}

/// Le mouvement : celui de l'app (`MicaboMotion`). Rien ne rebondit.
enum OnboardingMotion {
    /// Entrée d'un élément à l'ouverture d'un écran.
    static let enter = MicaboMotion.standard
    /// La course d'un élément qui entre.
    static let rise: CGFloat = 14
    /// Réaction à un appui.
    static let tap = MicaboMotion.quick
    /// La réaction d'une réponse qu'on choisit.
    static let select = MicaboMotion.quick
    /// Un élément qui change de forme sous les yeux.
    static let shift = MicaboMotion.standard
    /// Passage d'un état à l'autre dans un écran.
    static let page = MicaboMotion.quick
    /// Décalage entre deux éléments qui entrent à la suite.
    static let stagger = 0.05
    /// Le décalage dans une liste de réponses.
    static let rowStagger = 0.035
    /// **La poussée d'une page du parcours d'accueil** : la courbe standard de l'app, en
    /// trente-cinq centièmes (`OnboardingModel.move`, `OnboardingPush`).
    static let slide = MicaboMotion.standard
    static let slideDuration = 0.35
}

extension AnyTransition {
    /// **Un fondu, pour ce qui change à l'intérieur d'un écran** : les étapes d'un deck qui se
    /// crée.
    static var onboardingFade: AnyTransition {
        .opacity
    }
}

private struct OnboardingSurfaceKey: EnvironmentKey {
    static let defaultValue = OnboardingSurface.canvas
}

extension EnvironmentValues {
    /// Lu par les boutons de la création d'un deck et par le menu de langue, pour s'inverser
    /// sur un fond plein.
    var onboardingSurface: OnboardingSurface {
        get { self[OnboardingSurfaceKey.self] }
        set { self[OnboardingSurfaceKey.self] = newValue }
    }
}

// MARK: - La page

/// La mise en page d'un écran de la création d'un deck : un titre, une ligne grise au plus,
/// le contenu, puis une zone d'action ancrée en bas.
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
    var centered: Bool = false
    var content: () -> Content
    var footer: () -> Footer

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
        self.centered = centered
        self.content = content
        self.footer = footer
    }

    /// La hauteur visible de la page, au-dessus du pied.
    @State private var viewport: CGFloat = 0
    /// La hauteur naturelle de la composition.
    @State private var natural: CGFloat = 0

    /// Un écran sans défilement donne au contenu toute la hauteur.
    private var stretchesContent: Bool { expandsContent && !scrolls }

    var body: some View {
        scrollingPage
            // Le pied est épinglé en bas : la page défile dessous, et sa dernière ligne
            // remonte entièrement au-dessus de lui.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MicaboBottomBar(background: surface.background) {
                    footer()
                        .onboardingAppear(index: 4)
                }
                .background {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 28)
                        surface.background
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .background(surface.background.ignoresSafeArea())
            .environment(\.onboardingSurface, surface)
    }

    private var scrollingPage: some View {
        ScrollView {
            VStack(spacing: 0) {
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
        }
    }

    @ViewBuilder
    private var composition: some View {
        if stretchesContent {
            stack.frame(maxHeight: .infinity, alignment: .top)
        } else {
            stack.fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stack: some View {
        VStack(alignment: centered ? .center : .leading, spacing: contentSpacing) {
            VStack(alignment: centered ? .center : .leading, spacing: 10) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(MicaboFont.ui(11, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(surface.eyebrow)
                        .onboardingAppear(index: 0)
                }

                // Un passage entre deux astérisques doubles se peint du dégradé de l'app.
                OnboardingAccentText(
                    template: title,
                    size: titleSize,
                    alignment: centered ? .center : .leading,
                    color: surface.title
                )
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
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
                .frame(maxHeight: stretchesContent ? CGFloat.infinity : nil)
                .onboardingAppear(index: 3)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.md)
        .padding(.bottom, MicaboSpacing.lg)
        .frame(maxWidth: .infinity, alignment: centered ? .top : .topLeading)
    }
}

// MARK: - Entrée

/// **Un élément de la page, posé tout de suite** (lot 11). C'était une cascade : chaque élément
/// attendait `index × stagger` avant d'apparaître, ce que la direction artistique V3.3
/// interdit (rien n'attend). La page arrive maintenant d'un bloc, avec la transition de
/// l'écran ; les paramètres restent pour les appelants, et ne changent plus rien.
private struct OnboardingAppear: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func onboardingAppear(index: Int, stagger: Double = OnboardingMotion.stagger, rises: Bool = true) -> some View {
        modifier(OnboardingAppear())
    }
}

// MARK: - Le texte à passage coloré

/// Une phrase d'encre, avec un passage au dégradé de l'app, marqué entre deux astérisques
/// doubles dans la chaîne traduite.
struct OnboardingAccentText: View {
    let template: String
    var size: CGFloat = 34
    var alignment: TextAlignment = .center
    var color: Color = OnboardingPalette.ink

    var body: some View {
        composed
            .font(OnboardingPalette.title(size))
            .tracking(-0.6)
            .lineSpacing(-1)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var composed: Text {
        var result = Text("")
        for (index, part) in template.components(separatedBy: "**").enumerated() {
            if index % 2 == 1 {
                result = result + Text(part).foregroundStyle(
                    LinearGradient(colors: OnboardingPalette.mikaGradient, startPoint: .leading, endPoint: .trailing)
                )
            } else {
                result = result + Text(part).foregroundStyle(color)
            }
        }
        return result
    }
}

// MARK: - Les boutons

/// Le bouton à libellé : une pilule pleine largeur, et un gris clair tant qu'aucune réponse
/// n'est donnée.
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
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(surface.buttonForeground)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(isEnabled ? surface.buttonTint : surface.disabledButtonTint, in: RoundedRectangle(cornerRadius: MicaboButtonMetrics.radius, style: .continuous))
            .shadow(color: surface.buttonTint.opacity(isEnabled && !surface.isDark ? 0.22 : 0), radius: 10, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: MicaboButtonMetrics.radius, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .medium))
        .disabled(!isEnabled || isLoading)
        .animation(OnboardingMotion.select, value: isEnabled)
        .animation(OnboardingMotion.select, value: isLoading)
    }
}

/// Le rond fléché de la création d'un deck.
struct OnboardingArrowButton: View {
    var isEnabled: Bool = true
    var isLoading: Bool = false
    /// Le rond se pousse tout seul à droite de sa ligne. À faux, il ne prend que sa place.
    var fillsWidth: Bool = true
    var action: () -> Void

    @Environment(\.onboardingSurface) private var surface
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    static let size: CGFloat = 64

    var body: some View {
        if fillsWidth {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                button
            }
        } else {
            button
        }
    }

    private var button: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(surface.buttonForeground)
                } else {
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 23, weight: .bold))
                }
            }
            .foregroundStyle(surface.buttonForeground)
            .frame(width: Self.size, height: Self.size)
            .background(isEnabled ? surface.buttonTint : surface.disabledButtonTint, in: Circle())
            .shadow(color: surface.buttonTint.opacity(isEnabled && !surface.isDark ? 0.24 : 0), radius: 12, y: 6)
            .contentShape(Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .medium))
        .disabled(!isEnabled || isLoading)
        .animation(OnboardingMotion.select, value: isEnabled)
        .animation(OnboardingMotion.select, value: isLoading)
        .accessibilityLabel(i18n.t("common.continue"))
    }
}

// MARK: - Les réponses

/// Rangée de choix : une carte, un emoji, un libellé ; bleue quand elle est choisie.
struct OnboardingChoiceRow: View {
    let title: String
    var emoji: String?
    var subtitle: String?
    var isSelected: Bool
    var fillsHeight: Bool = false
    /// Le rang de la rangée dans sa liste, quand elle doit entrer à la suite des autres.
    var rank: Int?
    var action: () -> Void

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

/// Liste de réponses.
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
            }
        }
        .frame(maxWidth: .infinity)
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

/// L'entrée d'une rangée de réponse à la suite des autres, ou rien quand elle n'a pas de rang.
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
        .animation(MicaboMotion.quick, value: isOn)
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
    /// Une réponse : une carte bordée, à relief, bleue quand elle est choisie.
    func onboardingCard(selected: Bool, radius: CGFloat = 18) -> some View {
        modifier(OnboardingCardStyle(selected: selected, radius: radius))
    }
}

// MARK: - Le curseur d'une note

/// **La note en très grand, et un curseur dessous** : la note visée d'un deck. On glisse le
/// pouce, la note change cran par cran avec un petit coup.
struct GradeWheel: View {
    let choices: [GradeTick]
    @Binding var score: Int?
    /// Le cran de départ, quand rien n'a encore été choisi. Le milieu, sauf avis contraire.
    var fallbackIndex: Int?
    let label: String
    var valueSize: CGFloat = 96
    /// Un mot sous la valeur, quand elle en appelle un.
    var caption: String?

    @GestureState private var isDragging = false

    private var start: Int {
        Swift.min(Swift.max(0, fallbackIndex ?? (choices.count - 1) / 2), Swift.max(0, choices.count - 1))
    }

    private var index: Int {
        guard let score, let found = choices.firstIndex(where: { $0.score == score }) else { return start }
        return found
    }

    private var current: GradeTick? {
        choices.indices.contains(index) ? choices[index] : nil
    }

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 4) {
                Text(current?.label ?? "")
                    .font(MicaboFont.ui(valueSize, weight: .bold))
                    .foregroundStyle(OnboardingPalette.ink)
                    .tracking(-valueSize * 0.04)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: valueSize * 1.15)
                    .contentTransition(.numericText())
                    .animation(OnboardingMotion.select, value: index)

                if let caption {
                    Text(caption)
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.gray)
                        .contentTransition(.opacity)
                        .animation(OnboardingMotion.select, value: caption)
                }
            }

            slider

            HStack {
                Text(choices.first?.label ?? "")
                Spacer(minLength: 0)
                Text(choices.last?.label ?? "")
            }
            .font(MicaboFont.ui(13, weight: .semibold))
            .foregroundStyle(OnboardingPalette.gray)
            .monospacedDigit()
        }
        .padding(.top, MicaboSpacing.md)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(current?.label ?? "")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(to: index + 1)
            case .decrement: move(to: index - 1)
            @unknown default: break
            }
        }
        .onAppear {
            // La réponse existe dès l'affichage : une note affichée sans être enregistrée
            // ferait refuser le bouton sans dire pourquoi.
            if score == nil, let tick = current { score = tick.score }
        }
    }

    private static let knob: CGFloat = 32
    private static let track: CGFloat = 10

    /// Une piste, la part parcourue, un bouton rond. Le doigt peut se poser n'importe où sur
    /// la piste : on ne vise pas le bouton, on vise la note.
    private var slider: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let steps = Swift.max(1, choices.count - 1)
            let usable = width - Self.knob
            let x = Self.knob / 2 + usable * CGFloat(index) / CGFloat(steps)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MicaboColor.track)
                    .frame(height: Self.track)

                Capsule()
                    .fill(LinearGradient(colors: OnboardingPalette.mikaGradient, startPoint: .leading, endPoint: .trailing))
                    .frame(width: x, height: Self.track)

                // Les crans, en points sur la piste.
                ForEach(Array(choices.indices), id: \.self) { tick in
                    Circle()
                        .fill(tick <= index ? OnboardingPalette.white.opacity(0.5) : OnboardingPalette.cardStrong)
                        .frame(width: 4, height: 4)
                        .position(x: Self.knob / 2 + usable * CGFloat(tick) / CGFloat(steps), y: Self.knob / 2)
                }

                Circle()
                    .fill(MicaboColor.surface)
                    .frame(width: Self.knob, height: Self.knob)
                    .overlay(Circle().strokeBorder(MicaboColor.accent, lineWidth: 4))
                    .shadow(color: MicaboColor.accent.opacity(0.3), radius: 8, y: 4)
                    .scaleEffect(isDragging ? 1.12 : 1)
                    .position(x: x, y: Self.knob / 2)
            }
            .frame(height: Self.knob)
            .contentShape(Rectangle())
            .animation(OnboardingMotion.select, value: index)
            .animation(OnboardingMotion.select, value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in
                        let fraction = (value.location.x - Self.knob / 2) / Swift.max(1, usable)
                        let target = Int((fraction * CGFloat(steps)).rounded())
                        move(to: target)
                    }
            )
        }
        .frame(height: Self.knob)
        .padding(.horizontal, 2)
    }

    private func move(to target: Int) {
        let clamped = Swift.min(Swift.max(0, target), Swift.max(0, choices.count - 1))
        guard clamped != index else { return }
        score = choices[clamped].score
        Haptics.selection()
    }
}

// MARK: - Ce qu'on regarde pendant qu'un cours se construit

/// **Mika travaille** : lui, ce qu'il fait, le pourcentage, une grille de points qui se
/// remplit, et l'étape en cours. C'est le parent qui donne l'avancement, mesuré sur un vrai
/// travail (un cours qui se construit).
struct MikaLoadingView: View {
    /// Entre 0 et 1.
    var progress: Double
    var title: String
    var subtitle: String
    /// L'étape en cours, sous la grille.
    var stepLabel: String
    var isDone: Bool = false

    private static let rows = 4
    private static let columns = 28

    private var percent: Int {
        Int((min(1, max(0, progress)) * 100).rounded())
    }

    /// Les colonnes de points que l'avancement a remplies.
    private var filledColumns: Int {
        Int((min(1, max(0, progress)) * Double(Self.columns)).rounded(.down))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            MikaMascot(mood: isDone ? .happy : .think, size: 160)
                .accessibilityHidden(true)
                .padding(.bottom, 26)

            Text(title)
                .font(MicaboFont.display(32))
                .tracking(-0.8)
                .foregroundStyle(OnboardingPalette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            MikaGradientText(text: subtitle, size: 24, weight: .bold)
                .padding(.top, 10)
                .padding(.horizontal, MicaboSpacing.xl)

            Spacer(minLength: MicaboSpacing.lg)
                .frame(maxHeight: MicaboSpacing.xxl)

            percentLabel

            dots
                .padding(.top, 18)
                .padding(.horizontal, MicaboSpacing.screen)

            Text(stepLabel)
                .font(MicaboFont.ui(14, weight: .medium))
                .foregroundStyle(OnboardingPalette.gray)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(MicaboMotion.quick, value: stepLabel)
                .padding(.top, 16)
                .frame(minHeight: 40, alignment: .top)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingPalette.white.ignoresSafeArea())
        // Le travail se sent : un coup doux à chaque colonne qui s'allume, un coup plus net à
        // chaque étape franchie.
        .onChange(of: filledColumns) { previous, next in
            guard next > previous else { return }
            Haptics.soft()
        }
        .onChange(of: stepLabel) { _, _ in
            Haptics.light()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(stepLabel)")
        .accessibilityValue(Text(L10n.percent(percent, locale: .resolved())))
    }

    /// Le chiffre a une largeur fixe, celle de « 100 % », et s'y aligne à droite : il ne se
    /// recentre pas à chaque chiffre gagné.
    private var percentLabel: some View {
        ZStack(alignment: .trailing) {
            Text(L10n.percent(100, locale: .resolved()))
                .hidden()

            if isDone {
                Text(L10n.percent(100, locale: .resolved()))
            } else {
                Text(L10n.percent(percent, locale: .resolved()))
                    .contentTransition(.numericText(value: Double(percent)))
                    .animation(MicaboMotion.quick, value: percent)
            }
        }
        .font(MicaboFont.ui(40, weight: .bold))
        .tracking(-1.2)
        .foregroundStyle(OnboardingPalette.ink)
        .monospacedDigit()
        .fixedSize()
        .transaction { transaction in
            if isDone { transaction.animation = nil }
        }
    }

    /// Quatre rangées de points. Ceux que l'avancement a dépassés sont en couleur, le reste
    /// attend en gris.
    private var dots: some View {
        let filled = filledColumns

        return VStack(spacing: 5) {
            ForEach(0..<Self.rows, id: \.self) { _ in
                HStack(spacing: 0) {
                    ForEach(0..<Self.columns, id: \.self) { column in
                        Circle()
                            .fill(Self.color(column: column, filled: filled))
                            .frame(width: 4, height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .animation(MicaboMotion.quick, value: filled)
        .transaction { transaction in
            if isDone { transaction.animation = nil }
        }
        .accessibilityHidden(true)
    }

    private static func color(column: Int, filled: Int) -> Color {
        if column < filled - 2 { return OnboardingPalette.mikaGradient[0] }
        if column < filled { return OnboardingPalette.mikaGradient[1] }
        return OnboardingPalette.cardStrong
    }
}
