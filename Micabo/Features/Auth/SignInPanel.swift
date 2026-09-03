import AuthenticationServices
import SwiftUI

/// Les deux fournisseurs OAuth. Le courriel n'est pas un cas de plus : c'est le
/// formulaire sous le séparateur, le même que sur le web.
enum SignInProvider: String, CaseIterable, Identifiable {
    case apple
    case google

    var id: String { rawValue }

    func title(t: (String) -> String) -> String {
        switch self {
        case .apple: t("onboarding.continueApple")
        case .google: t("onboarding.continueGoogle")
        }
    }

    var title: String {
        title(t: { L10n.t($0, locale: .resolved()) })
    }
}

/// Ce que l'écran a à dire quand ça n'a pas marché, ou quand le lien est parti.
///
/// Une annulation ne dit rien : elle n'est pas un échec, et `AuthController` la laisse déjà
/// sans message.
struct SignInFailureNote: View {
    var includeSent: Bool = true
    var includeError: Bool = true

    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        if let message = auth.message {
            switch message {
            case .error(let detail) where includeError:
                Text(detail)
                    .font(MicaboFont.hanken(13.5, weight: .medium))
                    .foregroundStyle(MicaboColor.negative)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isStaticText)
                    .transition(.opacity)
            case .sent(let email) where includeSent:
                Text(i18n?.t("onboarding.linkSent", ["email": email]) ?? "Ouvre le lien envoyé à \(email)")
                    .font(MicaboFont.hanken(14.5, weight: .medium))
                    .foregroundStyle(MicaboColor.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            default:
                EmptyView()
            }
        }
    }
}

/// La porte de ceux qui ont déjà un compte — et la même que sur le web.
///
/// Logo, titre, Apple, Google, le séparateur « ou », le courriel, la ligne légale.
/// Les trois surfaces iOS (feuille d'accueil, reconnexion, fin du parcours) passent
/// par ici : deux compositions qui demandent la même chose ne peuvent pas la
/// demander différemment.
struct SignInScreen: View {
    enum Placement {
        /// Plein écran : le bloc est centré, comme la page /connexion.
        case page
        /// Feuille : le contenu part du haut, sous l'indicateur de drag.
        case sheet
    }

