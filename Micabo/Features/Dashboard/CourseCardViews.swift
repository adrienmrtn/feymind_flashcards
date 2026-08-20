import SwiftUI

extension MicaboRow {
    /// Rangée d'un cours : vignette, titre, matière et nombre de cartes, état à droite.
    static func course(_ course: Course, action: (() -> Void)? = nil) -> MicaboRow {
        MicaboRow(
            tile: MicaboTile.course(course),
            title: course.title,
            subtitle: CourseRowLabels.meta(for: course),
            accessory: CourseRowLabels.accessory(for: course),
            action: action
        )
    }

    /// Rangée d'un cours pendant une session : le nombre de cartes à revoir en pastille.
    static func courseDue(_ course: Course, dueCount: Int, action: (() -> Void)? = nil) -> MicaboRow {
        MicaboRow(
            tile: MicaboTile.course(course),
            title: course.title,
            subtitle: course.subject?.nilIfBlank,
            accessory: .badge("\(dueCount) à revoir", .accent),
            action: action
        )
    }
}

/// Ce qu'une rangée de cours raconte : la matière, le volume, et l'état de la file.
enum CourseRowLabels {
    static func meta(for course: Course) -> String {
        let cards = "\(course.cards.count) carte\(course.cards.count > 1 ? "s" : "")"
        guard let subject = course.subject?.nilIfBlank else { return cards }
        return "\(subject) · \(cards)"
    }

    static func accessory(for course: Course) -> MicaboRowAccessory {
        let due = course.dueCards.count
        if due > 0 {
            return .badge("\(due) due\(due > 1 ? "s" : "")", .accent)
        }
        if course.cards.isEmpty {
            return .badge("vide", .neutral)
        }
        return .badge("à jour", .neutral)
    }
}

/// Bloc d'appel « Réviser maintenant » : le seul aplat d'encre de l'app,
/// pour que le geste du jour ne se confonde pas avec le reste.
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
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(streak > 0 ? "SÉRIE · \(streak) JOUR\(streak > 1 ? "S" : "")" : "AUJOURD'HUI")
                        .font(MicaboFont.eyebrow)
                        .tracking(MicaboTracking.caps)
                        .foregroundStyle(MicaboColor.onInkMuted)

                    Spacer()

                    if dueCount > 0 {
                        Text("\(dueCount) carte\(dueCount > 1 ? "s" : "") due\(dueCount > 1 ? "s" : "")")
                            .font(MicaboFont.hanken(11, weight: .semibold))
                            .foregroundStyle(MicaboColor.onInk)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 9)
                            .background(Color.white.opacity(0.14), in: Capsule())
                    }
                }

                Text(dueCount > 0 ? "Réviser maintenant" : "Tout est à jour")
                    .font(MicaboFont.hanken(23, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .tracking(-0.4)

                HStack {
                    Text(dueCount > 0 ? "≈ \(estimatedMinutes) min aujourd'hui" : subtitleIdle)
                        .font(MicaboFont.hanken(13, weight: .regular))
                        .foregroundStyle(MicaboColor.onInkMuted)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .frame(width: 36, height: 36)
                        .background(MicaboColor.onInk, in: Circle())
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.ink, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var subtitleIdle: String {
        reviewedToday > 0
            ? "\(reviewedToday) carte\(reviewedToday > 1 ? "s" : "") travaillée\(reviewedToday > 1 ? "s" : "")"
            : "Aucune carte à échéance"
    }
}
