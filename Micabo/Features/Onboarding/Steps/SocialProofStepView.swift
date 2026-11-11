import StoreKit
import SwiftUI
import UIKit

// La page « Ce n'est pas de la magie : c'est prouvé » (`socialProof`) est partie au lot 7 :
// l'étude de Harvard y répétait le « 2x » de l'accroche, et celle de Karpicke la ligne du
// paywall. La seule étude du parcours est maintenant dite une fois, juste après que l'élève
// s'est testé (`SampleCardStepView`).

// MARK: - Les avis

/// Un avis : un titre, une phrase ou deux, un pseudo et un pays.
struct OnboardingReview: Identifiable {
    let id: Int
    let title: String
    let body: String
    let author: String

    /// Le nom de la photo dans le catalogue.
    var imageName: String { "ReviewAvatar\(id)" }
}

enum OnboardingReviews {
    static let count = 5

    static func all(locale: UiLocale) -> [OnboardingReview] {
        (1...count).map { index in
            OnboardingReview(
                id: index,
                title: L10n.t("ios.onb.review\(index).title", locale: locale),
                body: L10n.t("ios.onb.review\(index).body", locale: locale),
                author: L10n.t("ios.onb.review\(index).author", locale: locale)
            )
        }
    }
}

/// **Le carrousel : une carte par avis, la suivante qui dépasse à droite.** Il avance seul
/// toutes les quatre secondes et se laisse glisser au doigt ; un glissement arrête
/// l'avance automatique, qui ne reprend pas — on ne reprend pas la main à quelqu'un qui
/// vient de la prendre.
struct OnboardingReviewCarousel: View {
    let reviews: [OnboardingReview]
    var cardHeight: CGFloat = Self.fullHeight

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var position: Int? = 1
    @State private var isDriving = true

    private static let cardWidth: CGFloat = 300
    static let fullHeight: CGFloat = 296

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(reviews) { review in
                    OnboardingReviewCard(review: review)
                        .frame(width: Self.cardWidth, height: cardHeight)
                        .id(review.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position)
        .contentMargins(.horizontal, MicaboSpacing.screen, for: .scrollContent)
        .scrollIndicators(.hidden)
        // L'ombre des cartes déborde en haut et en bas : sans ça, la bande les coupait net.
        .scrollClipDisabled()
        .frame(height: cardHeight)
        .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in isDriving = false })
        // Chaque carte qui s'aligne se sent, qu'elle vienne seule ou du doigt.
        .onChange(of: position) { _, _ in Haptics.selection() }
        .task {
            guard !reduceMotion, reviews.count > 1 else { return }
            while !Task.isCancelled, isDriving {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled, isDriving else { return }
                let current = position ?? 1
                let next = current >= reviews.count ? 1 : current + 1
                withAnimation(MicaboMotion.standard) { position = next }
            }
        }
    }
}

/// Une carte d'avis : la photo, les étoiles, le titre en gras, le texte, le pseudo en bas
/// à droite.
struct OnboardingReviewCard: View {
    let review: OnboardingReview

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                avatar
                Spacer(minLength: 0)
                OnboardingStars(size: 17, spacing: 3)
            }

            Text(review.title)
                .font(MicaboFont.ui(19, weight: .heavy))
                .tracking(-0.3)
                .foregroundStyle(OnboardingPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            // Sur une carte raccourcie, le texte se resserre plutôt que de passer sous le pseudo.
            Text(review.body)
                .font(MicaboFont.ui(15.5, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink.opacity(0.85))
                .lineSpacing(4)
                .minimumScaleFactor(0.78)
                .frame(maxHeight: .infinity, alignment: .topLeading)

            Text(review.author)
                .font(MicaboFont.ui(13, weight: .medium))
                .foregroundStyle(OnboardingPalette.grayLight)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
        .accessibilityElement(children: .combine)
    }

    /// La photo du catalogue, cerclée du dégradé ; à défaut, l'initiale sur le dégradé.
    private var avatar: some View {
        ZStack {
            if UIImage(named: review.imageName) != nil {
                Image(review.imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: OnboardingPalette.mikaGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(String(review.author.prefix(1)).uppercased())
                    .font(MicaboFont.ui(20, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(
                LinearGradient(colors: OnboardingPalette.mikaGradient, startPoint: .top, endPoint: .bottom),
                lineWidth: 2.5
            )
        }
        .accessibilityHidden(true)
    }
}
