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
/// **Une pile d'avis, pas un carrousel.** Le panneau horizontal qui glissait tout seul
/// d'un avis au suivant se lisait comme une bannière, et une bannière est ce qu'on a appris
/// à ne pas regarder. Ici les avis sont empilés comme des cartes : celle du dessus se lit,
/// les deux suivantes dépassent dessous, et toutes les trois secondes et demie la première
/// s'efface pour laisser la suivante monter. On peut aussi appuyer pour passer. Au-dessus,
/// la mascotte se réjouit — c'est elle qui a fait le parcours, c'est elle qui montre qu'il
/// marche.
///
/// **C'est ici que Micabo demande sa note**, et c'est le seul endroit où il la demande. La
/// boîte s'ouvre après que le premier avis a été lu, pas à l'apparition : arriver en même
/// temps que l'écran, c'est recouvrir la preuve par la demande. iOS décide seul si elle
/// s'affiche — trois fois par an au plus — et `OnboardingPreferences.ratingAsked` note
/// qu'on a demandé, pour ne pas dépenser le quota à chaque passage.
struct SocialProofStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.requestReview) private var requestReview

    private struct Review: Identifiable {
        let id: Int
        let quote: String
        let name: String
        let level: String
        let emoji: String
    }

    /// Un emoji par étudiant, celui de ce qu'il étudie : une photo de profil qui n'existe
    /// pas aurait l'air d'un client inventé, une initiale dans un rond aussi.
    private static let emojis = ["🩺", "🎓", "📈", "⚖️"]

    private var reviews: [Review] {
        (1...4).map { index in
            Review(
                id: index,
                quote: t("ios.review\(index).quote"),
                name: t("ios.review\(index).name"),
                level: t("ios.review\(index).level"),
                emoji: Self.emojis[(index - 1) % Self.emojis.count]
            )
        }
    }

    private func t(_ key: String) -> String {
        i18n.t(key)
    }

    /// L'avis sur le dessus de la pile.
    @State private var top = 0

    private let ticker = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.socialProof"),
            titleSize: 26,
            contentSpacing: MicaboSpacing.lg,
            scrolls: false,
            expandsContent: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 22) {
                    MicaboMascot(mood: .celebrating, size: 92)
                    stack
                    dots
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
        .onReceive(ticker) { _ in
            advance()
        }
        .task {
            await askForRating()
        }
    }

    /// Demande la note, une fois, et après le premier avis.
    @MainActor
    private func askForRating() async {
        guard !OnboardingPreferences.ratingAsked else { return }
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        OnboardingPreferences.ratingAsked = true
        requestReview()
    }

    // MARK: - La pile

    private static let cardHeight: CGFloat = 176

    /// Les trois premières cartes se voient ; celle qui part rétrécit derrière les autres
    /// et s'efface, plutôt que de s'envoler : une carte qui traverse l'écran attire l'œil
    /// sur le mouvement, pas sur l'avis qui arrive.
    private var stack: some View {
        ZStack {
            ForEach(reviews) { review in
                card(review, depth: depth(of: review))
            }
        }
        .frame(height: Self.cardHeight + 32)
        .padding(.horizontal, MicaboSpacing.xs)
        .contentShape(Rectangle())
        .onTapGesture(perform: advance)
    }

    private func depth(of review: Review) -> Int {
        let index = review.id - 1
        return (index - top + reviews.count) % reviews.count
    }

    private func card(_ review: Review, depth: Int) -> some View {
        // Nommées et typées avant la chaîne : une carte a six modificateurs qui dépendent
        // de la profondeur, et le compilateur n'a pas à les inférer un par un.
        let isVisible = depth < 3
        let scale: CGFloat = isVisible ? 1 - CGFloat(depth) * 0.05 : 0.85
        let drop: CGFloat = isVisible ? CGFloat(depth) * 14 : 36
        let alpha: Double = isVisible ? 1 - Double(depth) * 0.22 : 0
        let order: Double = Double(reviews.count - depth)

        return reviewCard(review)
            .scaleEffect(scale)
            .offset(y: drop)
            .opacity(alpha)
            .zIndex(order)
            .animation(.spring(response: 0.55, dampingFraction: 0.8), value: top)
    }

    private func reviewCard(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            stars

            Text(review.quote)
                .font(MicaboFont.ui(15.5, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Text(review.emoji)
                    .font(.system(size: 17))
                    .frame(width: 34, height: 34)
                    .background(MicaboColor.pastel(at: review.id - 1), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(review.name)
                        .font(MicaboFont.ui(14, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)

                    Text(review.level)
                        .font(MicaboFont.ui(12, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: Self.cardHeight)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        // Une ombre douce, la seule exception à la règle du filet : c'est elle qui fait lire
        // la pile comme une pile, une carte au-dessus de l'autre.
        .shadow(color: MicaboColor.ink.opacity(0.06), radius: 16, y: 8)
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

    /// Les points disent combien d'avis restent : sans eux, une pile qui change toute seule
    /// se lit comme un bug d'affichage.
    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(reviews.indices, id: \.self) { position in
                Capsule()
                    .fill(position == top ? MicaboColor.ink : MicaboColor.strokeStrong)
                    .frame(width: position == top ? 18 : 6, height: 6)
            }
        }
        .animation(OnboardingMotion.shift, value: top)
        .accessibilityHidden(true)
    }

    private func advance() {
        top = (top + 1) % reviews.count
        Haptics.tick()
    }
}
