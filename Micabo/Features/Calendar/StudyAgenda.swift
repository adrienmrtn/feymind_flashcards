import Foundation
import SwiftData

/// **Une ligne de l'agenda d'un jour**, quelle que soit sa source : un cours de l'emploi du
/// temps, une séance de révision posée par Mika, un examen, un examen blanc conseillé, une
/// tâche à rendre, une séance de concentration menée.
///
/// Les textes ne sont pas écrits ici : la ligne garde ce qu'il faut pour les écrire (la
/// salle, le nom du calendrier, la durée), et l'écran les met dans la langue de l'app.
struct AgendaItem: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case exam
        case milestone
        case task
        case lesson
        case revision
        case custom
        case focus
    }

    var id: String
    var kind: Kind
    var title: String
    var day: Date
    /// `nil` pour une ligne « toute la journée » : un examen, une tâche, un rendez-vous.
    var startMinute: Int?
    var endMinute: Int?
    var tintIndex: Int
    var emoji: String?
    var calendarName: String?
    var room: String = ""
    var courseID: UUID?
    var examID: UUID?
    var eventID: UUID?
    var taskID: UUID?
    var milestone: AgendaKind?
    /// Les minutes d'une séance de concentration.
    var minutes: Int = 0
    var isDone = false

    var isAllDay: Bool { startMinute == nil }

    /// **En retard** : une chose à faire (tâche, séance de révision, jalon d'examen), pas faite,
    /// dont le moment est passé — un jour d'avant, ou aujourd'hui une séance déjà finie. C'est
    /// la seule ligne de l'agenda qui prend le rouge.
    func isOverdue(now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> Bool {
        guard !isDone else { return false }
        switch kind {
        case .task, .revision, .milestone: break
        case .exam, .lesson, .custom, .focus: return false
        }
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: day)
        if start < today { return true }
        guard start == today, let end = endMinute, startMinute != nil else { return false }
        return end <= CalendarTime.minute(of: now, calendar: calendar)
    }
}

/// Ce qu'un calendrier apporte à l'agenda, sans SwiftData.
struct AgendaCalendarInfo: Equatable, Identifiable {
    var id: UUID
    var name: String
    var emoji: String
    var tintIndex: Int
    var isVisible: Bool
}

/// Un examen, tel que l'agenda le lit.
struct AgendaExamInfo: Equatable, Identifiable {
    var id: UUID
    var name: String
    var date: Date
    var courseIDs: [UUID]
}

/// **Tout ce que l'agenda lit**, figé à un instant : la page en calcule les jours, les points
/// de la semaine et la grille du mois sans relire la base à chaque case.
struct AgendaSnapshot: Equatable {
    var calendars: [AgendaCalendarInfo] = []
    var events: [CalendarEventSpec] = []
    var exams: [AgendaExamInfo] = []
    var milestones: [AgendaEvent] = []
    var tasks: [StudyTaskSpec] = []
    var focus: [FocusSessionSpec] = []
}

/// **L'agenda d'un jour**, en fonction pure : la page, le mois, Home et les tests passent tous
/// par ici.
enum StudyAgenda {
    /// Les couleurs fixes de ce qui ne vient pas d'un calendrier.
    /// Les couleurs ont un sens (charte du lot 6 § 3) : le rouge est gardé pour ce qui est en
    /// retard, le jaune pour la série et l'XP. L'examen et ses jalons prennent le sarcelle, les
    /// tâches l'ardoise ; la séance de concentration menée, le vert du réussi.
    static let examTint = 2
    static let taskTint = 11
    static let focusTint = 3

