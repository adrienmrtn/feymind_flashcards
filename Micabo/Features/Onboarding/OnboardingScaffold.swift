import SwiftUI

/// Fond d'un écran du parcours. Le crème est la règle, mais deux écrans basculent sur
/// l'encre ou sur l'accent pour donner du rythme : deux écrans voisins ne doivent pas se
/// ressembler. Le texte reste fer à gauche et le bouton collé en bas, quel que soit le
/// fond : la variété s'arrête aux couleurs et aux compositions.
enum OnboardingSurface {
    case canvas
    case ink
    /// Le vert de Micabo en pleine page. Il s'appelait `indigo` quand l'accent l'était.
    case accent

    var background: Color {
        switch self {
        case .canvas: MicaboColor.canvas
        case .ink: MicaboColor.ink
        case .accent: MicaboColor.accent
        }
    }

    var isDark: Bool {
        self != .canvas
    }

    var title: Color {
        isDark ? MicaboColor.onInk : MicaboColor.ink
    }

    var prose: Color {
        isDark ? MicaboColor.onInk.opacity(0.78) : MicaboColor.inkSecondary
    }

    var eyebrow: Color {
        switch self {
        case .canvas: MicaboColor.accent
        case .ink: MicaboColor.accentSoft
        case .accent: MicaboColor.onInk.opacity(0.72)
        }
    }

    /// Teinte de la jauge du parcours. Une seule couleur par fond : le vert sur le crème,
    /// l'inverse de l'encre sur les fonds sombres, puisqu'un vert posé sur le vert ne se
    /// verrait pas.
    var progressTint: Color {
        isDark ? MicaboColor.onInk : MicaboColor.progress
    }

    var progressTrack: Color {
        isDark ? MicaboColor.onInk.opacity(0.22) : MicaboColor.progressTrack
    }

    /// Surface du bouton d'action, inversée sur fond sombre.
    var buttonTint: Color {
        isDark ? MicaboColor.onInk : MicaboColor.ink
    }

    var buttonForeground: Color {
        isDark ? MicaboColor.ink : MicaboColor.onInk
    }

    var disabledButtonTint: Color {
        isDark ? MicaboColor.onInk.opacity(0.3) : MicaboColor.strokeStrong
    }
}

/// **Le mouvement du parcours d'accueil, en un seul endroit.**
///
/// Une seule règle, et elle explique toutes les courbes ci-dessous : **rien ne rebondit.**
/// Un ressort dépasse sa cible puis revient, et vingt écrans qui dépassent leur cible
/// donnent un parcours qui tremble. Les quatre courbes sont donc monotones : elles partent
/// vite, elles ralentissent, elles s'arrêtent net.
///
/// L'exception est déclarée ailleurs et volontairement unique : le bouton `isShiny` de la
/// démonstration respire et se laisse balayer d'un reflet. C'est le seul écran où l'on a
/// regardé une animation sans rien toucher, donc le seul où il faut aller chercher un doigt
/// immobile.
///
/// Les avoir ici plutôt que dans chaque écran n'est pas une coquetterie : c'est ce qui fait
/// qu'un écran ne peut pas se mettre à bouger autrement que ses voisins.
enum OnboardingMotion {
    /// Entrée d'un élément à l'ouverture d'un écran.
    static let enter = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.42)
    /// Réaction à un appui : elle doit être finie avant qu'on ait relevé le doigt.
    static let tap = Animation.timingCurve(0.3, 0, 0.2, 1, duration: 0.2)
    /// Un élément qui se déplace ou change de forme sous les yeux.
    static let shift = Animation.timingCurve(0.25, 0.8, 0.25, 1, duration: 0.48)
    /// Passage d'un écran au suivant.
    static let page = Animation.timingCurve(0.32, 0.72, 0.2, 1, duration: 0.36)
    /// Décalage entre deux éléments qui entrent à la suite.
    static let stagger = 0.075
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
/// Elle n'existe que là où la réponse est réellement facultative. Demander son
/// établissement à quelqu'un qui n'en a pas, qui est entre deux écoles, ou qui n'a pas envie
/// de le dire, ne doit pas fermer le parcours : un écran sans issue se quitte en quittant
/// l'app, et on ne le retrouve jamais.
struct OnboardingSkip {
    var title: String = "Passer"
    var action: () -> Void
}

