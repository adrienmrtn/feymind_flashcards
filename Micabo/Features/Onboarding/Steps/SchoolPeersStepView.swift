import SwiftUI

/// Preuve sociale après le choix d'établissement : l'effectif, posé à même le fond.
struct SchoolPeersStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var peers = 0

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
            titleSize: 28
        ) {
            VStack(spacing: 8) {
                Text("\(peers)")
                    .font(MicaboFont.hanken(72, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-2.5)
                    .monospacedDigit()

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
            .padding(.vertical, MicaboSpacing.lg)
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
        .onAppear {
            // Effectif stable pour cette session, tiré une seule fois.
            if peers == 0 { peers = Int.random(in: 30...70) }
        }
    }
}
