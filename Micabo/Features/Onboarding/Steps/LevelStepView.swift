import SwiftUI

/// Écran 2 : où en est l'étudiant.
///
/// C'est la première question du parcours, et elle vient juste après l'accroche parce
/// qu'elle situe tout le reste : un lycéen et un PASS n'ont ni les mêmes matières, ni les
/// mêmes examens, ni le même rythme.
///
/// Les sept réponses **occupent la page**, et c'est un changement de pied assumé. Elles
/// tenaient avant en pastilles serrées sous le titre : tout était visible d'un coup, mais
/// les deux tiers de l'écran restaient vides en dessous, et une question posée dans le
/// coin supérieur d'une page blanche se lit comme un formulaire. En rangées qui se
/// partagent la hauteur, le regard tombe sur les réponses, et le pouce les atteint sans
/// viser. Rien ne défile pour autant : sept rangées tiennent dans la page.
///
/// Le choix n'enchaîne pas tout seul : on peut se tromper, et « Continuer » laisse le
/// temps de se corriger.
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
            OnboardingAnswerList(StudyLevel.allCases, spacing: 8) { level in
                OnboardingChoiceRow(
                    title: level.title,
                    emoji: level.emoji,
                    isSelected: model.level == level,
                    fillsHeight: true
                ) {
                    Haptics.selection()
                    model.level = level
                }
            }
        } footer: {
            OnboardingContinueButton(isEnabled: model.level != nil) {
                model.advance()
            }
        }
    }
}
