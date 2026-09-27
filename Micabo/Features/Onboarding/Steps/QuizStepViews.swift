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

// MARK: - Ce qu'il a essayé

/// **« Tu as déjà essayé une app de révision ? »** Deux cases. La réponse ne change rien
/// au plan ; elle prépare l'écran de comparaison qui vient plus loin.
struct TriedAppsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.quiz.tried")
        ) {
            HStack(spacing: 12) {
                OnboardingChoiceTile(
                    title: i18n.t("ios.quiz.tried.yes"),
                    emoji: "📱",
                    isSelected: model.triedApps == true
                ) {
                    model.triedApps = true
                }

                OnboardingChoiceTile(
                    title: i18n.t("ios.quiz.tried.no"),
                    emoji: "🆕",
                    isSelected: model.triedApps == false
                ) {
                    model.triedApps = false
                }
            }
        } footer: {
            OnboardingContinueButton(isEnabled: model.triedApps != nil) {
                model.advance()
            }
        }
    }
}

// MARK: - Le temps par jour

/// **« Combien de temps par jour ? »** Quatre crans, et sous chacun le nombre de cartes que
/// ça fait : la réponse devient un chiffre du plan avant même qu'on l'ait choisie.
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
            OnboardingContinueButton(isEnabled: selection != nil) {
                model.advance()
            }
        }
    }
}

// MARK: - Ce qui bloque

/// **« Qu'est-ce qui te bloque ? »** Cinq réponses, et la plupart des élèves se
/// reconnaissent dans la première : c'est la question où l'on se sent compris, et c'est
/// pour ça que l'écran de rétention vient juste après.
struct BlockerStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingSingleChoiceStep(
            title: i18n.t("ios.quiz.blocker"),
            items: OnboardingBlocker.allCases,
            selection: model.blocker,
            label: { i18n.t("ios.quiz.blocker.\($0.rawValue)") },
            emoji: { $0.emoji },
            onSelect: { model.blocker = $0 },
            onContinue: { model.advance() }
        )
    }
}

// MARK: - La prochaine échéance

/// **« C'est pour quand ? »** Un horizon, pas une date : personne ne connaît la date de
/// son prochain contrôle au dixième écran d'une app, et un sélecteur de date ferait
/// passer la question pour un formulaire.
struct NextExamStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingSingleChoiceStep(
            title: i18n.t("ios.quiz.exam"),
            items: OnboardingExamHorizon.allCases,
            selection: model.examHorizon,
            label: { i18n.t("ios.quiz.exam.\($0.rawValue)") },
            emoji: { $0.emoji },
            onSelect: { model.examHorizon = $0 },
            onContinue: { model.advance() }
        )
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
