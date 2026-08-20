import SwiftUI

/// Écran 8c : le geste de révision. Une pile de trois cartes, la première se retourne
/// au doigt, et la note donnée fixe la prochaine date.
///
/// Deux phrases d'explication au maximum sur tout l'écran : la pédagogie de la
/// répétition espacée a déjà eu ses écrans, ici on révise.
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

        var tint: Color {
            switch self {
            case .again: MicaboColor.caution
            case .known: MicaboColor.positive
            }
        }
    }

    @State private var isFlipped = false
    @State private var verdict: Verdict?

    private var cards: [OnboardingDemo.Card] { OnboardingDemo.cards }
    private var card: OnboardingDemo.Card { cards[0] }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Comment ça marche · 3 sur 3",
            title: "À toi de jouer.",
            subtitle: "Appuie sur la carte, puis dis si tu savais.",
            titleSize: 28,
            scrolls: false
        ) {
            VStack(spacing: 20) {
                cardStack
                controls
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - La pile

    /// Les deux cartes restantes dépassent derrière : on voit qu'il y en a d'autres,
    /// sans les lire.
    private var cardStack: some View {
        ZStack {
            ForEach(Array(cards.dropFirst().enumerated()), id: \.element.id) { index, _ in
                RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous)
                    .fill(MicaboColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous)
                            .strokeBorder(MicaboColor.stroke, lineWidth: 1)
                    }
                    .frame(height: 176)
                    .scaleEffect(1 - CGFloat(index + 1) * 0.04)
                    .offset(y: CGFloat(index + 1) * 12)
                    .opacity(0.7)
            }

            FlipCard(front: card.front, back: card.back, isFlipped: isFlipped)
                .onTapGesture(perform: flip)
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(isFlipped ? card.back : card.front)
                .accessibilityHint(isFlipped ? "" : "Appuie pour voir la réponse")
        }
        .padding(.top, 4)
    }

    // MARK: - Commandes

    @ViewBuilder
    private var controls: some View {
        if let verdict {
            HStack(spacing: 7) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                Text("Elle revient \(verdict.interval)")
                    .font(MicaboFont.hanken(14, weight: .semibold))
            }
            .foregroundStyle(verdict.tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(verdict.tint.opacity(0.12), in: Capsule())
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
                Text("Appuie sur la carte")
                    .font(MicaboFont.hanken(13, weight: .semibold))
            }
            .foregroundStyle(MicaboColor.ink)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(MicaboColor.surfaceMuted, in: Capsule())
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        }
    }

    private func verdictButton(_ value: Verdict, title: String, systemImage: String) -> some View {
        Button {
            choose(value)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(MicaboFont.hanken(14, weight: .semibold))
            }
            .foregroundStyle(value.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(value.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }

    // MARK: - Actions

    /// La note vaut validation : on laisse voir la prochaine échéance, puis on enchaîne.
    private func choose(_ value: Verdict) {
        guard verdict == nil else { return }
        Haptics.success()
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.35)) {
            verdict = value
        }

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            flow.advance()
        }
    }

    private func flip() {
        guard !isFlipped else { return }
        Haptics.rigid()
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.4)) {
            isFlipped = true
        }
    }
}

/// Carte qui pivote sur son axe vertical. Une ligne au recto, une ligne au verso.
private struct FlipCard: View {
    let front: String
    let back: String
    let isFlipped: Bool

    var body: some View {
        ZStack {
            face(label: OnboardingDemo.subject, text: front, isAnswer: false)
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
                .font(MicaboFont.eyebrow)
                .tracking(MicaboTracking.caps)
                .foregroundStyle(isAnswer ? MicaboColor.accent : MicaboColor.inkTertiary)

            Text(text)
                .font(MicaboFont.hanken(isAnswer ? 22 : 20, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: 176)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.07), radius: 16, x: 0, y: 9)
    }
}
