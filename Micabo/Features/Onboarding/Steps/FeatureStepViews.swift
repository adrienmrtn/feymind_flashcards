import SwiftUI
import UIKit

// MARK: - Ce que Micabo sait faire, en cinq écrans

/// **Une maquette de téléphone en haut, un titre, une ligne, le rond.** Cinq écrans de la
/// même forme, l'un après l'autre : les fiches, le plan, les cartes, la poche, Mika. Ils
/// viennent **après** le quiz et le profil, pas avant : on montre à quelqu'un dont on sait
/// déjà le niveau et les matières, et il lit ces cinq écrans comme une réponse.
///
/// **La maquette est une image du catalogue** (`OnboardingFeature1` à `5`), fournie à part.
/// Tant qu'elle manque, un téléphone dessiné tient sa place — reconnaissable, jamais vide —
/// pour que l'écran se lise déjà en entier.
struct FeatureStepView: View {
    let feature: OnboardingFeature

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    OnboardingFeatureMockup(feature: feature)
                        .frame(height: proxy.size.height * 0.56)
                        .frame(maxWidth: .infinity)
                        .onboardingAppear(index: 1)

                    VStack(spacing: 12) {
                        Text(i18n.t(feature.titleKey))
                            .font(MicaboFont.ui(30, weight: .bold))
                            .tracking(-0.8)
                            .lineSpacing(-1)
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .onboardingAppear(index: 2)

                        Text(i18n.t(feature.subtitleKey))
                            .font(MicaboFont.ui(16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.gray)
                            .lineSpacing(3)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .onboardingAppear(index: 3)
                    }
                    .padding(.horizontal, MicaboSpacing.xl)
                    .padding(.top, MicaboSpacing.lg)

                    Spacer(minLength: 0)
                }
            }

            OnboardingArrowBar {
                model.advance()
            }
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}

/// Les cinq fonctionnalités montrées, dans l'ordre.
enum OnboardingFeature: Int, CaseIterable, Identifiable {
    case sheets = 1
    case plan
    case cards
    case pocket
    case mika

    var id: Int { rawValue }

    /// Le nom de l'image dans le catalogue.
    var imageName: String { "OnboardingFeature\(rawValue)" }

    var titleKey: String {
        switch self {
        case .sheets: "ios.onb.feature.sheets.title"
        case .plan: "ios.onb.feature.plan.title"
        case .cards: "ios.onb.feature.cards.title"
        case .pocket: "ios.onb.feature.pocket.title"
        case .mika: "ios.onb.feature.mika.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .sheets: "ios.onb.feature.sheets.sub"
        case .plan: "ios.onb.feature.plan.sub"
        case .cards: "ios.onb.feature.cards.sub"
        case .pocket: "ios.onb.feature.pocket.sub"
        case .mika: "ios.onb.feature.mika.sub"
        }
    }

    static func from(step: OnboardingStep) -> OnboardingFeature? {
        switch step {
        case .featureSheets: .sheets
        case .featurePlan: .plan
        case .featureCards: .cards
        case .featurePocket: .pocket
        case .featureMika: .mika
        default: nil
        }
    }
}

// MARK: - La maquette

/// **L'image du catalogue si elle existe, le téléphone dessiné sinon.** Dans les deux cas,
/// le bas se fond dans le blanc : la maquette est coupée, comme sur la référence, et c'est
/// le titre qui la termine.
struct OnboardingFeatureMockup: View {
    let feature: OnboardingFeature

    var body: some View {
        Group {
            if UIImage(named: feature.imageName) != nil {
                Image(feature.imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, MicaboSpacing.xxl)
            } else {
                OnboardingPhoneSketch(feature: feature)
                    .padding(.horizontal, 64)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, MicaboSpacing.md)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.72),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }
}

/// **Un téléphone dessiné, avec l'écran de la fonctionnalité en formes.**
///
/// Rien n'y est du vrai contenu : des blocs, des lignes, un surligneur, une grille. C'est
/// une place tenue en attendant l'image, mais une place qui ressemble déjà à ce qu'elle
/// annonce — un lecteur de fiche, un plan, des cartes, une bibliothèque, une conversation.
struct OnboardingPhoneSketch: View {
    let feature: OnboardingFeature

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let radius = width * 0.16

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(OnboardingPalette.ink)

                RoundedRectangle(cornerRadius: radius - 7, style: .continuous)
                    .fill(OnboardingPalette.white)
                    .padding(7)

                screen
                    .padding(22)
                    .padding(.top, 28)

