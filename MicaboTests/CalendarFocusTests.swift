import XCTest
@testable import Micabo

/// **Calendrier et Concentration** : ce qui se calcule sans écran — l'expansion des cours
/// répétés, le planning de révisions de Mika, la lecture d'un emploi du temps, les phases d'une
/// séance Pomodoro, les chiffres de la semaine et les rappels.
final class CalendarFocusTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.firstWeekday = 2
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: - L'expansion des événements répétés

    func testAWeeklyClassComesBackEveryWeekAcrossTheClockChange() {
        // Lundi 19 octobre 2026 ; l'heure d'hiver arrive le dimanche 25.
        let event = CalendarEventSpec(title: "Maths", day: date(2026, 10, 19), startMinute: 8 * 60, endMinute: 9 * 60, repeatsWeekly: true)

        XCTAssertTrue(CalendarRecurrence.occurs(event, on: date(2026, 10, 19), calendar: calendar))
        XCTAssertTrue(CalendarRecurrence.occurs(event, on: date(2026, 10, 26), calendar: calendar))
        XCTAssertTrue(CalendarRecurrence.occurs(event, on: date(2026, 11, 2, 15), calendar: calendar))
        XCTAssertFalse(CalendarRecurrence.occurs(event, on: date(2026, 10, 27), calendar: calendar))
        XCTAssertFalse(CalendarRecurrence.occurs(event, on: date(2026, 10, 12), calendar: calendar), "pas avant la première occurrence")

        let after = CalendarRecurrence.occurrences(of: [event], on: date(2026, 10, 26), calendar: calendar)
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(calendar.component(.hour, from: after[0].start), 8, "8 h reste 8 h après le changement d'heure")
        XCTAssertEqual(calendar.component(.hour, from: after[0].end), 9)
    }

    func testASkippedDayAndAOneOffEvent() {
        var weekly = CalendarEventSpec(title: "SVT", day: date(2026, 11, 4), startMinute: 600, endMinute: 660, repeatsWeekly: true)
        weekly.skippedDays = [date(2026, 11, 11)]
        XCTAssertFalse(CalendarRecurrence.occurs(weekly, on: date(2026, 11, 11), calendar: calendar))
        XCTAssertTrue(CalendarRecurrence.occurs(weekly, on: date(2026, 11, 18), calendar: calendar))

        let once = CalendarEventSpec(title: "Sortie", day: date(2026, 11, 12), startMinute: 600, endMinute: 700)
        XCTAssertTrue(CalendarRecurrence.occurs(once, on: date(2026, 11, 12, 18), calendar: calendar))
        XCTAssertFalse(CalendarRecurrence.occurs(once, on: date(2026, 11, 19), calendar: calendar))

        let range = CalendarRecurrence.occurrences(of: [weekly, once], from: date(2026, 11, 1), through: date(2026, 11, 30), calendar: calendar)
        XCTAssertEqual(range.count, 4, "4, 18, 25 novembre et la sortie du 12 ; le 11 est sauté")
        XCTAssertEqual(CalendarRecurrence.busyMinutes(of: [weekly, once], on: date(2026, 11, 18), calendar: calendar), [600...660])
    }

    func testTimesParseInTheUsualSpellings() {
        XCTAssertEqual(CalendarTime.parse("08:30"), 510)
        XCTAssertEqual(CalendarTime.parse("8h30"), 510)
        XCTAssertEqual(CalendarTime.parse("14.05"), 845)
        XCTAssertEqual(CalendarTime.parse("9"), 540)
        XCTAssertNil(CalendarTime.parse("25:00"))
        XCTAssertNil(CalendarTime.parse("8:75"))
        XCTAssertNil(CalendarTime.parse("midi"))
    }

    func testTheWeekStartsOnMonday() {
        let week = MicaboCalendar.week(of: date(2026, 11, 10), calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first, date(2026, 11, 9))
        XCTAssertEqual(week.last, date(2026, 11, 15))
        XCTAssertEqual(MicaboCalendar.isoWeekday(of: date(2026, 11, 15), calendar: calendar), 7)
        XCTAssertEqual(MicaboCalendar.isoWeekday(of: date(2026, 11, 9), calendar: calendar), 1)
        let grid = MicaboCalendar.monthGrid(of: date(2026, 11, 10), calendar: calendar)
        XCTAssertEqual(grid.count % 7, 0)
        XCTAssertEqual(grid.first, date(2026, 10, 26))
    }

    // MARK: - Le planning de Mika

    private let lessons = [PlanLesson(id: UUID(), title: "La photosynthèse"), PlanLesson(id: UUID(), title: "La respiration")]

    func testThePlanTightensAsTheExamNearsAndRestsTheDayBefore() {
        let plan = RevisionPlanner.plan(
            examDate: date(2026, 11, 30),
            examName: "Bac blanc",
            lessons: lessons,
            dailyMinutes: 30,
            preferredStartMinute: 18 * 60,
            busy: { _ in [] },
            now: date(2026, 11, 10, 10),
            calendar: calendar
        )
        let days = plan.map { calendar.component(.day, from: $0.day) }
        // Au-delà de deux semaines un jour sur trois, puis un sur deux, puis tous les jours ;
        // rien la veille ni le jour J.
        XCTAssertEqual(days, [12, 15, 16, 18, 20, 22, 23, 24, 25, 26, 27, 28])
        XCTAssertFalse(days.contains(29))
        XCTAssertTrue(plan.allSatisfy { $0.startMinute == 18 * 60 && $0.endMinute == 18 * 60 + 30 })
        XCTAssertEqual(plan.map(\.courseID).prefix(3), [lessons[0].id, lessons[1].id, lessons[0].id], "les leçons tournent")

        let again = RevisionPlanner.plan(
            examDate: date(2026, 11, 30), examName: "Bac blanc", lessons: lessons, dailyMinutes: 30,
            preferredStartMinute: 18 * 60, busy: { _ in [] }, now: date(2026, 11, 10, 10), calendar: calendar
        )
        XCTAssertEqual(plan, again, "déterministe")
    }

    func testThePlanAvoidsClassesAndKeepsSomeAir() {
        let plan = RevisionPlanner.plan(
            examDate: date(2026, 11, 20),
            examName: "Contrôle",
            lessons: [],
            dailyMinutes: 45,
            preferredStartMinute: 18 * 60,
            busy: { _ in [(17 * 60 + 30)...(19 * 60)] },
            now: date(2026, 11, 10, 8),
            calendar: calendar
        )
        XCTAssertFalse(plan.isEmpty)
        for session in plan {
            XCTAssertEqual(session.startMinute, 19 * 60 + 15, "dix minutes d'air après le cours, au quart d'heure")
            XCTAssertEqual(session.endMinute - session.startMinute, 45)
            XCTAssertEqual(session.title, "Contrôle", "sans leçon, la séance porte le nom de l'examen")
            XCTAssertNil(session.courseID)
        }
    }

    func testThePlanSlidesEarlierWhenTheEveningIsFull() {
        XCTAssertEqual(RevisionPlanner.slot(length: 60, preferred: 18 * 60, busy: [(17 * 60)...(22 * 60)]), 15 * 60 + 45)
        XCTAssertNil(RevisionPlanner.slot(length: 60, preferred: 18 * 60, busy: [(7 * 60)...(22 * 60)]))
    }

    func testThePlanNeverStartsInThePastAndNeedsTwoDays() {
        let close = RevisionPlanner.plan(
            examDate: date(2026, 11, 11), examName: "Oral", lessons: lessons, dailyMinutes: 20,
            busy: { _ in [] }, now: date(2026, 11, 10, 9), calendar: calendar
        )
        XCTAssertTrue(close.isEmpty, "l'examen est demain : on se repose")

        let tonight = RevisionPlanner.plan(
            examDate: date(2026, 11, 12), examName: "Oral", lessons: lessons, dailyMinutes: 20,
            busy: { _ in [] }, now: date(2026, 11, 10, 9), calendar: calendar
        )
        XCTAssertEqual(tonight.count, 1)
        XCTAssertEqual(calendar.component(.day, from: tonight[0].day), 10)

        let late = RevisionPlanner.plan(
            examDate: date(2026, 11, 12), examName: "Oral", lessons: lessons, dailyMinutes: 30,
            busy: { _ in [] }, now: date(2026, 11, 10, 21, 40), calendar: calendar
        )
        XCTAssertTrue(late.isEmpty, "à 21 h 40, la séance du soir n'a plus de place avant 22 h")
    }

    func testTheSessionLengthFollowsTheDailyMinutes() {
        XCTAssertEqual(RevisionPlanner.sessionLength(dailyMinutes: 5), 15)
        XCTAssertEqual(RevisionPlanner.sessionLength(dailyMinutes: 22), 20)
        XCTAssertEqual(RevisionPlanner.sessionLength(dailyMinutes: 30), 30)
        XCTAssertEqual(RevisionPlanner.sessionLength(dailyMinutes: 300), 90)
    }

    func testTheFreePlanIsForOneExam() throws {
        let suite = "micabo.tests.plan"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let first = UUID()
        let second = UUID()
        XCTAssertTrue(RevisionPlanAllowance.allows(examID: first, isPro: false, defaults: defaults))
        RevisionPlanAllowance.noteUsed(examID: first, defaults: defaults)
        XCTAssertTrue(RevisionPlanAllowance.allows(examID: first, isPro: false, defaults: defaults), "le refaire reste offert")
        XCTAssertFalse(RevisionPlanAllowance.allows(examID: second, isPro: false, defaults: defaults))
        XCTAssertTrue(RevisionPlanAllowance.allows(examID: second, isPro: true, defaults: defaults))
        RevisionPlanAllowance.forget(defaults: defaults)
        XCTAssertTrue(RevisionPlanAllowance.allows(examID: second, isPro: false, defaults: defaults))
    }

    // MARK: - L'emploi du temps lu par Mika

    func testTheTimetableIsReadFromAChattyReply() {
        let reply = """
        Voici ton emploi du temps :
        ```json
        [{"day":3,"start":"14h30","end":"16:00","title":"Histoire [groupe A]","room":""},
         {"day":1,"start":"08:00","end":"09:00","title":"Maths","room":"B12"}]
        ```
        Bon courage !
        """
        let entries = TimetableParser.entries(from: reply)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].title, "Maths")
        XCTAssertEqual(entries[0].weekday, 1)
        XCTAssertEqual(entries[0].room, "B12")
        XCTAssertEqual(entries[1].title, "Histoire [groupe A]")
        XCTAssertEqual(entries[1].startMinute, 14 * 60 + 30)
        XCTAssertEqual(entries[1].endMinute, 16 * 60)
    }

    func testTheTimetableDropsWhatDoesNotStandUp() {
        let reply = """
        [1, 2] puis [{"day":9,"start":"08:00","end":"09:00","title":"Hors semaine"},
        {"day":2,"start":"10:00","end":"09:00","title":"À l'envers"},
        {"day":2,"start":"10:00","end":"11:00","title":"  "},
        {"day":2,"start":"10:00","end":"11:00","title":"Physique"},
        {"day":2,"start":"10:00","end":"11:00","title":"Physique"},
        {"day":"5","start":"13:00","end":"14:00","title":"Anglais"}]
        """
        let entries = TimetableParser.entries(from: reply)
        XCTAssertEqual(entries.map(\.title), ["Physique", "Anglais"])
        XCTAssertEqual(entries.map(\.weekday), [2, 5])
    }

    func testNothingReadableGivesNothing() {
        XCTAssertTrue(TimetableParser.entries(from: "Je ne vois pas d'emploi du temps.").isEmpty)
        XCTAssertTrue(TimetableParser.entries(from: "[]").isEmpty)
        XCTAssertTrue(TimetableParser.entries(from: "[{\"day\":1,").isEmpty)
        XCTAssertLessThan(TimetableParser.instruction.count, MikaLimits.messageCharacters)
    }

    func testAReadClassStartsInTheCurrentWeek() {
        let wednesday = TimetableParser.firstDay(for: 3, from: date(2026, 11, 10, 15), calendar: calendar)
        XCTAssertEqual(wednesday, date(2026, 11, 11))
        let monday = TimetableParser.firstDay(for: 1, from: date(2026, 11, 10, 15), calendar: calendar)
        XCTAssertEqual(monday, date(2026, 11, 9))
    }

    // MARK: - Les phases d'une séance

    func testASimpleSession() {
        let plan = FocusPlan(mode: .simple, workMinutes: 25)
        XCTAssertEqual(plan.phases.count, 1)
        let start = FocusPhases.position(in: plan.phases, elapsed: 0)
        XCTAssertEqual(start.remaining, 1_500)
        XCTAssertFalse(start.finished)
        let end = FocusPhases.position(in: plan.phases, elapsed: 1_600)
        XCTAssertTrue(end.finished)
        XCTAssertEqual(end.workDone, 1_500)
        XCTAssertEqual(plan.xpToEarn, XPRules.focusSession)
    }

    func testPomodoroPhasesAlternateWithoutATrailingBreak() {
        let plan = FocusPlan(mode: .pomodoro, workMinutes: 25, cycles: 4, breakMinutes: 5)
        let phases = plan.phases
        XCTAssertEqual(phases.map(\.kind), [.work, .rest, .work, .rest, .work, .rest, .work])
        XCTAssertEqual(FocusPhases.total(phases), 4 * 1_500 + 3 * 300)
        XCTAssertEqual(plan.totalWorkMinutes, 100)
        XCTAssertEqual(plan.xpToEarn, 4 * XPRules.focusSession)

        let inBreak = FocusPhases.position(in: phases, elapsed: 1_600)
        XCTAssertEqual(inBreak.index, 1)
        XCTAssertEqual(inBreak.phase.kind, .rest)
        XCTAssertEqual(inBreak.phase.cycle, 1)
        XCTAssertEqual(inBreak.remaining, 200)
        XCTAssertEqual(inBreak.workDone, 1_500, "la pause ne compte pas")

        let second = FocusPhases.position(in: phases, elapsed: 1_900)
        XCTAssertEqual(second.phase.kind, .work)
        XCTAssertEqual(second.phase.cycle, 2)
        XCTAssertEqual(second.workDone, 1_600)

        XCTAssertEqual(FocusPhases.elapsedAtNextPhase(in: phases, elapsed: 1_600), 1_800, "passer la pause")
        XCTAssertEqual(FocusPhases.upcomingBoundaries(in: phases, elapsed: 1_600, now: Date()).count, 6)

        let one = FocusPlan(mode: .pomodoro, workMinutes: 30, cycles: 9)
        XCTAssertEqual(one.effectiveCycles, 4, "quatre cycles au plus")
    }

    func testXPComesPerFinishedBlockOfTwentyFiveMinutes() {
        XCTAssertEqual(FocusPhases.xp(forWorkSeconds: 20 * 60), 0)
        XCTAssertEqual(FocusPhases.xp(forWorkSeconds: 25 * 60), XPRules.focusSession)
        XCTAssertEqual(FocusPhases.xp(forWorkSeconds: 49 * 60), XPRules.focusSession)
        XCTAssertEqual(FocusPhases.xp(forWorkSeconds: 50 * 60), 2 * XPRules.focusSession)
        XCTAssertEqual(FocusPhases.xp(forWorkSeconds: 25 * 60 - 0.2), XPRules.focusSession, "une fraction de seconde ne coûte pas un bloc")
    }

    func testTheClockAndTheDefaultDuration() {
        XCTAssertEqual(FocusPhases.clock(1_500), "25:00")
        XCTAssertEqual(FocusPhases.clock(59.2), "1:00")
        XCTAssertEqual(FocusPhases.clock(3_900), "1:05:00")
        XCTAssertEqual(FocusPlan.defaultMinutes(dailyMinutes: nil), 25)
        XCTAssertEqual(FocusPlan.defaultMinutes(dailyMinutes: 22), 20)
        XCTAssertEqual(FocusPlan.defaultMinutes(dailyMinutes: 300), 120)
    }

    // MARK: - Les chiffres

    func testTheWeekInNumbers() {
        let now = date(2026, 11, 12, 20)
        let sessions = [
            FocusSessionSpec(startedAt: date(2026, 11, 12, 9), endedAt: date(2026, 11, 12, 9, 25), focusedSeconds: 1_500),
            FocusSessionSpec(startedAt: date(2026, 11, 12, 14), endedAt: date(2026, 11, 12, 14, 10), focusedSeconds: 600),
            FocusSessionSpec(startedAt: date(2026, 11, 10, 18), endedAt: date(2026, 11, 10, 19), focusedSeconds: 3_000),
            FocusSessionSpec(startedAt: date(2026, 11, 6, 18), endedAt: date(2026, 11, 6, 19), focusedSeconds: 1_800),
            FocusSessionSpec(startedAt: date(2026, 11, 11, 7), endedAt: date(2026, 11, 11, 7), focusedSeconds: 20),
        ]
        XCTAssertEqual(FocusStats.minutes(on: now, sessions: sessions, calendar: calendar), 35)
        let days = FocusStats.lastSevenDays(endingAt: now, sessions: sessions, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.last?.day, date(2026, 11, 12))
        XCTAssertEqual(days.last?.minutes, 35)
        XCTAssertEqual(days.first?.day, date(2026, 11, 6))
        XCTAssertEqual(days.first?.minutes, 30)
        XCTAssertEqual(FocusStats.weekMinutes(now: now, sessions: sessions, calendar: calendar), 85, "du lundi 9 à aujourd'hui")
        XCTAssertEqual(FocusStats.weekSessions(now: now, sessions: sessions, calendar: calendar), 3, "une séance de vingt secondes ne compte pas")
    }

    // MARK: - L'agenda d'un jour

    func testTheDayAgendaOrdersAndFilters() {
        let classes = AgendaCalendarInfo(id: UUID(), name: "Cours", emoji: "🏫", tintIndex: 9, isVisible: true)
        let hidden = AgendaCalendarInfo(id: UUID(), name: "Club", emoji: "🎭", tintIndex: 3, isVisible: false)
        let day = date(2026, 11, 16)
        let exam = AgendaExamInfo(id: UUID(), name: "Bac blanc", date: day, courseIDs: [])
        let snapshot = AgendaSnapshot(
            calendars: [classes, hidden],
            events: [
                CalendarEventSpec(calendarID: classes.id, title: "Anglais", day: date(2026, 11, 2), startMinute: 600, endMinute: 660, repeatsWeekly: true, kind: .lesson),
                CalendarEventSpec(calendarID: classes.id, title: "Maths", day: date(2026, 11, 2), startMinute: 480, endMinute: 540, repeatsWeekly: true, kind: .lesson),
                CalendarEventSpec(calendarID: hidden.id, title: "Théâtre", day: day, startMinute: 1_000, endMinute: 1_100),
            ],
            exams: [exam],
            tasks: [StudyTaskSpec(title: "DM", dueDate: date(2026, 11, 16, 12))],
            focus: [FocusSessionSpec(startedAt: date(2026, 11, 16, 17), endedAt: date(2026, 11, 16, 17, 30), focusedSeconds: 1_500)]
        )
        let items = StudyAgenda.items(on: day, in: snapshot, calendar: calendar)
        XCTAssertEqual(items.map(\.kind), [.exam, .task, .lesson, .lesson, .focus])
        XCTAssertEqual(items.compactMap { $0.kind == .lesson ? $0.title : nil }, ["Maths", "Anglais"])
        XCTAssertFalse(items.contains { $0.title == "Théâtre" }, "un calendrier caché ne montre rien")
        XCTAssertEqual(items.last?.minutes, 25)
        XCTAssertEqual(StudyAgenda.dots(on: day, in: snapshot, calendar: calendar), [StudyAgenda.examTint, StudyAgenda.taskTint, 9])
        XCTAssertTrue(StudyAgenda.items(on: date(2026, 11, 17), in: snapshot, calendar: calendar).isEmpty)
    }

    // MARK: - Les rappels

    func testRemindersComeTenMinutesBeforeAndTheEveningBefore() {
        let now = date(2026, 11, 10, 9)
        let revision = CalendarEventSpec(title: "La photosynthèse", day: date(2026, 11, 11), startMinute: 18 * 60, endMinute: 18 * 60 + 30, kind: .revision)
        var done = revision
        done.id = UUID()
        done.isDone = true
        let past = CalendarEventSpec(title: "Passée", day: date(2026, 11, 9), startMinute: 18 * 60, endMinute: 19 * 60, kind: .revision)
        let exam = AgendaExamInfo(id: UUID(), name: "Bac blanc", date: date(2026, 11, 13), courseIDs: [])
        let planned = StudyNotifications.plan(revisions: [revision, done, past], exams: [exam], now: now, calendar: calendar, locale: .fr)
        XCTAssertEqual(planned.count, 2)
        XCTAssertEqual(planned[0].date, date(2026, 11, 11, 17, 50))
        XCTAssertEqual(planned[1].date, date(2026, 11, 12, 19))
        XCTAssertTrue(planned[0].title.contains("La photosynthèse"))
        XCTAssertTrue(planned[1].title.contains("Bac blanc"))
        XCTAssertTrue(planned.allSatisfy { $0.identifier.hasPrefix(StudyNotifications.identifierPrefix) })
    }
}
