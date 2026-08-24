import SwiftUI

/// Fond d'un écran du parcours. Le crème est la règle, mais quelques écraas basculent
/// sur l'encre ou l'indigo pour donner du rythme : deux écrans voisins ne doivent pas
/// se ressembler. Le texte reste fer à gauche et le bouton collé en bas, quel que soit
/// le fond — la variété s'arrête aux couleurs et aux compositions.
enum OnboardingSurface {
    case canvas
    case ink
    case indigo

    var background: Color {
        switch self {
        case .canvas: MicaboColor.canvas
        case .ink: MicaboColor.ink
        case .indigo: MicaboColor.accent
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
        case .indigo: MicaboColor.onInk.opacity(0.72)
        }
    }

    /// Teinte de la jauge du parcours. Une seule couleur par fond : l'indigo sur le
    /// crème, l'inverse de l'encre sur les fonds sombres — un indigo posé sur l'indigo
    /// ne se verrait pas.
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
    var surface: OnboardingSurface = .canvas
    var content: () -> Content
    var footer: () -> Footer

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        titleSize: CGFloat = 30,
        contentSpacing: CGFloat = MicaboSpacing.xl,
        scrolls: Bool = true,
        surface: OnboardingSurface = .canvas,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.titleSize = titleSize
        self.contentSpacing = contentSpacing
        self.scrolls = scrolls
        self.surface = surface
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
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(MicaboFont.hanken(11, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(surface.eyebrow)
                        .onboardingAppear(index: 0)
                }

                Text(title)
                    .font(MicaboFont.hanken(titleSize, weight: .bold))
                    .foregroundStyle(surface.title)
                    .tracking(-0.7)
                    .lineSpacing(-1)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 1)

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
                .onboardingAppear(index: 3)

            if !inScrollView {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.lg)
        .padding(.bottom, inScrollView ? MicaboSpacing.lg : 0)
        .frame(maxWidth: .infinity, maxHeight: inScrollView ? nil : .infinity, alignment: .topLeading)
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
        surface: OnboardingSurface = .canvas,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            titleSize: titleSize,
            contentSpacing: contentSpacing,
            scrolls: scrolls,
            surface: surface,
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
    var action: () -> Void

    @Environment(\.onboardingSurface) private var surface

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

/// Rangée de choix : libellé, coche, et rien de plus.
///
/// La tuile d'icône a disparu. Une icône par ligne sur six lignes fait six pastilles
/// colorées qui n'apprennent rien, et c'est précisément ce qui rendait ces écrans
/// bavards : on lisait des pictogrammes au lieu de lire les réponses.
struct OnboardingChoiceRow: View {
    let title: String
    var subtitle: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
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

/// Pastille de choix, pour les questions à réponses courtes.
///
/// Sept niveaux d'études en sept rangées font un écran qu'on fait défiler. En pastilles qui
/// s'enroulent, ils tiennent en trois lignes et se lisent d'un coup d'œil, ce qui est tout
/// ce qu'on demande à une question fermée.
struct OnboardingChoiceChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MicaboFont.hanken(15, weight: .medium))
                .foregroundStyle(isSelected ? MicaboColor.onInk : MicaboColor.ink)
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background(isSelected ? MicaboColor.ink : MicaboColor.surface, in: Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .animation(OnboardingMotion.tap, value: isSelected)
    }
}