    var placement: Placement = .page
    var titleKey: String = "onboarding.connexionTitle"
    var subtitleKey: String = "onboarding.connexionSubtitle"
    var showsLanguageSwitcher: Bool = true
    var onDismiss: (() -> Void)? = nil
    var onCreateAccount: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil
    var isResolving: Bool = false

    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var t: (String) -> String {
        { key in i18n?.t(key) ?? L10n.t(key, locale: .resolved()) }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if placement == .page {
                        Spacer(minLength: MicaboSpacing.lg)
                    }
                    content
                    if placement == .page {
                        Spacer(minLength: MicaboSpacing.lg)
                    }
                }
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, placement == .sheet ? MicaboSpacing.sm : 0)
                .padding(.bottom, MicaboSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .animation(.easeOut(duration: 0.22), value: auth.message)
        .overlay {
            if isResolving {
                ProgressView()
                    .tint(MicaboColor.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MicaboColor.canvas.opacity(0.72))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(t("onboarding.parcoursBusy"))
            }
        }
        .allowsHitTesting(!isResolving)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            titleBlock
                .padding(.top, 28)
            SignInProviderButtons()
                .padding(.top, 28)
            SignInFailureNote(includeSent: false, includeError: true)
                .padding(.top, MicaboSpacing.sm)
            legalLine
                .padding(.top, 32)
            if let onCreateAccount {
                createAccountLine(action: onCreateAccount)
                    .padding(.top, 24)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            MicaboBrandLockup(size: 28)
            Spacer(minLength: 8)
            if showsLanguageSwitcher {
                LanguageSwitcher(variant: .compact)
            }
            if let onSkip {
                Button(t("common.skip"), action: onSkip)
                    .font(MicaboFont.hanken(14.5, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .accessibilityLabel(t("ios.skipNoAccount"))
            }
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .frame(width: 32, height: 32)
                        .background(MicaboColor.surfaceMuted, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
                .accessibilityLabel(t("app.a11y.close"))
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t(titleKey))
                .font(MicaboFont.display(32))
                .tracking(MicaboTracking.display)
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(t(subtitleKey))
                .font(MicaboFont.hanken(15))
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legalLine: some View {
        Text(legalAttributed)
            .font(MicaboFont.hanken(12.5))
            .foregroundStyle(MicaboColor.inkTertiary)
            .tint(MicaboColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var legalAttributed: AttributedString {
        var result = AttributedString()
        result += AttributedString(t("onboarding.legalPrefix") + " ")

        var terms = AttributedString(t("onboarding.legalTerms"))
        terms.link = URL(string: PaywallLinks.terms)
        terms.underlineStyle = .single
        result += terms

        result += AttributedString(" " + t("onboarding.legalAnd") + " ")

        var privacy = AttributedString(t("onboarding.legalPrivacy"))
        privacy.link = URL(string: PaywallLinks.privacy)
        privacy.underlineStyle = .single
        result += privacy

        result += AttributedString(".")
        return result
    }

    private func createAccountLine(action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(t("onboarding.noAccount"))
                .foregroundStyle(MicaboColor.inkTertiary)
            Button(t("onboarding.createIt"), action: action)
                .font(MicaboFont.hanken(13.5, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .underline()
        }
        .font(MicaboFont.hanken(13.5))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Apple, Google, puis le courriel — le même ordre que sur le web.
///
/// Ils ne sont pas conditionnés à ce que le projet Supabase annonce activé. Un fournisseur
/// éteint côté serveur le dit clairement dans son message d'erreur, ce qui est plus utile
/// qu'un bouton absent dont personne ne peut deviner la cause.
struct SignInProviderButtons: View {
    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Un nonce ne sert qu'une fois : le suivant est prêt avant même que celui-ci soit
    /// vérifié.
    @State private var appleNonce = AppleNonce()
    @State private var email = ""

    private var t: (String) -> String {
        { key in i18n?.t(key) ?? L10n.t(key, locale: .resolved()) }
    }

    private var linkWasSent: Bool {
        if case .sent = auth.message { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 10) {
            appleButton
            googleButton
            if linkWasSent {
                SignInFailureNote(includeSent: true, includeError: false)
                    .padding(.top, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                orDivider
                    .padding(.vertical, 10)
                emailForm
            }
        }
        .animation(.easeOut(duration: 0.2), value: auth.isWorking)
        .animation(.easeOut(duration: 0.2), value: auth.message)
    }

    /// Le bouton d'Apple est dessiné par le système, et ce n'est pas négociable : ses règles
    /// d'interface imposent sa forme, son libellé et sa hauteur dès qu'on propose sa
    /// connexion. Il construit aussi sa propre requête, d'où le nonce gardé ici le temps de
    /// l'aller-retour.
    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
            request.nonce = appleNonce.hashed
        } onCompletion: { result in
            let nonce = appleNonce.raw
            appleNonce = AppleNonce()
            Haptics.medium()
            Task { await auth.signInWithApple(result: result, nonce: nonce) }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        .disabled(auth.isWorking)
        .accessibilityLabel(t("onboarding.continueApple"))
    }

    private var googleButton: some View {
        Button {
            Task { await auth.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                Image("GoogleG")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)

                Text(SignInProvider.google.title(t: t))
                    .font(MicaboFont.cardTitle)
                    .foregroundStyle(MicaboColor.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                MicaboColor.surface,
                in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                    .strokeBorder(MicaboColor.strokeStrong, lineWidth: 1)
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .medium))
        .disabled(auth.isWorking)
        .opacity(auth.isWorking ? 0.5 : 1)
        .accessibilityLabel(t("onboarding.continueGoogle"))
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(MicaboColor.hairline)
                .frame(height: 1)
            Text(t("onboarding.or"))
                .font(MicaboFont.hanken(12, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
            Rectangle()
                .fill(MicaboColor.hairline)
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    private var emailForm: some View {
        VStack(spacing: 10) {
            TextField(t("onboarding.emailPlaceholder"), text: $email)
                .font(MicaboFont.hanken(16, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .tint(MicaboColor.accent)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(
                    MicaboColor.surface,
                    in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                        .strokeBorder(MicaboColor.strokeStrong, lineWidth: 1)
                }
                .disabled(auth.isWorking)
                .onSubmit { sendLink() }
                .accessibilityLabel(t("onboarding.emailLabel"))

            Button {
                sendLink()
            } label: {
                Text(t("onboarding.sendLink"))
                    .font(MicaboFont.cardTitle)
                    .foregroundStyle(MicaboColor.onInk)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                    .background(
                        MicaboColor.ink,
                        in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                    )
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .medium))
            .disabled(auth.isWorking || !EmailAddress.isPlausible(email))
            .opacity(auth.isWorking || !EmailAddress.isPlausible(email) ? 0.5 : 1)
        }
    }

    private func sendLink() {
        guard EmailAddress.isPlausible(email) else { return }
        Haptics.medium()
        Task { await auth.sendMagicLink(to: email) }
    }
}
