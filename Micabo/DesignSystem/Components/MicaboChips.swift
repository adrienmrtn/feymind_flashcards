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

/// Pilule de sélection : encre pleine quand elle est active, blanche cerclée sinon.
struct MicaboSelectChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MicaboFont.hanken(14, weight: .medium))
                .foregroundStyle(isSelected ? MicaboColor.onInk : MicaboColor.inkSecondary)
                .padding(.vertical, 9)
                .padding(.horizontal, 16)
                .background(isSelected ? MicaboColor.ink : MicaboColor.surface, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(isSelected ? Color.clear : MicaboColor.stroke, lineWidth: 1)
                }
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}

/// Intitulé d'une section de contenu : capitales grises, et un lien à droite.
struct MicaboSectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                MicaboEyebrow(text: title)
                if let subtitle {
                    Text(subtitle)
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
            }
            Spacer(minLength: MicaboSpacing.xs)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(MicaboFont.hanken(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.accent)
            }
        }
        .padding(.leading, MicaboSpacing.xxs)
    }
}

struct MicaboEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: MicaboSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(MicaboColor.accent.opacity(0.75))
                .frame(width: 76, height: 76)
                .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text(title)
                .font(MicaboFont.hanken(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.3)
                .multilineTextAlignment(.center)
                .padding(.top, MicaboSpacing.xxs)

            Text(message)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 300)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(MicaboPrimaryButtonStyle())
                    .padding(.top, MicaboSpacing.sm)
                    .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MicaboSpacing.xl)
        .padding(.horizontal, MicaboSpacing.lg)
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
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: progress)
        }
    }
}

/// Barre de progression fine : jauge du parcours d'accueil et sessions de révision.
/// La couleur reste `MicaboColor.progress` ; elle ne s'inverse que posée sur un fond
/// sombre, où l'indigo ne se verrait plus.
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
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: progress)
            }
        }
        .frame(height: 5)
    }
}
