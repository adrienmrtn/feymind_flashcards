import SwiftUI

/// Étapes affichées pendant un appel à l'IA.
struct GenerationStep: Identifiable, Equatable {
    let id = UUID()
    var label: String
}

/// Voile plein écran avec progression étape par étape.
struct GenerationOverlay: View {
    let title: String
    let steps: [String]
    var accent: Color = FeyColor.accent

    @State private var currentStep = 0
    @State private var pulse = false

    private let timer = Timer.publish(every: 2.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            FeyColor.canvas.opacity(0.97).ignoresSafeArea()

            VStack(spacing: FeySpacing.lg) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.10))
                        .frame(width: 108, height: 108)
                        .scaleEffect(pulse ? 1.12 : 0.94)

                    Circle()
                        .fill(accent.opacity(0.16))
                        .frame(width: 76, height: 76)
                        .scaleEffect(pulse ? 0.94 : 1.1)

                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(accent)
                }
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)

                Text(title)
                    .font(FeyFont.screenTitle)
                    .foregroundStyle(FeyColor.ink)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: FeySpacing.sm) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: FeySpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(index <= currentStep ? accent : FeyColor.surfaceSunken)
                                    .frame(width: 20, height: 20)

                                if index < currentStep {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                } else if index == currentStep {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 7, height: 7)
                                }
                            }

                            Text(step)
                                .font(FeyFont.body)
                                .foregroundStyle(index <= currentStep ? FeyColor.ink : FeyColor.inkTertiary)
                        }
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(FeySpacing.md)
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
        title: "Création du cours",
        steps: ["Lecture du document", "Repérage des idées clés", "Mise en forme des schémas", "Derniers ajustements"]
    )
}
