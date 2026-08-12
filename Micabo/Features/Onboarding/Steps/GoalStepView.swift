import SwiftUI

/// Écran 4 : objectif principal. Pas de bouton, le choix fait avancer le parcours.
struct GoalStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var selection: LearningGoal?

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Question 1 sur 3",
            title: "C'est quoi ton objectif ?",
            subtitle: "Choisis ce qui te ressemble le plus."
        ) {
            VStack(spacing: 10) {
                ForEach(LearningGoal.allCases) { goal in
                    OnboardingChoiceRow(
                        title: goal.title,
                        subtitle: goal.subtitle,
                        systemImage: goal.systemImage,
                        isSelected: selection == goal
                    ) {
                        select(goal)
                    }
                }
            }
        } footer: {
            OnboardingHint(text: "Appuie sur une réponse pour continuer")
        }
    }

    private func select(_ goal: LearningGoal) {
        guard selection == nil else { return }
        Haptics.selection()
        selection = goal

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model
        flow.goal = goal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            flow.advance()
        }
    }
}
