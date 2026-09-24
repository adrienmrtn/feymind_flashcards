import SwiftUI

/// **« Ton parcours est prêt. »** Ce que le compte va garder, avant qu'on le demande.
///
/// L'écran de connexion arrivait juste après la construction, et un élève sur quatre
/// appuyait sur « Passer » — dix-sept sans même essayer. On lui demandait de protéger
/// quelque chose qu'il n'avait pas vu. Cet écran le lui montre : la matière et l'année, le
/// nombre de matières, l'examen et dans combien de jours, le rythme, le chemin d'une note
/// à l'autre, et ce qui est offert. C'est concret, c'est à lui, et c'est ça qu'on lui
/// propose de garder à l'écran suivant.
struct PathReadyStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var summary: OnboardingSummary {
        OnboardingSummary(model: model, locale: i18n.locale)
    }

    var body: some View {
        let summary = summary

        OnboardingScaffold(
            title: i18n.t("ios.pathReady.title"),
            subtitle: i18n.t("ios.pathReady.sub"),
            contentSpacing: MicaboSpacing.lg
        ) {
            VStack(spacing: 12) {
                header(summary)
                    .onboardingAppear(index: 3)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    fact(systemImage: "books.vertical", text: i18n.t("ios.pathReady.subjects", ["count": "\(summary.subjectCount)"]))
                        .onboardingAppear(index: 4, stagger: OnboardingMotion.rowStagger)
                    fact(systemImage: "calendar", text: i18n.t("ios.pathReady.exam", ["exam": summary.examName, "days": "\(summary.examDays)"]))
                        .onboardingAppear(index: 5, stagger: OnboardingMotion.rowStagger)
                    fact(systemImage: "rectangle.stack", text: i18n.t("ios.pathReady.daily", ["n": "\(summary.cardsPerDay)"]))
                        .onboardingAppear(index: 6, stagger: OnboardingMotion.rowStagger)
                    fact(systemImage: "chart.line.uptrend.xyaxis", text: i18n.t("ios.pathReady.grade", ["from": summary.fromGrade, "to": summary.toGrade]))
                        .onboardingAppear(index: 7, stagger: OnboardingMotion.rowStagger)
                }

                gift
                    .onboardingAppear(index: 8, stagger: OnboardingMotion.rowStagger)
            }
        } footer: {
            OnboardingContinueButton(title: i18n.t("ios.pathReady.cta")) {
                model.advance()
            }
        }
    }

    /// La matière en tête, avec son emoji sur son pastel : c'est la tuile qu'on retrouvera
    /// dans la grille des decks, et l'élève doit la reconnaître en arrivant.
    private func header(_ summary: OnboardingSummary) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous)
                    .fill(MicaboColor.pastel(forName: summary.subject))
                Text(SubjectCatalog.emoji(for: summary.subject))
                    .font(.system(size: 26))
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.subject)
                    .font(MicaboFont.ui(17, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)

                Text(summary.level)
                    .font(MicaboFont.ui(13.5, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private func fact(systemImage: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)

            Text(text)
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    /// Ce qui est offert, sur le lavis vert : le premier chapitre fiché, sans rien payer.
    private var gift: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MicaboColor.positiveInk)
                .frame(width: 34, height: 34)
                .background(MicaboColor.positiveSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text(i18n.t("ios.pathReady.gift"))
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(MicaboColor.positiveInk)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(MicaboColor.positiveWash, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
    }
}
