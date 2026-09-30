import SwiftUI

// MARK: - « Ça t'a plu ? »

/// **Le gratuit contre Premium, en six lignes**, juste avant l'essai. L'élève vient de
/// lire un cours et de répondre à trois cartes : il sait ce qu'il compare. Chaque ligne
/// porte une valeur, pas une croix — « 1 cours » contre « illimités » se lit, un tiret
/// contre une coche s'interprète.
struct ComparisonStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private static let rows = 6

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.onb.compare.title"),
            subtitle: i18n.t("ios.onb.compare.sub"),
            contentSpacing: MicaboSpacing.lg
        ) {
            table
        } footer: {
            OnboardingContinueButton(title: i18n.t("ios.onb.compare.cta")) {
                model.advance()
            }
        }
    }

    private static let columnWidth: CGFloat = 78

    private var table: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 8)

            // Les lignes arrivent l'une après l'autre, et chacune se sent : le tableau se
            // remplit sous les yeux plutôt que d'être posé d'un bloc.
            ForEach(1...Self.rows, id: \.self) { index in
                row(index)
                    .onboardingAppear(index: 4 + index, stagger: Self.rowStagger)
                if index < Self.rows {
                    Rectangle()
                        .fill(OnboardingPalette.cardStrong)
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onboardingAppear(index: 3)
        .onAppear {
            for index in 1...Self.rows {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(4 + index) * Self.rowStagger) {
                    Haptics.soft()
                }
            }
        }
    }

    /// L'écart entre deux lignes qui entrent : un peu plus que celui des réponses, pour que
    /// les six coups se distinguent.
    private static let rowStagger = 0.07

    private var header: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(i18n.t("ios.onb.compare.free"))
                .font(MicaboFont.ui(12.5, weight: .semibold))
                .foregroundStyle(OnboardingPalette.gray)
                .frame(width: Self.columnWidth)

            Text(i18n.t("ios.onb.compare.pro").uppercased())
                .font(MicaboFont.ui(11.5, weight: .bold))
                .tracking(1)
                .foregroundStyle(OnboardingPalette.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: Self.columnWidth, height: 26)
                .background(OnboardingPalette.accent, in: Capsule())
        }
    }

    private func row(_ index: Int) -> some View {
        let free = i18n.t("ios.onb.compare.row\(index).free")
        let pro = i18n.t("ios.onb.compare.row\(index).pro")

        return HStack(spacing: 0) {
            Text(i18n.t("ios.onb.compare.row\(index)"))
                .font(MicaboFont.ui(14.5, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, MicaboSpacing.xs)

            cell(free, isPro: false)
                .frame(width: Self.columnWidth)

            cell(pro, isPro: true)
                .frame(width: Self.columnWidth)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    /// Une valeur écrite quand il y en a une ; une coche pour « oui », un tiret pour
    /// « non ».
    @ViewBuilder
    private func cell(_ value: String, isPro: Bool) -> some View {
        switch value {
        case "yes":
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isPro ? OnboardingPalette.accent : OnboardingPalette.ink)
        case "no":
            Text("—")
                .font(MicaboFont.ui(15, weight: .regular))
                .foregroundStyle(OnboardingPalette.grayLight)
        default:
            Text(value)
                .font(MicaboFont.ui(13.5, weight: isPro ? .bold : .medium))
                .foregroundStyle(isPro ? OnboardingPalette.accent : OnboardingPalette.gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}
