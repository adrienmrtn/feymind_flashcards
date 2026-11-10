import Foundation
import SwiftData
import SwiftUI
import UIKit

// MARK: - Les calendriers

/// **Un calendrier de l'élève** : « Cours », « Révisions », ou un des siens (« Club de
/// théâtre »). Un nom, un emoji, une des douze couleurs, et la case qui le montre ou le cache.
///
/// Tout ce qui vit dans l'onglet Calendrier reste **sur le téléphone** : rien ne monte au
/// serveur. Les modèles s'ajoutent au schéma sans toucher aux anciens, la migration est
/// légère (`MicaboApp.schema`), et `LocalWipe` les efface à la sortie d'un compte.
@Model
final class StudyCalendar {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "📚"
    /// Rang dans `CalendarTint.all`.
    var colorIndex: Int = 0
    var isVisible: Bool = true
    /// `classes` et `revision` pour les deux calendriers posés à la première ouverture, `custom`
    /// pour les autres. C'est ce qui dit où Mika range ses séances de révision.
    var kindRaw: String = StudyCalendarKind.custom.rawValue
    var position: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String, emoji: String, colorIndex: Int, kind: StudyCalendarKind = .custom, position: Int = 0) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorIndex = colorIndex
        self.kindRaw = kind.rawValue
        self.position = position
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var kind: StudyCalendarKind {
        StudyCalendarKind(rawValue: kindRaw) ?? .custom
    }

    var tint: CalendarTint { CalendarTint.at(colorIndex) }
}

enum StudyCalendarKind: String, Codable {
    case classes
    case revision
    case custom
}

/// Ce qu'un événement représente. Un cours de l'emploi du temps, une séance que Mika a posée
/// pour un examen, ou un événement libre.
enum CalendarEventKind: String, Codable {
    case lesson
    case revision
    case custom
}

/// **Un événement** : un titre, un jour, une heure de début et de fin, et, s'il revient chaque
/// semaine, la règle qui le répète. Les heures sont gardées en **minutes depuis minuit** et
/// pas en dates : un cours de 8 h reste à 8 h le jour du changement d'heure, et un fuseau
/// changé ne le déplace pas.
///
/// Le calendrier, la leçon et l'examen sont désignés par leur identifiant, comme les leçons
/// d'un examen (`Exam.courseIDs`) : supprimer une leçon ne supprime pas le cours.
@Model
final class CalendarEvent {
    var id: UUID = UUID()
    var calendarID: UUID = UUID()
    var title: String = ""
    /// Le jour de la première occurrence, ramené au début de la journée.
    var day: Date = Date()
    var startMinute: Int = 8 * 60
    var endMinute: Int = 9 * 60
    var repeatsWeekly: Bool = false
    /// Les jours sautés d'un événement répété (« pas de cours ce jeudi-là »).
    var skippedDays: [Date] = []
    var room: String = ""
    var notes: String = ""
    var courseID: UUID?
    var examID: UUID?
    var kindRaw: String = CalendarEventKind.custom.rawValue
    /// Une séance de révision faite : elle reste dans l'agenda, cochée.
    var isDone: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        calendarID: UUID,
        title: String,
        day: Date,
        startMinute: Int,
        endMinute: Int,
        repeatsWeekly: Bool = false,
        room: String = "",
        notes: String = "",
        courseID: UUID? = nil,
        examID: UUID? = nil,
        kind: CalendarEventKind = .custom
    ) {
        self.id = UUID()
        self.calendarID = calendarID
        self.title = title
        self.day = day
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.repeatsWeekly = repeatsWeekly
        self.room = room
        self.notes = notes
        self.courseID = courseID
        self.examID = examID
        self.kindRaw = kind.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var kind: CalendarEventKind {
        CalendarEventKind(rawValue: kindRaw) ?? .custom
    }

    /// La forme pure de l'événement, celle que lisent l'expansion et le planificateur.
    var spec: CalendarEventSpec {
        CalendarEventSpec(
            id: id,
            calendarID: calendarID,
            title: title,
            day: day,
            startMinute: startMinute,
            endMinute: endMinute,
            repeatsWeekly: repeatsWeekly,
            skippedDays: skippedDays,
            room: room,
            courseID: courseID,
            examID: examID,
            kind: kind,
            isDone: isDone
        )
    }
}

/// **Une tâche** de l'onglet Concentration : un titre, une échéance si l'on veut (elle
/// apparaît alors dans le calendrier), une leçon si elle en parle.
@Model
final class StudyTask {
    var id: UUID = UUID()
    var title: String = ""
    var dueDate: Date?
    var courseID: UUID?
    var isDone: Bool = false
    var doneAt: Date?
    var createdAt: Date = Date()

    init(title: String, dueDate: Date? = nil, courseID: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.dueDate = dueDate
        self.courseID = courseID
        self.createdAt = Date()
    }

    var spec: StudyTaskSpec {
        StudyTaskSpec(id: id, title: title, dueDate: dueDate, courseID: courseID, isDone: isDone)
    }
}

