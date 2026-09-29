import SwiftUI

// MARK: - Le niveau

/// **« Tu en es où ? »** Le palier large, dans les termes du pays. Il ne se pose qu'aux
/// pays dont on ne connaît pas les filières ; ailleurs, la filière et l'année le déduisent.
struct LevelStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingSingleChoiceStep(
            title: i18n.t("ios.quiz.level"),
            items: model.country.stages,
            selection: model.stage,
            label: { $0.localizedTitle },
            emoji: { $0.emoji },
            onSelect: { model.stage = $0 },
            onContinue: { model.advance() }
        )
    }
}

// MARK: - Les inquiétudes

/// **« Qu'est-ce qui t'inquiète le plus dans tes études ? »** Plusieurs réponses. La
/// première cochée donne son titre à l'écran suivant, qui lui répond.
struct WorriesStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingMultiChoiceStep(
            title: i18n.t("ios.onb.worries.title"),
            subtitle: i18n.t("ios.onb.worries.sub"),
            items: StudyWorry.allCases,
            selection: model.worries,
            label: { $0.title(locale: i18n.locale) },
            emoji: { $0.emoji },
            onToggle: { toggle($0) },
            onContinue: { model.advance() }
        )
    }

    private func toggle(_ worry: StudyWorry) {
        if model.worries.contains(worry) {
            model.worries.remove(worry)
        } else {
            model.worries.insert(worry)
        }
    }
}

// MARK: - Les supports

/// **« Tu as tes supports de cours ? »** Deux cases, et c'est la seule branche du parcours :
/// oui mène au dépôt des documents, non au choix d'un cours de démonstration. Dans les
/// deux cas, l'élève voit ensuite un cours fiché.
struct MaterialsQuestionStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.onb.materials.title"),
            subtitle: i18n.t("ios.onb.materials.sub"),
            scrolls: false,
            expandsContent: true
        ) {
            VStack(spacing: 10) {
                OnboardingChoiceTile(
                    title: i18n.t("ios.onb.materials.yes"),
                    emoji: "📄",
                    subtitle: i18n.t("ios.onb.materials.yes.hint"),
                    isSelected: model.hasMaterials == true
                ) {
                    model.hasMaterials = true
                }

                OnboardingChoiceTile(
                    title: i18n.t("ios.onb.materials.no"),
                    emoji: "✨",
                    subtitle: i18n.t("ios.onb.materials.no.hint"),
                    isSelected: model.hasMaterials == false
                ) {
                    model.hasMaterials = false
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } footer: {
            OnboardingArrowButton(isEnabled: model.hasMaterials != nil) { model.advance() }
        }
    }
}

// MARK: - Le temps par jour

/// **« Combien de temps par jour ? »** Quatre crans. La réponse devient le rythme du
/// plan, et elle se confirme en tenant le bouton.
struct DailyTimeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var selection: OnboardingDailyTime? {
        model.dailyMinutes.flatMap(OnboardingDailyTime.init(rawValue:))
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.quiz.time"),
            scrolls: false,
            expandsContent: true
        ) {
            OnboardingAnswerList(OnboardingDailyTime.allCases) { rank, time in
                OnboardingChoiceRow(
                    title: i18n.t("ios.quiz.time.minutes", ["n": "\(time.rawValue)"]),
                    emoji: time.emoji,
                    isSelected: selection == time,
                    fillsHeight: true,
                    rank: rank
                ) {
                    model.dailyMinutes = time.rawValue
                }
            }
        } footer: {
            // **Pas de rond : un bouton qu'on tient.** Le temps par jour est la seule
            // réponse du quiz qui engage, et « tu es sûr ? » se répond en le tenant une
            // seconde et demie, pendant que le violet le remplit.
            OnboardingHoldButton(
                title: i18n.t("ios.quiz.time.hold"),
                isEnabled: selection != nil
            ) {
                model.advance()
            }
        }
    }
}
