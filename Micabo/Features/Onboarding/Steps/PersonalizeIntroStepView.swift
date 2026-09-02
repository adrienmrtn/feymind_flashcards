import SwiftUI

/// Transition avant les questions de personnalisation. **Une phrase, et rien d'autre.**
///
/// Il y avait ici un sous-titre et trois rangées à picto qui annonçaient les trois
/// questions suivantes. Annoncer trois questions prend plus de temps que d'y répondre :
/// tout est parti. Ce qui reste est le titre, dont le gras se pose mot par mot — c'est la
/// seule chose à regarder, et elle donne au bouton une raison d'arriver après.
struct PersonalizeIntroStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var isTitleWritten = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MicaboSpacing.lg)

            OnboardingWordByWordTitle(
                text: i18n?.t("ios.personalizeIntro") ?? "Quelques questions\npour personnaliser\nton expérience.",
                size: 32
            ) {
                withAnimation(OnboardingMotion.enter) {
                    isTitleWritten = true
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)

            Spacer(minLength: MicaboSpacing.lg)

            MicaboBottomBar {
                OnboardingContinueButton(title: i18n?.t("onboarding.letsGo") ?? "C'est parti") {
                    model.advance()
                }
                .opacity(isTitleWritten ? 1 : 0)
                .offset(y: isTitleWritten ? 0 : 8)
                // Tant que le titre s'écrit, le bouton n'est pas seulement invisible : il
                // ne prend pas les appuis. Un bouton qu'on peut toucher sans le voir est
                // pire qu'un bouton absent.
                .allowsHitTesting(isTitleWritten)
            }
        }
    }
}
