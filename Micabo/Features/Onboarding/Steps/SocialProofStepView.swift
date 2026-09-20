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
/// **C'est ici que Micabo demande sa note**, et c'est le seul endroit où il la demande. Un
/// écran qui montre quatre avis cinq étoiles est le seul moment du parcours où l'on a
/// vraiment en tête l'idée de noter une app — la demander ailleurs, c'est la poser sur
/// quelqu'un qui pensait à autre chose. La boîte s'ouvre après que le premier avis a été
/// lu, pas à l'apparition : arriver en même temps que l'écran, c'est recouvrir la preuve
/// par la demande.
///
/// iOS décide seul si la boîte s'affiche — trois fois par an au plus, et jamais deux fois
/// pour la même version. On ne peut donc ni savoir si elle est apparue, ni ce qui a été
/// répondu : `OnboardingPreferences.ratingAsked` ne note pas une réponse, il note qu'on a
/// demandé, pour ne pas dépenser le quota à chaque passage.
struct SocialProofStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.requestReview) private var requestReview

    private struct Review: Identifiable {
        let id: Int
        let quote: String
        let name: String
        let level: String
    }

    private var reviews: [Review] {
        (1...4).map { index in
            Review(
                id: index,
                quote: t("ios.review\(index).quote"),
                name: t("ios.review\(index).name"),
                level: t("ios.review\(index).level")
            )
        }
    }

    private func t(_ key: String) -> String {
        i18n.t(key)
    }

    /// L'avis posé au milieu de l'écran. Le carrousel est un `ScrollView` horizontal qui
    /// s'aligne sur ses vues, et non un `TabView` paginé : il se peint sur le crème sans
    /// rapporter de fond, et le défilement automatique n'est qu'une écriture de plus dans
    /// cette variable.
    @State private var visible: Int?

    private let ticker = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    private var index: Int {
        guard let visible, let position = reviews.firstIndex(where: { $0.id == visible }) else {
            return 0
        }
        return position
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.socialProof"),
            titleSize: 26,
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
        .task {
            await askForRating()
        }
    }

    /// Demande la note, une fois, et après le premier avis.
    ///
    /// Le délai est celui d'un avis affiché : la boîte du système recouvre l'écran, et la
    /// faire arriver avant qu'on ait lu quoi que ce soit remplacerait la preuve par la
    /// demande. Rien n'est attendu en retour — `requestReview` ne dit pas si la boîte s'est
    /// ouverte, et le parcours ne s'arrête pas pour elle.
    @MainActor
    private func askForRating() async {
        guard !OnboardingPreferences.ratingAsked else { return }
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        OnboardingPreferences.ratingAsked = true
        requestReview()
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
                .font(MicaboFont.ui(16, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Pas de rond avec une initiale dedans : c'est une photo de profil qui n'existe
            // pas, et sur un avis elle a en plus l'air d'un client inventé.
            VStack(alignment: .leading, spacing: 1) {
                Text(review.name)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)

                Text(review.level)
                    .font(MicaboFont.ui(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Un filet plutôt qu'une carte à ombre : c'est la règle de toute la refonte, et cet
        // écran n'a pas de raison d'y échapper.
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
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
        .accessibilityLabel(t("ios.starsA11y"))
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
    }
}
