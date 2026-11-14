import SwiftUI

// MARK: - Mika prépare le plan

/// **« Je prépare ton plan… »** Le seul chargement du parcours, et sa seule horloge.
///
/// Mika écrit ; le pourcentage monte ; la liste se coche ligne à ligne, et **chaque ligne est
/// une réponse de l'élève** (sa classe, ses matières, sa matière la plus dure, son objectif,
/// son examen et sa date, son temps par jour et l'heure, sa première leçon :
/// `OnboardingModel.planLines`). Une information absente retire sa ligne. À cent pour cent,
/// l'écran avance seul, vers le plan prêt.
///
/// **L'horloge ne redessine que ce qui bouge** : le pourcentage, la jauge et la liste vivent
/// dans une vue à part, sous une `TimelineView` périodique.
struct PlanBuildingStepView: View {
    /// Pour les rendus : l'avancement à montrer, figé.
    var previewProgress: Double?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    /// La durée du chargement, en secondes.
    static let duration = 4.4
    /// Ce qu'on laisse lire « 100 % » avant d'avancer.
    static let hold = 0.4
    /// Le pas de l'horloge : trente images par seconde suffisent à un pourcentage.
    private static let tick = 1.0 / 30.0

    /// L'instant où le chargement a commencé.
    @State private var start = Date()
    @State private var didAdvance = false

    /// De 0 à 1, d'après le temps écoulé, **à vitesse constante** (lot 12) : le pourcentage
    /// coule sans à-coup, et les lignes se cochent à intervalles réguliers.
    static func progress(elapsed: TimeInterval) -> Double {
        let time = min(1, max(0, elapsed / duration))
        return time
    }

    /// Le nombre de lignes cochées : elles se partagent la course, la dernière à cent.
    static func checkedCount(progress: Double, lines: Int) -> Int {
        guard lines > 0 else { return 0 }
        return min(lines, Int((progress * Double(lines) + 0.0001).rounded(.down)))
    }

    private var lines: [String] {
        model.planLines(locale: i18n.locale)
    }

    var body: some View {
        OnbScreen {
            Spacer(minLength: 8)
                .layoutPriority(-1)

            OnbHeroMika(mood: .write, max: 130, min: 80)

            Text(i18n.t("ios.onb10.build.title"))
                .font(V3Font.h1)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .accessibilityAddTraits(.isHeader)

            if let frozen = previewProgress ?? (still ? 1 : nil) {
                PlanBuildingProgress(progress: frozen, lines: lines, isLive: false)
            } else {
                TimelineView(.periodic(from: start, by: Self.tick)) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    PlanBuildingProgress(progress: Self.progress(elapsed: elapsed), lines: lines, isLive: true)
                        .onChange(of: elapsed >= Self.duration + Self.hold) { _, isOver in
                            guard isOver else { return }
                            finish()
                        }
                }
            }

            Spacer(minLength: 8)
                .layoutPriority(-1)
        }
    }

    /// Le chargement est fini : le parcours passe au plan prêt, une fois.
    private func finish() {
        guard !didAdvance, model.step == .planBuilding else { return }
        didAdvance = true
        Haptics.success()
        model.advance()
    }
}

/// **Ce qui bouge pendant le chargement** : le pourcentage, la jauge, et la liste qui se coche.
private struct PlanBuildingProgress: View {
    let progress: Double
    let lines: [String]
    /// Faux dans un rendu : pas de retour haptique.
    let isLive: Bool

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var checked: Int {
        PlanBuildingStepView.checkedCount(progress: progress, lines: lines.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(L10n.percent(Int((progress * 100).rounded()), locale: i18n.locale))
                .font(V3Font.display(48))
                .foregroundStyle(V3Color.accentBright)
                .monospacedDigit()
                .padding(.top, 4)
            V3ProgressBar(value: progress)
                .padding(.top, 6)

            checklist
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: checked) { previous, next in
            guard isLive, next > previous else { return }
            Haptics.soft()
        }
    }

    /// La liste, dans une carte : cochée, en cours (un anneau), à venir.
    private var checklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .center, spacing: 12) {
                    mark(index)
                    Text(line)
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(index < checked ? V3Color.ink : (index == checked ? V3Color.ink2 : V3Color.ink3))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card()
    }

    @ViewBuilder
    private func mark(_ index: Int) -> some View {
        if index < checked {
            Image(systemName: "checkmark.circle.fill")
                .font(V3Font.title)
                .foregroundStyle(V3Color.green)
                .transition(.scale.combined(with: .opacity))
        } else if index == checked {
            Image(systemName: "circle")
                .font(V3Font.title)
                .foregroundStyle(V3Color.accent)
        } else {
            Image(systemName: "circle.fill")
                .font(V3Font.title)
                .foregroundStyle(V3Color.line)
        }
    }
}

