import SwiftUI

/// Aiguillage au lancement : parcours d'accueil au premier démarrage, application ensuite.
/// Le drapeau vit dans les réglages système, ce qui permet de relancer le parcours
/// depuis l'écran Réglages sans redémarrer l'app.
struct RootView: View {
    @AppStorage(OnboardingPreferences.Key.completed) private var didCompleteOnboarding = false

    var body: some View {
        ZStack {
            if didCompleteOnboarding {
                RootTabView()
                    .transition(.opacity)
            } else {
                OnboardingFlowView {
                    didCompleteOnboarding = true
                }
                .transition(.opacity.combined(with: .scale(scale: 1.03)))
            }
        }
        .animation(.easeInOut(duration: 0.45), value: didCompleteOnboarding)
    }
}
