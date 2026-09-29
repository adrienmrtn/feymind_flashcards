import SwiftUI

/// **Un écran du parcours qui n'est pas encore écrit.**
///
/// Le parcours déclare tous ses écrans d'un coup, pour que l'ordre, la jauge et le retour
/// soient les bons dès le premier lot ; ceux des lots suivants passent par ici le temps
/// d'être dessinés. Il porte le titre définitif de l'écran et le rond fléché, et rien
/// d'autre : c'est une place réservée, pas une maquette.
struct OnboardingComingStepView: View {
    let step: OnboardingStep

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var title: String {
        switch step {
        case .trainPrompt: i18n.t("ios.onb.train.title")
        case .trainCards: i18n.t("ios.onb.train.title")
        case .wellDone: i18n.t("ios.onb.wellDone.title", ["name": model.displayName])
        case .socialProof: i18n.t("ios.onb.social.title")
        case .comparison: i18n.t("ios.onb.compare.title")
        default: step.analyticsName
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: MicaboSpacing.lg) {
                Spacer(minLength: 0)

                OnboardingAccentText(template: title, size: 30)
                    .padding(.horizontal, MicaboSpacing.screen)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(OnboardingPalette.cardStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .frame(height: 220)
                    .padding(.horizontal, MicaboSpacing.screen)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            OnboardingArrowBar {
                model.advance()
            }
        }
        .onboardingChromeInset(step.showsChrome)
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}
