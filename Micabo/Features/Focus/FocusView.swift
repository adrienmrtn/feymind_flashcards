import SwiftData
import SwiftUI

/// **L'onglet Concentration** : la journée de concentration et le grand bouton qui lance une
/// séance, la prochaine révision posée par Mika, « Mes tâches », et la semaine en chiffres.
///
/// Une séance se prépare (`FocusSetupSheet`), se mène (`FocusTimerView`) et se range
/// (`FocusRecorder`) : ses minutes comptent ici, dans les heures de Home, et dans le calendrier.
struct FocusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TabRouter.self) private var router: TabRouter?

    @Query(sort: \StudyTask.createdAt) private var tasks: [StudyTask]
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var sessions: [FocusSession]
    @Query private var events: [CalendarEvent]
    @Query(sort: \Exam.date) private var exams: [Exam]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var setup: FocusPlan?
    @State private var running: FocusPlan?
    @State private var pendingRun: FocusPlan?
    @State private var showsTasks = false
    @State private var addingTask = false
    @State private var streak = StudyStreak.status()
    @State private var now = Date()

    private var lessons: [Course] { courses.filter { $0.isLesson && $0.source != .deck } }
    private var specs: [FocusSessionSpec] { sessions.prefix(500).map(\.spec) }
    private var goalMinutes: Int { max(5, OnboardingPreferences.dailyMinutes) }

    /// Les tâches de la carte : celles à faire, et celles cochées aujourd'hui.
    private var cardTasks: [StudyTaskSpec] {
        tasks
            .filter { !$0.isDone || ($0.doneAt.map { MicaboCalendar.shared.isDateInToday($0) } ?? false) }
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (left?, right?): return left < right
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return lhs.createdAt < rhs.createdAt
                }
            }
            .map(\.spec)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MicaboPageHeading(title: loc("ios.focus.title"), subtitle: nil) { EmptyView() }
                        .padding(.top, MicaboSpacing.xs)

                    FocusHeroCard(
                        minutesToday: FocusStats.minutes(on: now, sessions: specs),
                        goalMinutes: goalMinutes,
                        streak: streak.current,
                        streakLit: streak.studiedToday,
                        onStart: { openSetup() }
                    )

                    if let next = nextRevision {
                        FocusNextRevisionCard(
                            time: CalendarTime.label(next.start),
                            title: next.event.title,
                            detail: revisionDetail(next),
                            onStart: { startRevision(next) }
                        )
                    }

                    FocusTasksCard(
                        tasks: cardTasks,
                        lessonTitles: Dictionary(lessons.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first }),
                        onAdd: { addingTask = true },
                        onToggle: toggleTask,
                        onDelete: deleteTask,
                        onSeeAll: { showsTasks = true }
                    )

                    FocusStatsCard(
                        days: FocusStats.lastSevenDays(endingAt: now, sessions: specs).map { FocusDayBar(day: $0.day, minutes: $0.minutes) },
                        goalMinutes: goalMinutes,
                        weekMinutes: FocusStats.weekMinutes(now: now, sessions: specs),
                        weekSessions: FocusStats.weekSessions(now: now, sessions: specs),
                        bestStreak: streak.best
                    )
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .tabBarClearance()
            .toolbar(.hidden, for: .navigationBar)
        }
        .reportsNavigationDepth(for: .focus, depth: 0)
        .sheet(item: $setup, onDismiss: launchPending) { plan in
            FocusSetupSheet(initial: plan, lessons: lessons, tasks: cardTasks.filter { !$0.isDone }) { prepared in
                pendingRun = prepared
                setup = nil
            }
        }
        .fullScreenCover(item: $running, onDismiss: refresh) { plan in
            FocusTimerView(plan: plan)
        }
        .sheet(isPresented: $showsTasks) {
            TasksSheet(lessons: lessons)
        }
        .sheet(isPresented: $addingTask) {
            TaskEditSheet(lessons: lessons)
        }
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onChange(of: router?.focusRequests ?? 0) { _, _ in openSetup() }
        .onReceive(NotificationCenter.default.publisher(for: .micaboStreakDidChange)) { _ in refresh() }
    }

    // MARK: La prochaine révision

    /// La prochaine séance de révision d'aujourd'hui, pas encore faite ni passée.
    private var nextRevision: CalendarOccurrence? {
        let revisions = events.filter { $0.kind == .revision && !$0.isDone }.map(\.spec)
        return CalendarRecurrence.occurrences(of: revisions, on: now).first { $0.end > now }
    }

    private func revisionDetail(_ occurrence: CalendarOccurrence) -> String {
        let minutes = CalendarTime.duration(minutes: occurrence.event.endMinute - occurrence.event.startMinute)
        guard let exam = exams.first(where: { $0.id == occurrence.event.examID }) else { return minutes }
        return "\(exam.name) · \(minutes)"
    }

    private func startRevision(_ occurrence: CalendarOccurrence) {
        let course = lessons.first { $0.id == occurrence.event.courseID }
        running = .revision(
            eventID: occurrence.event.id,
            startMinute: occurrence.event.startMinute,
            endMinute: occurrence.event.endMinute,
            courseID: course?.id,
            courseTitle: course?.title
        )
    }

    // MARK: Les gestes

    private func openSetup() {
        guard setup == nil, running == nil else { return }
        setup = FocusPlan(workMinutes: FocusPlan.defaultMinutes(dailyMinutes: OnboardingPreferences.dailyMinutes))
    }

    /// La feuille est refermée : la séance préparée part maintenant. Une couverture ne se
    /// présente pas pendant qu'une feuille descend.
    private func launchPending() {
        guard let plan = pendingRun else { return }
        pendingRun = nil
        running = plan
    }

    private func refresh() {
        now = Date()
        let next = StudyStreak.status()
        if next != streak { streak = next }
    }

    private func toggleTask(_ id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        withAnimation(.spring(duration: 0.3)) {
            task.isDone.toggle()
            task.doneAt = task.isDone ? Date() : nil
        }
        try? modelContext.save()
        if task.isDone {
            Haptics.success()
            Analytics.track(.taskDone)
        }
    }

    private func deleteTask(_ id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        modelContext.delete(task)
        try? modelContext.save()
    }
}
