import AuthenticationServices
import SwiftUI

/// L'écran de compte : créer, se connecter, ou remettre à plus tard.
///
/// Il arrive **après** le parcours d'accueil, et c'est un choix de parcours. Demander un
/// compte avant d'avoir montré ce que fait l'app, c'est demander un effort avant d'avoir
/// donné une raison ; les vingt écrans d'accueil existent précisément pour donner cette
/// raison. À l'inverse, le compte ne peut pas venir plus tard que ça : les cours importés
/// avant lui n'auraient nulle part à aller.
///
/// « Plus tard » reste possible, et ce n'est pas une faiblesse. Micabo a fonctionné sans
/// compte depuis le premier jour, tout est stocké sur l'appareil, et l'app doit continuer de
/// s'ouvrir dans un train sans réseau. Le bouton dit donc franchement ce qu'on perd.
///
/// **Les boutons Apple et Google n'apparaissent que si le projet Supabase les a activés**
/// (`AuthProviders`, lu au lancement). Un bouton « Continuer avec Google » qui mène à une page
/// d'erreur coûte plus cher qu'un bouton absent, et celui-ci apparaîtra tout seul le jour où
/// le fournisseur sera configuré, sans mise à jour de l'app.
struct AuthView: View {
    @Environment(AuthController.self) private var auth
    /// Appelé quand on choisit de continuer sans compte.
    var onSkip: () -> Void

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    /// Le nonce du prochain appui sur le bouton Apple. Il est renouvelé après chaque essai :
    /// un nonce ne sert qu'une fois.
    @State private var appleNonce = AppleNonce()
    @FocusState private var focus: Field?

    private enum Mode {
        case signIn
        case signUp

        var title: String {
            switch self {
            case .signIn: "Content de te revoir."
            case .signUp: "On garde tes cours."
            }
        }

        var lead: String {
            switch self {
            case .signIn: "Retrouve tes cours, tes cartes et ton planning là où tu les as laissés."
            case .signUp: "Un compte, et tes fiches te suivent sur tes autres appareils, bientôt sur le web."
            }
        }

        var action: String {
            switch self {
            case .signIn: "Se connecter"
            case .signUp: "Créer mon compte"
            }
        }
    }

    private enum Field: Hashable {
        case name, email, password
    }

    private var canSubmit: Bool {
        guard email.contains("@"), password.count >= 8 else { return false }
        return !auth.isWorking
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    header
                    if let message = auth.message {
                        banner(message)
                    }
                    providerButtons
                    emailForm
                    helpers
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xl)
                .padding(.bottom, MicaboLayout.bottomBarClearance)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            .scrollDismissesKeyboard(.interactively)

