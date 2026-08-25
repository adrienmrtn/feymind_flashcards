import SwiftUI

/// Écran 2 : où en est l'étudiant.
///
/// C'est la première question du parcours, et elle vient juste après l'accroche parce
/// qu'elle situe tout le reste : un lycéen et un PASS n'ont ni les mêmes matières, ni les
/// mêmes examens, ni le même rythme.
///
/// Sept réponses en pastilles et non en rangées. Sept rangées feraient un écran qu'on fait
/// défiler pour répondre à une question fermée ; en pastilles, tout est visible d'un coup.
/// Le choix n'enchaîne pas tout seul : on peut se tromper, et « Continuer » laisse le temps
/// de se corriger.
struct LevelStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Pour commencer",
            title: "Tu en es où ?",
            titleSize: 32,
            scrolls: false,
            animatesTitle: true
        ) {
            MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(StudyLevel.allCases) { level in
                    OnboardingChoiceChip(
                        title: level.title,
                        emoji: level.emoji,
                        isSelected: model.level == level
                    ) {
                        Haptics.selection()
                        model.level = level
                    }
                }
            }
        } footer: {
            OnboardingContinueButton(isEnabled: model.level != nil) {
                model.advance()
            }
        }
    }
}
