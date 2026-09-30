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