            MicaboBottomBar {
                VStack(spacing: 2) {
                    Button(action: submit) {
                        Text(auth.isWorking ? "Un instant…" : mode.action)
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle(tint: canSubmit ? MicaboColor.ink : MicaboColor.strokeStrong))
                    .disabled(!canSubmit)

                    Button("Continuer sans compte", action: onSkip)
                        .buttonStyle(MicaboQuietButtonStyle())
                        .disabled(auth.isWorking)
                }
            }
        }
        .animation(.easeOut(duration: 0.22), value: mode)
        .animation(.easeOut(duration: 0.22), value: auth.message)
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            MicaboEyebrow(text: mode == .signUp ? "Ton compte" : "Connexion")

            Text(mode.title)
                .font(MicaboFont.hanken(30, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(MicaboTracking.tight)
                .fixedSize(horizontal: false, vertical: true)

            Text(mode.lead)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Les messages ne sont pas tous des erreurs : trois d'entre eux annoncent qu'un courriel
    /// est parti, ce qui est un succès et se lit comme tel.
    private func banner(_ message: AuthController.AuthMessage) -> some View {
        let isError = { if case .error = message { return true } else { return false } }()

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "envelope.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isError ? MicaboColor.negative : MicaboColor.accent)

            Text(text(for: message))
                .font(MicaboFont.hanken(13.5, weight: .regular))
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isError ? MicaboColor.negativeSoft : MicaboColor.accentSoft,
            in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
        )
        .transition(.opacity)
    }

    private func text(for message: AuthController.AuthMessage) -> String {
        switch message {
        case .error(let detail):
            detail
        case .confirmationSent(let address):
            "Compte créé. Ouvre le lien envoyé à \(address) pour le confirmer, puis reviens te connecter."
        case .magicLinkSent(let address):
            "Lien de connexion envoyé à \(address). Ouvre-le depuis ce téléphone."
        case .passwordResetSent(let address):
            "Lien de réinitialisation envoyé à \(address)."
        }
    }

    // MARK: - Fournisseurs

    @ViewBuilder
    private var providerButtons: some View {
        if auth.providers.apple || auth.providers.google {
            VStack(spacing: 10) {
                if auth.providers.apple {
                    // Le bouton d'Apple est dessiné par le système, et ce n'est pas
                    // négociable : ses règles d'interface imposent sa forme, son libellé et
                    // sa hauteur dès qu'on propose sa connexion. Il construit aussi sa propre
                    // requête, d'où le nonce gardé ici le temps de l'aller-retour.
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = appleNonce.hashed
                    } onCompletion: { result in
                        let nonce = appleNonce.raw
                        // Un nonce ne sert qu'une fois : le suivant est prêt avant même que
                        // celui-ci soit vérifié.
                        appleNonce = AppleNonce()
                        Task { await auth.signInWithApple(result: result, nonce: nonce) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
                    .disabled(auth.isWorking)
                }

                if auth.providers.google {
                    Button {
                        Task { await auth.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Continuer avec Google")
                        }
                    }
                    .buttonStyle(MicaboSecondaryButtonStyle())
                    .disabled(auth.isWorking)
                }
            }

            separator
        }
    }

    private var separator: some View {
        HStack(spacing: 12) {
            MicaboHairline(onCanvas: true)
            Text("ou")
                .font(MicaboFont.micro)
                .foregroundStyle(MicaboColor.inkTertiary)
            MicaboHairline(onCanvas: true)
        }
    }

    // MARK: - Formulaire

    private var emailForm: some View {
        VStack(spacing: 0) {
            if mode == .signUp {
                field(
                    emoji: "🙂",
                    background: MicaboColor.tilePastels[1],
                    placeholder: "Ton prénom",
                    text: $displayName,
                    field: .name,
                    keyboard: .default,
                    isSecure: false
                )
                MicaboHairline(inset: 71)
            }

            field(
                emoji: "✉️",
                background: MicaboColor.tilePastels[3],
                placeholder: "Adresse e-mail",
                text: $email,
                field: .email,
                keyboard: .emailAddress,
                isSecure: false
            )

            MicaboHairline(inset: 71)

            field(
                emoji: "🔒",
                background: MicaboColor.tilePastels[4],
                placeholder: "Mot de passe",
                text: $password,
                field: .password,
                keyboard: .default,
                isSecure: true
            )
        }
        .micaboGroup()
    }

    private func field(
        emoji: String,
        background: Color,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType,
        isSecure: Bool
    ) -> some View {
        HStack(spacing: 13) {
            MicaboTile(glyph: .emoji(emoji), background: background)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                } else {
                    TextField(placeholder, text: text)
                        .textContentType(field == .email ? .emailAddress : .givenName)
                }
            }
            .font(MicaboFont.rowTitle)
            .foregroundStyle(MicaboColor.ink)
            .tint(MicaboColor.accent)
            .keyboardType(keyboard)
            .textInputAutocapitalization(field == .name ? .words : .never)
            .autocorrectionDisabled()
            .focused($focus, equals: field)
            .submitLabel(field == .password ? .go : .next)
            .onSubmit(advance)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, MicaboSpacing.md)
    }

    /// Les deux chemins de secours, et la bascule connexion / inscription.
    private var helpers: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            MicaboSectionFootnote(text: "Huit caractères au minimum. Micabo ne lit jamais ton mot de passe : il est vérifié par Supabase.")

            HStack(spacing: MicaboSpacing.md) {
                Button(mode == .signIn ? "Créer un compte" : "J'ai déjà un compte") {
                    auth.clearMessage()
                    mode = mode == .signIn ? .signUp : .signIn
                }
                .font(MicaboFont.hanken(13, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
                .buttonStyle(MicaboPressableButtonStyle())

                Spacer(minLength: 0)

                if email.contains("@") {
                    Button(mode == .signIn ? "Lien de connexion" : "Mot de passe oublié") {
                        Task {
                            if mode == .signIn {
                                await auth.sendMagicLink(email: email)
                            } else {
                                await auth.sendPasswordReset(email: email)
                            }
                        }
                    }
                    .font(MicaboFont.hanken(13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .buttonStyle(MicaboPressableButtonStyle())
                    .disabled(auth.isWorking)
                }
            }
        }
    }

    // MARK: - Actions

    private func advance() {
        switch focus {
        case .name: focus = .email
        case .email: focus = .password
        case .password, nil:
            Haptics.medium()
            submit()
        }
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil

        Task {
            switch mode {
            case .signIn:
                await auth.signIn(email: email, password: password)
            case .signUp:
                await auth.signUp(email: email, password: password, displayName: displayName)
            }
        }
    }
}
