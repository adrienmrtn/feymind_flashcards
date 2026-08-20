import SwiftUI

/// Écran 15 : mise en place du profil, en trois temps. Purement visuel :
/// les réponses sont déjà enregistrées depuis les écrans précédents.
struct PersonalizingStepView: View {
    @Environment(OnboardingModel.self) private var model

    private let phases = [
        "Analyse de ton objectif",
        "Calibrage de la répétition espacée",
        "Préparation de ta première session"
    ]

    @State private var completedPhases = 0
    @State private var didStart = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 26) {
                MicaboProgressRing(
                    progress: Double(completedPhases) / Double(phases.count),
                    lineWidth: 6
                )
                .frame(width: 84, height: 84)
                .overlay {
                    Text("\(Int(Double(completedPhases) / Double(phases.count) * 100)) %")
                        .font(MicaboFont.hanken(15, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                VStack(spacing: 8) {
                    Text("On personnalise ton profil")
                        .font(MicaboFont.hanken(24, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .tracking(-0.5)

                    Text("Quelques secondes, promis.")
                        .font(MicaboFont.hanken(14, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }

                VStack(alignment: .leading, spacing: 13) {
                    ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                        PhaseRow(
                            title: phase,
                            isDone: index < completedPhases,
                            isActive: index == completedPhases
                        )
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                        .strokeBorder(MicaboColor.stroke, lineWidth: 1)
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)

            Spacer(minLength: 0)
        }
        .onAppear(perform: runPhases)
    }

    private func runPhases() {
        guard !didStart else { return }
        didStart = true

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model

        for index in phases.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9 + Double(index) * 1.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    completedPhases = index + 1
                }
                Haptics.tick()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9 + Double(phases.count) * 1.15 + 0.5) {
            Haptics.success()
            flow.advance()
        }
    }
}

private struct PhaseRow: View {
    let title: String
    let isDone: Bool
    let isActive: Bool

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MicaboColor.positive)
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
                .font(MicaboFont.hanken(14, weight: isActive || isDone ? .medium : .regular))
                .foregroundStyle(isDone || isActive ? MicaboColor.ink : MicaboColor.inkTertiary)

            Spacer(minLength: 0)
        }
    }
}
