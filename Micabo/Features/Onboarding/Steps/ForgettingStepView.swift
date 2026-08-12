import SwiftUI

/// Écran 5 : question fermée sur l'oubli. Sert d'accroche à la démonstration qui suit.
struct ForgettingStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var selection: Bool?

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Question 2 sur 3",
            title: "Tu as l'impression d'oublier ce que tu apprends ?",
            subtitle: "Sois honnête, personne ne regarde."
        ) {
            VStack(spacing: 10) {
                OnboardingChoiceRow(
                    title: "Oui, tout le temps",
                    subtitle: "Relu la veille, envolé le lendemain",
                    systemImage: "cloud.rain",
                    isSelected: selection == true
                ) {
                    select(true)
                }

                OnboardingChoiceRow(
                    title: "Non, ça va",
                    subtitle: "Je retiens plutôt bien",
                    systemImage: "checkmark.seal",
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
        model.forgetsOften = answer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            model.advance()
        }
    }
}
