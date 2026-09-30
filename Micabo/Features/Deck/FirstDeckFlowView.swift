import SwiftData
import SwiftUI

/// **Le deck construit à la sortie du parcours, pour que l'app s'ouvre sur Decks.**
///
/// Il passe du parcours à `RootTabView` par ici plutôt que par un réglage : c'est un objet
/// du même lancement, pas un état à retrouver au suivant. La liste ne l'ouvre pas d'elle-
/// même — l'élève vient de le parcourir — ; elle consomme la remise, et le deck attend en
/// tête. S'il n'est pas consommé — l'app tuée entre les deux — rien n'est perdu : le deck
/// est dans la bibliothèque.
@MainActor
enum FirstDeckHandoff {
    static var course: Course?
}

/// **« Créons ton premier cours ensemble. »**
///
/// Ce qui suit le paywall, et ce qui précède l'app. Quelqu'un qui sort du parcours n'a
/// rien à voir dans une liste vide : l'écran qui l'attend est une phrase, un bouton, puis
/// la création du premier deck — la même que partout ailleurs, **sans croix**. Il n'y a
/// nulle part où revenir, et une croix qui mène sur du vide n'est pas une sortie.
///
/// La page reste blanche d'un bout à l'autre, comme le parcours : le passage de l'un à
/// l'autre est un fondu, et rien d'autre.
struct FirstDeckFlowView: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var isSettingUp = false

    var body: some View {
        ZStack {
            OnboardingPalette.white.ignoresSafeArea()

            if isSettingUp {
                DeckSetupFlowView(
                    isDismissable: false,
                    onCreated: { course in
                        FirstDeckHandoff.course = course
                        // Lever le drapeau fait basculer `RootView` sur l'app, ouverte
                        // sur Decks, où ce cours attend en tête.
                        OnboardingPreferences.pendingFirstImport = false
                    },
                    onCancel: {}
                )
                .transition(.opacity)
            } else {
                intro
                    .transition(.opacity)
            }
        }
        .animation(OnboardingMotion.page, value: isSettingUp)
        .environment(\.onboardingSurface, .canvas)
        .preferredColorScheme(.light)
        // La page d'intro est le premier cran de l'entonnoir d'import : sans elle, on ne
        // saurait pas combien s'arrêtent avant même la première question.
        .onAppear {
            Analytics.track(.deckSetupStep, ["step": "firstDeckIntro", "index": -1, "first": true])
        }
    }

    private var intro: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(OnboardingPalette.card)
                        .frame(width: 112, height: 112)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(OnboardingPalette.ink)
                }
                .accessibilityHidden(true)
                .onboardingAppear(index: 0)

                Text(i18n.t("ios.firstDeck.title"))
                    .font(OnboardingPalette.title(34))
                    .foregroundStyle(OnboardingPalette.ink)
                    .tracking(-0.9)
                    .lineSpacing(-2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 1)

                Text(i18n.t("ios.firstDeck.sub"))
                    .font(MicaboFont.ui(15, weight: .regular))
                    .foregroundStyle(OnboardingPalette.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MicaboSpacing.md)
                    .onboardingAppear(index: 2)
            }
            .padding(.horizontal, MicaboSpacing.screen)

            Spacer(minLength: 0)

            MicaboBottomBar(background: OnboardingPalette.white) {
                OnboardingContinueButton(title: i18n.t("ios.firstDeck.cta")) {
                    Haptics.medium()
                    isSettingUp = true
                }
                .onboardingAppear(index: 3)
            }
        }
    }
}
