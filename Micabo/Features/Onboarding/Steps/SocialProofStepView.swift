import StoreKit
import SwiftUI

/// La preuve sociale, chiffrée, juste après le compte.
///
/// **Des nombres, pas une pile d'avis.** Les avis ont leur écran, dans la démonstration, où
/// on les lit en entier. Ici, une fois le compte créé, la question qui reste n'est plus
/// « est-ce que ça marche ? » mais « est-ce que je suis seul ? » — et on y répond avec
/// trois nombres : les élèves du même pays, les fiches écrites cette semaine, la note. Les
/// nombres viennent de `OnboardingProofFigures`, où ils attendent d'être branchés sur la
/// vue serveur ; l'écran ne les connaît pas.
///
/// La mascotte qui se réjouissait au-dessus de la pile est partie : un personnage qui
/// saute de joie pendant qu'on lit un chiffre fait douter du chiffre.
///
/// **C'est ici que Micabo demande sa note**, et c'est le seul endroit où il la demande. La
/// boîte s'ouvre une seconde après l'écran, pas à l'apparition : arriver en même temps que
/// l'écran, c'est recouvrir la preuve par la demande. iOS décide seul si elle s'affiche —
/// trois fois par an au plus — et `OnboardingPreferences.ratingAsked` note qu'on a demandé,
/// pour ne pas dépenser le quota à chaque passage.
struct SocialProofStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.requestReview) private var requestReview

    private var locale: UiLocale { i18n.locale }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.socialProof"),
            contentSpacing: MicaboSpacing.lg
        ) {
            VStack(spacing: 12) {
                figure(
                    value: OnboardingNumbers.text(OnboardingProofFigures.students(in: model.country), locale: locale),
                    label: i18n.t("ios.social.students", ["country": model.country.localizedName(locale: locale)]),
                    systemImage: "person.2"
                )
                .onboardingAppear(index: 3)

                figure(
                    value: OnboardingNumbers.text(OnboardingProofFigures.sheetsThisWeek, locale: locale),
                    label: i18n.t("ios.social.sheets"),
                    systemImage: "doc.text"
                )
                .onboardingAppear(index: 4)

                figure(
                    value: OnboardingNumbers.text(OnboardingProofFigures.rating, locale: locale),
                    label: i18n.t("ios.social.rating", ["n": OnboardingNumbers.text(OnboardingProofFigures.reviews, locale: locale)]),
                    systemImage: "star.fill"
                )
                .onboardingAppear(index: 5)
            }
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
        .task {
            await askForRating()
        }
    }

    /// Demande la note, une fois, et après que l'écran s'est posé.
    @MainActor
    private func askForRating() async {
        guard !OnboardingPreferences.ratingAsked else { return }
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        OnboardingPreferences.ratingAsked = true
        requestReview()
    }

    /// Un nombre en grand, ce qu'il compte en dessous, et son symbole à droite.
    private func figure(value: String, label: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(MicaboFont.number(30, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(MicaboColor.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(MicaboFont.ui(13.5, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
                .frame(width: 42, height: 42)
                .background(MicaboColor.accentWash, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
