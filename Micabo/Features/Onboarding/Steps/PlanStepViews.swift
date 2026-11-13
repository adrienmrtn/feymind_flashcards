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

    /// De 0 à 1, d'après le temps écoulé. La course part vite et se pose : c'est un travail
    /// qui s'achève.
    static func progress(elapsed: TimeInterval) -> Double {
        let time = min(1, max(0, elapsed / duration))
        return 1 - (1 - time) * (1 - time)
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

/// **« Lina, ton plan est prêt »** : le moment où le parcours rend ce qu'il a demandé, **comme
/// un objet à lui** (lot 12).
///
/// Mika fête, des confettis une fois, et le plan en une carte : « Plan de Lina », son examen et
/// le temps qu'il reste ; sa semaine, un point par jour ; **la première séance, ce soir à son
/// heure**, sur sa première leçon (ou sa matière la plus dure) ; son objectif dans son barème.
/// Une réponse absente retire sa ligne. Le compte se propose en quittant cet écran.
///
/// Le nom de l'étape reste `profileSummary` : sa courbe dans les statistiques continue.
struct ProfileSummaryStepView: View {
    var now = Date()

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    private var title: String {
        guard let name = model.displayName.nilIfBlank else { return i18n.t("ios.onb10.plan.titleNoName") }
        return i18n.t("ios.onb10.plan.title", ["name": name])
    }

    private var planName: String {
        guard let name = model.displayName.nilIfBlank else { return i18n.t("ios.onb12.plan.nameAny") }
        return i18n.t("ios.onb12.plan.name", ["name": name])
    }

    /// Ce que la séance de ce soir travaille : la première leçon, sinon la matière la plus dure.
    private var tonight: String {
        if let lesson = model.firstLessonLine(locale: i18n.locale) { return lesson }
        if let subject = model.focusSubject { return SubjectDisplay.subject(subject, locale: i18n.locale) }
        return model.firstSubjectName(locale: i18n.locale) ?? i18n.t("ios.onb11.plan.lesson")
    }

    var body: some View {
        OnbScreen {
            OnbHeroMika(mood: .celebrate, max: compact ? 96 : 130, min: 72)
                .padding(.top, 4)

            OnbTitle(title, size: OnbLayout.display, alignment: .center)
                .padding(.top, 6)

            plan
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

    /// **Le plan, comme un objet** : son nom, son examen, sa semaine, la séance de ce soir, son
    /// objectif.
    private var plan: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Text(planName)
                    .font(V3Font.heading(24))
                    .foregroundStyle(V3Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let exam = model.examName(locale: i18n.locale), let days = model.examDaysLeft(now: now), days > 0 {
                    // « Bac · 7 mois » : deux mots de l'élève, séparés d'un point médian.
                    Text(verbatim: "\(exam) · \(OnbWords.duration(days: days, locale: i18n.locale))")
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.yellowInk)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(V3Color.yellowWash, in: Capsule())
                }
            }

            V3WeekStrip(days: PlanDemoStepView.week(from: now, examDate: model.datedExam?.date, locale: i18n.locale))

            // La séance de ce soir : le temps fort de la carte.
            HStack(spacing: 12) {
                OnbIcon(icon: .alarm, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(i18n.t("ios.onb12.plan.tonight", ["hour": OnbWords.hour(model.reminderHour, locale: i18n.locale)]))
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.accentBright)
                    Text(tonight)
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(V3Color.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(i18n.t("ios.quiz.time.short", ["n": "\(model.minutesPerDay)"]))
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.accentBright)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(V3Color.accentWash, in: Capsule())
            }
            .padding(12)
            .background(V3Color.accentWash.opacity(0.5), in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous)
                    .strokeBorder(V3Color.accent, lineWidth: V3Metric.border)
            )

            if let target = model.targetLabel(locale: i18n.locale) {
                HStack(spacing: 12) {
                    OnbIcon(icon: .trophy, size: 24)
                    Text(i18n.t("ios.onb5.plan.goal"))
                        .font(V3Font.body)
                        .foregroundStyle(V3Color.ink2)
                    Spacer(minLength: 8)
                    Text(model.currentLabel(locale: i18n.locale).map { OnbWords.range(from: $0, to: target, locale: i18n.locale) } ?? target)
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(V3Color.green)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }

            let names = OnbDemo.sessionSubjects(for: model, locale: i18n.locale)
            if !names.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    OnbIcon(icon: .book, size: 24)
                    Text(OnbWords.list(names, locale: i18n.locale))
                        .font(V3Font.body)
                        .foregroundStyle(V3Color.ink2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(selected: true)
    }
}
