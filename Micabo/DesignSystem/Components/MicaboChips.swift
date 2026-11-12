import SwiftUI

/// Étiquette d'information : matière, compteur, état d'une carte.
struct MicaboChip: View {
    let text: String
    var systemImage: String?
    var tint: Color = MicaboColor.inkSecondary
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(MicaboFont.micro)
        }
        .foregroundStyle(filled ? MicaboColor.onInk : tint)
        .padding(.vertical, 6)
        .padding(.horizontal, 11)
        .background(filled ? tint : MicaboColor.surfaceMuted, in: Capsule())
    }
}

/// Étiquette posée sur une couverture sombre.
struct MicaboGlassChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MicaboFont.micro)
            .foregroundStyle(MicaboColor.onInk)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.black.opacity(0.28), in: Capsule())
    }
}

/// Pilule de sélection : l'accent plein quand elle est active, une surface cerclée sur sa
/// lèvre sinon — la même touche que les cartes et les boutons (lot 9).
struct MicaboSelectChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MicaboFont.ui(15, weight: isSelected ? .heavy : .bold))
                .foregroundStyle(isSelected ? MicaboColor.onAccent : MicaboColor.ink)
                .padding(.vertical, 9)
                .padding(.horizontal, 16)
                .background {
                    ZStack {
                        Capsule().fill(isSelected ? MicaboColor.accentDeep : MicaboColor.edge).offset(y: 2)
                        Capsule().fill(isSelected ? MicaboColor.accent : MicaboColor.surface)
                    }
                }
                .overlay {
                    Capsule().strokeBorder(isSelected ? Color.clear : MicaboColor.stroke, lineWidth: 1)
                }
                .padding(.bottom, 2)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .selection))
        .animation(MicaboMotion.quick, value: isSelected)
    }
}

/// Intitulé d'une section de contenu : **le titre de section de l'app** (`MicaboSectionHeading`),
/// et un lien « Tout voir » à droite (`MicaboSeeAllLink`).
struct MicaboSectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        MicaboSectionHeading(title: title, subtitle: subtitle) {
            if let actionTitle, let action {
                MicaboSeeAllLink(title: actionTitle, action: action)
            }
        }
    }
}

struct MicaboEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    /// **Mika en entier à la place du pictogramme** : un écran vide est l'un de ses moments
    /// (la règle de mise en scène, `MikaMascot.swift`). Il fait son geste une fois.
    var mika: MikaMood?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            if let mika {
                MikaMascot(mood: mika, size: 120)
                    .padding(.bottom, 8)
            } else {
                // Le pictogramme dans le bleu de l'app, sur son lavis : un gris sur gris disait
                // « rien », alors qu'un écran vide invite à commencer (lot 7).
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MicaboColor.accent)
                    .frame(width: 56, height: 56)
                    .background(MicaboColor.accentWash, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.bottom, 4)
            }

            Text(title)
                .font(MicaboFont.ui(19, weight: .black))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(MicaboBrandButtonStyle())
                    .padding(.top, 6)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MicaboSpacing.md)
        .padding(.horizontal, MicaboSpacing.md)
    }
}

/// Anneau de progression utilisé pour les révisions du jour.
struct MicaboProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var tint: Color = MicaboColor.progress
    var track: Color = MicaboColor.progressTrack

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(MicaboMotion.gentle, value: progress)
        }
    }
}

/// Barre de progression fine : jauge du parcours d'accueil et sessions de révision.
/// La couleur reste `MicaboColor.progress` ; elle ne s'inverse que posée sur un fond
/// sombre, où le vert ne se verrait plus.
struct MicaboProgressBar: View {
    let progress: Double
    var tint: Color = MicaboColor.progress
    var track: Color = MicaboColor.progressTrack

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
                    .animation(MicaboMotion.standard, value: progress)
            }
        }
        // Huit points (lot 9) : une jauge de cinq se lisait comme un filet, pas comme une
        // avancée.
        .frame(height: 8)
    }
}
