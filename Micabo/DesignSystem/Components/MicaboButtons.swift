import SwiftUI

/// Bouton d'action principal : bloc d'encre à coins 16 pt, qui s'enfonce à l'appui.
struct MicaboPrimaryButtonStyle: ButtonStyle {
    var tint: Color = MicaboColor.ink
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MicaboFont.cardTitle)
            .foregroundStyle(MicaboColor.onInk)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, fullWidth ? 0 : 24)
            .background(tint, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Bouton secondaire : surface blanche sans bordure, le fond ivoire suffit à la détacher.
struct MicaboSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MicaboFont.cardTitle)
            .foregroundStyle(MicaboColor.ink)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, fullWidth ? 0 : 24)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Petit bouton discret pour les actions annexes.
struct MicaboQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MicaboFont.captionEmphasis)
            .foregroundStyle(MicaboColor.inkSecondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

enum MicaboCircleStyle: Equatable {
    case light
    case dark
    /// Posé sur une couverture, quelle que soit sa clarté.
    case glass
    /// Posé sur un panneau pastel : verre blanc, icône dans la teinte du cours.
    case tinted(Color)

    var foreground: Color {
        switch self {
        case .light: MicaboColor.ink
        case .dark, .glass: MicaboColor.onInk
        case .tinted(let color): color
        }
    }

    var background: Color {
        switch self {
        case .light: MicaboColor.surface
        case .dark: MicaboColor.ink
        case .glass: Color.black.opacity(0.32)
        case .tinted: Color.white.opacity(0.75)
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .light: 0.05
        case .dark: 0.12
        case .glass, .tinted: 0
        }
    }
}

/// Pastille circulaire blanche, sans bordure. Utilisée seule dans un `Menu`,
/// ou enveloppée par `MicaboCircleButton`.
struct MicaboCircleIcon: View {
    let systemImage: String
    var style: MicaboCircleStyle = .light
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.38, weight: .medium))
            .foregroundStyle(style.foreground)
            .frame(width: size, height: size)
            .background(style.background, in: Circle())
            .shadow(color: Color.black.opacity(style.shadowOpacity), radius: 10, x: 0, y: 4)
    }
}

/// Bouton circulaire, posé sur le fond ou sur une couverture.
struct MicaboCircleButton: View {
    let systemImage: String
    var style: MicaboCircleStyle = .light
    var size: CGFloat = 38
    var accessibilityTitle: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            MicaboCircleIcon(systemImage: systemImage, style: style, size: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle ?? systemImage)
    }
}

/// Zone d'action ancrée en bas d'un écran, avec fondu vers le fond.
struct MicaboBottomBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [MicaboColor.canvas.opacity(0), MicaboColor.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)

            content
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.sm)
                .background(MicaboColor.canvas)
        }
    }
}

/// Bouton « + » flottant de l'accueil (bas droite, au-dessus de la tab bar).
struct MicaboFloatingAddButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(MicaboColor.onInk)
                .frame(width: 56, height: 56)
                .background(MicaboColor.ink, in: Capsule())
                .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Importer un cours")
    }
}
