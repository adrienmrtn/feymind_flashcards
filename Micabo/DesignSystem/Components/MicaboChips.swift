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
        .background(filled ? tint : MicaboColor.surface, in: Capsule())
        .overlay {
            if !filled {
                Capsule().strokeBorder(MicaboColor.strokeStrong, lineWidth: 1)
            }
        }
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

/// Pilule de sélection : sombre quand elle est active, blanche sinon.
struct MicaboSelectChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MicaboFont.captionEmphasis)
                .foregroundStyle(isSelected ? MicaboColor.onInk : Color(hex: 0x4A463F))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(isSelected ? MicaboColor.ink : MicaboColor.surface, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(isSelected ? Color.clear : MicaboColor.strokeStrong, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}

/// Rangée horizontale de pilules de sélection.
struct MicaboSelectChipRow: View {
    let titles: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MicaboSpacing.xs) {
                ForEach(titles, id: \.self) { title in
                    MicaboSelectChip(title: title, isSelected: title == selection) {
                        selection = title
                    }
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

struct MicaboSectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MicaboFont.cardTitle)
                    .foregroundStyle(MicaboColor.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
            }
            Spacer(minLength: MicaboSpacing.xs)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(MicaboFont.captionEmphasis)
                    .foregroundStyle(MicaboColor.accent)
            }
        }
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
                .foregroundStyle(MicaboColor.inkTertiary)
                .frame(width: 74, height: 74)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(MicaboColor.strokeStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }

            Text(title)
                .font(MicaboFont.hanken(17, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .padding(.top, MicaboSpacing.xxs)

            Text(message)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(MicaboPrimaryButtonStyle())
                    .padding(.top, MicaboSpacing.xs)
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
    var tint: Color = MicaboColor.ink
    var track: Color = MicaboColor.surfaceSunken

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

/// Barre de progression fine, utilisée en haut des sessions d'entraînement.
struct MicaboProgressBar: View {
    let progress: Double
    var tint: Color = MicaboColor.accent
    var track: Color = MicaboColor.surfaceSunken

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
