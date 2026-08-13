import SwiftUI

/// Mise en page commune à tous les écrans du parcours : sur-titre, titre, sous-titre,
/// contenu, puis une zone d'action ancrée en bas. Le tout arrive en cascade.
struct OnboardingScaffold<Content: View, Footer: View>: View {
    var eyebrow: String?
    var title: String
    var subtitle: String?
    var titleSize: CGFloat = 30
    var contentSpacing: CGFloat = MicaboSpacing.lg
    var scrolls: Bool = true
    var content: () -> Content
    var footer: () -> Footer

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        titleSize: CGFloat = 30,
        contentSpacing: CGFloat = MicaboSpacing.lg,
        scrolls: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.titleSize = titleSize
        self.contentSpacing = contentSpacing
        self.scrolls = scrolls
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

            MicaboBottomBar {
                footer()
                    .onboardingAppear(index: 4)
            }
        }
    }

    private func stack(inScrollView: Bool) -> some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            VStack(alignment: .leading, spacing: 10) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(MicaboFont.hanken(11, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(MicaboColor.accent)
                        .onboardingAppear(index: 0)
                }

                Text(title)
                    .font(MicaboFont.hanken(titleSize, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 1)

                if let subtitle {
                    Text(subtitle)
                        .font(MicaboFont.hanken(15, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
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
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            titleSize: titleSize,
            contentSpacing: contentSpacing,
            scrolls: scrolls,
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

/// CTA principal du parcours : plein largeur, coins 14 pt, retour haptique moyen.
struct OnboardingContinueButton: View {
    var title: String = "Continuer"
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            Haptics.medium()
            action()
        } label: {
            Text(title)
        }
        .buttonStyle(MicaboPrimaryButtonStyle(tint: isEnabled ? MicaboColor.ink : MicaboColor.strokeStrong))
        .disabled(!isEnabled)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

/// Petit texte qui remplace le bouton sur les écrans à avancement automatique.
struct OnboardingHint: View {
    let text: String

    @State private var isVisible = false

    var body: some View {
        Text(text)
            .font(MicaboFont.hanken(12, weight: .medium))
            .foregroundStyle(MicaboColor.inkTertiary)
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
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.22), value: isSelected)
    }
}
