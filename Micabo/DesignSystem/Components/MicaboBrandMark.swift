import SwiftUI

/// Le stylo sur fond bleu, le même fichier que le favicon du site.
///
/// L'image est déjà un squircle : on la recoupe encore d'un filet continu pour que le
/// halo gris de l'export ne se lise pas à côté du mot « Micabo ».
struct MicaboBrandMark: View {
    var size: CGFloat = 32

    var body: some View {
        Image("BrandMark")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            }
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
                .font(MicaboFont.hanken(16, weight: .bold))
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
                .font(MicaboFont.hanken(22, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(MicaboColor.ink)
                .padding(.top, 12)
            if !tagline.isEmpty {
                Text(tagline)
                    .font(MicaboFont.hanken(11, weight: .medium))
                    .tracking(2.4)
                    .textCase(.uppercase)
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
