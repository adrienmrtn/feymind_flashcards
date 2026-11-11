import Foundation
import UserNotifications

/// **Le rappel de fin d'essai, réellement posé.**
///
/// Le paywall et la chronologie de l'essai promettent « un rappel la veille de la fin de
/// l'essai ». Jusqu'à la version 2 du parcours, rien ne le programmait (choix du 23 octobre
/// 2026) ; la promesse est maintenant tenue : à l'achat d'un essai, une notification locale
/// est posée vingt-quatre heures avant la fin, à l'heure de l'achat.
///
/// Rien n'est demandé au système ici : l'autorisation se demande une fois, dans le parcours
/// (`NotificationPermission`). Sans elle, on ne pose rien — et la chronologie de l'essai dit
/// alors comment l'activer, au lieu de promettre un rappel qui ne viendrait pas.
enum TrialEndReminder {
    static let identifier = "micabo.trial.end"

    /// **Quand le rappel part** : vingt-quatre heures avant la fin de l'essai, et jamais dans
    /// l'heure qui vient (un essai d'un jour n'a pas de veille). Pur, pour se tester.
    static func fireDate(purchasedAt: Date, trialDays: Int) -> Date? {
        guard trialDays >= 2 else { return nil }
        let end = purchasedAt.addingTimeInterval(TimeInterval(trialDays) * 86_400)
        let fire = end.addingTimeInterval(-86_400)
        return fire > purchasedAt.addingTimeInterval(3_600) ? fire : nil
    }

    /// Le texte du rappel, dans la langue de l'app.
    static func content(locale: UiLocale) -> (title: String, body: String) {
        (
            L10n.t("ios.onb5.reminder.title", locale: locale),
            L10n.t("ios.onb5.reminder.body", locale: locale)
        )
    }

    /// Pose le rappel, s'il peut l'être. Rend vrai quand il est posé.
    @discardableResult
    static func schedule(
        trialDays: Int,
        purchasedAt: Date = Date(),
        locale: UiLocale = .resolved(),
        calendar: Calendar = .current
    ) async -> Bool {
        guard let fire = fireDate(purchasedAt: purchasedAt, trialDays: trialDays),
              await NotificationPermission.isAuthorized()
        else { return false }
        let text = content(locale: locale)
        let notification = UNMutableNotificationContent()
        notification.title = text.title
        notification.body = text.body
        notification.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: notification, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do {
            try await center.add(request)
            Analytics.track(.paywallTrialReminder)
            return true
        } catch {
            return false
        }
    }
}
