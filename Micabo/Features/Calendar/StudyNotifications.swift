import Foundation
import SwiftData
import UserNotifications

/// **Les rappels du calendrier** : dix minutes avant une séance de révision posée par Mika,
/// et la veille au soir d'un examen.
///
/// Ils ne partent que si l'élève a **déjà** dit oui aux notifications : le calendrier ne pose
/// jamais la question lui-même (le parcours d'accueil l'a posée, au bon moment). Chaque
/// changement de planning les efface tous et les repose : un rappel pour une séance déplacée
/// ou effacée serait pire que pas de rappel.
///
/// iOS garde 64 notifications en attente par app ; les rappels du jour en prennent quatorze
/// (`DailyReminder.days`). Le calendrier s'en tient à trente, les plus proches.
enum StudyNotifications {
    static let identifierPrefix = "micabo.study."
    static let limit = 30
    /// La veille d'un examen, à 19 h.
    static let examEveHour = 19
    static let leadMinutes = 10
    static let horizonDays = 21

    struct Planned: Equatable {
        var identifier: String
        var date: Date
        var title: String
        var body: String
    }

    /// Ce qui serait posé, sans rien poser : une fonction pure, pour les tests.
    static func plan(
        revisions: [CalendarEventSpec],
        exams: [AgendaExamInfo],
        now: Date,
        calendar: Calendar = MicaboCalendar.shared,
        locale: UiLocale = .resolved()
    ) -> [Planned] {
        var planned: [Planned] = []
        let horizon = calendar.date(byAdding: .day, value: horizonDays, to: now) ?? now
        let open = revisions.filter { $0.kind == .revision && !$0.isDone }
        for occurrence in CalendarRecurrence.occurrences(of: open, from: now, through: horizon, calendar: calendar) {
            let fire = occurrence.start.addingTimeInterval(TimeInterval(-leadMinutes * 60))
            guard fire > now else { continue }
            planned.append(Planned(
                identifier: identifierPrefix + "rev." + occurrence.id,
                date: fire,
                title: L10n.t("ios.cal.notif.revisionTitle", locale: locale, vars: ["title": occurrence.event.title]),
                body: L10n.t("ios.cal.notif.revisionBody", locale: locale, vars: ["time": CalendarTime.label(occurrence.start, locale: locale)])
            ))
        }
        for exam in exams {
            let examDay = calendar.startOfDay(for: exam.date)
            guard let eve = calendar.date(byAdding: .day, value: -1, to: examDay),
                  let fire = calendar.date(bySettingHour: examEveHour, minute: 0, second: 0, of: eve),
                  fire > now, fire <= horizon else { continue }
            planned.append(Planned(
                identifier: identifierPrefix + "exam." + exam.id.uuidString,
                date: fire,
                title: L10n.t("ios.cal.notif.examTitle", locale: locale, vars: ["name": exam.name]),
                body: L10n.t("ios.cal.notif.examBody", locale: locale)
            ))
        }
        return Array(planned.sorted { $0.date < $1.date }.prefix(limit))
    }

    /// Relit la base et repose les rappels, sans attendre.
    @MainActor
    static func refresh(in context: ModelContext, now: Date = Date()) {
        let revisions = ((try? context.fetch(FetchDescriptor<CalendarEvent>())) ?? []).map(\.spec)
        let exams = ExamRepository.all(in: context).map { AgendaExamInfo(id: $0.id, name: $0.name, date: $0.date, courseIDs: $0.courseIDs) }
        let planned = plan(revisions: revisions, exams: exams, now: now)
        Task { await apply(planned) }
    }

    /// Efface tous les rappels du calendrier, puis pose ceux-ci si l'élève a dit oui.
    static func apply(_ planned: [Planned]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        let calendar = Calendar.current
        for reminder in planned {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
        }
    }

    /// La sortie d'un compte : plus aucun rappel pour ses séances.
    static func cancelAll() {
        Task { await apply([]) }
    }
}
