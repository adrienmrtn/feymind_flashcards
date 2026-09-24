import SwiftUI

/// **« Ce que Pro débloque. »** Juste avant le paywall, en trois lignes.
///
/// Le paywall était refermé après sept secondes en médiane, et personne n'avait lu ce qu'il
/// ouvrait : il arrivait avec un prix avant d'avoir dit pour quoi. Cet écran le dit, et il le
/// dit avec ce que l'élève vient de voir — la fiche de l'écran de démonstration, en entier ;
/// toutes ses cartes ; les examens blancs comme celui qu'on lui a montré. Rien de nouveau,
/// rien à imaginer : les trois choses qu'il a regardées, et qui s'ouvrent.
struct ProUnlocksStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.pro.unlocks.title"),
            contentSpacing: MicaboSpacing.lg
        ) {
            VStack(spacing: 10) {
                row(systemImage: "doc.text", title: i18n.t("ios.pro.sheet"), detail: i18n.t("ios.pro.sheetDetail", ["subject": model.demoSheet.subjectName]))
                    .onboardingAppear(index: 3)
                row(systemImage: "rectangle.stack", title: i18n.t("ios.pro.cards"), detail: i18n.t("ios.pro.cardsDetail"))
                    .onboardingAppear(index: 4)
                row(systemImage: "doc.text.magnifyingglass", title: i18n.t("ios.pro.mock"), detail: i18n.t("ios.pro.mockDetail"))
                    .onboardingAppear(index: 5)
            }
        } footer: {
            OnboardingContinueButton(title: i18n.t("ios.pro.cta")) {
                model.advance()
            }
        }
    }

    /// Un cadenas ouvert, ce qui s'ouvre, et en quoi : une ligne de titre, une de détail.
    private func row(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous)
                    .fill(MicaboColor.accentWash)
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MicaboColor.accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(MicaboFont.ui(15.5, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(MicaboFont.ui(13.5, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "lock.open")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MicaboColor.positive)
                .padding(.top, 3)
        }
        .padding(16)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
