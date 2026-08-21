import SwiftUI

/// Écran 5 : objectifs. Plusieurs réponses possibles, validées par le bouton du bas.
struct GoalStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var selection: Set<LearningGoal> = []

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Question 1 sur 3",
            title: "C'est quoi tes objectifs ?",
            subtitle: "Choisis tout ce qui te ressemble."
        ) {
            VStack(spacing: 10) {
                ForEach(LearningGoal.allCases) { goal in
                    OnboardingChoiceRow(
                        title: goal.title,
                        subtitle: goal.subtitle,
                        systemImage: goal.systemImage,
                        isSelected: selection.contains(goal)
                    ) {
                        toggle(goal)
                    }
                }
            }
        } footer: {
            OnboardingContinueButton(isEnabled: !selection.isEmpty) {
                model.goals = selection
                model.advance()
            }
        }
        .onAppear {
            if selection.isEmpty {
                selection = model.goals
            }
        }
    }

    private func toggle(_ goal: LearningGoal) {
        Haptics.selection()
        if selection.contains(goal) {
            selection.remove(goal)
        } else {
            selection.insert(goal)
        }
        model.goals = selection
    }
}
