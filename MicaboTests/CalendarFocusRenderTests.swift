import SwiftUI
import XCTest
@testable import Micabo

/// **Les rendus du Calendrier et de la Concentration**, de jour, de nuit, en allemand et en
/// arabe. Les écrans sont posés immobiles (`homeStill`) et sans défilement : `ImageRenderer`
/// ne dessine ni les vues UIKit ni les animations.
@MainActor
final class CalendarFocusRenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    // MARK: - Les données de démonstration

    private let classes = AgendaCalendarInfo(id: UUID(), name: "Cours", emoji: "🏫", tintIndex: CalendarTint.classesIndex, isVisible: true)
    private let revisions = AgendaCalendarInfo(id: UUID(), name: "Révisions", emoji: "📚", tintIndex: CalendarTint.revisionIndex, isVisible: true)
    private let club = AgendaCalendarInfo(id: UUID(), name: "Théâtre", emoji: "🎭", tintIndex: 6, isVisible: false)

    private var today: Date { MicaboCalendar.shared.startOfDay(for: Date()) }

    private func dayItems() -> [AgendaItem] {
        let day = today
        return [
            AgendaItem(id: "m", kind: .milestone, title: "Bac blanc d'histoire", day: day, tintIndex: StudyAgenda.examTint, examID: UUID(), milestone: .mock, minutes: 15),
            AgendaItem(id: "t", kind: .task, title: "Rendre le DM de maths", day: day, tintIndex: StudyAgenda.taskTint, taskID: UUID()),
            AgendaItem(id: "a", kind: .lesson, title: "Mathématiques", day: day, startMinute: 8 * 60, endMinute: 9 * 60 + 30, tintIndex: classes.tintIndex, emoji: "🏫", calendarName: "Cours", room: "B12"),
            AgendaItem(id: "b", kind: .lesson, title: "Histoire-géographie", day: day, startMinute: 10 * 60, endMinute: 11 * 60, tintIndex: classes.tintIndex, emoji: "🏫", calendarName: "Cours", room: "Salle 204"),
            AgendaItem(id: "f", kind: .focus, title: "", day: day, startMinute: 14 * 60, endMinute: 14 * 60 + 25, tintIndex: StudyAgenda.focusTint, minutes: 25, isDone: true),
            AgendaItem(id: "r", kind: .revision, title: "La guerre froide", day: day, startMinute: 18 * 60, endMinute: 18 * 60 + 30, tintIndex: revisions.tintIndex, emoji: "📚", calendarName: "Révisions", examID: UUID(), eventID: UUID()),
        ]
    }

    private func dots(_ day: Date) -> [Int] {
        let weekday = MicaboCalendar.isoWeekday(of: day)
        switch weekday {
        case 1, 2, 4: return [classes.tintIndex, revisions.tintIndex]
        case 3: return [classes.tintIndex]
        case 5: return [StudyAgenda.examTint, classes.tintIndex, StudyAgenda.taskTint]
        default: return []
        }
    }

    private func calendarDay() -> some View {
        let exam = NextExamSummary(
            examID: UUID(),
            name: "Bac d'histoire",
            date: MicaboCalendar.shared.date(byAdding: .day, value: 12, to: today) ?? today,
            daysLeft: 12,
            lessonTitles: ["La guerre froide", "La décolonisation", "La Ve République", "L'Europe"],
            readiness: 64,
            plannedCount: 9,
            nextSession: loc("ios.cal.nextSessionToday", ["time": CalendarTime.label(minute: 18 * 60)]),
            hasLessons: true
        )
        return VStack(alignment: .leading, spacing: 18) {
            CalendarHeader(month: today, showsToday: false, onMonth: {}, onToday: {}) {
                CalendarAddLabel()
            }
            WeekPager(weekOffset: .constant(0), selected: today, dots: dots, onSelect: { _ in })
            NextExamCard(summary: exam, onRevise: {}, onMock: {}, onPlan: {}, onPlanMenu: {}, onEdit: {})
            DayAgendaSection(day: today, items: dayItems(), onTap: { _ in }, onStart: { _ in }, onToggleTask: { _ in }, onAdd: {})
            ExamsSummaryRow(upcoming: 2, onOpen: {}, onAdd: {})
        }
        .padding(20)
        .environment(\.homeStill, true)
    }

    private func calendarBottom() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            NoExamCard {}
            DayAgendaSection(day: MicaboCalendar.shared.date(byAdding: .day, value: 1, to: today) ?? today, items: [], onTap: { _ in }, onStart: { _ in }, onToggleTask: { _ in }, onAdd: {})
            TimetableScanPromo {}
            VStack(spacing: 12) {
                CalendarListRow(calendar: classes, eventCount: 14, onToggle: {}, onEdit: {})
                CalendarListRow(calendar: revisions, eventCount: 9, onToggle: {}, onEdit: {})
                CalendarListRow(calendar: club, eventCount: 1, onToggle: {}, onEdit: {})
            }
            .padding(14)
            .homeCard(radius: MicaboStage.tileRadius)
        }
        .padding(20)
        .environment(\.homeStill, true)
    }

    private func focusHome() -> some View {
        let tasks = [
            StudyTaskSpec(title: "Finir le DM de maths", dueDate: MicaboCalendar.shared.date(byAdding: .day, value: 1, to: today)),
            StudyTaskSpec(title: "Relire le chapitre 3 de SVT"),
            StudyTaskSpec(title: "Fiche sur la guerre froide", isDone: true),
        ]
        let days: [FocusDayBar] = (0..<7).reversed().map { offset in
            FocusDayBar(
                day: MicaboCalendar.shared.date(byAdding: .day, value: -offset, to: today) ?? today,
                minutes: [20, 45, 0, 30, 60, 15, 25][6 - offset]
            )
        }
        return VStack(alignment: .leading, spacing: 18) {
            MicaboPageHeading(title: loc("ios.focus.title"), subtitle: nil) { EmptyView() }
            FocusHeroCard(minutesToday: 25, goalMinutes: 30, streak: 12, streakLit: true, onStart: {})
            FocusNextRevisionCard(time: CalendarTime.label(minute: 18 * 60), title: "La guerre froide", detail: "Bac d'histoire · 30 min", onStart: {})
            FocusTasksCard(tasks: tasks, lessonTitles: [:], onAdd: {}, onToggle: { _ in }, onDelete: { _ in }, onSeeAll: {})
            FocusStatsCard(days: days, goalMinutes: 30, weekMinutes: 195, weekSessions: 8, bestStreak: 18)
        }
        .padding(20)
        .environment(\.homeStill, true)
    }

    private func setup(_ mode: FocusMode, goalsOpen: Bool) -> some View {
        let tasks = [StudyTaskSpec(title: "Finir le DM de maths"), StudyTaskSpec(title: "Relire le chapitre 3")]
        var plan = FocusPlan(mode: mode, workMinutes: 25, cycles: 4)
        plan.courseTitle = goalsOpen ? "La photosynthèse" : nil
        if goalsOpen { plan.taskIDs = [tasks[0].id] }
        return VStack(spacing: 14) {
            FocusSetupForm(plan: .constant(plan), goalsOpen: .constant(goalsOpen), tasks: tasks, onPickLesson: {})
            FocusStartBar(xp: plan.xpToEarn, onStart: {})
        }
        .padding(20)
        .environment(\.homeStill, true)
    }

    private func live(rest: Bool, paused: Bool = false) -> some View {
        let plan = FocusPlan(mode: .pomodoro, workMinutes: 25, cycles: 4, courseTitle: "La photosynthèse")
        let elapsed: TimeInterval = rest ? 1_800 + 1_500 + 120 : 1_800 + 612
        let tasks = [StudyTaskSpec(title: "Relire le chapitre 3", isDone: true), StudyTaskSpec(title: "Faire les exercices 4 à 7")]
        return FocusSessionScreen(
            plan: plan,
            position: FocusPhases.position(in: plan.phases, elapsed: elapsed),
            isPaused: paused,
            lessonTitle: plan.courseTitle,
            tasks: tasks,
            onToggleTask: { _ in },
            onOpenLesson: {},
            onPauseResume: {},
            onSkipBreak: {},
            onStop: {}
        )
        .environment(\.homeStill, true)
    }

    private func scanReview() -> some View {
        let entries = [
            TimetableEntry(weekday: 1, startMinute: 8 * 60, endMinute: 9 * 60, title: "Mathématiques", room: "B12"),
            TimetableEntry(weekday: 1, startMinute: 9 * 60, endMinute: 10 * 60, title: "Anglais", room: "C03"),
            TimetableEntry(weekday: 2, startMinute: 10 * 60, endMinute: 12 * 60, title: "Physique-chimie", room: "Labo 2"),
            TimetableEntry(weekday: 3, startMinute: 13 * 60 + 30, endMinute: 15 * 60, title: "Histoire-géographie", room: ""),
        ]
        return VStack(spacing: 14) {
            TimetableReviewContent(entries: .constant(entries))
            TimetableSaveButton(count: entries.count, onConfirm: {})
        }
        .padding(20)
        .environment(\.homeStill, true)
    }

    private func newCalendar() -> some View {
        CalendarEditForm(
            name: .constant(""),
            emoji: .constant("🗓️"),
            color: .constant(2),
            isVisible: .constant(true),
            showsEmoji: .constant(true),
            showsVisibility: false,
            canUseCamera: true,
            onCamera: {},
            onLibrary: {}
        )
        .padding(20)
        .environment(\.homeStill, true)
    }

    private func month() -> some View {
        MonthGrid(month: .constant(today), selected: today, dots: dots, onSelect: { _ in })
            .padding(20)
            .environment(\.homeStill, true)
    }

    private func tabBar() -> some View {
        let router = TabRouter()
        router.selection = .calendar
        return MicaboTabBar()
            .environment(router)
            .padding(.vertical, 20)
    }

    // MARK: - Les rendus

    func testCalendarScreens() throws {
        try RenderGallery.render("cal-day", night: true, calendarDay())
        try RenderGallery.render("cal-more", night: true, calendarBottom())
        try RenderGallery.render("cal-month", night: true, month())
        try RenderGallery.render("cal-new", night: true, newCalendar())
        try RenderGallery.render("cal-scan", night: true, scanReview())
        try RenderGallery.render("cal-tabbar", night: true, tabBar())
    }

    func testFocusScreens() throws {
        try RenderGallery.render("focus-home", night: true, focusHome())
        try RenderGallery.render("focus-setup", night: true, setup(.simple, goalsOpen: false))
        try RenderGallery.render("focus-setup-pomodoro", night: true, setup(.pomodoro, goalsOpen: true))
        try RenderGallery.render("focus-live", height: 852, night: true, live(rest: false))
        try RenderGallery.render("focus-live-break", height: 852, live(rest: true))
    }

    func testCalendarAndFocusInOtherLanguages() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: UiLocale.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) } else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }
        defaults.set(UiLocale.de.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("cal-day-de", calendarDay())
        try RenderGallery.render("cal-scan-de", scanReview())
        try RenderGallery.render("focus-home-de", focusHome())
        try RenderGallery.render("focus-setup-de", setup(.pomodoro, goalsOpen: true))
        try RenderGallery.render("focus-live-de", height: 852, live(rest: false, paused: true))
        try RenderGallery.render("cal-tabbar-de", tabBar())
        defaults.set(UiLocale.fi.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("cal-tabbar-fi", tabBar())
        defaults.set(UiLocale.en.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("cal-day-en", calendarDay())
        defaults.set(UiLocale.ar.rawValue, forKey: UiLocale.storageKey)
        try RenderGallery.render("cal-day-ar", calendarDay().environment(\.layoutDirection, .rightToLeft))
        try RenderGallery.render("focus-home-ar", focusHome().environment(\.layoutDirection, .rightToLeft))
    }
}
