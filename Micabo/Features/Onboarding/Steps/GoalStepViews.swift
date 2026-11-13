import SwiftUI

// L'acte 2 : ce qui bloque. Chaque réponse revient dans la bulle de Mika à l'écran suivant,
// puis toutes reviennent ensemble sur `solutionMap`, où Mika reformule avant de montrer.

// MARK: - L'objectif n°1

/// **« Ton objectif n°1 cette année ? »** Une réponse, parmi celles de son niveau
/// (`LearningGoal.offered(for:)`). Mika reprend la matière la plus dure qu'il vient de citer.
struct GoalStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var say: OnbSay {
        if let subject = model.hardestSubject {
            return OnbSay(i18n.t("ios.onb12.react.hardest", ["subject": SubjectDisplay.subject(subject, locale: i18n.locale)]), mood: .happy)
        }
        return OnbSay(i18n.t("ios.onb12.say.goal"), mood: .idle)
    }

    var body: some View {
        OnbQuestion(i18n.t("ios.onb10.q.goal"), say: say) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(LearningGoal.offered(for: model.tier)) { goal in
                    OnbOption(
                        title: goal.title(locale: i18n.locale),
                        icon: goal.icon,
                        isSelected: model.mainGoal == goal
                    ) {
                        OnbPick.choose(on: .goal, model: model) { model.goals = [goal] }
                    }
                }
            }
        } footer: {
            // Un appui suffit (la page part à la fin du ressort) ; le bouton reste à sa place,
            // le même que partout, pour qui revient sur l'écran.
            V3Button(i18n.t("common.continue"), isEnabled: model.mainGoal != nil) {
                model.advance()
            }
        }
    }
}

// MARK: - Ce qui bloque

/// **« Qu'est-ce qui te bloque le plus ? »** Plusieurs réponses. Mika répond à chaque coche,
/// au dernier blocage coché, et son humeur change avec lui.
struct WorriesStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var say: OnbSay {
        guard let last = model.worriesInOrder.last else {
            return OnbSay(i18n.t("ios.onb12.say.worries"), mood: .look)
        }
        return OnbSay(Self.reaction(to: last, locale: i18n.locale), mood: last == .examStress ? .wink : .happy)
    }

    /// Ce que Mika répond à un blocage.
    static func reaction(to worry: StudyWorry, locale: UiLocale) -> String {
        switch worry {
        case .examStress: L10n.t("ios.onb12.react.worry.examStress", locale: locale)
        case .hardLessons: L10n.t("ios.onb12.react.worry.hardLessons", locale: locale)
        case .homework: L10n.t("ios.onb12.react.worry.homework", locale: locale)
        case .forgetting: L10n.t("ios.onb12.react.worry.forgetting", locale: locale)
        case .noStart: L10n.t("ios.onb12.react.worry.noStart", locale: locale)
        case .motivation: L10n.t("ios.onb12.react.worry.motivation", locale: locale)
        }
    }

    var body: some View {
        OnbQuestion(i18n.t("ios.onb10.q.worries"), say: say) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(StudyWorry.allCases) { worry in
                    OnbOption(
                        title: worry.title(locale: i18n.locale),
                        icon: worry.icon,
                        isSelected: model.worries.contains(worry),
                        multiple: true
                    ) {
                        withAnimation(MicaboMotion.quick) { model.toggle(worry: worry) }
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

// MARK: - Le temps de révision

/// **« Tu révises combien de temps par semaine ? »** (lot 12) Ce que ça lui coûte
/// aujourd'hui, en quatre crans, sans jugement. Un appui avance.
struct StudyHoursStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbQuestion(
            i18n.t("ios.onb12.q.hours"),
            say: OnbSay(i18n.t("ios.onb12.react.worries"), mood: .happy)
        ) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(WeeklyStudy.allCases) { hours in
                    OnbOption(title: hours.title(locale: i18n.locale), icon: hours.icon, isSelected: model.weeklyStudy == hours) {
                        OnbPick.choose(on: .studyHours, model: model) { model.weeklyStudy = hours }
                    }
                }
            }
        } footer: {
            // Un appui suffit (la page part à la fin du ressort) ; le bouton reste à sa place,
            // le même que partout, pour qui revient sur l'écran.
            V3Button(i18n.t("common.continue"), isEnabled: model.weeklyStudy != nil) {
                model.advance()
            }
        }
    }
}

