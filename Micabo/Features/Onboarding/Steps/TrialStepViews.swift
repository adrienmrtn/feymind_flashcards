import SwiftUI

/// Écran 16 : annonce de l'essai gratuit.
///
/// Composition à part dans le parcours : le visuel déborde de la marge droite et le texte
/// se lit en bas, fer à gauche comme partout. Il tombe entre l'écran indigo de
/// personnalisation et la liste des jalons, ce qui casse la répétition des mises en page.
struct TrialOfferStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var giftScale = 0.7
    @State private var haloScale = 0.8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: MicaboSpacing.md)

            gift
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, -54)

            Spacer(minLength: MicaboSpacing.md)

            VStack(alignment: .leading, spacing: 12) {
                Text("3 jours offerts")
                    .font(MicaboFont.hanken(13, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(MicaboColor.accent)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(MicaboColor.accentSoft, in: Capsule())

                Text("On t'offre Micabo\npendant 3 jours.")
                    .font(MicaboFont.hanken(32, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Cours illimités, génération de cartes, révisions : tout est ouvert, sans engagement.")
                    .font(MicaboFont.hanken(15, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.lg)

            MicaboBottomBar {
                OnboardingContinueButton {
                    model.advance()
                }
            }
        }
        .onAppear(perform: animateIn)
    }

    private var gift: some View {
        ZStack {
            Circle()
                .fill(MicaboColor.accentSoft)
                .frame(width: 210, height: 210)
                .scaleEffect(haloScale)

            Image(systemName: "gift.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(MicaboColor.onInk)
                .frame(width: 124, height: 124)
                .background(MicaboColor.ink, in: Circle())
                .scaleEffect(giftScale)
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.15)) {
            giftScale = 1
        }
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.4)) {
            haloScale = 1.08
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Haptics.success()
        }
    }
}

/// Écran 17 : promesse de rappel avant la fin de l'essai.
struct TrialReminderStepView: View {
    @Environment(OnboardingModel.self) private var model

    private struct Milestone: Identifiable {
        let id = UUID()
        let day: String
        let title: String
        let detail: String
        let systemImage: String
        let isHighlighted: Bool
    }

    private let milestones: [Milestone] = [
        Milestone(
            day: "Aujourd'hui",
            title: "Tout est débloqué",
            detail: "Tu importes tes cours et tu commences à réviser.",
            systemImage: "lock.open",
            isHighlighted: false
        ),
        Milestone(
            day: "Jour 2",
            title: "On te prévient",
            detail: "Une notification, un jour avant la fin de l'essai. Pas de surprise.",
            systemImage: "bell.badge",
            isHighlighted: true
        ),
        Milestone(
            day: "Jour 3",
            title: "Fin de l'essai",
            detail: "Tu continues si ça t'a servi, tu arrêtes sinon.",
            systemImage: "flag.checkered",
            isHighlighted: false
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 22) {
                RingingBell()

                VStack(alignment: .leading, spacing: 10) {
                    Text("On te prévient un jour\navant la fin.")
                        .font(MicaboFont.hanken(28, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .tracking(-0.6)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Tu gardes la main du début à la fin.")
                        .font(MicaboFont.hanken(15, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                        MilestoneRow(
                            day: milestone.day,
                            title: milestone.title,
                            detail: milestone.detail,
                            systemImage: milestone.systemImage,
                            isHighlighted: milestone.isHighlighted,
                            isLast: index == milestones.count - 1
                        )
                    }
                }
                .padding(16)
                .micaboGroup()
            }
            .padding(.horizontal, MicaboSpacing.screen)

            Spacer(minLength: 0)

            MicaboBottomBar {
                OnboardingContinueButton(title: "Voir l'offre") {
                    model.advance()
                }
            }
        }
    }
}

/// Cloche qui sonne en boucle.
private struct RingingBell: View {
    var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(MicaboColor.onInk)
            .frame(width: 78, height: 78)
            .background(MicaboColor.ink, in: Circle())
            // Les angles sont tous distincts : deux phases identiques d'affilée
            // empêcheraient l'animateur de repartir. La dernière tient la pose,
            // ce qui donne la pause entre deux sonneries.
            .phaseAnimator([0.0, -14.0, 12.0, -8.0, 6.0, -3.0, 1.0]) { content, angle in
                content.rotationEffect(.degrees(angle), anchor: .top)
            } animation: { angle in
                angle == 1.0 ? .easeInOut(duration: 1.5) : .spring(response: 0.17, dampingFraction: 0.42)
            }
            .onAppear { Haptics.tick() }
    }
}

private struct MilestoneRow: View {
    let day: String
    let title: String
    let detail: String
    let systemImage: String
    let isHighlighted: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isHighlighted ? MicaboColor.onInk : MicaboColor.inkSecondary)
                    .frame(width: 30, height: 30)
                    .background(isHighlighted ? MicaboColor.ink : MicaboColor.surfaceMuted, in: Circle())

                if !isLast {
                    Rectangle()
                        .fill(MicaboColor.stroke)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(day.uppercased())
                    .font(MicaboFont.hanken(9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(isHighlighted ? MicaboColor.accent : MicaboColor.inkTertiary)

                Text(title)
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)

                Text(detail)
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
