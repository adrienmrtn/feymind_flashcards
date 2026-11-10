import Foundation
import SwiftData

/// Une leçon au programme, telle que le planificateur la lit.
struct PlanLesson: Equatable {
    var id: UUID
    var title: String
}

/// Une séance de révision proposée : un jour, des heures, une leçon.
struct PlannedRevision: Equatable {
    var day: Date
    var startMinute: Int
    var endMinute: Int
    var courseID: UUID?
    var title: String
}

/// **Mika planifie les révisions d'un examen.** Une fonction pure et déterministe : les mêmes
/// entrées donnent toujours le même planning, à la minute près.
///
/// Les règles, dans l'ordre où elles s'appliquent :
/// - **la veille de l'examen est un jour de repos**, et le jour J n'a pas de séance : on ne
///   bachote pas la nuit d'avant ;
/// - **plus l'examen approche, plus les séances se resserrent** : tous les jours la dernière
///   semaine, un jour sur deux la semaine d'avant, un sur trois au-delà. La cadence se compte
///   depuis l'examen, pas depuis aujourd'hui : rouvrir l'app trois jours plus tard ne change
///   pas les jours choisis ;
/// - **six semaines au plus** : au-delà, un planning est une promesse qu'on ne tient pas ;
/// - **une séance dure le temps que l'élève s'est donné** dans le parcours d'accueil
///   (`OnboardingPreferences.dailyMinutes`), entre 15 et 90 minutes ;
/// - **elle tombe à l'heure qu'il a choisie** pour réviser, ou à 18 h, et **jamais sur un
///   cours** : à défaut, elle glisse au plus près, avec dix minutes d'air de chaque côté, entre
///   7 h et 22 h ; un jour sans créneau n'a pas de séance ;
/// - **les leçons tournent**, dans l'ordre de l'examen.
enum RevisionPlanner {
    static let horizonDays = 42
    static let maxSessions = 30
    static let earliestStart = 7 * 60
    static let latestEnd = 22 * 60
    static let buffer = 10
    static let step = 15
    static let defaultStartMinute = 18 * 60

    /// La durée d'une séance, d'après le temps quotidien de l'élève.
    static func sessionLength(dailyMinutes: Int) -> Int {
        let clamped = max(15, min(90, dailyMinutes))
        return Int((Double(clamped) / 5).rounded()) * 5
    }

    /// Vrai si un jour situé `daysBefore` jours avant l'examen reçoit une séance.
    static func wantsSession(daysBefore: Int) -> Bool {
        switch daysBefore {
        case ...1: false
        case 2...7: true
        case 8...14: daysBefore % 2 == 0
        default: daysBefore % 3 == 0
        }
    }

    static func plan(
        examDate: Date,
        examName: String,
        lessons: [PlanLesson],
        dailyMinutes: Int,
        preferredStartMinute: Int = defaultStartMinute,
        busy: (Date) -> [ClosedRange<Int>],
        now: Date,
        calendar: Calendar = MicaboCalendar.shared
    ) -> [PlannedRevision] {
        let today = calendar.startOfDay(for: now)
        let examDay = calendar.startOfDay(for: examDate)
        let daysLeft = calendar.dateComponents([.day], from: today, to: examDay).day ?? 0
        guard daysLeft >= 2 else { return [] }

        let length = sessionLength(dailyMinutes: dailyMinutes)
        let preferred = max(earliestStart, min(latestEnd - length, preferredStartMinute))
        let firstBefore = min(daysLeft, horizonDays)
        // Aujourd'hui, une séance ne peut pas commencer dans le passé : un quart d'heure de
        // marge, arrondi au quart d'heure suivant.
        let nowMinute = CalendarTime.minute(of: now, calendar: calendar) + step
        let todayFloor = Int((Double(nowMinute) / Double(step)).rounded(.up)) * step

        var sessions: [PlannedRevision] = []
        var lessonIndex = 0
        for before in stride(from: firstBefore, through: 2, by: -1) where wantsSession(daysBefore: before) {
            guard sessions.count < maxSessions,
                  let day = calendar.date(byAdding: .day, value: -before, to: examDay) else { continue }
            let notBefore = before == daysLeft ? todayFloor : earliestStart
            guard let start = slot(length: length, preferred: preferred, busy: busy(day), notBefore: notBefore) else { continue }
            let lesson = lessons.isEmpty ? nil : lessons[lessonIndex % lessons.count]
            lessonIndex += 1
            sessions.append(PlannedRevision(
                day: day,
                startMinute: start,
                endMinute: start + length,
                courseID: lesson?.id,
                title: lesson?.title ?? examName
            ))
        }
        return sessions
    }

