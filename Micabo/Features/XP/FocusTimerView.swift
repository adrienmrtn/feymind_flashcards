import SwiftData
import SwiftUI
import UIKit

/// Le temps de concentration mené au bout, toutes séances confondues : il s'ajoute aux heures
/// de révision de Home (`HomeStats`). Chaque séance a aussi sa ligne (`FocusSession`), pour la
/// journée, la semaine et le calendrier.
enum FocusLog {
    static let key = "micabo.focus.seconds"

    static var totalSeconds: Double {
        UserDefaults.standard.double(forKey: key)
    }

    static func add(_ seconds: Double) {
        UserDefaults.standard.set(totalSeconds + max(0, seconds), forKey: key)
    }

    /// Un compte qui s'en va (`LocalWipe`) : ses heures de concentration ne s'ajoutent pas à
    /// celles du compte suivant.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// **La séance en cours** (`docs/refonte-knowunity.md` § 5, puis l'onglet Concentration) : Mika
/// au centre d'un anneau qui se vide, le temps, Pause / Reprendre, Arrêter (avec confirmation).
/// En Pomodoro, les cycles de travail et les pauses s'enchaînent seuls, et une pause peut se
/// passer. Au bout, la fête, l'XP de chaque bloc de 25 minutes, et le temps compte dans les
/// heures de révision.
///
/// **Le temps se calcule depuis l'heure de départ**, jamais en comptant des secondes : l'app
/// peut passer en arrière-plan, l'écran peut se verrouiller, la séance continue de courir et la
/// phase tombe juste au retour. Une notification annonce chaque fin de phase pendant que l'app
/// dort. L'écran reste allumé tant que la séance est ouverte.
struct FocusTimerView: View {
    let plan: FocusPlan

    init(plan: FocusPlan = .default) {
        self.plan = plan
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \StudyTask.createdAt) private var allTasks: [StudyTask]
    @Query private var courses: [Course]

    /// Le premier départ de la séance.
    @State private var startedAt: Date?
    /// Le départ du morceau en cours ; nil en pause.
    @State private var segmentStart: Date?
    /// Le temps déjà couru avant le morceau en cours.
    @State private var elapsedBefore: TimeInterval = 0
    @State private var finished = false
    @State private var award: XPAward?
    @State private var workDone: TimeInterval = 0
    @State private var confirmsStop = false
    @State private var openLesson: Course?
    @State private var lastPhase = 0

    private var phases: [FocusPhase] { plan.phases }
    private var isPaused: Bool { segmentStart == nil && !finished }
    private var goalTasks: [StudyTask] { allTasks.filter { plan.taskIDs.contains($0.id) } }
    private var goalCourse: Course? { courses.first { $0.id == plan.courseID } }

