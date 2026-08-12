import SwiftUI

/// Écran 10 : la pile de cartes se remplit sous les yeux de l'utilisateur.
struct GeneratedCardsStepView: View {
    @Environment(OnboardingModel.self) private var model

    private struct SampleCard: Identifiable {
        let id = UUID()
        let subject: String
        let question: String
        let tint: Color
    }

    private let cards: [SampleCard] = [
        SampleCard(subject: "Histoire", question: "Quel événement ouvre la Révolution française ?", tint: Color(hex: 0x6B5548)),
        SampleCard(subject: "Histoire", question: "Que vote l'Assemblée le 26 août 1789 ?", tint: Color(hex: 0x6B5548)),
        SampleCard(subject: "Biologie", question: "Quelle enzyme fixe le CO₂ dans le cycle de Calvin ?", tint: Color(hex: 0x47665A)),
        SampleCard(subject: "Biologie", question: "Où se déroule la phase photochimique ?", tint: Color(hex: 0x47665A)),
        SampleCard(subject: "Maths", question: "Quelle est la dérivée de ln(x) ?", tint: Color(hex: 0x4F5A72)),
        SampleCard(subject: "Maths", question: "Comment calculer un coefficient directeur ?", tint: Color(hex: 0x4F5A72)),
        SampleCard(subject: "Espagnol", question: "Comment traduire « apprendre par cœur » ?", tint: Color(hex: 0x8C6A3F)),
        SampleCard(subject: "Philosophie", question: "Que désigne l'impératif catégorique ?", tint: Color(hex: 0x6E5566)),
        SampleCard(subject: "Physique", question: "Qu'énonce la deuxième loi de Newton ?", tint: Color(hex: 0x5B5BD6)),
        SampleCard(subject: "Droit", question: "Quelles sont les conditions de validité d'un contrat ?", tint: Color(hex: 0x4A6741))
    ]

    @State private var revealed = 0

    private var isFinished: Bool { revealed >= cards.count }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ta première pile",
            title: "Tes cartes sont prêtes.",
            subtitle: "Voilà ce que Micabo produit à partir d'un cours. Recto court, verso précis, rien à recopier.",
            titleSize: 28
        ) {
            VStack(alignment: .leading, spacing: 12) {
                counter

                VStack(spacing: 9) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        if index < revealed {
                            SampleCardRow(subject: card.subject, question: card.question, tint: card.tint)
                                .transition(
                                    .asymmetric(
                                        insertion: .offset(y: 18).combined(with: .opacity).combined(with: .scale(scale: 0.96)),
                                        removal: .opacity
                                    )
                                )
                        }
                    }
                }
            }
        } footer: {
            OnboardingContinueButton(title: "Suivant", isEnabled: isFinished) {
                model.advance()
            }
        }
        .onAppear(perform: revealCards)
    }

    private var counter: some View {
        HStack(spacing: 8) {
            Image(systemName: isFinished ? "checkmark.circle.fill" : "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isFinished ? MicaboColor.positive : MicaboColor.accent)
                .contentTransition(.symbolEffect(.replace))

            Text("\(revealed) cartes générées")
                .font(MicaboFont.hanken(13, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .contentTransition(.numericText())

            Spacer(minLength: 0)

            Text("4 cours")
                .font(MicaboFont.hanken(11, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 13)
        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
    }

    private func revealCards() {
        for index in cards.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(index) * 0.13) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.76)) {
                    revealed = index + 1
                }
                Haptics.tick()

                if index == cards.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        Haptics.success()
                    }
                }
            }
        }
    }
}

private struct SampleCardRow: View {
    let subject: String
    let question: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint)
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(subject.uppercased())
                    .font(MicaboFont.hanken(9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(MicaboColor.inkTertiary)

                Text(question)
                    .font(MicaboFont.hanken(14, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }
}
