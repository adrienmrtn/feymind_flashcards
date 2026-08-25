import SwiftUI

/// Objectifs. Plusieurs réponses possibles, validées par le bouton du bas.
struct GoalStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var selection: Set<LearningGoal> = []

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Question 1 sur 3",
            title: "Tu veux retenir quoi ?",
            subtitle: "Plusieurs réponses possibles.",
            animatesTitle: true
        ) {
            VStack(spacing: 8) {
                ForEach(LearningGoal.allCases) { goal in
                    OnboardingChoiceRow(
                        title: goal.title,
                        emoji: goal.emoji,
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
