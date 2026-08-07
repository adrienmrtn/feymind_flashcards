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
            FeyColor.canvas.opacity(0.98).ignoresSafeArea()

            VStack(spacing: FeySpacing.lg) {
                ZStack {
                    Circle()
                        .fill(FeyColor.surfaceSunken)
                        .frame(width: 104, height: 104)
                        .scaleEffect(pulse ? 1.1 : 0.94)

                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(FeyColor.onInk)
                        .frame(width: 72, height: 72)
                        .background(FeyColor.ink, in: Circle())
                }
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

                Text(title)
                    .font(FeyFont.screenTitle)
                    .foregroundStyle(FeyColor.ink)
                    .tracking(FeyTracking.tight)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: FeySpacing.sm) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: FeySpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(index <= currentStep ? FeyColor.ink : FeyColor.surfaceSunken)
                                    .frame(width: 20, height: 20)

                                if index < currentStep {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(FeyColor.onInk)
                                } else if index == currentStep {
                                    Circle()
                                        .fill(FeyColor.onInk)
                                        .frame(width: 6, height: 6)
                                }
                            }

                            Text(step)
                                .font(FeyFont.body)
                                .foregroundStyle(index <= currentStep ? FeyColor.ink : FeyColor.inkTertiary)
                        }
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .frame(maxWidth: 340, alignment: .leading)

                Text("Cela prend en général moins d'une minute.")
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)
            }
            .padding(FeySpacing.lg)
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