/// Mise en page commune à tous les écrans du parcours : sur-titre, titre, sous-titre,
/// contenu, puis une zone d'action ancrée en bas. Le tout arrive en cascade.
///
/// Un écran de ce parcours tient en **un titre court, une ligne de sous-titre au plus, et
/// une seule chose à regarder.** Ce n'est pas une préférence esthétique : un écran
/// d'inscription se lit en deux secondes ou ne se lit pas, et un paragraphe posé dans un
/// bloc blanc à coins arrondis est exactement ce à quoi ressemble un texte que personne n'a
/// relu.
struct OnboardingScaffold<Content: View, Footer: View>: View {
    var eyebrow: String?
    var title: String
    var subtitle: String?
    var titleSize: CGFloat = 30
    var contentSpacing: CGFloat = MicaboSpacing.xl
    var scrolls: Bool = true
    /// Le titre s'écrit mot à mot au lieu d'apparaître d'un bloc.
    ///
    /// Réservé aux **questions** : un titre qui s'écrit sous les yeux donne le rythme d'une
    /// conversation, et l'animation dure exactement le temps qu'il faut pour la lire. On ne
    /// l'utilise pas sur un écran de démonstration, où le regard doit aller au contenu, ni
    /// sur un écran qu'on traverse en deux secondes.
    var animatesTitle: Bool = false
    /// Donne au contenu toute la hauteur restante au lieu de le tasser sous le titre.
    ///
    /// Sur un écran de question, les réponses *sont* le contenu : les serrer en haut de la
    /// page laisse un grand vide en dessous et les fait passer pour une note. Elles
    /// occupent alors la page, et le regard tombe dessus au lieu de les chercher.
    var expandsContent: Bool = false
    var surface: OnboardingSurface = .canvas
    var skip: OnboardingSkip?
    var content: () -> Content
    var footer: () -> Footer

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        titleSize: CGFloat = 30,
        contentSpacing: CGFloat = MicaboSpacing.xl,
        scrolls: Bool = true,
        animatesTitle: Bool = false,
        expandsContent: Bool = false,
        surface: OnboardingSurface = .canvas,
        skip: OnboardingSkip? = nil,
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
        self.skip = skip
        self.content = content
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: 0) {
            if scrolls {
                ScrollView {
                    stack(inScrollView: true)
                }
                .scrollIndicators(.hidden)
            } else {
                stack(inScrollView: false)
            }

            MicaboBottomBar(background: surface.background) {
                footer()
                    .onboardingAppear(index: 4)
            }
        }
        .background(surface.background.ignoresSafeArea(edges: .bottom))
        .environment(\.onboardingSurface, surface)
    }

    private func stack(inScrollView: Bool) -> some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            VStack(alignment: .leading, spacing: 9) {
                // Le sur-titre et l'échappatoire partagent la même ligne : « Passer » se
                // pose ainsi en haut à droite de l'écran sans ajouter une rangée vide
                // au-dessus du titre.
                if eyebrow != nil || skip != nil {
                    HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.sm) {
                        if let eyebrow {
                            Text(eyebrow.uppercased())
                                .font(MicaboFont.hanken(11, weight: .semibold))
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

                if animatesTitle {
                    OnboardingWordByWordTitle(text: title, size: titleSize)
                } else {
                    Text(title)
                        .font(MicaboFont.hanken(titleSize, weight: .bold))
                        .foregroundStyle(surface.title)
                        .tracking(-0.7)
                        .lineSpacing(-1)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingAppear(index: 1)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(MicaboFont.hanken(15, weight: .regular))
                        .foregroundStyle(surface.prose)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingAppear(index: 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content()
                .frame(maxHeight: expandsContent && !inScrollView ? CGFloat.infinity : nil)
                .onboardingAppear(index: 3)

            if !inScrollView, !expandsContent {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.lg)
        .padding(.bottom, inScrollView ? MicaboSpacing.lg : 0)
        .frame(maxWidth: .infinity, maxHeight: inScrollView ? nil : .infinity, alignment: .topLeading)
    }

    /// Volontairement discret : c'est une sortie, pas une proposition. Un « Passer » aussi
    /// visible que le bouton du bas ferait douter de l'intérêt de la question.
    private func skipButton(_ skip: OnboardingSkip) -> some View {
        Button {
            Haptics.light()
            skip.action()
        } label: {
            HStack(spacing: 3) {
                Text(skip.title)
                    .font(MicaboFont.hanken(13.5, weight: .semibold))

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(surface.isDark ? MicaboColor.onInk.opacity(0.72) : MicaboColor.inkSecondary)
            .padding(.vertical, 7)
            .padding(.horizontal, 11)
            .background(
                surface.isDark ? MicaboColor.onInk.opacity(0.12) : MicaboColor.surfaceMuted,
                in: Capsule()
            )
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .accessibilityLabel("\(skip.title) cette question")
    }
}

extension OnboardingScaffold where Footer == EmptyView {
    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        titleSize: CGFloat = 30,
        contentSpacing: CGFloat = MicaboSpacing.lg,
        scrolls: Bool = true,
        animatesTitle: Bool = false,
        expandsContent: Bool = false,
        surface: OnboardingSurface = .canvas,
        skip: OnboardingSkip? = nil,
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
            skip: skip,
            content: content,
            footer: { EmptyView() }
        )
    }
}

// MARK: - Entrée en cascade

/// Fait monter l'élément d'un rien, décalé selon sa position dans l'écran.
///
/// Le flou de mise au point qu'il y avait ici est parti : c'est un effet qui coûte une
/// passe de rendu à chaque image, qui rend le texte illisible pendant sa propre apparition,
/// et qui est devenu la signature des interfaces produites à la chaîne. Huit points de
/// montée et un fondu suffisent à faire arriver un élément.
private struct OnboardingAppear: ViewModifier {
    let index: Int
    var stagger: Double = OnboardingMotion.stagger

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 8)
            .onAppear {
                withAnimation(OnboardingMotion.enter.delay(0.04 + Double(index) * stagger)) {
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

// MARK: - Titre qui s'écrit mot par mot

/// Titre dont le **gras se pose mot par mot**, de gauche à droite, comme si on le
/// soulignait en le lisant.
///
/// Chaque mot est composé deux fois au même endroit — une fois maigre, une fois gras — et
/// occupe toujours la largeur de sa version grasse. C'est ce qui permet au gras d'arriver
/// sans que la ligne se recompose : un titre qui se réaligne à chaque mot se lit comme un
/// bug, pas comme une animation.
///
/// Les retours à la ligne écrits dans le titre sont respectés, et chaque ligne peut
/// elle-même se replier si l'écran est trop étroit.
struct OnboardingWordByWordTitle: View {
    let text: String
    var size: CGFloat = 32
    /// Temps entre deux mots.
    var wordDelay: Double = 0.16
    /// Temps mort avant le premier mot, le temps que l'écran arrive.
    var startDelay: Double = 0.3
    /// Appelé une fois le dernier mot en gras.
    var onFinish: () -> Void = {}

    @Environment(\.onboardingSurface) private var surface

    @State private var boldCount = 0
    @State private var didStart = false

    private var lines: [[String]] {
        text.components(separatedBy: "\n").map { line in
            line.split(separator: " ").map(String.init)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lineOffsets.enumerated()), id: \.offset) { lineIndex, offset in
                MicaboFlowLayout(spacing: size * 0.26, lineSpacing: 2, alignment: .leading) {
                    ForEach(Array(lines[lineIndex].enumerated()), id: \.offset) { wordIndex, word in
                        self.word(word, isBold: offset + wordIndex < boldCount)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement()
        .accessibilityLabel(text.replacingOccurrences(of: "\n", with: " "))
        .onAppear(perform: run)
    }

    /// Index du premier mot de chaque ligne, pour que le gras avance d'une ligne à
    /// l'autre sans repartir de zéro.
    private var lineOffsets: [Int] {
        var offsets: [Int] = []
        var total = 0
        for line in lines {
            offsets.append(total)
            total += line.count
        }
        return offsets
    }

    private var wordCount: Int {
        lines.reduce(0) { $0 + $1.count }
    }

    /// Le gabarit gras, invisible, réserve la place ; les deux vraies versions se
    /// croisent par-dessus, calées à gauche.
    private func word(_ word: String, isBold: Bool) -> some View {
        Text(word)
            .font(MicaboFont.hanken(size, weight: .bold))
            .tracking(-0.7)
            .opacity(0)
            .overlay(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Text(word)
                        .font(MicaboFont.hanken(size, weight: .regular))
                        .foregroundStyle(surface.title.opacity(0.3))
                        .opacity(isBold ? 0 : 1)

                    Text(word)
                        .font(MicaboFont.hanken(size, weight: .bold))
                        .foregroundStyle(surface.title)
                        .opacity(isBold ? 1 : 0)
                }
                .tracking(-0.7)
                .fixedSize()
            }
            .animation(.easeOut(duration: 0.22), value: isBold)
    }

    private func run() {
        guard !didStart else { return }
        didStart = true

        for index in 0..<wordCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + Double(index) * wordDelay) {
                boldCount = index + 1
                Haptics.tick()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + Double(wordCount) * wordDelay) {
            onFinish()
        }
    }
}

// MARK: - Bouton d'avancement

/// CTA principal du parcours : pleine largeur, retour haptique moyen, et un état
/// de chargement pour les actions qui ne rendent pas la main tout de suite.
///
/// Quand `isLoading` est vrai, le bouton annonce ce qu'il fait et refuse les appuis :
/// c'est ce qui évite les doubles taps quand une opération tourne derrière.
struct OnboardingContinueButton: View {
    var title: String = "Continuer"
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var loadingTitle: String = "Un instant…"
    /// Reflet qui balaie le bouton, et respiration qui le fait rebondir sur place.
    ///
    /// Réservé au bouton qui clôt une animation qu'on vient de regarder sans rien faire :
    /// après dix secondes de démonstration, la main est immobile, et il faut lui dire
    /// franchement où appuyer. Le reste du parcours n'y a pas droit — un bouton qui brille
    /// à chaque écran ne brille plus nulle part.
    var isShiny: Bool = false
    var action: () -> Void

    @Environment(\.onboardingSurface) private var surface

    @State private var shinePhase: CGFloat = 0
    @State private var isBouncing = false

    private var isLively: Bool { isShiny && isEnabled && !isLoading }

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 9) {
                if isLoading {
                    // L'indicateur prend la couleur du texte du bouton, pas celle de la
                    // progression : posé sur un aplat, il doit d'abord rester lisible.
                    ProgressView()
                        .controlSize(.small)
                        .tint(surface.buttonForeground)
                }

                Text(isLoading ? loadingTitle : title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(
            MicaboPrimaryButtonStyle(
                tint: isEnabled ? surface.buttonTint : surface.disabledButtonTint,
                foreground: surface.buttonForeground
            )
        )
        .disabled(!isEnabled || isLoading)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
        .animation(.easeOut(duration: 0.2), value: isLoading)
        // Le reflet et la respiration se posent au-dessus des animations d'état, et pas
        // dedans : le bouton s'active à l'instant où il se met à respirer, et une courbe
        // d'activation qui s'appliquerait à la respiration lui mangerait sa répétition.
        .overlay { if isLively { shine } }
        .scaleEffect(isBouncing ? 1.028 : 1)
        .onAppear(perform: startLiveliness)
        .onChange(of: isLively) { _, _ in startLiveliness() }
    }

    /// Bande claire inclinée qui traverse le bouton, découpée à sa forme pour qu'elle
    /// n'aille pas baver sur le fond de l'écran.
    private var shine: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let band = max(60, width * 0.34)

            LinearGradient(
                colors: [
                    surface.buttonForeground.opacity(0),
                    surface.buttonForeground.opacity(0.4),
                    surface.buttonForeground.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            // Deux fois la hauteur du bouton, remontée de moitié : une bande inclinée
            // qui ferait juste la hauteur laisserait deux coins non balayés.
            .frame(width: band, height: proxy.size.height * 2)
            .rotationEffect(.degrees(16))
            .offset(x: shinePhase * (width + band * 2) - band, y: -proxy.size.height / 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        .allowsHitTesting(false)
    }

    private func startLiveliness() {
        guard isLively else {
            withAnimation(.easeOut(duration: 0.2)) { isBouncing = false }
            return
        }

        shinePhase = 0
        withAnimation(.linear(duration: 1.7).repeatForever(autoreverses: false)) {
            shinePhase = 1
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.4).repeatForever(autoreverses: true)) {
            isBouncing = true
        }
    }
}

/// Petit texte qui remplace le bouton sur les écrans à avancement automatique.
struct OnboardingHint: View {
    let text: String

    @Environment(\.onboardingSurface) private var surface

    @State private var isVisible = false

    var body: some View {
        Text(text)
            .font(MicaboFont.hanken(12, weight: .medium))
            .foregroundStyle(surface.isDark ? MicaboColor.onInk.opacity(0.6) : MicaboColor.inkTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                    isVisible = true
                }
            }
    }
}

/// Rangée de choix : un emoji, un libellé, une coche.
///
/// Les tuiles pastel qui vivaient ici ont été retirées, et à juste titre : six pastilles
/// colorées à gauche de six lignes faisaient lire des pictogrammes au lieu des réponses.
/// **Un emoji n'est pas une tuile.** Posé à même la ligne, sans fond ni cadre, il donne à
/// chaque réponse un point d'accroche que l'œil retrouve sans lire, et une liste de réponses
/// scolaires cesse de ressembler à un formulaire administratif.
///
/// `fillsHeight` fait grandir la rangée avec la place qu'on lui laisse. C'est ce qui
/// permet à une liste de réponses d'occuper la page entière plutôt que de se tasser sous
/// le titre : le rembourrage vertical fixe est un plancher, pas un plafond.
struct OnboardingChoiceRow: View {
    let title: String
    var emoji: String?
    var subtitle: String?
    var isSelected: Bool
    var fillsHeight: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MicaboFont.hanken(16, weight: .medium))
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.leading)

                    if let subtitle {
                        Text(subtitle)
                            .font(MicaboFont.hanken(12.5, weight: .regular))
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: MicaboSpacing.xs)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(isSelected ? MicaboColor.ink : MicaboColor.strokeStrong)
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: fillsHeight ? CGFloat.infinity : nil, alignment: .leading)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                    .strokeBorder(isSelected ? MicaboColor.ink : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .animation(OnboardingMotion.tap, value: isSelected)
    }
}

/// Liste de réponses qui occupe toute la hauteur qu'on lui laisse.
///
/// Les rangées se partagent la place à égalité : aucune réponse n'est plus grande qu'une
/// autre, et la question ne se lit pas comme un formulaire posé en haut d'une page vide.
struct OnboardingAnswerList<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let spacing: CGFloat
    private let row: (Item) -> Content

    init(_ items: [Item], spacing: CGFloat = 10, @ViewBuilder row: @escaping (Item) -> Content) {
        self.items = items
        self.spacing = spacing
        self.row = row
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(items) { item in
                row(item)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Une question fermée à deux réponses n'a pas besoin d'une liste. Deux cases côte à côte
/// se comparent d'un seul regard, là où deux rangées empilées se lisent l'une après
/// l'autre et laissent croire que la première compte plus que la seconde.
struct OnboardingChoiceTile: View {
    let title: String
    var systemImage: String?
    var emoji: String?
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
                        .foregroundStyle(isSelected ? MicaboColor.ink : MicaboColor.inkTertiary)
                }

                Text(title)
                    .font(MicaboFont.hanken(16, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, MicaboSpacing.lg)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                    .strokeBorder(isSelected ? MicaboColor.ink : MicaboColor.stroke, lineWidth: isSelected ? 1.8 : 1)
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .animation(OnboardingMotion.tap, value: isSelected)
    }
}

/// Pastille de choix, pour les questions à réponses courtes.
///
/// Dix pays en dix rangées font un écran qu'on fait défiler. En pastilles qui s'enroulent,
/// ils tiennent en quelques lignes et se lisent d'un coup d'œil. L'emoji tient sur la même
/// ligne que le libellé : un drapeau se reconnaît plus vite que le nom du pays.
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
                    .font(MicaboFont.hanken(15, weight: .medium))
                    .foregroundStyle(isSelected ? MicaboColor.onInk : MicaboColor.ink)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(isSelected ? MicaboColor.ink : MicaboColor.surface, in: Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .animation(OnboardingMotion.tap, value: isSelected)
    }
}
