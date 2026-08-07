import SwiftUI

/// Étiquette d'information : matière, compteur, état d'une carte.
struct FeyChip: View {
    let text: String
    var systemImage: String?
    var tint: Color = FeyColor.inkSecondary
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(FeyFont.micro)
        }
        .foregroundStyle(filled ? FeyColor.onInk : tint)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(filled ? tint : FeyColor.surfaceMuted, in: Capsule())
    }
}

/// Étiquette posée sur une couverture sombre.
struct FeyGlassChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(FeyFont.micro)
            .foregroundStyle(FeyColor.onInk)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.black.opacity(0.28), in: Capsule())
    }
}

/// Pilule de sélection : sombre quand elle est active, blanche sinon.
struct FeySelectChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FeyFont.captionEmphasis)
                .foregroundStyle(isSelected ? FeyColor.onInk : FeyColor.inkSecondary)
                .padding(.vertical, 11)
                .padding(.horizontal, 18)
                .background(isSelected ? FeyColor.ink : FeyColor.surface, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(isSelected ? Color.clear : FeyColor.stroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}

/// Rangée horizontale de pilules de sélection.
struct FeySelectChipRow: View {
    let titles: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FeySpacing.xs) {
                ForEach(titles, id: \.self) { title in
                    FeySelectChip(title: title, isSelected: title == selection) {
                        selection = title
                    }
                }
            }
            .padding(.horizontal, FeySpacing.screen)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

struct FeySectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FeyFont.sectionTitle)
                    .foregroundStyle(FeyColor.ink)
                    .tracking(FeyTracking.tight)
                if let subtitle {
                    Text(subtitle)
                        .font(FeyFont.caption)
                        .foregroundStyle(FeyColor.inkTertiary)
                }
            }
            Spacer(minLength: FeySpacing.xs)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(FeyFont.captionEmphasis)
                    .foregroundStyle(FeyColor.ink)
            }
        }
    }
}

struct FeyEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: FeySpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(FeyColor.inkTertiary)
                .frame(width: 74, height: 74)
                .background(FeyColor.surfaceMuted, in: Circle())

            Text(title)
                .font(FeyFont.pageTitle)
                .foregroundStyle(FeyColor.ink)
                .tracking(FeyTracking.tight)
                .multilineTextAlignment(.center)
                .padding(.top, FeySpacing.xxs)

            Text(message)
                .font(FeyFont.body)
                .foregroundStyle(FeyColor.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(FeyPrimaryButtonStyle(fullWidth: false))
                    .padding(.top, FeySpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FeySpacing.xl)
    }
}

/// Anneau de progression utilisé pour les révisions du jour.
struct FeyProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var tint: Color = FeyColor.ink
    var track: Color = FeyColor.surfaceSunken

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
struct FeyProgressBar: View {
    let progress: Double
    var tint: Color = FeyColor.ink
    var track: Color = FeyColor.surfaceSunken

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
