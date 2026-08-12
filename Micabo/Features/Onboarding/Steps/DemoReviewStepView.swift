import SwiftUI

/// Écran 8c : dernier temps. L'utilisateur retourne une vraie carte et se note,
/// puis voit la date de la prochaine révision se calculer.
struct DemoReviewStepView: View {
    @Environment(OnboardingModel.self) private var model

    private enum Verdict {
        case again
        case known

        var interval: String {
            switch self {
            case .again: "dans 10 minutes"
            case .known: "dans 3 jours"
            }
        }

        var message: String {
            switch self {
            case .again: "Pas grave. Micabo te la repose tout à l'heure, avant qu'elle ne s'efface."
            case .known: "Bien joué. L'intervalle s'allonge : la carte revient plus tard, et pour plus longtemps."
            }
        }

        var tint: Color {
            switch self {
            case .again: MicaboColor.caution
            case .known: MicaboColor.positive
            }
        }
    }

    @State private var isFlipped = false
    @State private var verdict: Verdict?

    private var card: OnboardingDemo.Card { OnboardingDemo.cards[0] }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Comment ça marche · 3 sur 3",
            title: "À toi de jouer.",
            subtitle: "Retourne la carte, puis dis honnêtement si tu savais. C'est cette réponse qui fixe la prochaine date.",
            titleSize: 28
        ) {
            VStack(spacing: 16) {
                FlipCard(front: card.front, back: card.back, isFlipped: isFlipped)
                    .onTapGesture(perform: flip)

                controls
            }
        } footer: {
            OnboardingContinueButton(isEnabled: verdict != nil) {
                model.advance()
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if let verdict {
            VStack(spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Prochaine révision \(verdict.interval)")
                        .font(MicaboFont.hanken(13, weight: .semibold))
                }
                .foregroundStyle(verdict.tint)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(verdict.tint.opacity(0.12), in: Capsule())

                Text(verdict.message)
                    .font(MicaboFont.hanken(13, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MicaboSpacing.xs)
            }
            .frame(maxWidth: .infinity)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        } else if isFlipped {
            HStack(spacing: 10) {
                verdictButton(.again, title: "À revoir", systemImage: "arrow.counterclockwise")
                verdictButton(.known, title: "Je savais", systemImage: "checkmark")
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            HStack(spacing: 7) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Appuie sur la carte pour voir la réponse")
                    .font(MicaboFont.hanken(13, weight: .semibold))
            }
            .foregroundStyle(MicaboColor.ink)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(MicaboColor.surfaceMuted, in: Capsule())
            .transition(.opacity)
        }
    }

    private func verdictButton(_ value: Verdict, title: String, systemImage: String) -> some View {
        Button {
            Haptics.success()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                verdict = value
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(MicaboFont.hanken(14, weight: .semibold))
            }
            .foregroundStyle(value.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(value.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func flip() {
        guard !isFlipped else { return }
        Haptics.rigid()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            isFlipped = true
        }
    }
}

/// Carte qui pivote sur son axe vertical.
private struct FlipCard: View {
    let front: String
    let back: String
    let isFlipped: Bool

    var body: some View {
        ZStack {
            face(label: OnboardingDemo.subject.uppercased(), text: front, isAnswer: false)
                .opacity(isFlipped ? 0 : 1)

            face(label: "Réponse", text: back, isAnswer: true)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    private func face(label: String, text: String, isAnswer: Bool) -> some View {
        VStack(spacing: 12) {
            Text(label.uppercased())
                .font(MicaboFont.hanken(10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(isAnswer ? MicaboColor.accent : MicaboColor.inkTertiary)

            Text(text)
                .font(MicaboFont.hanken(isAnswer ? 18 : 20, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}
