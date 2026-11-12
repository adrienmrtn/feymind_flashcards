import SwiftData
import SwiftUI

/// Les pages qu'on pousse depuis le calendrier.
enum CalendarRoute: Hashable {
    case exams
}

/// **L'onglet Calendrier** : la vie d'étude en un seul endroit.
///
/// 1. le mois et la semaine, qu'on fait glisser ; le mois s'ouvre en grille ;
/// 2. le prochain examen, épinglé : le compte à rebours, la préparation, réviser, l'examen
///    blanc, et Mika qui planifie les révisions ;
/// 3. l'agenda du jour choisi : les cours de l'emploi du temps, les séances de Mika, les
///    examens et leurs rendez-vous, les tâches à rendre, les séances de concentration menées ;
/// 4. « Mes examens », qui pousse la page de tous les examens (l'ancien onglet Examen) ;
/// 5. « Mes calendriers », et le scanner d'emploi du temps.
///
/// L'écran se compose de vues sans état (`CalendarScreen.swift`) ; celle-ci lit la base,
/// tient les feuilles, et fait les gestes.
struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TabRouter.self) private var router: TabRouter?
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \StudyCalendar.position) private var calendars: [StudyCalendar]
    @Query private var events: [CalendarEvent]
    @Query(sort: \StudyTask.createdAt) private var tasks: [StudyTask]
    @Query(sort: \Exam.date) private var exams: [Exam]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var focusSessions: [FocusSession]

    @State private var path = NavigationPath()
    @State private var selectedDay = MicaboCalendar.shared.startOfDay(for: Date())
    @State private var weekOffset = 0
    @State private var milestones: [AgendaEvent] = []
    @State private var readiness: [UUID: Int] = [:]
    /// Les points des jours déjà calculés, gardés d'une passe à l'autre (`AgendaDotsMemo`).
    @State private var dotsMemo = AgendaDotsMemo()

    @State private var showsMonth = false
    @State private var editingCalendar: CalendarEditTarget?
    @State private var editingEvent: EventEditTarget?
    @State private var editingExam: ExamEditTarget?
    @State private var mock: MockExamStart?
    @State private var dueCourses: DueCourses?
    @State private var focusPlan: FocusPlan?
    @State private var revisionChoice: AgendaItem?
    @State private var planMenuExam: Exam?
    @State private var paywall: PaywallTrigger?
    @State private var planMessage: String?

    private var lessons: [Course] { courses.filter { $0.isLesson && $0.source != .deck } }
    private var upcomingExams: [Exam] { exams.filter { !$0.isPast() } }

    /// Le compilateur type mal d'un seul tenant la pile, les feuilles et les dialogues : chaque
    /// morceau se type de son côté, comme dans `CoursesListView`.
    var body: some View {
        dialogs
            .task {
                CalendarDefaults.ensure(in: modelContext)
                StudyNotifications.refresh(in: modelContext)
            }
            .task(id: examsKey) { refreshExamData() }
            .onChange(of: router?.calendarRequests ?? 0) { _, _ in
                if let day = router?.calendarDay { select(day) }
            }
    }

    private var stack: some View {
        NavigationStack(path: $path) {
            page
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Course.self) { LessonPathView(course: $0) }
                .navigationDestination(for: CalendarRoute.self) { route in
                    switch route {
                    case .exams: ExamsView()
                    }
                }
        }
        .reportsNavigationDepth(for: .calendar, depth: path.count)
        .returnsHome(path: $path)
    }

    // MARK: La page

    private var page: some View {
        let snapshot = self.snapshot
        let items = StudyAgenda.items(on: selectedDay, in: snapshot)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CalendarHeader(
                    month: selectedDay,
                    showsToday: !MicaboCalendar.shared.isDateInToday(selectedDay),
                    onMonth: { showsMonth = true },
                    onToday: { select(Date()) }
                ) {
                    addMenu
                }
                .padding(.top, MicaboSpacing.xs)
                .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: MicaboCalendar.shared.isDateInToday(selectedDay))

                WeekPager(
                    weekOffset: $weekOffset,
                    selected: selectedDay,
                    dots: { dotsMemo.dots(on: $0, in: snapshot) },
                    onSelect: { select($0, movesWeek: false) }
                )

                if let exam = upcomingExams.first {
                    NextExamCard(
                        summary: summary(for: exam),
                        onRevise: { revise(exam) },
                        onMock: { mock = MockExamStart(exam: exam) },
                        onPlan: { plan(exam) },
                        onPlanMenu: { planMenuExam = exam },
                        onEdit: { editingExam = .edit(exam) }
                    )
                    .contextMenu {
                        Button(loc("ios.cal.editExam"), systemImage: "pencil") { editingExam = .edit(exam) }
                    }
                }

                DayAgendaSection(
                    day: selectedDay,
                    items: items,
                    onTap: tap,
                    onStart: start,
                    onToggleTask: toggleTask,
                    onAdd: { editingEvent = .new(day: selectedDay) }
                )

                if upcomingExams.isEmpty {
                    NoExamCard { editingExam = .new }
                }
                ExamsSummaryRow(
                    upcoming: upcomingExams.count,
                    onOpen: { path.append(CalendarRoute.exams) },
                    onAdd: { editingExam = .new }
                )

                if !hasTimetable {
                    TimetableScanPromo { scanTimetable() }
                }

                calendarsSection(snapshot)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .tabBarClearance()
        .onChange(of: weekOffset) { _, offset in
            // La semaine a glissé : le même jour de la semaine, dans la nouvelle.
            let weekday = MicaboCalendar.isoWeekday(of: selectedDay)
            let days = WeekPager.days(offset: offset)
            if days.indices.contains(weekday - 1), !days.contains(selectedDay) {
                selectedDay = days[weekday - 1]
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button(loc("ios.cal.newEvent"), systemImage: "calendar.badge.plus") { editingEvent = .new(day: selectedDay) }
            Button(loc("ios.cal.newExam"), systemImage: "graduationcap") { editingExam = .new }
            Button(loc("ios.cal.newCalendar"), systemImage: "square.stack") { editingCalendar = .new(scan: false) }
            Button(loc("ios.cal.scan"), systemImage: "camera.viewfinder") { scanTimetable() }
        } label: {
            CalendarAddLabel()
        }
    }

    private func calendarsSection(_ snapshot: AgendaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            StudySectionTitle(title: loc("ios.cal.myCalendars")) {
                Button {
                    editingCalendar = .new(scan: false)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(MicaboColor.accentInk)
                        .frame(width: 34, height: 34)
                        .background(MicaboColor.accentSoft, in: Circle())
                }
                .buttonStyle(HomePressStyle(scale: 0.9))
                .accessibilityLabel(Text(loc("ios.cal.newCalendar")))
            }
            VStack(spacing: 12) {
                ForEach(snapshot.calendars) { info in
                    CalendarListRow(
                        calendar: info,
                        eventCount: events.filter { $0.calendarID == info.id }.count,
                        onToggle: { toggleVisibility(info.id) },
                        onEdit: {
                            if let calendar = calendars.first(where: { $0.id == info.id }) {
                                editingCalendar = .edit(calendar)
                            }
                        }
                    )
                }
                if hasTimetable {
                    Button {
                        scanTimetable()
                    } label: {
                        Label(loc("ios.cal.scan"), systemImage: "camera.viewfinder")
                            .font(MicaboFont.ui(15, weight: .black))
                            .foregroundStyle(MicaboColor.accentInk)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
                    }
                    .buttonStyle(HomePressStyle(scale: 0.97))
                }
            }
            .padding(14)
            .homeCard(radius: MicaboStage.tileRadius)
        }
    }

    // MARK: Les données

    private var snapshot: AgendaSnapshot {
        AgendaSnapshot(
            calendars: calendars.map { AgendaCalendarInfo(id: $0.id, name: $0.name, emoji: $0.emoji, tintIndex: $0.colorIndex, isVisible: $0.isVisible) },
            events: events.map(\.spec),
            exams: exams.map { AgendaExamInfo(id: $0.id, name: $0.name, date: $0.date, courseIDs: $0.courseIDs) },
            milestones: milestones,
            tasks: tasks.map(\.spec),
            focus: focusSessions.prefix(400).map(\.spec)
        )
    }

    private var hasTimetable: Bool {
        events.contains { $0.kind == .lesson }
    }

    private var examsKey: String {
        let stamp = exams.map { "\($0.id.uuidString)\($0.date.timeIntervalSince1970)\($0.courseIDs.count)" }.joined()
        return "\(stamp)-\(MicaboCalendar.shared.startOfDay(for: Date()).timeIntervalSince1970)"
    }

    private func refreshExamData() {
        milestones = StudyPlan.milestones(for: exams, in: modelContext)
        let logs = ExamReadiness.recentLogsByCard(in: modelContext)
        var values: [UUID: Int] = [:]
        for exam in upcomingExams.prefix(1) {
            let cards = ExamRepository.cards(of: exam, in: modelContext)
            guard !cards.isEmpty else { continue }
            values[exam.id] = ExamReadiness.masteryPercent(of: cards, logs: logs)
        }
        readiness = values
    }

    private func summary(for exam: Exam) -> NextExamSummary {
        let titles = lessonsOf(exam).map(\.title)
        let planned = events
            .filter { $0.examID == exam.id && $0.kind == .revision && !$0.isDone && $0.day >= MicaboCalendar.shared.startOfDay(for: Date()) }
            .sorted { ($0.day, $0.startMinute) < ($1.day, $1.startMinute) }
        var next: String?
        if let first = planned.first {
            let time = CalendarTime.label(minute: first.startMinute)
            next = MicaboCalendar.shared.isDateInToday(first.day)
                ? loc("ios.cal.nextSessionToday", ["time": time])
                : loc("ios.cal.nextSession", ["day": MicaboCalendar.dayLabel(first.day), "time": time])
        }
        return NextExamSummary(
            examID: exam.id,
            name: exam.name,
            date: exam.date,
            daysLeft: max(0, exam.daysRemaining()),
            lessonTitles: titles,
            readiness: readiness[exam.id],
            plannedCount: planned.count,
            nextSession: next,
            hasLessons: !titles.isEmpty
        )
    }

    private func lessonsOf(_ exam: Exam) -> [Course] {
        let wanted = Set(exam.courseIDs)
        return lessons.filter { wanted.contains($0.id) }
    }

    // MARK: Les gestes

    private func select(_ day: Date, movesWeek: Bool = true) {
        let start = MicaboCalendar.shared.startOfDay(for: day)
        withAnimation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion)) {
            selectedDay = start
            if movesWeek { weekOffset = WeekPager.offset(of: start) }
        }
    }

    /// Le scanner remplit « Cours » s'il existe, plutôt que d'ouvrir un second calendrier.
    private func scanTimetable() {
        if let classes = calendars.first(where: { $0.kind == .classes }) {
            editingCalendar = .edit(classes, scan: true)
        } else {
            editingCalendar = .new(scan: true)
        }
    }

    private func toggleVisibility(_ id: UUID) {
        guard let calendar = calendars.first(where: { $0.id == id }) else { return }
        calendar.isVisible.toggle()
        calendar.updatedAt = Date()
        try? modelContext.save()
    }

    private func tap(_ item: AgendaItem) {
        switch item.kind {
        case .exam:
            if let exam = exams.first(where: { $0.id == item.examID }) { editingExam = .edit(exam) }
        case .milestone:
            if let exam = exams.first(where: { $0.id == item.examID }) { mock = MockExamStart(exam: exam) }
        case .revision:
            revisionChoice = item
        case .lesson, .custom:
            if let event = events.first(where: { $0.id == item.eventID }) {
                editingEvent = .edit(event, occurrence: item.day)
            }
        case .task:
            toggleTask(item)
        case .focus:
            break
        }
    }

    private func start(_ item: AgendaItem) {
        guard let start = item.startMinute, let end = item.endMinute else { return }
        let course = lessons.first { $0.id == item.courseID }
        // Seule une séance de révision se coche en fin de séance : un cours qui revient chaque
        // semaine ne se marque pas « fait ».
        focusPlan = .revision(eventID: item.kind == .revision ? item.eventID : nil, startMinute: start, endMinute: end, courseID: course?.id, courseTitle: course?.title)
    }

    private func toggleTask(_ item: AgendaItem) {
        guard let task = tasks.first(where: { $0.id == item.taskID }) else { return }
        task.isDone.toggle()
        task.doneAt = task.isDone ? Date() : nil
        try? modelContext.save()
        if task.isDone { Haptics.success() }
    }

    private func revise(_ exam: Exam) {
        let examLessons = lessonsOf(exam)
        let due = DueReview.courses(examLessons)
        if !due.isEmpty {
            dueCourses = DueCourses(courses: due)
        } else if let first = examLessons.first {
            path.append(first)
        }
    }

    private func plan(_ exam: Exam) {
        let isPro = pro?.isPro ?? false
        guard RevisionPlanAllowance.allows(examID: exam.id, isPro: isPro) else {
            Analytics.track(.planBlocked)
            paywall = .upgrade
            return
        }
        let count = StudyPlanStore.generate(for: exam, in: modelContext)
        Analytics.track(.planGenerated, ["count": .number(Double(count)), "days": .number(Double(exam.daysRemaining()))])
        if count == 0 {
            Haptics.warning()
            planMessage = loc("ios.cal.planNone")
        } else {
            Haptics.success()
            planMessage = loc("ios.cal.planDone", ["count": "\(count)"])
        }
    }

    private func setDone(_ item: AgendaItem, _ done: Bool) {
        guard let event = events.first(where: { $0.id == item.eventID }) else { return }
        event.isDone = done
        event.updatedAt = Date()
        try? modelContext.save()
        StudyNotifications.refresh(in: modelContext)
    }

    // MARK: Les feuilles

    private var sheets: some View {
        stack
            .sheet(isPresented: $showsMonth) {
                let snapshot = self.snapshot
                CalendarMonthSheet(selected: selectedDay, dots: { dotsMemo.dots(on: $0, in: snapshot) }) { day in
                    select(day)
                }
            }
            .sheet(item: $editingCalendar) { target in
                CalendarEditSheet(target: target)
            }
            .sheet(item: $editingEvent) { target in
                EventEditSheet(target: target, calendars: calendars, lessons: lessons)
            }
            .sheet(item: $editingExam) { target in
                ExamEditSheet(target: target, lessons: lessons, initialDate: selectedDay)
            }
            .fullScreenCover(item: $dueCourses) { due in
                DueCardsReview(courses: due.courses)
            }
            .fullScreenCover(item: $mock) { start in
                MockExamFlow(start: start, lessons: lessons)
            }
            .fullScreenCover(item: $focusPlan) { plan in
                FocusTimerView(plan: plan)
            }
            .micaboPaywall($paywall)
    }

    private var dialogs: some View {
        sheets
            .confirmationDialog(
                revisionChoice.map { loc("ios.cal.revisionTitle", ["title": $0.title]) } ?? "",
                isPresented: Binding(get: { revisionChoice != nil }, set: { if !$0 { revisionChoice = nil } }),
                titleVisibility: .visible,
                presenting: revisionChoice,
                actions: revisionActions
            )
            .confirmationDialog(
                loc("ios.cal.planMenu"),
                isPresented: Binding(get: { planMenuExam != nil }, set: { if !$0 { planMenuExam = nil } }),
                titleVisibility: .visible,
                presenting: planMenuExam,
                actions: planActions,
                message: { _ in Text(loc("ios.cal.planMenuMsg")) }
            )
            .alert(
                planMessage ?? "",
                isPresented: Binding(get: { planMessage != nil }, set: { if !$0 { planMessage = nil } })
            ) {
                Button(L10n.t("ios.done", locale: .resolved()), role: .cancel) {}
            }
    }

    @ViewBuilder
    private func revisionActions(_ item: AgendaItem) -> some View {
        if !item.isDone {
            Button(loc("ios.cal.startSession")) { start(item) }
        }
        if let course = lessons.first(where: { $0.id == item.courseID }) {
            Button(loc("ios.cal.openLesson")) { path.append(course) }
        }
        Button(loc(item.isDone ? "ios.cal.markUndone" : "ios.cal.markDone")) { setDone(item, !item.isDone) }
        if let event = events.first(where: { $0.id == item.eventID }) {
            Button(loc("ios.cal.editEvent")) { editingEvent = .edit(event, occurrence: item.day) }
        }
    }

    @ViewBuilder
    private func planActions(_ exam: Exam) -> some View {
        Button(loc("ios.cal.planAgain")) { plan(exam) }
        Button(loc("ios.cal.planClear"), role: .destructive) {
            StudyPlanStore.clear(examID: exam.id, in: modelContext)
            Analytics.track(.planCleared)
        }
    }
}

/// **Les points d'un jour, calculés une fois tant que l'agenda ne change pas.**
///
/// Chaque case de la semaine et du mois demande ses points, et chaque demande refaisait tout
/// l'agenda du jour (les événements répétés, les tâches, les examens, les jalons) pour n'en
/// garder que trois couleurs. Toucher un jour relisait la page, donc les points de toutes les
/// cases visibles, alors que rien n'avait changé. Ils sont gardés ici par jour, et jetés dès
/// que l'agenda lu diffère du précédent.
final class AgendaDotsMemo {
    private var snapshot: AgendaSnapshot?
    private var dots: [Date: [Int]] = [:]

    func dots(on day: Date, in snapshot: AgendaSnapshot, calendar: Calendar = MicaboCalendar.shared) -> [Int] {
        if self.snapshot != snapshot {
            self.snapshot = snapshot
            dots.removeAll(keepingCapacity: true)
        }
        let key = calendar.startOfDay(for: day)
        if let known = dots[key] { return known }
        let made = StudyAgenda.dots(on: key, in: snapshot, calendar: calendar)
        dots[key] = made
        return made
    }
}

/// Les leçons dont on révise les cartes dues.
struct DueCourses: Identifiable {
    let id = UUID()
    let courses: [Course]
}
