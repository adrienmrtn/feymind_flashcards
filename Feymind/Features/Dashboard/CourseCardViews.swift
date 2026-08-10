import SwiftUI
import UIKit

/// Miniature 52×66 de la maquette : couverture PDF ou initiales sur fond pastel.
struct CourseThumb: View {
    let course: Course

    private var tint: Color { Color(hexString: course.accentHex) }

    var body: some View {
        ZStack {
            if let data = course.coverImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                tint.lightened(by: 0.82)
                Text(initials)
                    .font(FeyFont.hanken(10, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 52, height: 66)
        .clipShape(RoundedRectangle(cornerRadius: FeyRadius.cover, style: .continuous))
    }

    private var initials: String {
        let words = course.title.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }
}

/// Ligne compacte utilisée sur Accueil et Mes cours (maquette).
struct CourseRow: View {
    let course: Course
    var showsChevron: Bool = false

    private var dueCount: Int { course.dueCards.count }

    var body: some View {
        HStack(spacing: FeySpacing.sm) {
            CourseThumb(course: course)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(FeyFont.hanken(14, weight: .semibold))
                    .foregroundStyle(FeyColor.ink)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

                Text(metaLabel)
                    .font(FeyFont.hanken(12, weight: .regular))
                    .foregroundStyle(FeyColor.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: FeySpacing.xs)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xC9C3B8))
            }
        }
        .contentShape(Rectangle())
    }

    private var metaLabel: String {
        let total = course.cards.count
        if dueCount > 0 {
            return "\(total) cartes · \(dueCount) à réviser"
        }
        return "\(total) cartes"
    }
}

/// Carte sombre « Réviser maintenant » de l'accueil (maquette).
struct TodayCTACard: View {
    let dueCount: Int
    let reviewedToday: Int
    let streak: Int
    var action: () -> Void

    /// Estimation grossière : ~30 s par carte.
    private var estimatedMinutes: Int {
        max(1, Int((Double(max(dueCount, 1)) * 30 / 60).rounded(.up)))
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(streak > 0 ? "SÉRIE · \(streak) JOUR\(streak > 1 ? "S" : "")" : "AUJOURD'HUI")
                        .font(FeyFont.hanken(12, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(Color(hex: 0x8F8B82))

                    Spacer()

                    Text(dueCount > 0 ? "\(dueCount) carte\(dueCount > 1 ? "s" : "") due\(dueCount > 1 ? "s" : "")" : "À jour")
                        .font(FeyFont.hanken(12, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xC9B98A))
                }

                Text(dueCount > 0 ? "Réviser maintenant" : "Tout est à jour")
                    .font(FeyFont.hanken(21, weight: .bold))
                    .foregroundStyle(FeyColor.onInk)
                    .tracking(-0.2)

                HStack {
                    Text(dueCount > 0 ? "≈ \(estimatedMinutes) min aujourd'hui" : subtitleIdle)
                        .font(FeyFont.hanken(13, weight: .regular))
                        .foregroundStyle(Color(hex: 0x9A958A))

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FeyColor.ink)
                        .frame(width: 34, height: 34)
                        .background(FeyColor.onInk, in: Circle())
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FeyColor.ink, in: RoundedRectangle(cornerRadius: FeyRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var subtitleIdle: String {
        reviewedToday > 0
            ? "\(reviewedToday) carte\(reviewedToday > 1 ? "s" : "") travaillée\(reviewedToday > 1 ? "s" : "")"
            : "Aucune carte à échéance"
    }
}
