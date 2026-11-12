import SwiftUI

// MARK: - L'objectif n°1

/// **« Ton objectif n°1 cette année ? »** Une réponse, parmi celles de son niveau
/// (`LearningGoal.offered(for:)`) : un collégien ne voit pas « valider mon année », un
/// étudiant ne voit pas « entrer dans la formation de mes rêves ». L'examen n'y est jamais :
/// il vient d'être dit, et `learningGoals` l'ajoute de lui-même. Un appui avance.
struct GoalStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbQuestion(i18n.t("ios.onb10.q.goal")) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(LearningGoal.offered(for: model.tier)) { goal in
                    V3OptionRow(
                        goal.title(locale: i18n.locale),
                        icon: goal.icon,
                        isSelected: model.mainGoal == goal
                    ) {
                        model.goals = [goal]
                        model.advance()
                    }
                }
            }
        }
    }
}

// MARK: - Ce qui bloque

/// **« Qu'est-ce qui te bloque le plus ? »** Plusieurs réponses. L'écran suivant répond aux
/// trois premières cochées, dans l'ordre où elles l'ont été.
struct WorriesStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbQuestion(
            i18n.t("ios.onb10.q.worries"),
            mood: model.worries.isEmpty ? .idle : .happy
        ) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(StudyWorry.allCases) { worry in
                    V3OptionRow(
                        worry.title(locale: i18n.locale),
                        icon: worry.icon,
                        isSelected: model.worries.contains(worry),
                        multiple: true
                    ) {
                        model.toggle(worry: worry)
                    }
                }
            }
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: !model.worries.isEmpty) {
                model.advance()
            }
        }
    }
}

// MARK: - Ce que Mika y répond

/// **« Voilà comment je t'aide, {prénom} »** : pour chaque blocage coché (trois au plus, dans
/// l'ordre coché), une carte. La phrase de l'élève entre guillemets, puis la fonctionnalité
/// qui y répond : son icône, son nom, une ligne.
///
/// Cet écran remplace les huit où Mika se présentait : ce qu'ils disaient est dit une fois,
/// à propos de ce que l'élève vient de répondre.
struct SolutionMapStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var title: String {
        guard let name = model.displayName.nilIfBlank else { return i18n.t("ios.onb10.solutions.titleNoName") }
        return i18n.t("ios.onb10.solutions.title", ["name": name])
    }

    var body: some View {
        OnbScreen {
            OnbTitle(title)
                .padding(.top, OnbLayout.titleTop)

            VStack(spacing: OnbLayout.cardGap) {
                ForEach(model.answeredWorries) { worry in
                    card(worry)
                }
            }
            .padding(.top, OnbLayout.titleGap)
        } footer: {
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }

    private func card(_ worry: StudyWorry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(i18n.t("ios.onb10.solutions.quote", ["worry": worry.title(locale: i18n.locale)]))
                .font(V3Font.caption)
                .foregroundStyle(V3Color.ink3)

            HStack(alignment: .center, spacing: 12) {
                OnbIcon(icon: worry.solutionIcon)

                VStack(alignment: .leading, spacing: 2) {
                    Text(worry.solutionTitle(locale: i18n.locale))
                        .font(V3Font.display(21))
                        .foregroundStyle(V3Color.ink)
                    Text(worry.solutionBody(locale: i18n.locale))
                        .font(V3Font.support)
                        .foregroundStyle(V3Color.ink2)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card()
        .accessibilityElement(children: .combine)
    }
}
