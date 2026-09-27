import SwiftUI

/// **« Garde ta progression. »** Le compte, juste après le plan, et avant les rappels.
///
/// Il arrive à la fin et pas au début, et c'est la seule position défendable : demander un
/// compte à l'ouverture, c'est demander un compte pour une app qu'on n'a pas encore vue
/// fonctionner. Ici, le plan vient d'être montré, et le compte sert à ne pas le perdre.
///
/// **Le même écran que les questions, et pas un écran de connexion.** La marque, la
/// mascotte et la carte de la reconnexion sont partis : une jauge, un titre en 34, une ligne
/// grise, et une carte qui dit ce que le compte garde — le plan de l'écran d'avant, en trois
/// lignes. Puis les trois portes, telles que `SignInProviderButtons` les dessine partout.
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
            skip: OnboardingSkip(accessibilityLabel: i18n.t("ios.skipNoAccount"), action: skip)
        ) {
            VStack(alignment: .leading, spacing: 22) {
                keptCard

                SignInProviderButtons()

                SignInFailureNote(includeSent: false, includeError: true)

                legalLine
            }
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

    /// Ce que le compte garde : le plan qu'on vient de voir, en trois lignes cochées.
    private var keptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            line(i18n.t("ios.account.keep.plan", ["n": "\(model.cardsPerDay)"]))
            line(i18n.t("ios.account.keep.subjects", ["count": "\(model.subjects.count)"]))
            line(i18n.t("ios.account.keep.devices"))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func line(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(OnboardingPalette.white)
                .frame(width: 22, height: 22)
                .background(OnboardingPalette.ink, in: Circle())

            Text(text)
                .font(MicaboFont.ui(15, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
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
