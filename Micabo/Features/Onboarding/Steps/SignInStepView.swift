import SwiftUI

/// La connexion, posée juste après « c'est à ton tour » et juste avant l'offre d'essai.
///
/// Elle arrive à la fin et pas au début, et c'est la seule position défendable : demander un
/// compte à l'ouverture, c'est demander un compte pour une app qu'on n'a pas encore vue
/// fonctionner. Ici, la démonstration est passée, le parcours est construit, et le compte
/// sert à ne pas le perdre.
///
/// **Les trois flux sont branchés pour de vrai.** L'écran se contentait d'appeler
/// `model.advance()` sur les deux boutons : on croyait s'être connecté, rien n'était créé, et
/// l'app redemandait un compte juste après le parcours. Apple passe par son bouton natif —
/// ses règles d'interface l'imposent — et Google par une page web isolée. Une connexion
/// réussie avance d'elle-même vers l'offre ; un refus laisse l'écran en place avec sa raison.
///
/// Le chrome (logo, titre, boutons, légal) vit dans `SignInScreen` : c'est **le même
/// écran** que celui de la reconnexion, avec le titre de fin de parcours.
///
/// Le « Passer » en haut à droite est temporaire, et il fait deux choses : il avance, et il
/// **referme la porte du compte** pour que l'app ne repose pas la question à l'écran suivant.
struct SignInStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AuthController.self) private var auth

    /// Le même drapeau que celui lu par `RootView` : passer ici vaut passer pour de bon.
    @AppStorage(AccountGate.skippedKey) private var didSkipAccount = false

    @State private var didAdvance = false

    var body: some View {
        SignInScreen(
            placement: .page,
            titleKey: "onboarding.compteTitle",
            subtitleKey: "onboarding.compteSubtitle",
            showsLanguageSwitcher: false,
            onSkip: skip
        )
        // La connexion se termine dans le contrôleur, pas dans le bouton : c'est le passage à
        // l'état « connecté » qui fait avancer, quel que soit le fournisseur emprunté.
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            guard isSignedIn else { return }
            advanceOnce()
        }
        .onAppear {
            // Déjà connecté avant d'arriver ici, par un lien reçu par courriel par exemple :
            // on ne redemande pas.
            if auth.isSignedIn { advanceOnce() }
        }
    }

    // MARK: - Sorties

    private func advanceOnce() {
        guard !didAdvance else { return }
        didAdvance = true
        auth.clearMessage()
        model.advance()
    }

    private func skip() {
        didSkipAccount = true
        advanceOnce()
    }
}
