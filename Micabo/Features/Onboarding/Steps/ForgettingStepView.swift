import SwiftUI

/// Question sur l'oubli. Sert d'accroche à la démonstration qui suit.
///
/// Quatre réponses, et non plus deux cases côte à côte. Le oui/non forçait la caricature
/// sur une question à laquelle personne ne répond par oui ou par non : les deux réponses
/// du milieu, ajoutées ici, sont celles où la plupart des étudiants se reconnaissent, et
/// ce sont aussi les plus utiles — elles disent que le problème est la méthode.
///
/// Les réponses étant longues, elles se lisent en rangées pleine largeur, et elles
/// occupent la page plutôt que de se serrer sous le titre.
struct ForgettingStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var selection: ForgettingHabit?

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Question 2 sur 3",
            title: "En général, oublies-tu\nce que tu apprends ?",
            titleSize: 28,
            contentSpacing: MicaboSpacing.lg,
            scrolls: false,
            animatesTitle: true,
            expandsContent: true
        ) {
            OnboardingAnswerList(ForgettingHabit.allCases, spacing: 8) { habit in
                OnboardingChoiceRow(
                    title: habit.title,
                    emoji: habit.emoji,
                    isSelected: selection == habit,
                    fillsHeight: true
                ) {
                    select(habit)
                }
            }
        } footer: {
            OnboardingHint(text: "Appuie sur une réponse pour continuer")
        }
    }

    private func select(_ answer: ForgettingHabit) {
        guard selection == nil else { return }
        selection = answer

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model
        flow.forgetting = answer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            flow.advance()
        }
    }
}
