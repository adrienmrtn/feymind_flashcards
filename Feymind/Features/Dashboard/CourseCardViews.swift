import SwiftUI

/// Grande vignette de cours, avec sa couverture.
struct CourseCoverCard: View {
    let course: Course
    var height: CGFloat = 208

    private var dueCount: Int { course.dueCards.count }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CourseCover(course: course, emojiSize: 46)
            FeyCoverScrim()

            VStack(alignment: .leading, spacing: 5) {
                if let subject = course.subject?.nilIfBlank {
                    FeyGlassChip(text: subject)
                        .padding(.bottom, 2)
                }

                Text(course.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(FeyColor.onInk)
                    .tracking(FeyTracking.tight)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(metaLabel)
                    .font(FeyFont.caption)
                    .foregroundStyle(Color.white.opacity(0.78))
            }
            .padding(FeySpacing.md)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if dueCount > 0 {
                Text("\(dueCount) à réviser")
                    .font(FeyFont.micro)
                    .foregroundStyle(FeyColor.ink)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background(FeyColor.surface, in: Capsule())
                    .padding(FeySpacing.sm)
            }
        }
        .feySoftShadow(strength: 0.1)
    }

    private var metaLabel: String {
        let total = course.cards.count
        guard total > 0 else { return "Aucune carte pour l'instant" }
        return dueCount > 0
            ? "\(total) cartes"
            : "\(total) cartes, tout est à jour"
    }
}

/// Ligne compacte utilisée dans « Mes cours ».
struct CourseRow: View {
    let course: Course

    private var dueCount: Int { course.dueCards.count }

    var body: some View {
        HStack(spacing: FeySpacing.sm) {
            CourseCover(course: course, emojiSize: 24)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(course.title)
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.ink)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

                Text(metaLabel)
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: FeySpacing.xs)

            if dueCount > 0 {
                FeyChip(text: "\(dueCount)", tint: FeyColor.ink, filled: true)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FeyColor.inkTertiary.opacity(0.7))
        }
        .feyCard(padding: FeySpacing.sm, radius: FeyRadius.lg, elevated: false)
        .contentShape(Rectangle())
    }

    private var metaLabel: String {
        var parts: [String] = []
        if let subject = course.subject?.nilIfBlank { parts.append(subject) }
        parts.append("\(course.cards.count) cartes")
        return parts.joined(separator: " · ")
    }
}

/// Grande carte d'appel à l'action pour les révisions du jour.
struct TodayCTACard: View {
    let dueCount: Int
    let reviewedToday: Int
    let streak: Int
    var action: () -> Void

    private var progress: Double {
        let total = dueCount + reviewedToday
        guard total > 0 else { return 1 }
        return Double(reviewedToday) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FeySpacing.md) {
            HStack(alignment: .center, spacing: FeySpacing.md) {
                ZStack {
                    FeyProgressRing(
                        progress: progress,
                        lineWidth: 8,
                        tint: FeyColor.onInk,
                        track: Color.white.opacity(0.22)
                    )
                    .frame(width: 66, height: 66)

                    VStack(spacing: 0) {
                        Text("\(dueCount)")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(FeyColor.onInk)
                        Text(dueCount > 1 ? "cartes" : "carte")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(dueCount > 0 ? "Révisions du jour" : "Tout est à jour")
                        .font(FeyFont.pageTitle)
                        .foregroundStyle(FeyColor.onInk)
                        .tracking(FeyTracking.tight)

                    Text(subtitle)
                        .font(FeyFont.caption)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: FeySpacing.xs) {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: dueCount > 0 ? "play.fill" : "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text(dueCount > 0 ? "Réviser maintenant" : "Réviser en avance")
                    }
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(FeyColor.surface, in: Capsule())
                }
                .buttonStyle(.plain)

                if streak > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(streak)")
                            .font(FeyFont.cardTitle)
                    }
                    .foregroundStyle(FeyColor.onInk)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 17)
                    .background(Color.white.opacity(0.14), in: Capsule())
                }
            }
        }
        .padding(FeySpacing.md)
        .background(FeyColor.ink, in: RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous))
        .feySoftShadow(strength: 0.14)
    }

    private var subtitle: String {
        if dueCount == 0 {
            return reviewedToday > 0
                ? "\(reviewedToday) cartes travaillées aujourd'hui."
                : "Aucune carte n'arrive à échéance."
        }
        return reviewedToday > 0
            ? "\(reviewedToday) déjà faites, il en reste \(dueCount)."
            : "Quelques minutes suffisent."
    }
}
