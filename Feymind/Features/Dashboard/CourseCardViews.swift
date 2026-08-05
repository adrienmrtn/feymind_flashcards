import SwiftUI

/// Vignette de cours utilisée sur le tableau de bord et dans « Mes cours ».
struct CourseCard: View {
    let course: Course
    var showsProgress: Bool = true

    private var accent: Color { Color(hexString: course.accentHex) }

    private var dueCount: Int { course.dueCards.count }

    var body: some View {
        HStack(alignment: .top, spacing: FeySpacing.sm) {
            Text(course.emoji)
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(course.title)
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !course.summary.isEmpty {
                    Text(course.summary)
                        .font(.system(size: 13))
                        .foregroundStyle(FeyColor.inkTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 6) {
                    if let subject = course.subject?.nilIfBlank {
                        FeyChip(text: subject, tint: accent)
                    }
                    FeyChip(
                        text: "\(course.cards.count) cartes",
                        systemImage: "rectangle.on.rectangle",
                        tint: FeyColor.inkTertiary
                    )
                    if showsProgress, dueCount > 0 {
                        FeyChip(text: "\(dueCount) à revoir", tint: accent, filled: true)
                    }
                }
                .padding(.top, 1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(FeyColor.inkTertiary.opacity(0.6))
                .padding(.top, 6)
        }
        .feyCard(padding: FeySpacing.sm + 2, radius: FeyRadius.lg, elevated: false)
        .contentShape(Rectangle())
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
                    FeyProgressRing(progress: progress, lineWidth: 9, tint: .white, track: Color.white.opacity(0.28))
                        .frame(width: 68, height: 68)

                    VStack(spacing: 0) {
                        Text("\(dueCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(dueCount > 1 ? "cartes" : "carte")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(dueCount > 0 ? "Révisions du jour" : "Tout est à jour")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: FeySpacing.sm) {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: dueCount > 0 ? "play.fill" : "arrow.clockwise")
                        Text(dueCount > 0 ? "Réviser maintenant" : "Réviser en avance")
                    }
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.accentDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.white, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)

                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("\(streak)")
                            .font(FeyFont.cardTitle)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 13)
                    .padding(.horizontal, 15)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
                }
            }
        }
        .padding(FeySpacing.md)
        .background(
            LinearGradient(
                colors: [FeyColor.accent, FeyColor.accentDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous)
        )
        .shadow(color: FeyColor.accent.opacity(0.28), radius: 18, x: 0, y: 10)
    }

    private var subtitle: String {
        if dueCount == 0 {
            return reviewedToday > 0
                ? "\(reviewedToday) cartes déjà travaillées aujourd'hui."
                : "Aucune carte n'arrive à échéance aujourd'hui."
        }
        return reviewedToday > 0
            ? "\(reviewedToday) déjà faites, il en reste \(dueCount)."
            : "Prenez quelques minutes pour ancrer vos cours."
    }
}