    /// Le premier créneau libre le plus proche de l'heure voulue : d'abord plus tard, puis plus
    /// tôt. `nil` si la journée est pleine.
    static func slot(length: Int, preferred: Int, busy: [ClosedRange<Int>], notBefore: Int = earliestStart) -> Int? {
        func free(_ start: Int) -> Bool {
            guard start >= max(earliestStart, notBefore), start + length <= latestEnd else { return false }
            let wanted = (start - buffer)...(start + length + buffer)
            // Deux plages qui se touchent ne se chevauchent pas : un cours qui finit à 17 h 50
            // laisse une séance commencer à 18 h.
            return !busy.contains { $0.upperBound > wanted.lowerBound && $0.lowerBound < wanted.upperBound }
        }
        var candidate = preferred
        while candidate + length <= latestEnd {
            if free(candidate) { return candidate }
            candidate += step
        }
        candidate = preferred - step
        while candidate >= earliestStart {
            if free(candidate) { return candidate }
            candidate -= step
        }
        return nil
    }
}

// MARK: - Le planning écrit dans le calendrier

/// **Écrire, refaire et effacer le planning d'un examen** dans le calendrier « Révisions ».
///
/// Refaire un planning ne touche ni aux séances faites ni à celles des jours passés : elles
/// restent dans l'agenda, cochées ou non. Seules les séances à venir sont remplacées.
@MainActor
enum StudyPlanStore {
    /// Pose les séances d'un examen et rend leur nombre.
    @discardableResult
    static func generate(for exam: Exam, in context: ModelContext, now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> Int {
        removeUpcoming(examID: exam.id, in: context, now: now, calendar: calendar)
        let all = (try? context.fetch(FetchDescriptor<CalendarEvent>())) ?? []
        // Les cours, les événements, et les révisions des **autres** examens : deux plannings
        // ne se marchent pas dessus.
        let blocking = all.filter { $0.examID != exam.id || $0.kind != .revision }.map(\.spec)
        let lessons = ExamRepository.courses(of: exam, in: context).map { PlanLesson(id: $0.id, title: $0.title) }
        let planned = RevisionPlanner.plan(
            examDate: exam.date,
            examName: exam.name,
            lessons: lessons,
            dailyMinutes: OnboardingPreferences.dailyMinutes,
            preferredStartMinute: (OnboardingPreferences.studyHour ?? 18) * 60,
            busy: { CalendarRecurrence.busyMinutes(of: blocking, on: $0, calendar: calendar) },
            now: now,
            calendar: calendar
        )
        let target = CalendarDefaults.calendar(for: .revision, in: context)
        for session in planned {
            context.insert(CalendarEvent(
                calendarID: target.id,
                title: session.title,
                day: session.day,
                startMinute: session.startMinute,
                endMinute: session.endMinute,
                courseID: session.courseID,
                examID: exam.id,
                kind: .revision
            ))
        }
        try? context.save()
        RevisionPlanAllowance.noteUsed(examID: exam.id)
        StudyNotifications.refresh(in: context)
        return planned.count
    }

    /// Efface les séances à venir d'un examen (« Effacer le planning », un examen supprimé).
    static func clear(examID: UUID, in context: ModelContext, now: Date = Date()) {
        removeUpcoming(examID: examID, in: context, now: now)
        try? context.save()
        StudyNotifications.refresh(in: context)
    }

    /// Un examen supprimé emporte tout son planning, séances passées comprises.
    static func forget(examID: UUID, in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<CalendarEvent>())) ?? []
        for event in all where event.examID == examID && event.kind == .revision {
            context.delete(event)
        }
        try? context.save()
        StudyNotifications.refresh(in: context)
    }

    static func hasPlan(examID: UUID, in context: ModelContext, now: Date = Date()) -> Bool {
        upcoming(examID: examID, in: context, now: now).isEmpty == false
    }

    /// Les séances encore à venir d'un examen.
    static func upcoming(examID: UUID, in context: ModelContext, now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> [CalendarEvent] {
        let today = calendar.startOfDay(for: now)
        let all = (try? context.fetch(FetchDescriptor<CalendarEvent>())) ?? []
        return all
            .filter { $0.examID == examID && $0.kind == .revision && !$0.isDone && $0.day >= today }
            .sorted { ($0.day, $0.startMinute) < ($1.day, $1.startMinute) }
    }

    /// Un examen modifié (date, leçons) dont le planning existait : il est refait.
    static func refreshIfPlanned(_ exam: Exam, in context: ModelContext, now: Date = Date()) {
        guard hasPlan(examID: exam.id, in: context, now: now) else { return }
        generate(for: exam, in: context, now: now)
    }

    private static func removeUpcoming(examID: UUID, in context: ModelContext, now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) {
        for event in upcoming(examID: examID, in: context, now: now, calendar: calendar) {
            context.delete(event)
        }
    }
}

/// **Le planning offert.** Un élève sans Pro voit Mika planifier les révisions de son premier
/// examen, et peut le refaire autant qu'il veut ; planifier un autre examen est dans Pro.
enum RevisionPlanAllowance {
    static let key = "micabo.plan.freeExamID"

    static func allows(examID: UUID, isPro: Bool, defaults: UserDefaults = .standard) -> Bool {
        if isPro { return true }
        guard let used = defaults.string(forKey: key) else { return true }
        return used == examID.uuidString
    }

    static func noteUsed(examID: UUID, defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: key) == nil else { return }
        defaults.set(examID.uuidString, forKey: key)
    }

    static func forget(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
