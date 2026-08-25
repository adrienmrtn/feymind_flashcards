import SwiftUI

/// **La reconnexion, et c'est exactement l'écran du parcours d'accueil.**
///
/// Elle ne s'affiche que dans un cas : quelqu'un qui a un parcours terminé et qui vient de
/// se déconnecter depuis les réglages. C'est donc un écran rare, et c'était le plus mal
/// tenu de l'app — un formulaire d'adresse et de mot de passe, un lien de connexion, un
/// mot de passe oublié, une bascule « créer un compte / j'ai déjà un compte », et un
/// « continuer sans compte » en bas. Cinq chemins pour une porte qui n'en a plus qu'un.
///
/// **Le mot de passe est parti.** Micabo se connecte par Apple ou par Google, et rien
/// d'autre : ce sont les deux boutons du parcours d'accueil, portés par le même code
/// (`SignInProviderButtons`). Deux écrans qui demandent la même chose ne peuvent pas
/// demander différemment, et les faire vivre sur le même code est la seule façon de
/// garantir qu'ils ne divergeront pas.
///
/// **« Continuer sans compte » est parti aussi.** Ce n'est plus une porte de sortie : une
/// fois qu'on s'est déconnecté, on se reconnecte. L'écran ne propose donc rien d'autre que
/// les deux fournisseurs, et il n'a pas de bouton de renvoi.
///
/// La mise en page vient d'`OnboardingScaffold`, et c'est voulu : dupliquer la composition
/// de l'écran de connexion du parcours serait s'engager à la maintenir deux fois.
struct AuthView: View {
    @Environment(AuthController.self) private var auth

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ton compte",
            title: "Content de te revoir.",
            subtitle: "Connecte-toi pour retrouver tes cours, tes cartes et ta série là où tu les as laissés.",
            titleSize: 30,
            contentSpacing: MicaboSpacing.lg,
            scrolls: false
        ) {
            VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
                SignInBenefits()
                SignInFailureNote()
            }
        } footer: {
            SignInProviderButtons()
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        // Une session ouverte depuis un lien reçu par courriel ferme l'écran d'elle-même :
        // c'est `RootView` qui décide de l'afficher, et il relit l'état du compte.
        .animation(.easeOut(duration: 0.22), value: auth.message)
    }
}
