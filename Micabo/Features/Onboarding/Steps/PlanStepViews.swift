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

            // Lot 15 : le titre ne dit plus « je » — « Mika prépare ton plan… ».
            OnbTitle(i18n.t("ios.onb15.build.title"), size: OnbLayout.questionTitle, alignment: .center)
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
/// **Le plan se dévoile** (demande du fondateur) : le titre, puis les blocs un à un — chacun
/// avec son icône, d'un ressort et d'un léger retour haptique —, puis les confettis, et
/// seulement alors le bouton. **Mika ne reste pas figé** : après sa fête il flotte doucement, et
/// change de geste toutes les quelques secondes. Les rendus, « Réduire les animations » et
/// VoiceOver montrent tout posé.
///
/// Le compte se propose en quittant cet écran. Le nom de l'étape reste `profileSummary` : sa
/// courbe dans les statistiques continue.
struct ProfileSummaryStepView: View {
    var now = Date()

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still
    @OnbArrivalSkipped private var skipsArrival

    /// Ce qui est dévoilé : 0 rien, 1 le titre, puis un cran par bloc, puis le bouton.
    @State private var revealed = 0
    /// Le geste de Mika : la fête d'abord, puis il en change.
    @State private var mikaMood: MikaMood = .celebrate
    /// Mika flotte.
    @State private var floats = false

    /// Les gestes que Mika enchaîne après sa fête.
    private static let moods: [MikaMood] = [.happy, .wink, .proud, .wave, .celebrate]

    /// Une séance par jour : sept dans la semaine.
    static let sessionsPerWeek = 7

    /// La durée d'une séance (une heure au plus) et le nombre de séances par jour.
    private var sessionMinutes: Int { RevisionPlanner.sessionLength(dailyMinutes: model.minutesPerDay) }
    private var sessionsPerDay: Int { RevisionPlanner.sessionLengths(dailyMinutes: model.minutesPerDay).count }

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

    /// Un bloc du plan.
    private struct Block: Identifiable {
        let id: Int
        let icon: MicaboIcon
        let iconTone: Color
        let label: String
        let value: String
        let detail: String
        let tone: Color
        let highlighted: Bool
    }

    private var blocks: [Block] {
        // Lot 16 : une séance dure une heure au plus ; au-delà, plusieurs séances par jour.
        var blocks = [
            Block(
                id: 0,
                icon: .alarm,
                iconTone: V3Color.iconBlue,
                label: i18n.t("ios.onb12.plan.tonightLabel"),
                value: OnbWords.hour(model.reminderHour, locale: i18n.locale),
                detail: i18n.t("ios.onb12.plan.tonightDetail", ["topic": tonight, "min": "\(sessionMinutes)"]),
                tone: V3Color.accentBright,
                highlighted: true
            ),
            Block(
                id: 1,
                icon: .exam,
                iconTone: V3Color.iconYellow,
                label: i18n.t("ios.onb12.plan.weekLabel"),
                value: "\(Self.sessionsPerWeek * sessionsPerDay)",
                detail: sessionsPerDay > 1
                    ? i18n.t("ios.onb16.plan.weekSplit", ["min": "\(sessionMinutes)", "count": "\(sessionsPerDay)"])
                    : i18n.t("ios.onb12.plan.weekDetail", ["min": "\(sessionMinutes)"]),
                tone: V3Color.ink,
                highlighted: false
            ),
        ]
        if let goal {
            blocks.append(Block(
                id: 2,
                icon: .trophy,
                iconTone: V3Color.iconGreen,
                label: i18n.t("ios.onb12.plan.goalLabel"),
                value: goal.value,
                detail: goal.detail,
                tone: V3Color.green,
                highlighted: false
            ))
        }
        return blocks
    }

    /// Le cran où tout est dévoilé : le titre, chaque bloc, puis le bouton.
    private var lastStage: Int { blocks.count + 2 }
    private var stage: Int { skipsArrival ? lastStage : revealed }
    private var isUnveiled: Bool { stage >= lastStage }

    var body: some View {
        let blocks = self.blocks
        return OnbScreen {
            OnbHeroMika(mood: mikaMood, max: compact ? 84 : 120, min: 64)
                .offset(y: floats ? -5 : 3)
                .padding(.top, 2)

            OnbTitle(title, size: OnbLayout.display, alignment: .center)
                .padding(.top, 4)
                .opacity(stage >= 1 ? 1 : 0)
                .offset(y: stage >= 1 ? 0 : 10)

            VStack(spacing: 10) {
                ForEach(blocks) { item in
                    let shown = stage >= item.id + 2
                    block(item)
                        .opacity(shown ? 1 : 0)
                        .scaleEffect(shown ? 1 : 0.9)
                        .offset(y: shown ? 0 : 16)
                }
            }
            .padding(.top, 16)
        } footer: {
            V3Button(i18n.t("ios.deckBuild.seePlan")) {
                model.advance()
            }
            .onbRevealed(isUnveiled)
        }
        .overlay {
            OnbConfetti(isOn: isUnveiled)
        }
        .onAppear {
            guard !still, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { floats = true }
        }
        .task { await unveil(count: blocks.count) }
        .task { await enliven() }
    }

    /// Le plan se dévoile : le titre, les blocs un à un, puis la fête et le bouton.
    @MainActor
    private func unveil(count: Int) async {
        guard !skipsArrival, revealed == 0 else { return }
        // La page finit de glisser.
        try? await Task.sleep(for: .milliseconds(420))
        for next in 1...(count + 1) {
            guard !Task.isCancelled else { return }
            withAnimation(MicaboMotion.celebrate) { revealed = next }
            if next > 1 { Haptics.soft() }
            try? await Task.sleep(for: .milliseconds(next == 1 ? 480 : 440))
        }
        guard !Task.isCancelled else { return }
        Haptics.success()
        revealed = count + 2
    }

    /// Mika ne reste pas figé : il change de geste toutes les quelques secondes.
    @MainActor
    private func enliven() async {
        guard !still, !reduceMotion else { return }
        var index = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3.4))
            guard !Task.isCancelled else { return }
            mikaMood = Self.moods[index % Self.moods.count]
            index += 1
        }
    }

    /// Un bloc : le gros chiffre ; à côté, son icône et son nom, puis la ligne qui le dit en
    /// mots.
    private func block(_ item: Block) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(item.value)
                .font(V3Font.display(compact ? 34 : 40))
                .foregroundStyle(item.tone)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    MicaboIconView(icon: item.icon, size: 17 * 1.35, tint: item.iconTone)
                        .frame(width: 28, height: 28)
                        .background(V3Color.wash(of: item.iconTone), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text(item.label)
                        .font(V3Font.label)
                        .foregroundStyle(V3Color.ink2)
                }
                Text(item.detail)
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
        .v3Card(selected: item.highlighted)
        .accessibilityElement(children: .combine)
    }
}