                // L'île, tout en haut.
                Capsule()
                    .fill(OnboardingPalette.ink)
                    .frame(width: width * 0.3, height: 22)
                    .padding(.top, 16)
            }
            .aspectRatio(0.49, contentMode: .fit)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch feature {
        case .sheets: sheetScreen
        case .plan: planScreen
        case .cards: cardsScreen
        case .pocket: pocketScreen
        case .mika: mikaScreen
        }
    }

    // MARK: Les cinq écrans en formes

    private var sheetScreen: some View {
        VStack(alignment: .leading, spacing: 9) {
            bar(0.24, height: 3, color: OnboardingPalette.accent)
            bar(0.7, height: 12, color: OnboardingPalette.ink)
            bar(1, height: 5)
            bar(0.92, height: 5)
            bar(0.6, height: 5)
            bar(0.86, height: 5, color: Color(hex: 0xFFE58A))
            bar(0.4, height: 5)
            chart
            bar(0.95, height: 5)
            bar(0.75, height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var planScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            bar(0.62, height: 12, color: OnboardingPalette.ink)
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(OnboardingPalette.cardStrong, lineWidth: 6)
                    Circle().trim(from: 0, to: 0.64).stroke(OnboardingPalette.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 6) {
                    bar(0.7, height: 6)
                    bar(0.5, height: 6)
                }
            }
            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(row < 2 ? OnboardingPalette.accent : OnboardingPalette.cardStrong)
                            .frame(width: 14, height: 14)
                        bar(row == 2 ? 0.8 : 0.6, height: 6)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardsScreen: some View {
        VStack(spacing: 10) {
            bar(0.4, height: 6, color: OnboardingPalette.grayLight)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OnboardingPalette.card)
                .frame(height: 96)
                .overlay {
                    VStack(spacing: 8) {
                        bar(0.7, height: 8, color: OnboardingPalette.ink)
                        bar(0.5, height: 8, color: OnboardingPalette.ink)
                    }
                    .padding(16)
                }
            ForEach(0..<3, id: \.self) { row in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(row == 1 ? OnboardingPalette.accentWash : OnboardingPalette.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(row == 1 ? OnboardingPalette.accent : OnboardingPalette.cardStrong, lineWidth: 1.2)
                    }
                    .frame(height: 30)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 8) {
                            Circle().fill(row == 1 ? OnboardingPalette.accent : OnboardingPalette.cardStrong).frame(width: 12, height: 12)
                            bar(0.55, height: 5)
                        }
                        .padding(.horizontal, 10)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var pocketScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            bar(0.5, height: 12, color: OnboardingPalette.ink)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(["📐", "🧬", "🏛️", "⚗️"].enumerated()), id: \.offset) { index, emoji in
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Self.pastels[index % Self.pastels.count])
                            .aspectRatio(1, contentMode: .fit)
                            .overlay { Text(emoji).font(.system(size: 26)) }
                        bar(0.8, height: 5)
                        bar(0.5, height: 5, color: OnboardingPalette.cardStrong)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mikaScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer(minLength: 24)
                bubble(width: 0.7, tint: OnboardingPalette.ink, ink: OnboardingPalette.white.opacity(0.7))
            }
            HStack(alignment: .top, spacing: 8) {
                MikaBlob(size: 26, wobble: 0.16)
                bubble(width: 0.82, tint: OnboardingPalette.card, ink: OnboardingPalette.grayLight)
            }
            HStack {
                Spacer(minLength: 24)
                bubble(width: 0.5, tint: OnboardingPalette.ink, ink: OnboardingPalette.white.opacity(0.7))
            }
            HStack(alignment: .top, spacing: 8) {
                MikaBlob(size: 26, wobble: 0.16)
                bubble(width: 0.9, tint: OnboardingPalette.card, ink: OnboardingPalette.grayLight, lines: 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Les briques

    private static let pastels: [Color] = [
        Color(hex: 0xE9E0FF), Color(hex: 0xD9F4E4), Color(hex: 0xFFE9D6), Color(hex: 0xDCEBFF),
    ]

    private func bar(_ width: CGFloat, height: CGFloat, color: Color = OnboardingPalette.cardStrong) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(color)
                .frame(width: proxy.size.width * width, height: height)
        }
        .frame(height: height)
    }

    private var chart: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array([0.5, 0.85, 0.35, 0.65, 0.9].enumerated()), id: \.offset) { _, ratio in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(OnboardingPalette.accent.opacity(0.35))
                    .frame(height: 34 * ratio)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 34, alignment: .bottom)
        .padding(.vertical, 4)
    }

    private func bubble(width: CGFloat, tint: Color, ink: Color, lines: Int = 2) -> some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<lines, id: \.self) { line in
                    Capsule()
                        .fill(ink)
                        .frame(width: proxy.size.width * width * (line == lines - 1 ? 0.55 : 0.82), height: 4)
                }
            }
            .padding(10)
            .frame(width: proxy.size.width * width, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(height: CGFloat(lines) * 9 + 16)
    }
}
