import SwiftUI

/// Question fermée sur l'oubli. Sert d'accroche à la démonstration qui suit.
struct ForgettingStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var selection: Bool?

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Question 2 sur 3",
            title: "Tu oublies ce que\ntu apprends ?",
            scrolls: false,
            animatesTitle: true
        ) {
            // Deux réponses, deux cases de même taille posées côte à côte : la question
            // est un choix, et un choix se regarde d'un coup.
            HStack(spacing: 10) {
                OnboardingChoiceTile(
                    title: "Oui, tout le temps",
                    emoji: "😮‍💨",
                    isSelected: selection == true
                ) {
                    select(true)
                }

                OnboardingChoiceTile(
                    title: "Non, ça va",
                    emoji: "😌",
                    isSelected: selection == false
                ) {
                    select(false)
                }
            }
        } footer: {
            OnboardingHint(text: "Appuie sur une réponse pour continuer")
        }
    }

    private func select(_ answer: Bool) {
        guard selection == nil else { return }
        Haptics.selection()
        selection = answer

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model
        flow.forgetsOften = answer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            flow.advance()
        }
    }
}
