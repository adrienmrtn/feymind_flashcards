import SwiftUI

/// Fournisseur d'identité proposé à la fin du parcours.
///
/// **Rien n'est encore branché.** Les deux flux OAuth seront configurés plus tard ; en
/// attendant, l'écran existe, il est à sa place dans le parcours, et il passe par
/// `SignInStepView.signIn(with:)` — un seul point d'entrée, pour que le branchement ne
/// touche qu'une ligne le jour où les identifiants seront là.
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

/// Écran 19 : la connexion, posée juste avant l'offre.
///
/// Elle arrive à la fin et pas au début, et c'est la seule position défendable : demander
/// un compte à l'ouverture, c'est demander un compte pour une app qu'on n'a pas encore vue
/// fonctionner. Ici, la démonstration est passée, le parcours est construit, et le compte
/// sert à ne pas le perdre — ce que les trois lignes du milieu disent, plutôt que de
/// promettre « une expérience personnalisée ».
///
/// « Continuer sans compte » reste ouvert et volontairement discret. Un écran de connexion
/// sans issue se quitte en quittant l'app, et on ne revoit jamais celui qui l'a fait.
struct SignInStepView: View {
    @Environment(OnboardingModel.self) private var model

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
            scrolls: false
        ) {
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
        } footer: {
            VStack(spacing: 10) {
                providerButton(.apple)
                providerButton(.google)

                Button("Continuer sans compte") {
                    Haptics.light()
                    model.advance()
                }
                .buttonStyle(MicaboQuietButtonStyle())
            }
        }
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

    private func providerButton(_ provider: OnboardingSignInProvider) -> some View {
        Button {
            Haptics.medium()
            signIn(with: provider)
        } label: {
            HStack(spacing: 10) {
                mark(for: provider)

                Text(provider.title)
                    .font(MicaboFont.cardTitle)
            }
            .foregroundStyle(provider == .apple ? MicaboColor.onInk : MicaboColor.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                provider == .apple ? MicaboColor.ink : MicaboColor.surface,
                in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
            )
            .overlay {
                if provider == .google {
                    RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                        .strokeBorder(MicaboColor.strokeStrong, lineWidth: 1)
                }
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .accessibilityLabel(provider.title)
    }

    /// La pomme vient de SF Symbols. Le G de Google est dessiné ici en attendant le vrai
    /// logo : il arrive avec le SDK, et sa marque officielle ne se redessine pas à la main
    /// une fois qu'on l'a.
    @ViewBuilder
    private func mark(for provider: OnboardingSignInProvider) -> some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 17, weight: .medium))
        case .google:
            Text("G")
                .font(MicaboFont.hanken(16, weight: .bold))
                .foregroundStyle(Color(hex: 0x4285F4))
        }
    }

    /// Le jour où les flux OAuth seront configurés, c'est ici qu'ils se branchent : la
    /// connexion réussie appellera `model.advance()`, l'échec laissera l'écran en place
    /// avec son message. En attendant, on ne bloque personne.
    private func signIn(with provider: OnboardingSignInProvider) {
        model.advance()
    }
}
