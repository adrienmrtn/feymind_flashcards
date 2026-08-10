import SwiftUI

/// Bouton d'action principal : rectangle sombre à coins 14 pt (pas une capsule).
struct FeyPrimaryButtonStyle: ButtonStyle {
    var tint: Color = FeyColor.ink
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FeyFont.cardTitle)
            .foregroundStyle(FeyColor.onInk)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(tint, in: RoundedRectangle(cornerRadius: FeyRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Bouton secondaire : fond blanc, bordure fine, mêmes coins 14 pt.
struct FeySecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FeyFont.cardTitle)
            .foregroundStyle(FeyColor.ink)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FeyRadius.button, style: .continuous)
                    .strokeBorder(FeyColor.strokeStrong, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
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
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

enum FeyCircleStyle: Equatable {
    case light
    case dark
    /// Posé sur une couverture, quelle que soit sa clarté.
    case glass
    /// Posé sur un panneau pastel : verre blanc, icône dans la teinte du cours.
    case tinted(Color)

    var foreground: Color {
        switch self {
        case .light: FeyColor.ink
        case .dark, .glass: FeyColor.onInk
        case .tinted(let color): color
        }
    }

    var background: Color {
        switch self {
        case .light: FeyColor.surface
        case .dark: FeyColor.ink
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

/// Pastille circulaire. Utilisée seule dans un `Menu`, ou enveloppée par `FeyCircleButton`.
struct FeyCircleIcon: View {
    let systemImage: String
    var style: FeyCircleStyle = .light
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(style.foreground)
            .frame(width: size, height: size)
            .background(style.background, in: Circle())
            .overlay {
                if style == .light {
                    Circle().strokeBorder(FeyColor.strokeStrong, lineWidth: 1)
                }
            }
            .shadow(color: Color.black.opacity(style.shadowOpacity), radius: 8, x: 0, y: 3)
    }
}

/// Bouton circulaire, posé sur le fond ou sur une couverture.
struct FeyCircleButton: View {
    let systemImage: String
    var style: FeyCircleStyle = .light
    var size: CGFloat = 38
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
            .frame(height: 28)

            content
                .padding(.horizontal, FeySpacing.screen)
                .padding(.bottom, FeySpacing.sm)
                .background(FeyColor.canvas)
        }
    }
}

/// Bouton « + » flottant de l'accueil (bas droite, au-dessus de la tab bar).
struct FeyFloatingAddButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(FeyColor.onInk)
                .frame(width: 56, height: 56)
                .background(FeyColor.ink, in: Capsule())
                .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Importer un cours")
    }
}
