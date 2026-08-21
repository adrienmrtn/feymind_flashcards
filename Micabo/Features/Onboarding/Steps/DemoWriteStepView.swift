import SwiftUI

/// Écran 9b : la génération. Elle est simulée, donc elle va vite — trois secondes,
/// le temps de voir la page se transformer en pile de cartes et les étapes se cocher.
/// Aucune latence n'est mimée : l'écran montre un mécanisme, il ne fait pas patienter.
struct DemoWriteStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var completedSteps = 0
    @State private var cardsOut = 0
    @State private var sweep = 0.0
    @State private var didStart = false

    private var steps: [String] { OnboardingDemo.generationSteps }
    private var cards: [OnboardingDemo.Card] { OnboardingDemo.cards }
    private var isFinished: Bool { cardsOut == cards.count }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Comment ça marche · 2 sur 3",
            title: "Micabo écrit tes cartes.",
            titleSize: 28,
            scrolls: false
        ) {
            VStack(spacing: 24) {
                stage
                stepList
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } footer: {
            status
        }
        .onAppear(perform: run)
    }

    // MARK: - La page devient une pile

    private var stage: some View {
        ZStack {
            DemoDocumentPage(isScanning: completedSteps < 1, sweepProgress: sweep)
                .frame(width: 152)
                .scaleEffect(cardsOut > 0 ? 0.9 : 1)
                .rotationEffect(.degrees(cardsOut > 0 ? -7 : 0))
                .blur(radius: cardsOut > 0 ? 2 : 0)
                .opacity(pageOpacity)

            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                if index < cardsOut {
                    DemoMiniCard(index: index + 1, question: card.front)
                        .frame(width: 236)
                        .rotationEffect(.degrees(angle(for: index)))
                        .offset(y: lift(for: index))
                        .zIndex(Double(index))
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.7).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                }
            }
        }
        .frame(height: 214)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: cardsOut)
    }

    /// La page s'efface au fur et à mesure que les cartes en sortent.
    private var pageOpacity: Double {
        switch cardsOut {
        case 0:
            return 1.0
        case 1:
            return 0.45
        default:
            return 0.0
        }
    }

    /// Les cartes se posent en éventail, la dernière écrite sur le dessus.
    private func angle(for index: Int) -> Double {
        Double(index - 1) * 5.5
    }

    private func lift(for index: Int) -> CGFloat {
        CGFloat(1 - index) * 13
    }

    // MARK: - Les étapes

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                stepRow(title: step, isDone: index < completedSteps, isActive: index == completedSteps)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    private func stepRow(title: String, isDone: Bool, isActive: Bool) -> some View {
        HStack(spacing: 11) {
            ZStack {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MicaboColor.progress)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                } else if isActive {
                    ProgressView()
                        .controlSize(.small)
                        .tint(MicaboColor.progress)
                } else {
                    Circle()
                        .strokeBorder(MicaboColor.strokeStrong, lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                }
            }
            .frame(width: 20, height: 20)

            Text(title)
                .font(MicaboFont.hanken(14, weight: isDone || isActive ? .medium : .regular))
                .foregroundStyle(isDone || isActive ? MicaboColor.ink : MicaboColor.inkTertiary)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Pied d'écran

    @ViewBuilder
    private var status: some View {
        HStack(spacing: 8) {
            if isFinished {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MicaboColor.positive)

                Text("\(cards.count) cartes prêtes")
                    .font(MicaboFont.hanken(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(MicaboColor.progress)

                Text("Trois secondes, pas plus")
                    .font(MicaboFont.hanken(13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .animation(.easeOut(duration: 0.2), value: isFinished)
    }

    // MARK: - Déroulé

    /// 0,75 s par étape, une carte qui sort juste derrière, et on enchaîne à 3,2 s.
    private func run() {
        guard !didStart else { return }
        didStart = true

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model

        withAnimation(.easeInOut(duration: 0.85)) {
            sweep = 1
        }

        for index in steps.indices {
            // La première étape se coche à la fin du balayage, pas avant : sinon la
            // lueur de lecture disparaît en pleine descente.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85 + Double(index) * 0.75) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    completedSteps = index + 1
                }
                Haptics.tick()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05 + Double(index) * 0.75) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    cardsOut = min(index + 1, cards.count)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            Haptics.success()
            flow.advance()
        }
    }
}
