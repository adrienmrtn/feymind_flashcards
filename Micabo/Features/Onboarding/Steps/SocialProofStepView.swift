import StoreKit
import SwiftUI
import UIKit

// MARK: - « On a aidé 45 000 élèves »

/// **La preuve sociale, au moment où elle a quelque chose à prouver.** Elle vient après
/// le cours et les trois cartes, pas avant : posée en ouverture, elle demanderait de
/// croire une app qu'on n'a pas vue ; posée ici, elle répond à la seule question qui
/// reste — est-ce que ça marche pour d'autres que moi ?
///
/// La forme est celle de la référence : « on a aidé », le chiffre peint du dégradé, les
/// lauriers autour de l'App Store, puis les avis en carrousel, qui défilent seuls et se
/// laissent glisser. Les photos viennent du catalogue (`ReviewAvatar1` à `5`) ; en
/// attendant, une initiale sur le dégradé tient leur place.
///
/// **C'est ici que l'app demande sa note.** L'élève vient de lire un cours, de répondre
/// à trois cartes et de voir ce que d'autres en disent : c'est le moment où il a quelque
/// chose à dire, et la page qui parle de notes est la seule où la demande ne tombe pas de
/// nulle part. Le système garde la main — trois demandes par an au plus, et jamais deux
/// fois pour la même version —, donc la page ne compte pas dessus pour avancer.
struct SocialProofStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text(i18n.t("ios.onb.social.title"))
                            .font(OnboardingPalette.title(34))
                            .tracking(-0.9)
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)

                        MikaGradientText(
                            text: i18n.t("ios.onb.social.count", ["n": OnboardingProofFigures.text(OnboardingProofFigures.students, locale: i18n.locale)]),
                            size: 34,
                            weight: .bold
                        )
                    }
                    .padding(.top, MicaboSpacing.lg)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .onboardingAppear(index: 1)

                    laurels
                        .padding(.top, 26)
                        .onboardingAppear(index: 2)

                    OnboardingReviewCarousel(reviews: OnboardingReviews.all(locale: i18n.locale))
                        .padding(.top, 34)
                        .onboardingAppear(index: 3)
                }
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)

            OnboardingArrowBar {
                model.advance()
            }
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        // **Tout de suite, à l'arrivée sur la page** : la demande se pose sur « on a aidé
        // 45 000 élèves », pas une seconde après, quand l'œil est déjà passé aux avis.
        .onAppear {
            guard model.step == .socialProof else { return }
            requestReview()
        }
    }

    /// Les lauriers, et ce qu'ils encadrent.
    private var laurels: some View {
        HStack(spacing: 14) {
            Image(systemName: "laurel.leading")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(OnboardingPalette.grayLight)

            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 22, weight: .medium))
                    Text(i18n.t("ios.onb.social.store"))
                        .font(MicaboFont.ui(24, weight: .semibold))
                        .tracking(-0.4)
                }
                .foregroundStyle(OnboardingPalette.ink)

                Text(i18n.t("ios.onb.social.rank"))
                    .font(MicaboFont.ui(15, weight: .medium))
                    .foregroundStyle(OnboardingPalette.gray)
            }

            Image(systemName: "laurel.trailing")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(OnboardingPalette.grayLight)
        }
        .accessibilityElement(children: .combine)
    }
}

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var position: Int? = 1
    @State private var isDriving = true

    private static let cardWidth: CGFloat = 300
    private static let cardHeight: CGFloat = 296

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(reviews) { review in
                    OnboardingReviewCard(review: review)
                        .frame(width: Self.cardWidth, height: Self.cardHeight)
                        .id(review.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position)
        .contentMargins(.horizontal, MicaboSpacing.screen, for: .scrollContent)
        .scrollIndicators(.hidden)
        .frame(height: Self.cardHeight)
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
                withAnimation(.easeInOut(duration: 0.5)) { position = next }
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
                .font(MicaboFont.ui(19, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(OnboardingPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(review.body)
                .font(MicaboFont.ui(15.5, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text(review.author)
                .font(MicaboFont.ui(13, weight: .medium))
                .foregroundStyle(OnboardingPalette.grayLight)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                    .foregroundStyle(OnboardingPalette.white)
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