// MARK: - La méthode

/// **« Et tu révises comment, aujourd'hui ? »** (lot 12) Mika vient de réagir au temps qu'il y
/// passe. Un appui avance.
struct StudyMethodStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var say: OnbSay {
        guard let hours = model.weeklyStudy else { return OnbSay(i18n.t("ios.onb12.say.method"), mood: .idle) }
        return OnbSay(hours.reaction(locale: i18n.locale), mood: hours == .overSix ? .surprise : .happy)
    }

    var body: some View {
        OnbQuestion(i18n.t("ios.onb12.q.method"), say: say) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(StudyMethod.allCases) { method in
                    OnbOption(title: method.title(locale: i18n.locale), icon: method.icon, isSelected: model.studyMethod == method) {
                        OnbPick.choose(on: .studyMethod, model: model) { model.studyMethod = method }
                    }
                }
            }
        } footer: {
            // Un appui suffit (la page part à la fin du ressort) ; le bouton reste à sa place,
            // le même que partout, pour qui revient sur l'écran.
            V3Button(i18n.t("common.continue"), isEnabled: model.studyMethod != nil) {
                model.advance()
            }
        }
    }
}

// MARK: - Mika reformule

/// **« Je t'ai compris, Lina. »** Le pivot du parcours : de la douleur à l'espoir.
///
/// Mika, en grand, reprend ce que l'élève vient de dire, ligne à ligne (sa matière la plus
/// dure, ses blocages, son temps, sa méthode) — la preuve qu'il a écouté — puis annonce la
/// suite : « Pour chacun, j'ai une réponse. Je te montre ? ». Une réponse absente retire sa
/// ligne. Le nom de l'étape reste `solutionMap`.
struct SolutionMapStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var title: String {
        guard let name = model.displayName.nilIfBlank else { return i18n.t("ios.onb12.recap.titleNoName") }
        return i18n.t("ios.onb12.recap.title", ["name": name])
    }

    struct Line: Identifiable {
        var id: String { text }
        let icon: MicaboIcon
        let text: String
    }

    /// Les lignes du récapitulatif, tirées des réponses : quatre au plus.
    static func lines(for model: OnboardingModel, locale: UiLocale) -> [Line] {
        var lines: [Line] = []
        if let subject = model.hardestSubject {
            lines.append(Line(
                icon: MicaboIcon.subjectIcon(subject) ?? .book,
                text: L10n.t("ios.onb12.recap.hardest", locale: locale, vars: ["subject": SubjectDisplay.subject(subject, locale: locale)])
            ))
        }
        for worry in model.answeredWorries.prefix(2) {
            lines.append(Line(
                icon: worry.icon,
                text: L10n.t("ios.onb10.solutions.quote", locale: locale, vars: ["worry": worry.title(locale: locale)])
            ))
        }
        if let hours = model.weeklyStudy {
            lines.append(Line(
                icon: .hourglass,
                text: L10n.t("ios.onb12.recap.hours", locale: locale, vars: ["hours": hours.title(locale: locale)])
            ))
        }
        if let method = model.studyMethod {
            lines.append(Line(icon: method.icon, text: method.recap(locale: locale)))
        }
        return Array(lines.prefix(4))
    }

    var body: some View {
        OnbScreen {
            Spacer(minLength: 4)
                .layoutPriority(-1)

            OnbHeroMika(mood: .proud, max: 150, min: 90)

            OnbTitle(title, size: OnbLayout.display, alignment: .center)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Self.lines(for: model, locale: i18n.locale)) { line in
                    HStack(alignment: .center, spacing: 12) {
                        OnbIcon(icon: line.icon, size: 26)
                        Text(line.text)
                            .font(V3Font.bodyStrong)
                            .foregroundStyle(V3Color.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card()
            .padding(.top, 18)

            Spacer(minLength: 4)
                .layoutPriority(-1)
        } footer: {
            V3Button(i18n.t("ios.onb12.recap.cta")) {
                model.advance()
            }
        }
    }
}
