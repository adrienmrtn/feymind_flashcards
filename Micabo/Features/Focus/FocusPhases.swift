import Foundation

/// Une séance d'une traite, ou en cycles de travail et de pauses.
enum FocusMode: String, Codable, CaseIterable, Identifiable {
    case simple
    case pomodoro

    var id: String { rawValue }
}

/// **Ce que l'élève a préparé** dans « Préparer ma session » : la durée, les cycles, et
/// l'objectif (une leçon, des tâches, une séance de révision du calendrier).
struct FocusPlan: Equatable, Identifiable {
    var id = UUID()
    var mode: FocusMode = .simple
    /// La durée d'une séance simple, ou d'un cycle de travail.
    var workMinutes: Int = XPRules.focusMinutes
    var cycles: Int = 4
    var breakMinutes: Int = FocusPhases.breakMinutes
    var courseID: UUID?
    var courseTitle: String?
    /// Ce que la séance fait de sa leçon (lot 11) : elle l'ouvre dessus dès le départ.
    var activity: FocusActivity = .lesson
    var taskIDs: [UUID] = []
    /// La séance de révision du calendrier que cette séance accomplit.
    var eventID: UUID?

    static let `default` = FocusPlan()

    static let simpleRange = 5...120
    static let pomodoroRange = 15...60
    static let stepMinutes = 5
    static let cycleRange = 1...4

    /// La durée par défaut : le temps quotidien de l'élève, arrondi aux cinq minutes, ou 25.
    static func defaultMinutes(dailyMinutes: Int?) -> Int {
        guard let dailyMinutes, dailyMinutes > 0 else { return XPRules.focusMinutes }
        let rounded = Int((Double(dailyMinutes) / Double(stepMinutes)).rounded()) * stepMinutes
        return max(simpleRange.lowerBound, min(simpleRange.upperBound, rounded))
    }

    var effectiveCycles: Int { mode == .pomodoro ? max(1, min(FocusPlan.cycleRange.upperBound, cycles)) : 1 }

    /// Les minutes de travail, pauses exclues.
    var totalWorkMinutes: Int { workMinutes * effectiveCycles }

    var phases: [FocusPhase] { FocusPhases.phases(for: self) }

    /// L'XP qu'on gagne en allant au bout : `XPRules.focusSession` par bloc de 25 minutes de
    /// travail terminé.
    var xpToEarn: Int { FocusPhases.xp(forWorkSeconds: TimeInterval(totalWorkMinutes * 60)) }

    /// **Une séance de révision du calendrier, lancée telle quelle** : d'une traite, de sa durée
    /// prévue (cinq minutes au moins), sur sa leçon, et rattachée à son événement pour le cocher
    /// une fois menée. Le calendrier, Concentration et Home la lancent tous par ici.
    static func revision(eventID: UUID?, startMinute: Int, endMinute: Int, courseID: UUID?, courseTitle: String?) -> FocusPlan {
        FocusPlan(
            mode: .simple,
            workMinutes: max(5, min(simpleRange.upperBound, endMinute - startMinute)),
            courseID: courseID,
            courseTitle: courseTitle,
            eventID: eventID
        )
    }
}

/// Une phase de la séance : du travail, ou une pause.
struct FocusPhase: Equatable {
    enum Kind: String, Equatable {
        case work
        case rest
    }

    var kind: Kind
    var seconds: TimeInterval
    /// Le cycle de travail auquel la phase appartient, à partir de 1.
    var cycle: Int
}

/// Où l'on en est d'une séance, à un instant donné.
struct FocusPosition: Equatable {
    var index: Int
    var phase: FocusPhase
    /// Le temps restant dans la phase.
    var remaining: TimeInterval
    /// Le temps de travail déjà fait, pauses exclues.
    var workDone: TimeInterval
    var finished: Bool
}

/// **Le calcul d'une séance**, en fonction pure du temps écoulé. Le minuteur ne compte rien :
/// il garde l'heure de départ et le temps déjà passé avant une pause, et demande ici où il en
/// est. L'app peut dormir, l'écran se verrouiller, la séance tombe juste au retour.
enum FocusPhases {
    static let breakMinutes = 5

    static func phases(for plan: FocusPlan) -> [FocusPhase] {
        let work = TimeInterval(max(1, plan.workMinutes) * 60)
        guard plan.mode == .pomodoro else {
            return [FocusPhase(kind: .work, seconds: work, cycle: 1)]
        }
        let rest = TimeInterval(max(1, plan.breakMinutes) * 60)
        var result: [FocusPhase] = []
        for cycle in 1...plan.effectiveCycles {
            result.append(FocusPhase(kind: .work, seconds: work, cycle: cycle))
            // Pas de pause après le dernier cycle : la séance est finie.
            if cycle < plan.effectiveCycles {
                result.append(FocusPhase(kind: .rest, seconds: rest, cycle: cycle))
            }
        }
        return result
    }

