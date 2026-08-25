import SwiftUI

/// La porte du compte, et la clé qui la referme.
///
/// Le drapeau est partagé : c'est l'écran de connexion du parcours d'accueil qui le pose
/// quand on choisit de passer, et `RootView` qui le relit. Sans une clé commune, passer la
/// connexion pendant le parcours se payait par un second écran de connexion à la sortie.
enum AccountGate {
    static let skippedKey = "micabo.auth.skipped"
}

/// Aiguillage au lancement : parcours d'accueil, puis l'application.
///
/// **Le compte se demande maintenant dans le parcours**, entre « c'est à ton tour » et
/// l'offre d'essai. Il s'est longtemps demandé ici, après le parcours, ce qui donnait deux
/// écrans de connexion à la suite : celui du parcours ne branchait rien, et celui-ci
/// reposait la question à quelqu'un qui venait d'y répondre.
///
/// L'écran ci-dessous reste, mais comme **rattrapage** : il ne s'affiche que pour quelqu'un
/// qui a fini le parcours sans compte et sans passer explicitement — un cas qui n'arrive
/// plus que sur une déconnexion depuis les réglages.
///
/// Le compte reste **facultatif**, et ce n'est pas une faiblesse : Micabo a fonctionné sans
/// compte depuis le premier jour, tout est écrit sur l'appareil, et l'app doit continuer de
/// s'ouvrir dans un train sans réseau. « Continuer sans compte » n'est donc pas une dérobade,
/// c'est le mode d'origine — il se rattrape à tout moment depuis les réglages, et la synchro
/// remonte alors ce qui a été accumulé entre-temps.
struct RootView: View {
    @AppStorage(OnboardingPreferences.Key.completed) private var didCompleteOnboarding = false
    /// Vrai quand on a explicitement choisi de rester local. Le drapeau est nécessaire :
    /// sans lui, l'écran de compte reviendrait à chaque lancement.
    @AppStorage(AccountGate.skippedKey) private var didSkipAccount = false

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
