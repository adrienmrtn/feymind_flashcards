import SwiftUI

/// Aiguillage au lancement : parcours d'accueil, puis compte, puis l'application.
///
/// **L'ordre est un choix de parcours.** Le compte vient après les vingt écrans d'accueil,
/// parce que demander un effort avant d'avoir donné une raison ne marche pas ; et il vient
/// avant le premier import, parce qu'un cours importé sans compte n'aurait nulle part à aller.
///
/// Il reste **facultatif**, et ce n'est pas une faiblesse : Micabo a fonctionné sans compte
/// depuis le premier jour, tout est écrit sur l'appareil, et l'app doit continuer de s'ouvrir
/// dans un train sans réseau. « Continuer sans compte » n'est donc pas une dérobade, c'est le
/// mode d'origine — il se rattrape à tout moment depuis les réglages, et la synchro remonte
/// alors ce qui a été accumulé entre-temps.
struct RootView: View {
    @AppStorage(OnboardingPreferences.Key.completed) private var didCompleteOnboarding = false
    /// Vrai quand on a explicitement choisi de rester local. Le drapeau est nécessaire :
    /// sans lui, l'écran de compte reviendrait à chaque lancement.
    @AppStorage("micabo.auth.skipped") private var didSkipAccount = false

    @Environment(AuthController.self) private var auth

    private var showsAccountGate: Bool {
        didCompleteOnboarding && !auth.isSignedIn && !didSkipAccount && auth.state != .restoring
    }

    var body: some View {
        ZStack {
            if !didCompleteOnboarding {
                OnboardingFlowView {
                    didCompleteOnboarding = true
                }
                .transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else if showsAccountGate {
                AuthView { didSkipAccount = true }
                    .preferredColorScheme(.light)
                    .transition(.opacity)
            } else {
                // L'app est écrite en couleurs fixes : elle reste claire quel que soit
                // le réglage du téléphone. Le parcours d'accueil, lui, gère sa propre
                // bascule écran par écran.
                RootTabView()
                    .preferredColorScheme(.light)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: didCompleteOnboarding)
        .animation(.easeInOut(duration: 0.35), value: showsAccountGate)
        // Se connecter depuis les réglages referme la porte : sans ça, le drapeau « plus
        // tard » resterait vrai et l'écran de compte ne reviendrait jamais après une
        // déconnexion.
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if isSignedIn { didSkipAccount = false }
        }
    }
}