    static func items(on day: Date, in snapshot: AgendaSnapshot, calendar: Calendar = MicaboCalendar.shared) -> [AgendaItem] {
        let start = calendar.startOfDay(for: day)
        let calendars = Dictionary(snapshot.calendars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var allDay: [AgendaItem] = []
        var timed: [AgendaItem] = []

        for exam in snapshot.exams where calendar.isDate(exam.date, inSameDayAs: start) {
            allDay.append(AgendaItem(
                id: "exam-\(exam.id.uuidString)",
                kind: .exam,
                title: exam.name,
                day: start,
                tintIndex: examTint,
                emoji: "🎓",
                examID: exam.id
            ))
        }

        for milestone in snapshot.milestones where calendar.isDate(milestone.date, inSameDayAs: start) {
            allDay.append(AgendaItem(
                id: "milestone-\(milestone.id)",
                kind: .milestone,
                title: milestone.examName,
                day: start,
                tintIndex: examTint,
                examID: milestone.examId,
                milestone: milestone.kind,
                minutes: milestone.minutes,
                isDone: milestone.status == .done
            ))
        }

        for task in snapshot.tasks {
            guard let due = task.dueDate, calendar.isDate(due, inSameDayAs: start) else { continue }
            allDay.append(AgendaItem(
                id: "task-\(task.id.uuidString)",
                kind: .task,
                title: task.title,
                day: start,
                tintIndex: taskTint,
                courseID: task.courseID,
                taskID: task.id,
                isDone: task.isDone
            ))
        }

        let visibleEvents = snapshot.events.filter { calendars[$0.calendarID]?.isVisible ?? true }
        for occurrence in CalendarRecurrence.occurrences(of: visibleEvents, on: start, calendar: calendar) {
            let event = occurrence.event
            let info = calendars[event.calendarID]
            let kind: AgendaItem.Kind = switch event.kind {
            case .lesson: .lesson
            case .revision: .revision
            case .custom: .custom
            }
            timed.append(AgendaItem(
                id: "event-\(occurrence.id)",
                kind: kind,
                title: event.title,
                day: start,
                startMinute: event.startMinute,
                endMinute: event.endMinute,
                tintIndex: info?.tintIndex ?? CalendarTint.revisionIndex,
                emoji: info?.emoji,
                calendarName: info?.name,
                room: event.room,
                courseID: event.courseID,
                examID: event.examID,
                eventID: event.id,
                isDone: event.isDone
            ))
        }

        for session in snapshot.focus where calendar.isDate(session.startedAt, inSameDayAs: start) {
            let minutes = Int((session.focusedSeconds / 60).rounded())
            guard minutes >= 1 else { continue }
            let startMinute = CalendarTime.minute(of: session.startedAt, calendar: calendar)
            let endMinute = calendar.isDate(session.endedAt, inSameDayAs: start)
                ? CalendarTime.minute(of: session.endedAt, calendar: calendar)
                : CalendarTime.dayMinutes - 1
            timed.append(AgendaItem(
                id: "focus-\(session.id.uuidString)",
                kind: .focus,
                title: "",
                day: start,
                startMinute: startMinute,
                endMinute: max(startMinute, endMinute),
                tintIndex: focusTint,
                courseID: session.courseID,
                minutes: minutes,
                isDone: true
            ))
        }

        let order: [AgendaItem.Kind] = [.exam, .milestone, .task]
        allDay.sort { lhs, rhs in
            let left = order.firstIndex(of: lhs.kind) ?? 9
            let right = order.firstIndex(of: rhs.kind) ?? 9
            if left != right { return left < right }
            if lhs.isDone != rhs.isDone { return !lhs.isDone }
            return lhs.title < rhs.title
        }
        timed.sort { lhs, rhs in
            if lhs.startMinute != rhs.startMinute { return (lhs.startMinute ?? 0) < (rhs.startMinute ?? 0) }
            return lhs.id < rhs.id
        }
        return allDay + timed
    }

    /// Les couleurs des points d'une case (trois au plus, sans doublon), dans l'ordre de
    /// l'agenda.
    static func dots(on day: Date, in snapshot: AgendaSnapshot, calendar: Calendar = MicaboCalendar.shared) -> [Int] {
        var seen: [Int] = []
        for item in items(on: day, in: snapshot, calendar: calendar) where item.kind != .focus {
            if !seen.contains(item.tintIndex) { seen.append(item.tintIndex) }
            if seen.count == 3 { break }
        }
        return seen
    }
}

// MARK: - Ce que Home lira

/// **Le prochain examen**, pour qui veut l'annoncer (Home, le calendrier).
@MainActor
enum NextExam {
    static func current(in context: ModelContext, now: Date = Date()) -> Exam? {
        ExamRepository.next(in: context, now: now)
    }
}

/// **Le programme de l'élève**, lu dans la base : l'agenda d'aujourd'hui, la prochaine
/// séance de révision, les séances planifiées d'un examen. C'est la porte que Home prendra
/// pour montrer la journée sans connaître les modèles du calendrier.
@MainActor
enum StudyPlan {
    /// L'agenda d'aujourd'hui : cours, révisions, examens, tâches, séances menées.
    static func today(in context: ModelContext, now: Date = Date()) -> [AgendaItem] {
        items(on: now, in: context, now: now)
    }

    /// L'agenda d'un jour.
    static func items(on day: Date, in context: ModelContext, now: Date = Date()) -> [AgendaItem] {
        StudyAgenda.items(on: day, in: snapshot(in: context, now: now))
    }

