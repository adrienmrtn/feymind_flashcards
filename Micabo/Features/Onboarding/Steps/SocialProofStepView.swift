import Combine
import StoreKit
import SwiftUI

/// La preuve sociale, juste après la génération du parcours.
///
/// Sa place dans le parcours est tout le sujet. Une preuve sociale posée en ouverture
/// demande de croire une app qu'on n'a pas encore vue ; posée ici, elle arrive sur un
/// parcours qui vient d'être construit sous les yeux, et elle répond à la seule question
/// qui reste : est-ce que ça marche pour d'autres que moi ?
///
/// Les avis défilent seuls, et on peut les faire défiler à la main. Trois secondes et demie
/// par avis : le temps de lire une phrase, pas celui de s'installer.
///
/// **C'est aussi l'écran qui demande la note.** La demande du système est posée là et
/// nulle part ailleurs : l'écran parle déjà d'avis, cinq étoiles sont à l'écran, et la
/// question arrive donc dans son sujet plutôt qu'au milieu d'une révision. Elle part au
/// premier changement d'avis, une fois qu'on en a lu un — pas à l'ouverture, où l'alerte
/// couvrirait l'écran avant qu'on ait vu ce qu'il raconte.
struct SocialProofStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(\.requestReview) private var requestReview

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

    /// L'avis posé au milieu de l'écran. Le carrousel est un `ScrollView` horizontal qui
    /// s'aligne sur ses vues, et non un `TabView` paginé : il se peint sur le crème sans
    /// rapporter de fond, et le défilement automatique n'est qu'une écriture de plus dans
    /// cette variable.
    @State private var visible: UUID?

    private let ticker = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    private var index: Int {
        guard let visible, let position = reviews.firstIndex(where: { $0.id == visible }) else {
            return 0
        }
        return position
    }

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
        .onAppear {
            visible = reviews.first?.id
        }
        .onReceive(ticker) { _ in
            advanceCarousel()
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(reviews) { review in
                    card(review)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $visible)
        .frame(height: 226)
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

            // Pas de rond avec une initiale dedans : c'est une photo de profil qui n'existe
            // pas, et sur un avis elle a en plus l'air d'un client inventé.
            VStack(alignment: .leading, spacing: 1) {
                Text(review.name)
                    .font(MicaboFont.hanken(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)

                Text(review.level)
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        let next = (index + 1) % reviews.count
        withAnimation(OnboardingMotion.shift) {
            visible = reviews[next].id
        }
        askForRatingOnce()
    }

    /// La demande de note du système, une seule fois.
    ///
    /// Elle n'est pas garantie de s'afficher, et c'est très bien ainsi : le système décide,
    /// plafonne à trois demandes par an et ignore les suivantes. Ce qui est à nous, c'est de
    /// ne pas la dépenser deux fois au même endroit — d'où le drapeau, qui survit à un
    /// second passage dans le parcours.
    private func askForRatingOnce() {
        guard !OnboardingPreferences.ratingAsked else { return }
        OnboardingPreferences.ratingAsked = true
        requestReview()
    }
}
