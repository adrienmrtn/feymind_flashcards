import SwiftUI

/// **« Laisse-moi te montrer comment Micabo marche. »**
///
/// Le deuxième écran du parcours, entre l'accroche et la première explication. Il ne demande
/// rien et n'explique rien : la mascotte se présente, et dit ce qui va suivre, dans une
/// bulle. C'est l'écran qu'ont Hablo et Gizmo avant leurs questions, et il fait une chose
/// que le nôtre ne faisait pas — il donne un interlocuteur au parcours, avant de commencer
/// à poser des questions.
struct ShowMeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 26) {
                MicaboMascot(mood: .happy, size: 132)
                    .onboardingAppear(index: 0, stagger: 0.12)

                MicaboSpeechBubble(text: i18n.t("ios.intro.showMe"), tail: .top)
                    .padding(.horizontal, MicaboSpacing.xl)
                    .onboardingAppear(index: 1, stagger: 0.12)
            }

            Spacer(minLength: 0)

            MicaboBottomBar(background: MicaboColor.canvas) {
                OnboardingContinueButton(title: i18n.t("ios.intro.show"), isShiny: true) {
                    model.advance()
                }
                .onboardingAppear(index: 2, stagger: 0.12)
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}