/// **Une séance de concentration menée**, au bout ou arrêtée en route. Le temps compté est
/// celui du travail, pauses exclues. `FocusLog` en garde le total pour les heures de Home ;
/// ici, chaque séance a sa ligne, pour la journée, la semaine et le calendrier.
@Model
final class FocusSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date = Date()
    var focusedSeconds: Double = 0
    var modeRaw: String = FocusMode.simple.rawValue
    var plannedMinutes: Int = 25
    var cycles: Int = 1
    var completed: Bool = false
    var courseID: UUID?
    var eventID: UUID?
    var xpEarned: Int = 0

    init(
        startedAt: Date,
        endedAt: Date,
        focusedSeconds: Double,
        mode: FocusMode,
        plannedMinutes: Int,
        cycles: Int,
        completed: Bool,
        courseID: UUID? = nil,
        eventID: UUID? = nil,
        xpEarned: Int = 0
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.focusedSeconds = focusedSeconds
        self.modeRaw = mode.rawValue
        self.plannedMinutes = plannedMinutes
        self.cycles = cycles
        self.completed = completed
        self.courseID = courseID
        self.eventID = eventID
        self.xpEarned = xpEarned
    }

    var mode: FocusMode { FocusMode(rawValue: modeRaw) ?? .simple }

    var spec: FocusSessionSpec {
        FocusSessionSpec(id: id, startedAt: startedAt, endedAt: endedAt, focusedSeconds: focusedSeconds, completed: completed, courseID: courseID)
    }
}

// MARK: - Les formes pures

/// Un événement sans SwiftData : ce que les fonctions pures lisent et que les tests écrivent.
struct CalendarEventSpec: Equatable, Identifiable {
    var id: UUID = UUID()
    var calendarID: UUID = UUID()
    var title: String
    var day: Date
    var startMinute: Int
    var endMinute: Int
    var repeatsWeekly: Bool = false
    var skippedDays: [Date] = []
    var room: String = ""
    var courseID: UUID?
    var examID: UUID?
    var kind: CalendarEventKind = .custom
    var isDone: Bool = false
}

struct StudyTaskSpec: Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var dueDate: Date?
    var courseID: UUID?
    var isDone: Bool = false
}

struct FocusSessionSpec: Equatable, Identifiable {
    var id: UUID = UUID()
    var startedAt: Date
    var endedAt: Date
    var focusedSeconds: Double
    var completed: Bool = true
    var courseID: UUID?
}

// MARK: - Les douze couleurs

/// **Les douze couleurs d'un calendrier**, chacune avec sa version de nuit. Le bleu Micabo en
/// premier : c'est celui de « Révisions », la couleur de Mika.
///
/// Le rang est ce qui se garde (`StudyCalendar.colorIndex`) : réordonner la liste repeindrait
/// les calendriers de tout le monde.
struct CalendarTint: Identifiable, Equatable {
    let id: Int
    let day: UInt32
    let night: UInt32

    static let all: [CalendarTint] = [
        CalendarTint(id: 0, day: 0x3870FE, night: 0x6E96FF),
        CalendarTint(id: 1, day: 0x0EA5E9, night: 0x38BDF8),
        CalendarTint(id: 2, day: 0x0F9F8F, night: 0x2DD4BF),
        CalendarTint(id: 3, day: 0x22A055, night: 0x4ADE80),
        CalendarTint(id: 4, day: 0x7CA313, night: 0xA3D33B),
        CalendarTint(id: 5, day: 0xE9A10F, night: 0xF7B41F),
        CalendarTint(id: 6, day: 0xF2701A, night: 0xFB923C),
        CalendarTint(id: 7, day: 0xE3596C, night: 0xF0808F),
        CalendarTint(id: 8, day: 0xD3418A, night: 0xEC6FAE),
        CalendarTint(id: 9, day: 0x8B5CF6, night: 0xA78BFA),
        CalendarTint(id: 10, day: 0x9A6B45, night: 0xC79C76),
        CalendarTint(id: 11, day: 0x64748B, night: 0x94A3B8),
    ]

    /// « Cours » : le violet, qui se distingue du bleu des révisions au premier coup d'œil.
    static let classesIndex = 9
    static let revisionIndex = 0

    static func at(_ index: Int) -> CalendarTint {
        all[((index % all.count) + all.count) % all.count]
    }

    /// La couleur pleine : la barre d'un événement, une pastille, un point.
    var color: Color {
        Color.adaptive(light: Color(hex: day), dark: Color(hex: night))
    }

    /// Le lavis derrière un événement.
    var wash: Color {
        Color.adaptive(light: Color(hex: day).opacity(0.12), dark: Color(hex: night).opacity(0.2))
    }
}

extension Color {
    /// Une couleur qui suit le thème du moment, jour ou nuit.
    static func adaptive(light: Color, dark: Color) -> Color {
        let light = UIColor(light)
        let dark = UIColor(dark)
        return Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}
