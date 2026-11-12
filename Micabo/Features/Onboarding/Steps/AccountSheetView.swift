import SwiftUI

/// **La languette du compte : « Garde ton plan en lieu sûr ».** Apple, Google, le courriel, ou
/// « Plus tard ».
///
/// Elle monte en quittant le plan révélé : c'est là qu'un compte protège quelque chose, le
/// plan qu'on vient de construire. Une languette se lit comme une question, et elle se
/// referme ; elle ne coûte pas une page au parcours.
///
/// **« Plus tard » ne coûte rien à l'élève.** Ses cours sont enregistrés sur le téléphone, et
/// la synchronisation n'est qu'une copie : ils montent sur son compte à la première
/// connexion, depuis les réglages. Passer ouvre en silence un compte invité
/// (`AuthController`), qui porte le quota de génération et l'abonnement pris sans compte.
struct OnboardingAccountSheet: View {
    var onFinish: () -> Void

    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    /// Le même drapeau que celui lu par `RootView` : passer ici vaut passer pour de bon, et
    /// l'app ne repose pas la question à la sortie du parcours.
    @AppStorage(AccountGate.skippedKey) private var didSkipAccount = false

    @State private var didFinish = false

    var body: some View {
        Group {
            if still {
                // Les rendus ne dessinent pas l'intérieur d'un `ScrollView`.
                content
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    content
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(V3Color.bg.ignoresSafeArea())
        .animation(MicaboMotion.quick, value: auth.message)
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

    /// La question, les portes, la sortie et les mentions.
    private var content: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                OnbTitle(i18n.t("ios.onb10.account.title"), alignment: .center)

                Text(i18n.t("ios.account.sub"))
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 0) {
                // Apple, Google et le courriel, tels que `SignInProviderButtons` les dessine
                // partout, logos compris.
                SignInProviderButtons(offersEmail: true)

                SignInFailureNote(includeSent: false, includeError: true)
                    .padding(.top, 8)
            }
            .padding(.top, 22)
            // Les portes seules attendent la fin d'une connexion en cours : pas deux à la
            // fois. « Plus tard », juste en dessous, reste vivant.
            .allowsHitTesting(!auth.isWorking)

            VStack(spacing: 6) {
                V3Button(i18n.t("ios.onb10.later"), kind: .ghost) {
                    skip()
                }
                .accessibilityLabel(Text(i18n.t("ios.skipNoAccount")))

                legalLine
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, OnbLayout.margin)
        .padding(.top, 30)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    private var legalLine: some View {
        Text(legalAttributed)
            .font(V3Font.caption)
            .foregroundStyle(V3Color.ink3)
            .tint(V3Color.ink2)
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
