import SwiftUI

/// Bouton d'action principal : pilule sombre, texte blanc.
struct FeyPrimaryButtonStyle: ButtonStyle {
    var tint: Color = FeyColor.ink
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FeyFont.cardTitle)
            .foregroundStyle(FeyColor.onInk)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 17)
            .padding(.horizontal, fullWidth ? 0 : 26)
            .background(tint, in: Capsule())
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.06 : 0.14), radius: 14, x: 0, y: 7)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

/// Bouton secondaire : pilule blanche posée sur le fond gris.
struct FeySecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FeyFont.cardTitle)
            .foregroundStyle(FeyColor.ink)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, fullWidth ? 0 : 24)
            .background(FeyColor.surface, in: Capsule())
            .overlay {
                Capsule().strokeBorder(FeyColor.stroke, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

/// Petit bouton discret pour les actions annexes.
struct FeyQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FeyFont.captionEmphasis)
            .foregroundStyle(FeyColor.inkSecondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(FeyColor.surfaceMuted, in: Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

enum FeyCircleStyle {
    case light
    case dark
    /// Posé sur une couverture, quelle que soit sa clarté.
    case glass

    var foreground: Color {
        switch self {
        case .light: FeyColor.ink
        case .dark, .glass: FeyColor.onInk
        }
    }

    var background: Color {
        switch self {
        case .light: FeyColor.surface
        case .dark: FeyColor.ink
        case .glass: Color.black.opacity(0.32)
        }
    }
}

/// Pastille circulaire. Utilisée seule dans un `Menu`, ou enveloppée par `FeyCircleButton`.
struct FeyCircleIcon: View {
    let systemImage: String
    var style: FeyCircleStyle = .light
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(style.foreground)
            .frame(width: size, height: size)
            .background(style.background, in: Circle())
            .shadow(color: Color.black.opacity(style == .glass ? 0 : 0.08), radius: 10, x: 0, y: 4)
    }
}

/// Bouton circulaire, posé sur le fond ou sur une couverture.
struct FeyCircleButton: View {
    let systemImage: String
    var style: FeyCircleStyle = .light
    var size: CGFloat = 44
    var accessibilityTitle: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            FeyCircleIcon(systemImage: systemImage, style: style, size: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle ?? systemImage)
    }
}

/// Zone d'action ancrée en bas d'un écran, avec fondu vers le fond.
struct FeyBottomBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [FeyColor.canvas.opacity(0), FeyColor.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)

            content
                .padding(.horizontal, FeySpacing.screen)
                .padding(.bottom, FeySpacing.sm)
                .background(FeyColor.canvas)
        }
    }
}
