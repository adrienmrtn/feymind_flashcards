import StoreKit
import SwiftUI
import UIKit

// MARK: - « On a aidé 45 000 élèves »

/// **La preuve sociale, au moment où elle a quelque chose à prouver.** Elle vient après
/// que Mika s'est présenté, pas avant : posée en ouverture, elle demanderait de croire une
/// app qu'on n'a pas vue ; posée ici, elle répond à la seule question qui reste — est-ce
/// que ça marche pour d'autres que moi ? La recherche, elle, a son écran plus tôt
/// (« L'IA est le compagnon le plus incroyable pour apprendre »).
///
/// La forme est celle de la référence : « on a aidé », le chiffre peint du dégradé, les
/// lauriers autour de l'App Store, puis les avis en carrousel, qui défilent seuls et se
/// laissent glisser. Les photos viennent du catalogue (`ReviewAvatar1` à `5`) ; en
/// attendant, une initiale sur le dégradé tient leur place.
///
/// La demande de note vient à l'écran suivant, « Soutiens-nous » (`SupportUsStepView`).
struct SocialProofStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                // **Tout tient au-dessus du rond.** Les avis passaient sous le pied de page sur les
                // écrans courts : Mika s'efface d'abord, puis les cartes raccourcissent, et la page
                // ne défile qu'en dernier recours.
                let room = proxy.size.height
                let showsMika = room >= 650
                let cardHeight = min(OnboardingReviewCarousel.fullHeight, max(214, room - (showsMika ? 356 : 238)))
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 4) {
                            if showsMika {
                                MikaMascot(mood: .celebrate, size: 104, reactsToTap: true)
                                    .padding(.bottom, 6)
                                    .accessibilityHidden(true)
                            }

                            Text(i18n.t("ios.onb.social.title"))
                                .font(OnboardingPalette.title(32))
                                .tracking(-0.6)
                                .foregroundStyle(OnboardingPalette.ink)
                                .multilineTextAlignment(.center)

                            MikaGradientText(
                                text: i18n.t("ios.onb.social.count", ["n": OnboardingProofFigures.text(OnboardingProofFigures.students, locale: i18n.locale)]),
                                size: 34,
                                weight: .heavy
                            )
                        }
                        .padding(.top, MicaboSpacing.sm)
                        .padding(.horizontal, MicaboSpacing.screen)
                        .onboardingAppear(index: 1)

                        laurels
                            .padding(.top, 22)
                            .onboardingAppear(index: 2)

                        OnboardingReviewCarousel(reviews: OnboardingReviews.all(locale: i18n.locale), cardHeight: cardHeight)
                            .padding(.top, 24)
                            .onboardingAppear(index: 4)
                    }
                    .padding(.bottom, MicaboSpacing.md)
                    .frame(width: proxy.size.width)
                    .frame(minHeight: room, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }

            OnboardingArrowBar {
                model.advance()
            }
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
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

// MARK: - « Soutiens-nous »

/// **La demande de note, annoncée.** Juste après les avis : l'élève vient de lire ce que
/// d'autres pensent de Micabo, la page lui demande d'en dire autant, et le rond ouvre la
/// fenêtre de note du système, puis passe à la suite. Le système garde la main — trois
/// demandes par an au plus, jamais deux fois pour la même version — : si la fenêtre ne vient
/// pas, la page avance quand même.
struct SupportUsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.requestReview) private var requestReview
    @Environment(\.onboardingStill) private var still

    @State private var shown = false
    @State private var isAsking = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingCenteredScroll {
                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [MicaboColor.cautionVivid.opacity(0.24), MicaboColor.cautionVivid.opacity(0)], center: .center, startRadius: 4, endRadius: 110))
                            .frame(width: 220, height: 220)
                        MikaMascot(mood: .happy, size: 132, reactsToTap: true)
                        MicaboIconView(icon: .star, size: 50)
                            .rotationEffect(.degrees(-12))
                            .offset(x: -70, y: -58)
                        MicaboIconView(icon: .star, size: 36)
                            .rotationEffect(.degrees(14))
                            .offset(x: 74, y: -40)
                    }
                    .frame(height: 200)
                    .scaleEffect(shown || still ? 1 : 0.5)
                    .opacity(shown || still ? 1 : 0)
                    .accessibilityHidden(true)

                    OnboardingAccentText(template: i18n.t("ios.support.title"), size: 30, alignment: .center)
                        .onboardingAppear(index: 1)

                    Text(i18n.t("ios.support.body"))
                        .font(MicaboFont.ui(17, weight: .medium))
                        .foregroundStyle(OnboardingPalette.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingAppear(index: 2)

                    OnboardingStars(size: 30, spacing: 6)
                        .onboardingAppear(index: 3)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, MicaboSpacing.md)
            }

            OnboardingArrowBar(isEnabled: !isAsking) {
                ask()
            }
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.45).delay(0.1)) { shown = true }
        }
    }

    /// La fenêtre de note d'abord, la suite un instant après : passer à l'écran suivant au
    /// même moment la ferait apparaître sur une page qui défile.
    private func ask() {
        guard !isAsking else { return }
        isAsking = true
        Haptics.selection()
        requestReview()
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            model.advance()
            isAsking = false
        }
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