// MARK: - Le plan prêt

/// **« Lina, ton plan est prêt »** : le moment où le parcours rend ce qu'il a demandé, et qui
/// **se comprend en trois secondes** (lot 12). Trois blocs, un gros chiffre chacun :
///
/// 1. **Ce soir** : l'heure du rappel, en grand, et ce qu'on travaille (sa première leçon, sinon
///    sa matière la plus dure) pendant son temps choisi. Mis en avant.
/// 2. **Cette semaine** : sept séances, une par jour, à sa durée.
/// 3. **Ton objectif** : sa note visée, en vert, et le jour de son examen (sans examen :
///    l'horizon de trois mois ; sans note : l'examen et sa date ; sans rien : le bloc part).
///
/// Mika fête, des confettis une fois. Le compte se propose en quittant cet écran. Le nom de
/// l'étape reste `profileSummary` : sa courbe dans les statistiques continue.
struct ProfileSummaryStepView: View {
    var now = Date()

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    /// Une séance par jour : sept dans la semaine.
    static let sessionsPerWeek = 7

    private var title: String {
        guard let name = model.displayName.nilIfBlank else { return i18n.t("ios.onb10.plan.titleNoName") }
        return i18n.t("ios.onb10.plan.title", ["name": name])
    }

    /// Ce que la séance de ce soir travaille : la première leçon, sinon la matière la plus dure.
    private var tonight: String {
        if let lesson = model.firstLessonLine(locale: i18n.locale) { return lesson }
        if let subject = model.focusSubject { return SubjectDisplay.subject(subject, locale: i18n.locale) }
        return model.firstSubjectName(locale: i18n.locale) ?? i18n.t("ios.onb11.plan.lesson")
    }

    /// L'objectif : la valeur en grand et sa ligne, ou rien quand l'élève n'a dit ni note ni
    /// examen.
    private var goal: (value: String, detail: String)? {
        let exam = model.datedExam
        if let target = model.targetLabel(locale: i18n.locale) {
            if let exam {
                return (target, i18n.t("ios.onb12.plan.goalDetail", [
                    "exam": exam.choice.title(locale: i18n.locale),
                    "date": OnbWords.day(exam.date, locale: i18n.locale),
                ]))
            }
            return (target, i18n.t("ios.onb12.plan.goalOpen", [
                "time": OnbWords.duration(days: StartingPointStepView.openHorizonDays, locale: i18n.locale),
            ]))
        }
        if let exam {
            return (exam.choice.title(locale: i18n.locale), OnbWords.date(exam.date, locale: i18n.locale))
        }
        return nil
    }

    var body: some View {
        OnbScreen {
            OnbHeroMika(mood: .celebrate, max: compact ? 84 : 120, min: 64)
                .padding(.top, 2)

            OnbTitle(title, size: OnbLayout.display, alignment: .center)
                .padding(.top, 4)

            VStack(spacing: 10) {
                block(
                    label: i18n.t("ios.onb12.plan.tonightLabel"),
                    value: OnbWords.hour(model.reminderHour, locale: i18n.locale),
                    detail: i18n.t("ios.onb12.plan.tonightDetail", ["topic": tonight, "min": "\(model.minutesPerDay)"]),
                    tone: V3Color.accentBright,
                    highlighted: true
                )
                block(
                    label: i18n.t("ios.onb12.plan.weekLabel"),
                    value: "\(Self.sessionsPerWeek)",
                    detail: i18n.t("ios.onb12.plan.weekDetail", ["min": "\(model.minutesPerDay)"]),
                    tone: V3Color.ink,
                    highlighted: false
                )
                if let goal {
                    block(
                        label: i18n.t("ios.onb12.plan.goalLabel"),
                        value: goal.value,
                        detail: goal.detail,
                        tone: V3Color.green,
                        highlighted: false
                    )
                }
            }
            .padding(.top, 16)
        } footer: {
            V3Button(i18n.t("ios.deckBuild.seePlan")) {
                model.advance()
            }
        }
        .overlay {
            OnbConfetti(isOn: true)
        }
    }

    /// Un bloc : son nom en petit, le gros chiffre, la ligne qui le dit en mots.
    private func block(label: String, value: String, detail: String, tone: Color, highlighted: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(value)
                .font(V3Font.display(compact ? 34 : 40))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.ink2)
                Text(detail)
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, compact ? 10 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(selected: highlighted)
        .accessibilityElement(children: .combine)
    }
}
