import SwiftUI

struct FeyPrimaryButtonStyle: ButtonStyle {
    var tint: Color = FeyColor.accent
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FeyFont.cardTitle)
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(tint, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
            .shadow(color: tint.opacity(configuration.isPressed ? 0.12 : 0.26), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct FeySecondaryButtonStyle: ButtonStyle {
    var tint: Color = FeyColor.accent
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FeyFont.cardTitle)
            .foregroundStyle(tint)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, fullWidth ? 0 : 20)
            .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct FeyQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FeyFont.caption)
            .foregroundStyle(FeyColor.inkSecondary)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(FeyColor.surfaceMuted, in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Bouton d'action flottant du tableau de bord.
struct FeyFloatingButton: View {
    var systemImage: String = "plus"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(
                        colors: [FeyColor.accent, FeyColor.accentDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: FeyColor.accent.opacity(0.38), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Importer un cours")
    }
}

/// Bouton pleine largeur ancré en bas d'un écran, avec dégradé de fondu.
struct FeyBottomBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [FeyColor.canvas.opacity(0), FeyColor.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)

            content
                .padding(.horizontal, FeySpacing.screen)
                .padding(.bottom, FeySpacing.xs)
                .padding(.top, 2)
                .background(FeyColor.canvas)
        }
    }
}
