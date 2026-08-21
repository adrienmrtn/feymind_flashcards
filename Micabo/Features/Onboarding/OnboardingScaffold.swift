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
struct OnboardingScaffold<Content: View, Footer: View>: View {
    var eyebrow: String?
    var title: String
    var subtitle: String?
    var titleSize: CGFloat = 30
    var contentSpacing: CGFloat = MicaboSpacing.lg
    var scrolls: Bool = true
    var surface: OnboardingSurface = .canvas
    var content: () -> Content
    var footer: () -> Footer

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        titleSize: CGFloat = 30,
        contentSpacing: CGFloat = MicaboSpacing.lg,
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
            VStack(alignment: .leading, spacing: 10) {
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
                    .tracking(-0.6)
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

/// Fait monter l'élément avec un léger flou, décalé selon sa position dans l'écran.
private struct OnboardingAppear: ViewModifier {
    let index: Int
    var stagger: Double = 0.07

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .blur(radius: isVisible ? 0 : 5)
            .onAppear {
                withAnimation(
                    .timingCurve(0.22, 0.61, 0.36, 1, duration: 0.42)
                    .delay(0.06 + Double(index) * stagger)
                ) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func onboardingAppear(index: Int, stagger: Double = 0.07) -> some View {
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

/// Invitation à tapoter, volontairement trop visible pour qu'on ne la rate pas.
///
/// C'est un vrai bouton : il ressemble au CTA principal, il doit donc marcher comme
/// lui. Le contenu de l'écran reste tapable en parallèle, les deux gestes appellent
/// la même action.
struct OnboardingTapPrompt: View {
    var text: String = "Appuie pour découvrir la suite"
    var action: () -> Void

    @Environment(\.onboardingSurface) private var surface

    @State private var isVisible = false
    @State private var isPulsing = false
    @State private var bounce = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .offset(y: bounce ? -3 : 2)

                Text(text)
                    .font(MicaboFont.hanken(15, weight: .bold))
            }
            .foregroundStyle(surface.buttonForeground)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(surface.buttonTint, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
            .scaleEffect(isPulsing ? 1.03 : 0.98)
            .opacity(isVisible ? 1 : 0)
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(0.15)) {
                isVisible = true
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.2)) {
                isPulsing = true
            }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(0.2)) {
                bounce = true
            }
        }
    }
}

/// Rangée de choix : icône, libellé, coche. Utilisée pour l'objectif et les questions fermées.
struct OnboardingChoiceRow: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(isSelected ? MicaboColor.onInk : MicaboColor.inkSecondary)
                        .frame(width: 42, height: 42)
                        .background(
                            isSelected ? MicaboColor.ink : MicaboColor.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MicaboFont.hanken(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(MicaboFont.hanken(12, weight: .regular))
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: MicaboSpacing.xs)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(isSelected ? MicaboColor.ink : MicaboColor.strokeStrong)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                    .strokeBorder(isSelected ? MicaboColor.ink : MicaboColor.stroke, lineWidth: isSelected ? 1.6 : 1)
            }
            .scaleEffect(isSelected ? 0.985 : 1)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .animation(.easeOut(duration: 0.22), value: isSelected)
    }
}
