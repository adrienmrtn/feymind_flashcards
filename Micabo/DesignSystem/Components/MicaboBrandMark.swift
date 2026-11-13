import SwiftUI

/// **La marque de Micabo : le Mika vectoriel**, dans un squircle (lot 11).
///
/// C'était une image : l'ancien Mika noir et brillant, sur fond bleu, que l'utilisateur ne
/// reconnaissait plus à côté du Mika plat de l'app (l'écran de connexion la montrait encore).
/// C'est maintenant le même dessin que partout (`MikaFigure`, la tête), sur son disque, en
/// marine comme en clair — rien à exporter, net à toutes les tailles.
struct MicaboBrandMark: View {
    var size: CGFloat = 32

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let night = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
        MikaFigure(pose: .face, framing: .avatar, scale: size / MikaFraming.avatar.window.width, night: night)
            .frame(width: size, height: size)
            .background(MikaPalette.disc(night: night))
            .clipShape(shape)
            .overlay { shape.strokeBorder(V3Color.line, lineWidth: MicaboSurface.border) }
            // Le dessin de Mika ne se retourne pas en arabe.
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityHidden(true)
    }
}

/// Icône + mot, pour une barre ou le haut d'une feuille. L'image reste muette :
/// c'est le mot qui porte le nom.
struct MicaboBrandLockup: View {
    var size: CGFloat = 28
    var word: String = "Micabo"

    var body: some View {
        HStack(spacing: 10) {
            MicaboBrandMark(size: size)
            Text(word)
                .font(MicaboFont.ui(16, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(MicaboColor.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word)
    }
}

/// Le monogramme posé en grand : icône, mot, et la ligne « étudier ».
/// Pour un écran d'accueil, pas pour une barre.
struct MicaboBrandWordmark: View {
    var mark: CGFloat = 64
    var tagline: String = ""

    var body: some View {
        VStack(spacing: 0) {
            MicaboBrandMark(size: mark)
            Text("micabo")
                .font(MicaboFont.ui(22, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(MicaboColor.ink)
                .padding(.top, 12)
            if !tagline.isEmpty {
                Text(tagline)
                    .font(MicaboFont.ui(11, weight: .medium))
                    .tracking(2.4)
                    .textCase(.uppercase)
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