    var body: some View {
        ZStack {
            MicaboColor.canvas.ignoresSafeArea()
            if finished {
                FocusFinishedScreen(
                    minutes: Int(workDone / 60),
                    award: award,
                    tasks: goalTasks.map(\.spec),
                    onToggleTask: toggleTask,
                    onContinue: { dismiss() }
                )
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let position = FocusPhases.position(in: phases, elapsed: elapsed(at: context.date))
                    FocusSessionScreen(
                        plan: plan,
                        position: position,
                        isPaused: isPaused,
                        lessonTitle: goalCourse?.title ?? plan.courseTitle,
                        tasks: goalTasks.map(\.spec),
                        onToggleTask: toggleTask,
                        onOpenLesson: openLessonAction,
                        onPauseResume: { isPaused ? resume() : pause() },
                        onSkipBreak: skipBreak,
                        onStop: { confirmsStop = true }
                    )
                    .onChange(of: position.finished) { _, done in
                        if done { finish() }
                    }
                    .onChange(of: position.index) { _, index in
                        guard index != lastPhase else { return }
                        lastPhase = index
                        Haptics.success()
                    }
                }
            }
        }
        .animation(.spring(duration: 0.5), value: finished)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            guard startedAt == nil else { return }
            startedAt = Date()
            segmentStart = Date()
            Analytics.track(.focusStarted, [
                "mode": .text(plan.mode.rawValue),
                "minutes": .number(Double(plan.totalWorkMinutes)),
                "goal": .flag(plan.courseID != nil),
                "planned": .flag(plan.eventID != nil),
            ])
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            FocusPhaseAlerts.cancel()
        }
        // En arrière-plan, les fins de phase s'annoncent ; au retour, elles se retirent, et la
        // séance a pu se terminer pendant l'absence.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if !isPaused && !finished { FocusPhaseAlerts.schedule(plan: plan, elapsed: elapsed(at: Date())) }
            case .active:
                FocusPhaseAlerts.cancel()
                finishIfDue()
            default:
                break
            }
        }
        .sheet(item: $openLesson) { course in
            NavigationStack {
                LessonPathView(course: course)
            }
        }
        .confirmationDialog(
            L10n.t("ios.kx.timer.stopQ", locale: .resolved()),
            isPresented: $confirmsStop,
            titleVisibility: .visible
        ) {
            Button(L10n.t("ios.kx.timer.stop", locale: .resolved()), role: .destructive, action: stop)
            Button(L10n.t("ios.kx.timer.keepGoing", locale: .resolved()), role: .cancel) {}
        } message: {
            Text(loc("ios.focus.stopMsg"))
        }
    }

    /// Ouvrir la leçon de l'objectif, par-dessus la séance qui continue de courir.
    private var openLessonAction: (() -> Void)? {
        guard let course = goalCourse else { return nil }
        return { openLesson = course }
    }

    // MARK: Le temps

    private func elapsed(at date: Date) -> TimeInterval {
        elapsedBefore + (segmentStart.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    private func pause() {
        guard let segmentStart else { return }
        elapsedBefore += max(0, Date().timeIntervalSince(segmentStart))
        self.segmentStart = nil
        Haptics.light()
    }

    private func resume() {
        segmentStart = Date()
        Haptics.light()
    }

    private func skipBreak() {
        let now = Date()
        let next = FocusPhases.elapsedAtNextPhase(in: phases, elapsed: elapsed(at: now))
        elapsedBefore = next
        if segmentStart != nil { segmentStart = now }
        Haptics.medium()
    }

    private func finishIfDue() {
        guard !finished, FocusPhases.position(in: phases, elapsed: elapsed(at: Date())).finished else { return }
        finish()
    }

    private func finish() {
        guard !finished else { return }
        let total = FocusPhases.total(phases)
        elapsedBefore = total
        segmentStart = nil
        workDone = FocusPhases.position(in: phases, elapsed: total).workDone
        // La fête du jour se montre ici, dans l'écran de fin : pas de seconde fête par-dessus.
        award = FocusRecorder.record(
            plan: plan,
            startedAt: startedAt ?? Date().addingTimeInterval(-total),
            workSeconds: workDone,
            completed: true,
            in: modelContext
        )
        finished = true
        UIApplication.shared.isIdleTimerDisabled = false
        Haptics.success()
        Haptics.burst(count: 3, over: 0.45)
    }

    /// Arrêter en route : les minutes de travail faites comptent, et chaque bloc de 25 minutes
    /// terminé rapporte son XP.
    private func stop() {
        let done = FocusPhases.position(in: phases, elapsed: elapsed(at: Date())).workDone
        FocusRecorder.record(plan: plan, startedAt: startedAt ?? Date(), workSeconds: done, completed: false, in: modelContext)
        dismiss()
    }

    private func toggleTask(_ id: UUID) {
        guard let task = allTasks.first(where: { $0.id == id }) else { return }
        task.isDone.toggle()
        task.doneAt = task.isDone ? Date() : nil
        try? modelContext.save()
        if task.isDone { Haptics.success() }
    }

    static func format(_ seconds: TimeInterval) -> String {
        FocusPhases.clock(seconds)
    }
}

// MARK: - L'écran de la séance

/// **La séance, dessinée** sans horloge : la position vient de qui l'appelle (`TimelineView`
/// dans l'app, une valeur figée dans les rendus).
struct FocusSessionScreen: View {
    let plan: FocusPlan
    let position: FocusPosition
    let isPaused: Bool
    let lessonTitle: String?
    let tasks: [StudyTaskSpec]
    let onToggleTask: (UUID) -> Void
    let onOpenLesson: (() -> Void)?
    let onPauseResume: () -> Void
    let onSkipBreak: () -> Void
    let onStop: () -> Void

    private var isRest: Bool { position.phase.kind == .rest }

    private var mood: MikaMood {
        if isPaused { return .idle }
        return isRest ? .sleep : .write
    }

    private var ringColors: [Color] {
        isRest ? [LessonTone.mint.vivid, LessonTone.mint.vivid.opacity(0.7)] : MicaboColor.brandGradient
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 12)

            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .stroke(MicaboColor.track, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: max(0, min(1, position.remaining / max(1, position.phase.seconds))))
                    .stroke(
                        LinearGradient(colors: ringColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: position.remaining)
                MikaMascot(mood: mood, size: 120)
            }
            .frame(width: 250, height: 250)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(L10n.t("ios.kx.timer.remainingA11y", locale: .resolved(), vars: ["time": FocusPhases.clock(position.remaining)])))

            Text(FocusPhases.clock(position.remaining))
                .font(MicaboFont.number(60))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(countsDown: true))
                .padding(.top, 20)
                .accessibilityHidden(true)
            Text(message)
                .font(MicaboFont.ui(17, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.horizontal, 32)

            goals
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 16)

            Spacer(minLength: 12)

            buttons
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 16)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: isRest ? "cup.and.saucer.fill" : "brain.head.profile")
                    .font(.system(size: 13, weight: .bold))
                Text(loc(isRest ? "ios.focus.phaseRest" : "ios.focus.phaseWork"))
                    .font(MicaboFont.ui(14, weight: .black))
            }
            .foregroundStyle(isRest ? LessonTone.mint.ink : MicaboColor.accentInk)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(isRest ? LessonTone.mint.pale : MicaboColor.accentSoft, in: Capsule())

            if plan.mode == .pomodoro {
                Text(loc("ios.focus.cycleOf", ["n": "\(position.phase.cycle)", "total": "\(plan.effectiveCycles)"]))
                    .font(MicaboFont.ui(14, weight: .black))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(MicaboColor.surface, in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    private var message: String {
        if isPaused { return L10n.t("ios.kx.timer.paused", locale: .resolved()) }
        if isRest { return loc("ios.focus.restMessage") }
        return L10n.t("ios.kx.timer.focus", locale: .resolved())
    }

    @ViewBuilder
    private var goals: some View {
        if lessonTitle != nil || !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if let lessonTitle {
                    HStack(spacing: 10) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(MicaboColor.accentInk)
                        Text(lessonTitle)
                            .font(MicaboFont.ui(15, weight: .black))
                            .foregroundStyle(MicaboColor.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if let onOpenLesson {
                            Button(action: onOpenLesson) {
                                Text(loc("ios.focus.openLesson"))
                                    .font(MicaboFont.ui(13.5, weight: .black))
                                    .foregroundStyle(MicaboColor.accentInk)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 32)
                                    .background(MicaboColor.accentSoft, in: Capsule())
                            }
                            .buttonStyle(HomePressStyle(scale: 0.94))
                        }
                    }
                }
                ForEach(tasks.prefix(3)) { task in
                    Button {
                        onToggleTask(task.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(task.isDone ? MicaboColor.correctInk : MicaboColor.inkTertiary)
                            Text(task.title)
                                .font(MicaboFont.ui(15, weight: .bold))
                                .foregroundStyle(task.isDone ? MicaboColor.inkSecondary : MicaboColor.ink)
                                .strikethrough(task.isDone, color: MicaboColor.inkTertiary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HomePressStyle(scale: 0.98, feedback: .selection))
                }
            }
            .padding(14)
            .homeCard(radius: MicaboStage.tileRadius)
        }
    }

    /// Pendant une pause, le geste principal est de la passer : « Pause » sur un écran qui
    /// dit déjà « Pause » se lirait de travers.
    private var buttons: some View {
        VStack(spacing: 10) {
            if isRest && !isPaused {
                Button(action: onSkipBreak) {
                    Label(loc("ios.focus.skipBreak"), systemImage: "forward.fill")
                }
                .buttonStyle(MicaboBrandButtonStyle())
            } else {
                pauseButton
                    .buttonStyle(MicaboBrandButtonStyle())
            }
            HStack(spacing: 10) {
                if isRest && !isPaused {
                    pauseButton
                        .buttonStyle(MicaboSecondaryButtonStyle())
                }
                Button(action: onStop) {
                    Label(L10n.t("ios.kx.timer.stop", locale: .resolved()), systemImage: "stop.fill")
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
            }
        }
    }

    private var pauseButton: some View {
        Button(action: onPauseResume) {
            Label(
                isPaused ? L10n.t("ios.kx.timer.resume", locale: .resolved()) : L10n.t("ios.kx.timer.pause", locale: .resolved()),
                systemImage: isPaused ? "play.fill" : "pause.fill"
            )
        }
    }
}

// MARK: - La fin

/// **La séance terminée** : les confettis, Mika qui fête, les minutes, l'XP gagnée, les tâches
/// de la séance à cocher.
struct FocusFinishedScreen: View {
    let minutes: Int
    let award: XPAward?
    let tasks: [StudyTaskSpec]
    let onToggleTask: (UUID) -> Void
    let onContinue: () -> Void

    @Environment(\.homeStill) private var still

    var body: some View {
        ZStack {
            if !still {
                ConfettiView(colors: [MicaboColor.accent, MicaboColor.accentDeep, LessonTone.mint.vivid, MicaboBrand.pencil])
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            ScrollView {
                VStack(spacing: 16) {
                    if award?.reachedGoal == true {
                        XPGoalCard(showsButton: false)
                            .padding(.top, 24)
                    } else {
                        MicaboSpeechBubble(text: L10n.t("ios.kx.timer.mika", locale: .resolved()), tail: .bottom)
                            .padding(.top, 40)
                            .padding(.horizontal, 12)
                        MikaMascot(mood: .celebrate, size: 120, reactsToTap: true)
                    }
                    Text(L10n.t("ios.kx.timer.done", locale: .resolved()))
                        .font(MicaboFont.display(30))
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.t("ios.kx.timer.doneBody", locale: .resolved(), vars: ["n": "\(minutes)"]))
                        .font(MicaboFont.ui(17, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.center)
                    if let added = award?.added, added > 0 {
                        XPBadge(points: added)
                            .scaleEffect(1.25)
                            .padding(.top, 4)
                    }
                    if !tasks.isEmpty {
                        taskList
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, MicaboSpacing.screen)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(L10n.t("ios.kx.continue", locale: .resolved()), action: onContinue)
                    .buttonStyle(MicaboBrandButtonStyle())
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, 12)
                    .background(MicaboColor.canvas)
            }
        }
    }

    private var taskList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc("ios.focus.sessionTasks"))
                .font(MicaboFont.ui(15, weight: .black))
                .foregroundStyle(MicaboColor.ink)
            ForEach(tasks) { task in
                Button {
                    onToggleTask(task.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(task.isDone ? MicaboColor.correctInk : MicaboColor.inkTertiary)
                            .contentTransition(.symbolEffect(.replace))
                        Text(task.title)
                            .font(MicaboFont.ui(15.5, weight: .bold))
                            .foregroundStyle(task.isDone ? MicaboColor.inkSecondary : MicaboColor.ink)
                            .strikethrough(task.isDone, color: MicaboColor.inkTertiary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(HomePressStyle(scale: 0.98, feedback: .selection))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(radius: MicaboStage.tileRadius)
    }
}
