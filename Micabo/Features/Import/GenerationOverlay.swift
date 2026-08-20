import Combine
import SwiftUI

/// Voile plein écran avec progression étape par étape.
struct GenerationOverlay: View {
    let title: String
    let steps: [String]

    @State private var currentStep = 0
    @State private var pulse = false

    private let timer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            MicaboColor.canvas.opacity(0.98).ignoresSafeArea()

            VStack(spacing: MicaboSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(MicaboColor.surfaceSunken)
                        .frame(width: 104, height: 104)
                        .scaleEffect(pulse ? 1.1 : 0.94)

                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(MicaboColor.onInk)
                        .frame(width: 72, height: 72)
                        .background(MicaboColor.ink, in: Circle())
                }
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

                Text(title)
                    .font(MicaboFont.hanken(25, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(MicaboTracking.tight)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: MicaboSpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(index <= currentStep ? MicaboColor.ink : MicaboColor.surfaceSunken)
                                    .frame(width: 20, height: 20)

                                if index < currentStep {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(MicaboColor.onInk)
                                } else if index == currentStep {
                                    Circle()
                                        .fill(MicaboColor.onInk)
                                        .frame(width: 6, height: 6)
                                }
                            }

                            Text(step)
                                .font(MicaboFont.body)
                                .foregroundStyle(index <= currentStep ? MicaboColor.ink : MicaboColor.inkTertiary)
                        }
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .frame(maxWidth: 340, alignment: .leading)

                Text("Cela prend en général moins d'une minute.")
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(MicaboSpacing.lg)
        }
        .onAppear { pulse = true }
        .onReceive(timer) { _ in
            guard currentStep < steps.count - 1 else { return }
            currentStep += 1
        }
        .transition(.opacity)
    }
}

#Preview {
    GenerationOverlay(
        title: "Création des flashcards",
        steps: ["Lecture du document", "Repérage des notions clés", "Rédaction des questions", "Vérification des réponses"]
    )
}
