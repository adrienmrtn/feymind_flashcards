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

// MARK: - D'où il vient

/// **« Tu as connu Micabo comment ? »** La question la plus facile du parcours, posée
/// juste après les matières pour relancer : on vient de cocher des pastilles pendant
/// vingt secondes, et une réponse qui se donne en un appui remet en marche.
struct SourceStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingSingleChoiceStep(
            title: i18n.t("ios.quiz.source"),
            items: OnboardingSource.allCases,
            selection: model.source,
            label: { i18n.t("ios.quiz.source.\($0.rawValue)") },
            emoji: { $0.emoji },
            onSelect: { model.source = $0 },
            onContinue: { model.advance() }
        )
    }
}

// MARK: - Le temps par jour

/// **« Combien de temps par jour ? »** Quatre crans. La réponse devient le rythme du
/// plan, et elle se confirme en tenant le bouton : c'est la promesse qu'on signe à
/// l'écran suivant.
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
            // **Pas de bouton noir : un bouton qu'on tient.** Le temps par jour est la seule
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

// MARK: - La méthode

/// **« Tu révises comment, aujourd'hui ? »** La dernière question avant le prénom. La
/// réponse la plus fréquente est « je relis », et l'écran de preuve qui suit lui répond.
struct MethodStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingSingleChoiceStep(
            title: i18n.t("ios.quiz.method"),
            items: OnboardingMethod.allCases,
            selection: model.method,
            label: { i18n.t("ios.quiz.method.\($0.rawValue)") },
            emoji: { $0.emoji },
            onSelect: { model.method = $0 },
            onContinue: { model.advance() }
        )
    }
}
