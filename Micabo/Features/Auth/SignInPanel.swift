import AuthenticationServices
import SwiftUI

/// Fournisseur d'identité proposé par Micabo. Il n'y en a que deux, et il n'y a pas de
/// troisième chemin : ni mot de passe, ni lien envoyé par courriel.
enum SignInProvider: String, CaseIterable, Identifiable {
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

/// **Ce qu'un compte apporte, en trois lignes.** Partagé par les deux écrans qui demandent
/// à se connecter — celui du parcours d'accueil et celui de la reconnexion — parce que ce
/// sont le même écran et qu'ils doivent le rester.
struct SignInBenefits: View {
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
        VStack(spacing: 0) {
            ForEach(Array(benefits.enumerated()), id: \.element.id) { index, benefit in
                row(benefit)

                if index < benefits.count - 1 {
                    MicaboHairline(inset: 46)
                }
            }
        }
        .padding(.horizontal, 16)
        .micaboGroup()
    }

    private func row(_ benefit: Benefit) -> some View {
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
}

/// Ce que l'écran a à dire quand ça n'a pas marché.
///
/// Une annulation ne dit rien : elle n'est pas un échec, et `AuthController` la laisse déjà
/// sans message.
struct SignInFailureNote: View {
    @Environment(AuthController.self) private var auth

    private var failure: String? {
        guard case .error(let detail) = auth.message else { return nil }
        return detail
    }

    var body: some View {
        if let failure {
            Text(failure)
                .font(MicaboFont.hanken(13, weight: .medium))
                .foregroundStyle(MicaboColor.negative)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
        }
    }
}

/// **Les deux boutons de connexion, et eux seuls.**
///
/// Ils ne sont pas conditionnés à ce que le projet Supabase annonce activé. Un fournisseur
/// éteint côté serveur le dit clairement dans son message d'erreur, ce qui est plus utile
/// qu'un bouton absent dont personne ne peut deviner la cause — et un écran dont les deux
/// boutons disparaissent ensemble n'a plus rien à proposer du tout.
struct SignInProviderButtons: View {
    @Environment(AuthController.self) private var auth

    /// Un nonce ne sert qu'une fois : le suivant est prêt avant même que celui-ci soit
    /// vérifié.
    @State private var appleNonce = AppleNonce()

    var body: some View {
        VStack(spacing: 10) {
            appleButton
            googleButton
        }
        .animation(.easeOut(duration: 0.2), value: auth.isWorking)
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
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        .disabled(auth.isWorking)
        .accessibilityLabel(SignInProvider.apple.title)
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

                Text(SignInProvider.google.title)
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
        .accessibilityLabel(SignInProvider.google.title)
    }
}
