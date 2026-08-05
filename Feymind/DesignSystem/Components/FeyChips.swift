import SwiftUI

/// Petite étiquette arrondie utilisée pour les matières, compteurs et statuts.
struct FeyChip: View {
    let text: String
    var systemImage: String?
    var tint: Color = FeyColor.accent
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(FeyFont.micro)
        }
        .foregroundStyle(filled ? .white : tint)
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .background(filled ? tint : tint.opacity(0.11), in: Capsule())
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
                if let subtitle {
                    Text(subtitle)
                        .font(FeyFont.caption)
                        .foregroundStyle(FeyColor.inkTertiary)
                }
            }
            Spacer(minLength: FeySpacing.xs)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.accent)
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
            ZStack {
                Circle()
                    .fill(FeyColor.accentSoft)
                    .frame(width: 76, height: 76)
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(FeyColor.accent)
            }

            Text(title)
                .font(FeyFont.cardTitle)
                .foregroundStyle(FeyColor.ink)
                .multilineTextAlignment(.center)

            Text(message)
                .font(FeyFont.body)
                .foregroundStyle(FeyColor.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(FeySecondaryButtonStyle(fullWidth: false))
                    .padding(.top, FeySpacing.xxs)
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
    var tint: Color = FeyColor.accent
    var track: Color = FeyColor.accentTint

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
    var tint: Color = FeyColor.accent

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(FeyColor.surfaceSunken)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: progress)
            }
        }
        .frame(height: 6)
    }
}