    /// La prochaine séance de révision encore à faire, aujourd'hui ou plus tard.
    static func nextRevision(in context: ModelContext, now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> CalendarOccurrence? {
        let revisions = events(in: context).filter { $0.kind == .revision && !$0.isDone }.map(\.spec)
        let horizon = calendar.date(byAdding: .day, value: 60, to: now) ?? now
        return CalendarRecurrence.occurrences(of: revisions, from: now, through: horizon, calendar: calendar)
            .first { $0.end > now }
    }

    /// Les séances que Mika a posées pour un examen, dans l'ordre.
    static func sessions(for examID: UUID, in context: ModelContext) -> [CalendarEvent] {
        events(in: context)
            .filter { $0.examID == examID && $0.kind == .revision }
            .sorted { ($0.day, $0.startMinute) < ($1.day, $1.startMinute) }
    }

    /// Tout ce que l'agenda lit, en une fois.
    static func snapshot(in context: ModelContext, now: Date = Date(), withMilestones: Bool = true) -> AgendaSnapshot {
        CalendarDefaults.ensure(in: context)
        let calendars = ((try? context.fetch(FetchDescriptor<StudyCalendar>(sortBy: [SortDescriptor(\.position)]))) ?? [])
        let exams = ExamRepository.all(in: context)
        let tasks = (try? context.fetch(FetchDescriptor<StudyTask>())) ?? []
        let since = (MicaboCalendar.shared.date(byAdding: .day, value: -62, to: now)) ?? now
        let focus = (try? context.fetch(FetchDescriptor<FocusSession>(predicate: #Predicate { $0.startedAt >= since }))) ?? []
        return AgendaSnapshot(
            calendars: calendars.map { AgendaCalendarInfo(id: $0.id, name: $0.name, emoji: $0.emoji, tintIndex: $0.colorIndex, isVisible: $0.isVisible) },
            events: events(in: context).map(\.spec),
            exams: exams.map { AgendaExamInfo(id: $0.id, name: $0.name, date: $0.date, courseIDs: $0.courseIDs) },
            milestones: withMilestones ? milestones(for: exams, in: context, now: now) : [],
            tasks: tasks.map(\.spec),
            focus: focus.map(\.spec)
        )
    }

    /// Les examens blancs et les points d'étape conseillés des examens à venir
    /// (`ExamAgenda`). Un blanc rendu pour l'examen coche son rendez-vous.
    static func milestones(for exams: [Exam], in context: ModelContext, now: Date = Date()) -> [AgendaEvent] {
        let upcoming = exams.filter { !$0.isPast(from: now) }
        guard !upcoming.isEmpty else { return [] }
        let history = ExamHistory.all()
        return upcoming.flatMap { exam -> [AgendaEvent] in
            let done = history
                .filter { $0.examID == exam.id }
                .map { AgendaDone(examId: exam.id, kind: .mock, finishedAt: $0.date) }
            // Compté par la base (`ExamRepository.cardCount`) : relire les cours puis leurs
            // cartes pour n'en garder que le nombre coûtait soixante millisecondes par agenda.
            let cardCount = ExamRepository.cardCount(of: exam, in: context)
            return ExamAgenda.events(for: exam, cardCount: cardCount, done: done, now: now)
                .filter { $0.status != .missed }
        }
    }

    private static func events(in context: ModelContext) -> [CalendarEvent] {
        (try? context.fetch(FetchDescriptor<CalendarEvent>())) ?? []
    }
}

// MARK: - Les calendriers de départ

/// **« Cours » et « Révisions »**, posés à la première ouverture du calendrier. Une seule
/// fois : supprimés, ils ne reviennent pas. Celui des révisions est retrouvé par son genre,
/// pas par son nom, que l'élève peut changer.
@MainActor
enum CalendarDefaults {
    static let seededKey = "micabo.calendar.seeded"

    static func ensure(in context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)
        let existing = (try? context.fetchCount(FetchDescriptor<StudyCalendar>())) ?? 0
        guard existing == 0 else { return }
        let locale = UiLocale.resolved()
        context.insert(StudyCalendar(
            name: L10n.t("ios.cal.default.classes", locale: locale),
            emoji: "🏫",
            colorIndex: CalendarTint.classesIndex,
            kind: .classes,
            position: 0
        ))
        context.insert(StudyCalendar(
            name: L10n.t("ios.cal.default.revision", locale: locale),
            emoji: "📚",
            colorIndex: CalendarTint.revisionIndex,
            kind: .revision,
            position: 1
        ))
        try? context.save()
    }

    /// Le calendrier où ranger un genre d'événement : celui de ce genre, sinon le premier,
    /// sinon un nouveau.
    static func calendar(for kind: StudyCalendarKind, in context: ModelContext) -> StudyCalendar {
        ensure(in: context)
        let all = (try? context.fetch(FetchDescriptor<StudyCalendar>(sortBy: [SortDescriptor(\.position)]))) ?? []
        if let match = all.first(where: { $0.kind == kind }) { return match }
        if kind == .custom, let first = all.first { return first }
        let locale = UiLocale.resolved()
        let created = StudyCalendar(
            name: L10n.t(kind == .classes ? "ios.cal.default.classes" : "ios.cal.default.revision", locale: locale),
            emoji: kind == .classes ? "🏫" : "📚",
            colorIndex: kind == .classes ? CalendarTint.classesIndex : CalendarTint.revisionIndex,
            kind: kind == .custom ? .revision : kind,
            position: (all.map(\.position).max() ?? -1) + 1
        )
        context.insert(created)
        try? context.save()
        return created
    }

    /// La sortie d'un compte : le calendrier suivant repartira de « Cours » et « Révisions ».
    static func forget(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: seededKey)
    }
}
