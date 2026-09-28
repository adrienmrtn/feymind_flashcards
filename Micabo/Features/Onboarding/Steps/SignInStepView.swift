import SwiftUI

/// **« Garde ta progression. »** Le compte, juste après le plan, et avant les rappels.
///
/// Il arrive à la fin et pas au début, et c'est la seule position défendable : demander un
/// compte à l'ouverture, c'est demander un compte pour une app qu'on n'a pas encore vue
/// fonctionner. Ici, le plan vient d'être montré, et le compte sert à ne pas le perdre.
///
/// **Le même écran que les questions, et pas un écran de connexion.** La marque, la
/// mascotte, la carte de la reconnexion et le récapitulatif du plan sont partis : une
/// jauge, un titre en 34, une ligne grise, puis les trois portes, telles que
/// `SignInProviderButtons` les dessine partout, étalées sur la hauteur.
///
/// **Les trois flux sont branchés pour de vrai.** Une connexion réussie avance d'elle-même ;
/// un refus laisse l'écran en place avec sa raison. « Passer » avance, et **referme la porte
/// du compte** pour que l'app ne repose pas la question à l'écran suivant.
struct SignInStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Le même drapeau que celui lu par `RootView` : passer ici vaut passer pour de bon.
    @AppStorage(AccountGate.skippedKey) private var didSkipAccount = false

    @State private var didAdvance = false

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("onboarding.compteTitle"),
            subtitle: i18n.t("ios.account.sub"),
            contentSpacing: MicaboSpacing.lg,
            scrolls: false,
            expandsContent: true,
            skip: OnboardingSkip(accessibilityLabel: i18n.t("ios.skipNoAccount"), action: skip)
        ) {
            // Les portes au milieu de la page, et les mentions en bas : sans la carte qui
            // récapitulait le plan, il reste trois boutons, et ils respirent.
            VStack(alignment: .leading, spacing: 22) {
                Spacer(minLength: 0)

                SignInProviderButtons()

                SignInFailureNote(includeSent: false, includeError: true)

                Spacer(minLength: 0)

                legalLine
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeOut(duration: 0.22), value: auth.message)
        .allowsHitTesting(!auth.isWorking)
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

    private var legalLine: some View {
        Text(legalAttributed)
            .font(MicaboFont.ui(12.5))
            .foregroundStyle(OnboardingPalette.gray)
            .tint(OnboardingPalette.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private var legalAttributed: AttributedString {
        var result = AttributedString()
        result += AttributedString(i18n.t("onboarding.legalPrefix") + " ")

        var terms = AttributedString(i18n.t("onboarding.legalTerms"))
        terms.link = URL(string: PaywallLinks.terms)
        terms.underlineStyle = .single
        result += terms

        result += AttributedString(" " + i18n.t("onboarding.legalAnd") + " ")

        var privacy = AttributedString(i18n.t("onboarding.legalPrivacy"))
        privacy.link = URL(string: PaywallLinks.privacy)
        privacy.underlineStyle = .single
        result += privacy

        result += AttributedString(".")
        return result
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
