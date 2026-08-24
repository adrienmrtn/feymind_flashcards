import SwiftUI

/// Question fermée sur l'oubli. Sert d'accroche à la démonstration qui suit.
struct ForgettingStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var selection: Bool?

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Question 2 sur 3",
            title: "Tu oublies ce que\ntu apprends ?",
            subtitle: "Sois honnête, personne ne regarde.",
            scrolls: false
        ) {
            VStack(spacing: 8) {
                OnboardingChoiceRow(title: "Oui, tout le temps", isSelected: selection == true) {
                    select(true)
                }

                OnboardingChoiceRow(title: "Non, ça va", isSelected: selection == false) {
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
