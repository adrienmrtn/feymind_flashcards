import SwiftUI

/// **« Tu as choisi dix minutes par jour. Signe ici. »**
///
/// L'écran qui suit le temps par jour, et qui le fait tenir. Un tableau blanc, le doigt
/// qui laisse un trait, et un bouton qui dit « j'ai signé » : c'est un engagement qu'on
/// prend devant soi-même, et il pèse plus qu'une case cochée parce qu'il a coûté un geste.
/// C'est l'écran de contrat des apps de sport, ramené à ce qu'il fait vraiment.
///
/// **La signature n'est pas une donnée.** Elle vit dans l'état de la vue et meurt avec
/// elle ; rien n'est enregistré, ni ici, ni sur le serveur.
struct CommitmentStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var strokes: [[CGPoint]] = []

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.commit.title", ["n": "\(model.minutesPerDay)"]),
            subtitle: i18n.t("ios.commit.sub"),
            scrolls: false,
            expandsContent: true
        ) {
            VStack(spacing: 12) {
                Spacer(minLength: 0)

                OnboardingSignaturePad(
                    strokes: $strokes,
                    placeholder: i18n.t("ios.commit.hint")
                )

                Button {
                    strokes.removeAll()
                    Haptics.selection()
                } label: {
                    Text(i18n.t("ios.commit.clear"))
                        .font(MicaboFont.ui(13.5, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.vertical, 6)
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
                .opacity(strokes.isEmpty ? 0 : 1)
                .disabled(strokes.isEmpty)
                .animation(OnboardingMotion.enter, value: strokes.isEmpty)

                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } footer: {
            OnboardingContinueButton(
                title: i18n.t("ios.commit.cta"),
                isEnabled: !strokes.isEmpty
            ) {
                model.advance()
            }
        }
    }
}
