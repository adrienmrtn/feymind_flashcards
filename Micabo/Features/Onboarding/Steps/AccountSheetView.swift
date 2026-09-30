import SwiftUI

/// **La languette du compte** : Apple, Google, ou « Passer ».
///
/// Elle monte sur la page qui annonce la fiche, au moment où l'élève quitte cette page pour
/// déposer ses supports. C'était une page entière du parcours, avec sa jauge, son titre en
/// trente-quatre et ses mentions : une page de connexion au milieu d'un quiz se lit comme un
/// mur. Une languette se lit comme une question, et elle se referme.
///
/// **« Passer » ne coûte rien à l'élève.** Ses cours sont enregistrés sur le téléphone, et la
/// synchronisation n'est qu'une copie : ils montent sur son compte à la première connexion,
/// depuis les réglages. Passer ouvre en silence un compte invité (`AuthController`), qui
/// porte le quota de génération et l'abonnement pris sans compte.
struct OnboardingAccountSheet: View {
    var onFinish: () -> Void

    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Le même drapeau que celui lu par `RootView` : passer ici vaut passer pour de bon, et
    /// l'app ne repose pas la question à la sortie du parcours.
    @AppStorage(AccountGate.skippedKey) private var didSkipAccount = false

    @State private var didFinish = false

    var body: some View {
        // Trois étages sur toute la hauteur : la question en haut, les deux portes au milieu,
        // la sortie et les mentions en bas. Collés en haut, ils laissaient un grand blanc
        // sous les mentions et un autre au-dessus du titre.
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(i18n.t("onboarding.compteTitle"))
                    .font(OnboardingPalette.title(28))
                    .tracking(-0.8)
                    .foregroundStyle(OnboardingPalette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(i18n.t("ios.account.sub"))
                    .font(MicaboFont.ui(15, weight: .regular))
                    .foregroundStyle(OnboardingPalette.gray)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 24)

            VStack(spacing: 0) {
                // Apple et Google, tels que `SignInProviderButtons` les dessine partout, logos
                // compris. Le courriel reste à la reconnexion.
                SignInProviderButtons(offersEmail: false)

                SignInFailureNote(includeSent: false, includeError: true)
                    .padding(.top, 8)
            }

            Spacer(minLength: 20)

            VStack(spacing: 10) {
                Button(action: skip) {
                    Text(i18n.t("common.skip"))
                        .font(MicaboFont.ui(16, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.gray)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
                .accessibilityLabel(i18n.t("ios.skipNoAccount"))

                legalLine
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 36)
        .padding(.bottom, MicaboSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingPalette.white.ignoresSafeArea())
        .animation(.easeOut(duration: 0.22), value: auth.message)
        .allowsHitTesting(!auth.isWorking)
        // La connexion se termine dans le contrôleur, pas dans le bouton : c'est le passage à
        // l'état « connecté » qui referme, quel que soit le fournisseur emprunté.
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            guard isSignedIn else { return }
            finishOnce()
        }
        .onAppear {
            if auth.isSignedIn { finishOnce() }
        }
    }

    private var legalLine: some View {
        Text(legalAttributed)
            .font(MicaboFont.ui(11.5))
            .foregroundStyle(OnboardingPalette.grayLight)
            .tint(OnboardingPalette.gray)
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

    private func skip() {
        didSkipAccount = true
        Analytics.track(.onboardingAnswer, ["field": "account", "value": "passer"])
        Task { await auth.continueWithoutAccount() }
        finishOnce()
    }

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        auth.clearMessage()
        onFinish()
    }
}