    static func total(_ phases: [FocusPhase]) -> TimeInterval {
        phases.reduce(0) { $0 + $1.seconds }
    }

    /// La phase en cours après `elapsed` secondes.
    static func position(in phases: [FocusPhase], elapsed: TimeInterval) -> FocusPosition {
        guard let last = phases.last else {
            return FocusPosition(index: 0, phase: FocusPhase(kind: .work, seconds: 0, cycle: 1), remaining: 0, workDone: 0, finished: true)
        }
        var start: TimeInterval = 0
        var workDone: TimeInterval = 0
        let clamped = max(0, elapsed)
        for (index, phase) in phases.enumerated() {
            let end = start + phase.seconds
            if clamped < end {
                if phase.kind == .work { workDone += clamped - start }
                return FocusPosition(index: index, phase: phase, remaining: end - clamped, workDone: workDone, finished: false)
            }
            if phase.kind == .work { workDone += phase.seconds }
            start = end
        }
        return FocusPosition(index: phases.count - 1, phase: last, remaining: 0, workDone: workDone, finished: true)
    }

    /// Le temps écoulé au début de la phase suivante : « passer la pause ».
    static func elapsedAtNextPhase(in phases: [FocusPhase], elapsed: TimeInterval) -> TimeInterval {
        let current = position(in: phases, elapsed: elapsed)
        return max(0, elapsed) + current.remaining
    }

    /// Les heures de fin de chaque phase à venir, depuis `now` : les notifications posées quand
    /// l'app passe à l'arrière-plan.
    static func upcomingBoundaries(in phases: [FocusPhase], elapsed: TimeInterval, now: Date) -> [(date: Date, endedPhase: FocusPhase, next: FocusPhase?)] {
        var result: [(Date, FocusPhase, FocusPhase?)] = []
        var start: TimeInterval = 0
        for (index, phase) in phases.enumerated() {
            let end = start + phase.seconds
            if end > elapsed {
                let next = phases.indices.contains(index + 1) ? phases[index + 1] : nil
                result.append((now.addingTimeInterval(end - elapsed), phase, next))
            }
            start = end
        }
        return result.map { (date: $0.0, endedPhase: $0.1, next: $0.2) }
    }

    /// L'XP d'un temps de travail : un `focusSession` par bloc de 25 minutes **terminé**.
    static func xp(forWorkSeconds seconds: TimeInterval) -> Int {
        completedBlocks(workSeconds: seconds) * XPRules.focusSession
    }

    static func completedBlocks(workSeconds seconds: TimeInterval) -> Int {
        Int((max(0, seconds) + 0.5) / TimeInterval(XPRules.focusMinutes * 60))
    }

    /// « 25:00 », « 1:05:00 ».
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }
}

// MARK: - Les chiffres de la concentration

/// **Les chiffres de l'onglet Concentration**, en fonction pure des séances menées.
enum FocusStats {
    /// Les minutes de concentration d'un jour.
    static func minutes(on day: Date, sessions: [FocusSessionSpec], calendar: Calendar = MicaboCalendar.shared) -> Int {
        let seconds = sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.focusedSeconds }
        return Int((seconds / 60).rounded(.down))
    }

    /// Les sept derniers jours, du plus ancien à aujourd'hui, avec leurs minutes.
    static func lastSevenDays(endingAt now: Date, sessions: [FocusSessionSpec], calendar: Calendar = MicaboCalendar.shared) -> [(day: Date, minutes: Int)] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).reversed().compactMap { offset -> (day: Date, minutes: Int)? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day: day, minutes: minutes(on: day, sessions: sessions, calendar: calendar))
        }
    }

    /// Les minutes de la semaine en cours (du lundi à aujourd'hui).
    static func weekMinutes(now: Date, sessions: [FocusSessionSpec], calendar: Calendar = MicaboCalendar.shared) -> Int {
        let week = MicaboCalendar.week(of: now, calendar: calendar)
        guard let monday = week.first else { return 0 }
        let seconds = sessions
            .filter { $0.startedAt >= monday && $0.startedAt <= now }
            .reduce(0) { $0 + $1.focusedSeconds }
        return Int((seconds / 60).rounded(.down))
    }

    /// Les séances de la semaine en cours qui ont compté au moins une minute.
    static func weekSessions(now: Date, sessions: [FocusSessionSpec], calendar: Calendar = MicaboCalendar.shared) -> Int {
        let week = MicaboCalendar.week(of: now, calendar: calendar)
        guard let monday = week.first else { return 0 }
        return sessions.filter { $0.startedAt >= monday && $0.startedAt <= now && $0.focusedSeconds >= 60 }.count
    }
}
