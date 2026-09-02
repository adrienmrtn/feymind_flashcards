import SwiftUI

/// Objectifs. Plusieurs réponses possibles, validées par le bouton du bas.
///
/// La question demandait « tu veux retenir quoi ? », et les réponses n'y répondaient pas :
/// « préparer un concours » ou « monter en compétences » ne sont pas des choses qu'on
/// retient, ce sont des raisons d'apprendre. Elle demande donc ce qu'elle demande vraiment.
struct GoalStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var selection: Set<LearningGoal> = []

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.goalTitle") ?? "Quels sont tes objectifs ?",
            subtitle: i18n?.t("ios.goalSubtitle") ?? "Plusieurs réponses possibles.",
            animatesTitle: true
        ) {
            VStack(spacing: 8) {
                ForEach(LearningGoal.allCases) { goal in
                    OnboardingChoiceRow(
                        title: goal.title(locale: i18n?.locale ?? .resolved()),
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
        if selection.contains(goal) {
            selection.remove(goal)
        } else {
            selection.insert(goal)
        }
        model.goals = selection
    }
}
