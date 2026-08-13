import SwiftUI

/// Écran 8b : deuxième temps. L'utilisateur lance la génération et voit les cartes
/// se poser une à une.
struct DemoWriteStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var isGenerating = false
    @State private var revealedCards = 0

    private var isFinished: Bool { revealedCards == OnboardingDemo.cards.count }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Comment ça marche · 2 sur 3",
            title: "Micabo écrit\ntes flashcards.",
            subtitle: "Une question par idée, une réponse courte, dans ta langue. Tu peux tout modifier ensuite.",
            titleSize: 28
        ) {
            VStack(spacing: 14) {
                courseHeader

                if !isGenerating {
                    Button(action: generate) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Générer les cartes")
                        }
                    }
                    .buttonStyle(MicaboSecondaryButtonStyle())
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                VStack(spacing: 10) {
                    ForEach(Array(OnboardingDemo.cards.enumerated()), id: \.element.id) { index, card in
                        if index < revealedCards {
                            GeneratedCardRow(index: index + 1, front: card.front, back: card.back)
                                .transition(
                                    .asymmetric(
                                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                                        removal: .opacity
                                    )
                                )
                        }
                    }
                }

                if isGenerating, !isFinished {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(MicaboColor.accent)
                        Text("Rédaction en cours…")
                            .font(MicaboFont.hanken(13, weight: .medium))
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
                    .padding(.top, 4)
                }
            }
        } footer: {
            // Rien tant que les cartes s'écrivent : le bouton arrive avec le résultat.
            if isFinished {
                OnboardingContinueButton {
                    model.advance()
                }
                .transition(.opacity)
            }
        }
    }

    private var courseHeader: some View {
        HStack(spacing: 12) {
            Text("📜")
                .font(.system(size: 20))
                .frame(width: 44, height: 52)
                .background(
                    OnboardingDemo.accent.lightened(by: 0.78),
                    in: RoundedRectangle(cornerRadius: MicaboRadius.cover, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(OnboardingDemo.courseTitle)
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                Text(OnboardingDemo.subject)
                    .font(MicaboFont.hanken(11, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }

            Spacer(minLength: 0)

            Text("\(revealedCards) carte\(revealedCards > 1 ? "s" : "")")
                .font(MicaboFont.hanken(11, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(12)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private func generate() {
        guard !isGenerating else { return }
        Haptics.medium()
        withAnimation(.easeOut(duration: 0.25)) {
            isGenerating = true
        }

        for index in OnboardingDemo.cards.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75 + Double(index) * 0.62) {
                withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.4)) {
                    revealedCards = index + 1
                }
                Haptics.tick()

                if index == OnboardingDemo.cards.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        Haptics.success()
                    }
                }
            }
        }
    }
}

/// Carte générée, montrée recto et verso pour rendre le résultat lisible d'un coup d'œil.
private struct GeneratedCardRow: View {
    let index: Int
    let front: String
    let back: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(index)")
                    .font(MicaboFont.hanken(11, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .frame(width: 20, height: 20)
                    .background(MicaboColor.ink, in: Circle())

                Text(front)
                    .font(MicaboFont.hanken(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(back)
                .font(MicaboFont.hanken(13, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }
}
