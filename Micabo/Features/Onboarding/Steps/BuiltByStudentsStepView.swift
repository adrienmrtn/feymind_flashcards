import SwiftUI

/// Écran 3 : d'où vient l'app. Deux phrases, et on enchaîne.
///
/// Il y avait ici un titre de vingt-cinq mots, un sous-titre, et un bloc blanc avec trois
/// rangées à picto. Tout est parti. Un écran qui n'a rien à demander n'a pas besoin de
/// meubler : il dit une chose, et le bouton est déjà en bas de l'écran quand on a fini de
/// lire. Les trois promesses qui vivaient dans le bloc sont d'ailleurs montrées, et non
/// annoncées, par les trois écrans de démonstration qui suivent.
struct BuiltByStudentsStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Par des étudiants",
            title: "On a fait Micabo\npour nous.",
            subtitle: "Trop de cours à retenir, pas assez de temps. On a réglé le problème, puis on en a fait une app.",
            titleSize: 32,
            scrolls: false
        ) {
            EmptyView()
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}
