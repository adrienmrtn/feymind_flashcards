import SwiftUI

/// Bouton d'action principal : rectangle sombre à coins 14 pt (pas une capsule).
struct MicaboPrimaryButtonStyle: ButtonStyle {
    var tint: Color = MicaboColor.ink
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MicaboFont.cardTitle)
            .foregroundStyle(MicaboColor.onInk)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(tint, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Bouton secondaire : fond blanc, bordure fine, mêmes coins 14 pt.
struct MicaboSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MicaboFont.cardTitle)
            .foregroundStyle(MicaboColor.ink)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                    .strokeBorder(MicaboColor.strokeStrong, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
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
        case .tinted: Color.white.opacity(0.7)
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .light, .dark: 0.08
        case .glass, .tinted: 0
        }
    }
}

/// Pastille circulaire. Utilisée seule dans un `Menu`, ou enveloppée par `MicaboCircleButton`.
struct MicaboCircleIcon: View {
    let systemImage: String
    var style: MicaboCircleStyle = .light
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(style.foreground)
            .frame(width: size, height: size)
            .background(style.background, in: Circle())
            .overlay {
                if style == .light {
                    Circle().strokeBorder(MicaboColor.strokeStrong, lineWidth: 1)
                }
            }
            .shadow(color: Color.black.opacity(style.shadowOpacity), radius: 8, x: 0, y: 3)
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
