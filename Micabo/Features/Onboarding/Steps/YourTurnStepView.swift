import SwiftUI

/// Écran 18 : le passage de relais. Une phrase, et rien d'autre.
///
/// C'est le pivot du parcours : jusqu'ici on a montré ce que Micabo fait et ce qu'il a fait
/// pour d'autres, à partir d'ici c'est cet étudiant-là qui s'y met. L'écran passe donc sur
/// l'encre, et c'est **le seul écran sombre du parcours** depuis que l'accroche est passée
/// au pastel : le noir ne sert plus qu'au moment où l'on s'adresse à quelqu'un au lieu de
/// lui montrer quelque chose.
///
/// Le gras se pose mot par mot, et le bouton n'arrive qu'une fois le dernier mot en place :
/// on ne saute pas une phrase qu'on est en train de voir s'écrire. La phrase n'a pas de
/// retour à la ligne écrit à la main, elle se replie toute seule — cadrer des lignes à la
/// main sur une phrase de seize mots, c'est cadrer pour un seul modèle de téléphone.
struct YourTurnStepView: View {
    @Environment(OnboardingModel.self) private var model

    private let surface = OnboardingStep.yourTurn.surface

    @State private var isTitleWritten = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MicaboSpacing.lg)

            OnboardingWordByWordTitle(
                text: "C'est maintenant à ton tour de découvrir la méthode d'apprentissage que tous les meilleurs élèves utilisent.",
                size: 28,
                wordDelay: 0.1
            ) {
                withAnimation(OnboardingMotion.enter) {
                    isTitleWritten = true
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)

            Spacer(minLength: MicaboSpacing.lg)

            MicaboBottomBar(background: surface.background) {
                OnboardingContinueButton(title: "Je m'y mets") {
                    model.advance()
                }
                .opacity(isTitleWritten ? 1 : 0)
                .offset(y: isTitleWritten ? 0 : 8)
                // Tant que la phrase s'écrit, le bouton n'est pas seulement invisible : il
                // ne prend pas les appuis. Un bouton qu'on peut toucher sans le voir est
                // pire qu'un bouton absent.
                .allowsHitTesting(isTitleWritten)
            }
        }
        .background(surface.background.ignoresSafeArea(edges: .bottom))
        .environment(\.onboardingSurface, surface)
    }
}
