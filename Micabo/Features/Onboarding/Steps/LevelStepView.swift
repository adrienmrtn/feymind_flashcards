import SwiftUI

/// Où en est l'étudiant. **Les réponses sont celles de son pays.**
///
/// L'écran servait sept réponses françaises à tout le monde — Lycée, Prépa, Licence, PASS,
/// Master, Concours — ce qui laissait un Américain, un Britannique ou un Québécois sans une
/// seule réponse juste. La question vient donc après le pays, et sa liste vient de lui : les
/// paliers réels du système choisi, et à défaut une échelle générique en anglais.
///
/// Aucune réponse n'est cochée d'avance : c'est la question qui situe la rédaction de toutes
/// les fiches, et on ne la devine pas à la place de l'étudiant.
struct LevelStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Pour commencer",
            title: "Tu en es où ?",
            titleSize: 32,
            contentSpacing: MicaboSpacing.lg,
            scrolls: false,
            animatesTitle: true,
            expandsContent: true
        ) {
            OnboardingAnswerList(model.country.stages, spacing: 8) { stage in
                OnboardingChoiceRow(
                    title: stage.title,
                    emoji: stage.emoji,
                    isSelected: model.stage == stage,
                    fillsHeight: true
                ) {
                    model.stage = stage
                }
            }
        } footer: {
            OnboardingContinueButton(isEnabled: model.stage != nil) {
                model.advance()
            }
        }
    }
}
