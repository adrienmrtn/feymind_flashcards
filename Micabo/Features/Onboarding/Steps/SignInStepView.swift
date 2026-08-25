import AuthenticationServices
import SwiftUI

/// Fournisseur d'identité proposé à la fin du parcours.
enum OnboardingSignInProvider: String, CaseIterable, Identifiable {
    case apple
    case google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: "Continuer avec Apple"
        case .google: "Continuer avec Google"
        }
    }
}

/// La connexion, posée juste après « c'est à ton tour » et juste avant l'offre d'essai.
///
/// Elle arrive à la fin et pas au début, et c'est la seule position défendable : demander un
/// compte à l'ouverture, c'est demander un compte pour une app qu'on n'a pas encore vue
/// fonctionner. Ici, la démonstration est passée, le parcours est construit, et le compte
/// sert à ne pas le perdre.
///
/// **Les deux flux sont branchés pour de vrai.** L'écran se contentait d'appeler
/// `model.advance()` sur les deux boutons : on croyait s'être connecté, rien n'était créé, et
/// l'app redemandait un compte juste après le parcours. Apple passe par son bouton natif —
/// ses règles d'interface l'imposent — et Google par une page web isolée. Une connexion
/// réussie avance d'elle-même vers l'offre ; un refus laisse l'écran en place avec sa raison.
///
/// Les boutons ne sont pas conditionnés à ce que le projet Supabase annonce. Un fournisseur
/// éteint côté serveur le dit clairement dans le message d'erreur, ce qui est plus utile
/// qu'un bouton absent dont personne ne peut deviner la cause.
///
/// Le « Passer » en haut à droite est temporaire, et il fait deux choses : il avance, et il
/// **referme la porte du compte** pour que l'app ne repose pas la question à l'écran suivant.
struct SignInStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AuthController.self) private var auth

    /// Le même drapeau que celui lu par `RootView` : passer ici vaut passer pour de bon.
    @AppStorage(AccountGate.skippedKey) private var didSkipAccount = false

    /// Un nonce ne sert qu'une fois : le suivant est prêt avant même que celui-ci soit
    /// vérifié.
    @State private var appleNonce = AppleNonce()
    @State private var didAdvance = false

    private struct Benefit: Identifiable {
        let id = UUID()
        let systemImage: String
        let text: String
    }

    private let benefits: [Benefit] = [
        Benefit(systemImage: "icloud", text: "Tes cours et tes cartes sont sauvegardés."),
        Benefit(systemImage: "iphone.and.arrow.forward", text: "Tu retrouves ton avance sur n'importe quel appareil."),
        Benefit(systemImage: "flame", text: "Ta série de révisions ne repart pas de zéro.")
    ]

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ton compte",
            title: "Garde ta progression\nen sécurité.",
            subtitle: "Ton parcours est prêt. Un compte, et il te suit partout.",
            titleSize: 30,
            contentSpacing: MicaboSpacing.lg,
            scrolls: false,
            skip: OnboardingSkip(
                title: "Skip",
                accessibilityLabel: "Continuer sans compte",
                action: skip
            )
        ) {
            VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
                VStack(spacing: 0) {
                    ForEach(Array(benefits.enumerated()), id: \.element.id) { index, benefit in
                        benefitRow(benefit)

                        if index < benefits.count - 1 {
                            MicaboHairline(inset: 46)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .micaboGroup()

                if let failure {
                    Text(failure)
                        .font(MicaboFont.hanken(13, weight: .medium))
                        .foregroundStyle(MicaboColor.negative)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
        } footer: {
            VStack(spacing: 10) {
                appleButton
                googleButton
            }
            .animation(OnboardingMotion.tap, value: auth.isWorking)
        }
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

    /// Ce que l'écran a à dire quand ça n'a pas marché. Une annulation ne dit rien : elle
    /// n'est pas un échec, et `AuthController` la laisse déjà sans message.
    private var failure: String? {
        guard case .error(let detail) = auth.message else { return nil }
        return detail
    }

    // MARK: - Fournisseurs

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
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        .disabled(auth.isWorking)
        .accessibilityLabel(OnboardingSignInProvider.apple.title)
    }

    private var googleButton: some View {
        Button {
            Task { await auth.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                // Le G de Google est dessiné ici en attendant sa marque officielle, qui ne
                // se redessine pas à la main une fois qu'on l'a.
                Text("G")
                    .font(MicaboFont.hanken(16, weight: .bold))
                    .foregroundStyle(Color(hex: 0x4285F4))

                Text(OnboardingSignInProvider.google.title)
                    .font(MicaboFont.cardTitle)
                    .foregroundStyle(MicaboColor.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
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
        .accessibilityLabel(OnboardingSignInProvider.google.title)
    }

    private func benefitRow(_ benefit: Benefit) -> some View {
        HStack(spacing: 12) {
            Image(systemName: benefit.systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MicaboColor.accent)
                .frame(width: 34)

            Text(benefit.text)
                .font(MicaboFont.hanken(14.5, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 15)
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
