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
                    .font(MicaboFont.ui(13.5, weight: .medium))
                    .foregroundStyle(MicaboColor.negative)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isStaticText)
                    .transition(.opacity)
            case .sent(let email) where includeSent:
                Text(i18n.t("onboarding.linkSent", ["email": email]))
                    .font(MicaboFont.ui(14.5, weight: .medium))
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
    var showsBrand: Bool = true
    var showsSubtitle: Bool = true
    var showsLanguageSwitcher: Bool = true
    var onDismiss: (() -> Void)? = nil
    var onCreateAccount: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil
    var isResolving: Bool = false
    /// **La mascotte à la place du logo, et les portes sans cadre.** C'est la fin du
    /// parcours d'accueil : quelqu'un vient de répondre à quinze questions posées par un
    /// personnage, et l'écran qui lui demande un compte lui montrait soudain un logo dans
    /// un carré, et trois boutons dans une carte à filet. La même mascotte, qui se réjouit,
    /// dit que c'est la même conversation ; les boutons posés à même la page disent que ce
    /// n'est pas un formulaire.
    var showsMascot: Bool = false

    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var t: (String) -> String {
        { key in i18n.t(key) }
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
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, placement == .sheet ? MicaboSpacing.sm : 0)
                .padding(.bottom, MicaboSpacing.xl)
                .environment(\.locale, i18n.locale.foundation)
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

    /// **L'écran est centré, et les portes sont dans une carte.**
    ///
    /// Il était aligné à gauche, et il s'ouvrait sur quatre commandes avant le premier mot :
    /// un logo de vingt-huit points coincé entre le sélecteur d'apparence, celui de langue
    /// et la croix. Puis un titre, puis deux boutons, un séparateur, un champ, un second
    /// bouton, une ligne légale — le tout posé à même le fond, sans rien pour dire où ça
    /// commence ni où ça finit. Ça se lisait comme un formulaire administratif.
    ///
    /// Trois choses le réparent, et aucune ne change ce qu'on y fait :
    ///
    /// - **la marque prend le centre, à soixante-quatre points.** Un écran de connexion est
    ///   le seul endroit où l'on regarde un logo ; l'y mettre en vignette de barre d'outils
    ///   était le mettre partout sauf là où il sert ;
    /// - **les portes entrent dans une carte blanche.** Apple, Google et le courriel sont
    ///   une seule question posée de trois façons : ils appartiennent au même objet ;
    /// - **le sélecteur d'apparence s'en va.** Choisir entre le jour et la nuit avant même
    ///   d'avoir un compte est un réglage qui arrive trop tôt, et il vit déjà dans les
    ///   Réglages. La langue reste : elle change la page qu'on est en train de lire.
    private var content: some View {
        VStack(spacing: 0) {
            toolbar
            if showsMascot {
                MicaboMascot(mood: .celebrating, size: 104)
            } else if showsBrand {
                MicaboBrandMark(size: 64)
                    .padding(.top, 18)
            }
            titleBlock
                .padding(.top, showsMascot ? 4 : (showsBrand ? 16 : 24))
            if showsMascot {
                SignInProviderButtons()
                    .padding(.top, 26)
            } else {
                SignInProviderButtons()
                    .micaboCard(padding: 18, radius: MicaboRadius.card)
                    .padding(.top, 26)
            }
            SignInFailureNote(includeSent: false, includeError: true)
                .padding(.top, MicaboSpacing.sm)
            legalLine
                .padding(.top, 22)
            if let onCreateAccount {
                createAccountLine(action: onCreateAccount)
                    .padding(.top, 18)
            }
        }
    }

    /// Ce qui reste en haut : la langue, et la sortie quand il y en a une.
    private var toolbar: some View {
        HStack(spacing: 10) {
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
            Spacer(minLength: 8)
            if showsLanguageSwitcher {
                LanguageSwitcher(variant: .compact)
            }
            if let onSkip {
                Button(t("common.skip"), action: onSkip)
                    .font(MicaboFont.ui(14.5, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .accessibilityLabel(t("ios.skipNoAccount"))
            }
        }
        // La barre garde sa hauteur même vide : sans elle, la marque remonterait sous
        // l'encoche sur l'écran qui n'a ni croix ni langue.
        .frame(minHeight: 44)
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text(t(titleKey))
                .font(MicaboFont.ui(26, weight: .bold))
                .tracking(MicaboTracking.display)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if showsSubtitle {
                Text(t(subtitleKey))
                    .font(MicaboFont.ui(15))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var legalLine: some View {
        Text(legalAttributed)
            .font(MicaboFont.ui(12.5))
            .foregroundStyle(MicaboColor.inkTertiary)
            .tint(MicaboColor.inkSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
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
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .underline()
        }
        .font(MicaboFont.ui(14))
        .frame(maxWidth: .infinity)
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
        { key in i18n.t(key) }
    }

    private var linkWasSent: Bool {
        if case .sent = auth.message { return true }
        return false
    }

    /// La correction proposée, quand l'adresse tapée ressemble à une autre.
    private var suggestion: (typed: String, corrected: String)? {
        if case .suggestion(let typed, let corrected) = auth.message { return (typed, corrected) }
        return nil
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
                if let suggestion {
                    suggestionNote(typed: suggestion.typed, corrected: suggestion.corrected)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: auth.isWorking)
        .animation(.easeOut(duration: 0.2), value: auth.message)
    }

    /// « Tu voulais dire … ? », et les deux réponses partent.
    ///
    /// `gmial.com` existe et garde le courrier qu'on lui donne : personne ne peut jurer à la
    /// place de l'élève que ce n'est pas sa boîte. On corrige donc d'un appui, et on passe
    /// outre d'un autre — bloquer enfermerait dehors les rares qui ont raison.
    private func suggestionNote(typed: String, corrected: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(t("onboarding.emailSuggestionQuestion"))
                    .foregroundStyle(MicaboColor.inkSecondary)
                Button {
                    email = corrected
                    Haptics.medium()
                    Task { await auth.deliverMagicLink(to: corrected) }
                } label: {
                    Text(corrected)
                        .font(MicaboFont.ui(14, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .underline()
                }
            }

            Button {
                Task { await auth.deliverMagicLink(to: typed) }
            } label: {
                Text(i18n.t("onboarding.emailSuggestionKeep", ["email": typed]))
                    .font(MicaboFont.ui(13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .underline()
                    .multilineTextAlignment(.leading)
            }
        }
        .font(MicaboFont.ui(14, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .transition(.opacity)
    }

    /// Le bouton d'Apple est dessiné par le système, et ce n'est pas négociable : ses règles
    /// d'interface imposent sa forme, son libellé et sa hauteur dès qu'on propose sa
    /// connexion. Il construit aussi sa propre requête, d'où le nonce gardé ici le temps de
    /// l'aller-retour.
    private var appleButton: some View {
        ZStack {
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
            .opacity(0.02)

            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 18, weight: .medium))
                Text(SignInProvider.apple.title(t: t))
                    .font(MicaboFont.cardTitle)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.black, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
            .allowsHitTesting(false)
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        .disabled(auth.isWorking)
        .opacity(auth.isWorking ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
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
                .font(MicaboFont.ui(12, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
            Rectangle()
                .fill(MicaboColor.hairline)
                .frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    /// **Le champ a avalé son bouton.**
    ///
    /// Le courriel était un champ de cinquante-six points surmontant un bouton de
    /// cinquante-six points : cent vingt points pour la troisième façon de faire la même
    /// chose que les deux boutons du dessus, et l'écran finissait plus bas que l'écran.
    /// L'envoi est maintenant dans le champ, à droite, là où le pouce arrive en sortant du
    /// clavier.
    private var emailForm: some View {
        let canSend = !auth.isWorking && EmailAddress.isPlausible(email)

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField(t("onboarding.emailPlaceholder"), text: $email)
                    .font(MicaboFont.ui(15.5, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .tint(MicaboColor.accent)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .disabled(auth.isWorking)
                    .onSubmit { sendLink() }
                    .onChange(of: email) {
                        // Corriger l'adresse répond déjà à la question : la garder affichée
                        // proposerait une correction pour un texte qui n'est plus là.
                        if auth.message != nil { auth.clearMessage() }
                    }
                    .accessibilityLabel(t("onboarding.emailLabel"))

                Button(action: sendLink) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MicaboColor.onInk)
                        .frame(width: 42, height: 42)
                        .background(
                            MicaboColor.accent,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .medium))
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.4)
                .accessibilityLabel(t("onboarding.sendLink"))
            }
            .padding(.leading, 16)
            .padding(.trailing, 7)
            .frame(minHeight: 56)
            .background(
                MicaboColor.canvas,
                in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
            )

            // Ce que fait le bouton, puisque rien dans une flèche ne dit qu'il n'y aura pas
            // de mot de passe à choisir derrière.
            Text(t("onboarding.emailNote"))
                .font(MicaboFont.ui(12.5))
                .foregroundStyle(MicaboColor.inkTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func sendLink() {
        guard EmailAddress.isPlausible(email) else { return }
        Haptics.medium()
        Task { await auth.sendMagicLink(to: email) }
    }
}
