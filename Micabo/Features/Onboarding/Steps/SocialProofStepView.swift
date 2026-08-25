import Combine
import SwiftUI

/// Écran 17 : la preuve sociale, juste après la génération du parcours.
///
/// Sa place dans le parcours est tout le sujet. Une preuve sociale posée en ouverture
/// demande de croire une app qu'on n'a pas encore vue ; posée ici, elle arrive sur un
/// parcours qui vient d'être construit sous les yeux, et elle répond à la seule question
/// qui reste : est-ce que ça marche pour d'autres que moi ?
///
/// Les avis défilent seuls, et on peut les faire défiler à la main. Trois secondes et demie
/// par avis : le temps de lire une phrase, pas celui de s'installer.
struct SocialProofStepView: View {
    @Environment(OnboardingModel.self) private var model

    private struct Review: Identifiable {
        let id = UUID()
        let quote: String
        let name: String
        let level: String
    }

    private let reviews: [Review] = [
        Review(
            quote: "J'ai arrêté de tout relire la veille. Micabo me dit quoi réviser, je révise, et ça reste.",
            name: "Léa",
            level: "PASS, 1re année"
        ),
        Review(
            quote: "Mes fiches se font à partir des cours du prof. Je gagne deux heures par semaine, au minimum.",
            name: "Yanis",
            level: "Terminale"
        ),
        Review(
            quote: "Les cartes reviennent pile au moment où j'allais oublier. Je ne sais pas comment, mais ça tombe juste.",
            name: "Camille",
            level: "Prépa HEC"
        ),
        Review(
            quote: "Trois semaines avant les partiels, j'étais à jour pour la première fois de ma vie.",
            name: "Thomas",
            level: "Licence de droit"
        )
    ]

    @State private var index = 0

    private let ticker = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ils sont passés par là",
            title: "Nous avons aidé\n500 000 étudiants.",
            subtitle: "Voici ce qu'ils en disent.",
            titleSize: 30,
            contentSpacing: MicaboSpacing.lg,
            scrolls: false,
            expandsContent: true
        ) {
            VStack(spacing: MicaboSpacing.md) {
                Spacer(minLength: 0)
                carousel
                dots
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
        .onReceive(ticker) { _ in
            advanceCarousel()
        }
    }

    private var carousel: some View {
        TabView(selection: $index) {
            ForEach(Array(reviews.enumerated()), id: \.element.id) { position, review in
                card(review)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 6)
                    .tag(position)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 230)
    }

    private func card(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            stars

            Text(review.quote)
                .font(MicaboFont.hanken(16, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Text(String(review.name.prefix(1)))
                    .font(MicaboFont.hanken(14, weight: .bold))
                    .foregroundStyle(MicaboColor.accent)
                    .frame(width: 32, height: 32)
                    .background(MicaboColor.accentSoft, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(review.name)
                        .font(MicaboFont.hanken(14, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)

                    Text(review.level)
                        .font(MicaboFont.hanken(12, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .micaboGroup()
    }

    private var stars: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(MicaboColor.caution)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("5 étoiles sur 5")
    }

    /// Les points disent combien d'avis restent : sans eux, un panneau qui glisse tout seul
    /// se lit comme un bug d'affichage.
    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(reviews.indices, id: \.self) { position in
                Capsule()
                    .fill(position == index ? MicaboColor.ink : MicaboColor.strokeStrong)
                    .frame(width: position == index ? 18 : 6, height: 6)
            }
        }
        .animation(OnboardingMotion.shift, value: index)
        .accessibilityHidden(true)
    }

    private func advanceCarousel() {
        withAnimation(OnboardingMotion.shift) {
            index = (index + 1) % reviews.count
        }
    }
}
