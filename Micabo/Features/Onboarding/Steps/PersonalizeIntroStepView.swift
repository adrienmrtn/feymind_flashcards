import SwiftUI

/// Écran 3 : transition avant les questions de personnalisation.
struct PersonalizeIntroStepView: View {
    @Environment(OnboardingModel.self) private var model

    private let points: [(String, String)] = [
        ("target", "Ton objectif, pour choisir le bon rythme"),
        ("books.vertical", "Tes matières, pour te proposer les bons cours"),
        ("clock", "Ton temps, pour des sessions qui tiennent dans ta journée")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MicaboSpacing.lg)

            VStack(alignment: .leading, spacing: 18) {
                Text("Quelques questions\npour personnaliser\nton expérience.")
                    .font(MicaboFont.hanken(32, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 0, stagger: 0.1)

                Text("Trois minutes, pas plus. Tout reste sur ton téléphone.")
                    .font(MicaboFont.hanken(15, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .onboardingAppear(index: 1, stagger: 0.1)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        HStack(spacing: 12) {
                            Image(systemName: point.0)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(MicaboColor.accent)
                                .frame(width: 32, height: 32)
                                .background(MicaboColor.infoSoft, in: Circle())

                            Text(point.1)
                                .font(MicaboFont.hanken(14, weight: .medium))
                                .foregroundStyle(Color(hex: 0x4A463F))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .onboardingAppear(index: 2 + index, stagger: 0.1)
                    }
                }
                .padding(.top, MicaboSpacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MicaboSpacing.screen)

            Spacer(minLength: MicaboSpacing.lg)

            MicaboBottomBar {
                OnboardingContinueButton(title: "C'est parti") {
                    model.advance()
                }
                .onboardingAppear(index: 5, stagger: 0.1)
            }
        }
    }
}
