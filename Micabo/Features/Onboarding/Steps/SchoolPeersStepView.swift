import SwiftUI

/// Preuve sociale après le choix d'établissement : un compteur qui monte jusqu'à
/// un effectif aléatoire (30–70) pour le même lieu.
struct SchoolPeersStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var displayed = 0.0
    @State private var target = 0
    @State private var didStart = false

    private var schoolLabel: String {
        let name = model.institutionName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return name
        }
        return "ton établissement"
    }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Communauté",
            title: "Tu n'es pas seul.",
            subtitle: nil,
            titleSize: 28
        ) {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    CountingText(
                        value: displayed,
                        font: MicaboFont.hanken(64, weight: .bold),
                        color: MicaboColor.ink
                    )
                    .tracking(-2)

                    (
                        Text("personnes de ")
                        + Text(schoolLabel).font(MicaboFont.hanken(16, weight: .semibold))
                        + Text(" utilisent déjà Micabo pour étudier.")
                    )
                    .font(MicaboFont.hanken(16, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .padding(.horizontal, 18)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                        .strokeBorder(MicaboColor.stroke, lineWidth: 1)
                }

                HStack(spacing: 10) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MicaboColor.accent)
                    Text("Ils révisent déjà avec Micabo — tu peux les rejoindre.")
                        .font(MicaboFont.hanken(13, weight: .regular))
                        .foregroundStyle(Color(hex: 0x4A463F))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MicaboColor.infoSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
            }
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
        .onAppear(perform: runCounter)
    }

    private func runCounter() {
        guard !didStart else { return }
        didStart = true

        // Effectif stable pour cette session : recalculé seulement à l'apparition.
        target = Int.random(in: 30...70)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 1.45)) {
                displayed = Double(target)
            }
            Haptics.burst(count: 16, over: 1.35, intensity: 0.32)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                Haptics.success()
            }
        }
    }
}
