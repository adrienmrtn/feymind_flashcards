import Foundation
import SwiftData
import UserNotifications

/// **Le rappel du jour.**
///
/// Une notification par jour, à l'heure que l'élève a donnée dans le parcours d'accueil
/// (`OnboardingPreferences.studyHour`), et dont le texte dépend de ce qu'il a déjà fait :
///
/// - **sans cours importé**, elle l'invite à en importer un ;
/// - **avec des cours**, elle nomme celui sur lequel s'entraîner : celui qui a le plus de
///   cartes dues d'abord, puis chacun à son tour les jours suivants, pour qu'aucun ne soit
///   oublié et que le texte ne se répète pas d'un jour à l'autre.
///
/// **Personne en période d'essai ne la reçoit.** Les rappels commencent le jour où l'essai
/// finit, qu'il se transforme en abonnement ou non ; qui n'a jamais commencé d'essai les
/// reçoit dès maintenant.
///
/// **Des notifications posées d'avance, pas un rappel qui se répète.** Un rappel répété
/// garderait le même texte pour toujours. On en pose donc `days`, un par jour, et on les
/// repose à chaque lancement et à chaque passage à l'arrière-plan : le texte suit les cours
/// de la veille, et le rappel d'aujourd'hui tombe quand l'élève a déjà travaillé. Qui
/// n'ouvre plus l'app reçoit encore deux semaines de rappels, puis plus rien.
///
/// Rien n'est demandé au système ici : l'autorisation se demande une fois, dans le parcours
/// (`NotificationPermission`). Sans elle, on ne pose rien.
enum DailyReminder {
    static let identifierPrefix = "micabo.daily."
    /// Combien de jours sont posés d'avance. iOS en garde soixante-quatre au plus.
    static let days = 14
    /// L'heure du rappel quand le parcours ne l'a pas demandée : celle que propose son écran.
    static let defaultHour = 18

    struct Planned: Equatable {
        let identifier: String
        let date: DateComponents
        let title: String
        let body: String
    }

    /// **Le plan, sans rien toucher.** Pur, pour se tester sans notification ni base.
    ///
    /// - `courseTitles` : les cours de l'élève, du plus pressant au moins pressant ; vide
    ///   s'il n'en a importé aucun.
    /// - `trialEndsAt` : la fin de l'essai en cours, `nil` hors essai. Un essai sans date
    ///   de fin connue se passe en `.distantFuture`, et ne reçoit donc rien.
    /// - `studiedToday` : le rappel d'aujourd'hui saute quand l'élève a déjà travaillé.
    static func plan(
        courseTitles: [String],
        trialEndsAt: Date?,
        studiedToday: Bool,
        hour: Int,
        now: Date,
        calendar: Calendar = .current,
        locale: UiLocale
    ) -> [Planned] {
        let today = calendar.startOfDay(for: now)
        var planned: [Planned] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                  fire > now
            else { continue }
            if offset == 0, studiedToday { continue }
            if let trialEndsAt, fire < trialEndsAt { continue }

            // Le texte tourne avec le jour du calendrier, et non avec le rang dans la liste :
            // reposé le lendemain, le plan ne recommence pas par la même phrase.
            let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? offset
            let (title, body): (String, String)
            if courseTitles.isEmpty {
                let variant = ordinal % 2 + 1
                title = L10n.t("ios.reminder.import\(variant).title", locale: locale)
                body = L10n.t("ios.reminder.import\(variant).body", locale: locale)
            } else {
                // Le plus pressant d'abord, puis chacun son tour.
                let course = courseTitles[planned.count % courseTitles.count]
                title = L10n.t("ios.reminder.practice.title", locale: locale, vars: ["course": course])
                body = L10n.t("ios.reminder.practice.body\(ordinal % 2 + 1)", locale: locale)
            }

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let stamp = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
            planned.append(Planned(identifier: identifierPrefix + stamp, date: components, title: title, body: body))
        }
        return planned
    }

    /// **Repose les rappels** d'après les cours, l'essai et l'heure choisie.
    @MainActor
    static func reschedule(context: ModelContext, trialEndsAt: Date?, now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        // Les cours de l'élève : ni ceux repris de la bibliothèque, ni la démonstration.
        let courses = ((try? context.fetch(FetchDescriptor<Course>())) ?? [])
            .filter { !$0.isFromLibrary && $0.source != .sample && !$0.title.isEmpty }
            .sorted { lhs, rhs in
                if lhs.dueCount != rhs.dueCount { return lhs.dueCount > rhs.dueCount }
                return (lhs.lastOpenedAt ?? lhs.createdAt) > (rhs.lastOpenedAt ?? rhs.createdAt)
            }
        var reviewedToday = FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.reviewedAt >= today })
        reviewedToday.fetchLimit = 1
        let studiedToday = ((try? context.fetchCount(reviewedToday)) ?? 0) > 0
            || courses.contains { ($0.lastOpenedAt ?? .distantPast) >= today }

        let planned = plan(
            courseTitles: courses.map(\.title),
            trialEndsAt: trialEndsAt,
            studiedToday: studiedToday,
            hour: OnboardingPreferences.studyHour ?? defaultHour,
            now: now,
            calendar: calendar,
            locale: .resolved()
        )
        for reminder in planned {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.date, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
        }
    }
}
