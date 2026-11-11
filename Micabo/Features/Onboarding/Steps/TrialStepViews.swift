import Foundation
import SwiftUI

/// **Les trois moments de l'essai**, d'aujourd'hui au premier prélèvement : l'accès complet,
/// le rappel la veille de la fin (`TrialEndReminder`), puis l'abonnement.
///
/// La chronologie est calculée à partir d'une date reçue en paramètre plutôt que lue depuis
/// `Date.now` au fond d'une vue : c'est ce qui permet de vérifier la date du premier
/// prélèvement sans attendre trois jours.
enum TrialTimeline {
    /// Durée de l'essai, et seule source de vérité à ce sujet dans le parcours : la date
    /// annoncée sur la chronologie et celle facturée par la boutique doivent être la même.
    static let freeDays = 3

    /// Le jour du rappel : la veille de la fin.
    static var reminderDay: Int { max(1, freeDays - 1) }

    enum Tone {
        /// Ce qui est déjà fait.
        case done
        /// Ce qui commence maintenant.
        case current
        /// Ce qui arrivera.
        case upcoming
    }

    struct Milestone: Identifiable {
        /// Le libellé fait l'identité. Un `UUID()` tiré à la construction changerait à
        /// chaque recomposition de l'écran, et la cascade repartirait de zéro sous les yeux.
        var id: String { title }
        let title: String
        let detail: String
        let systemImage: String
        let tone: Tone
    }

    /// Aujourd'hui, le rappel, le premier prélèvement. `remindersOn` dit si le rappel partira
    /// vraiment (notifications permises) : sinon l'étape dit comment l'activer, plutôt que de
    /// promettre un rappel qui ne viendra pas.
    static func milestones(
        from date: Date = .now,
        calendar: Calendar = .current,
        locale: UiLocale = .fr,
        remindersOn: Bool = true
    ) -> [Milestone] {
        let dateText = billingDateText(from: date, calendar: calendar, locale: locale)
        return [
            Milestone(
                title: L10n.t("ios.onb5.trial.today", locale: locale),
                detail: L10n.t("ios.onb5.trial.todayDetail", locale: locale),
                systemImage: "lock.open.fill",
                tone: .current
            ),
            Milestone(
                title: L10n.t("ios.onb5.trial.reminder", locale: locale, vars: ["n": "\(reminderDay)"]),
                detail: L10n.t(remindersOn ? "ios.onb5.trial.reminderDetail" : "ios.onb5.trial.reminderOff", locale: locale),
                systemImage: "bell.fill",
                tone: .upcoming
            ),
            Milestone(
                title: L10n.t("ios.onb5.trial.billing", locale: locale, vars: ["n": "\(freeDays)"]),
                detail: L10n.t("ios.onb5.trial.billingDetail", locale: locale, vars: ["date": dateText]),
                systemImage: "star.fill",
                tone: .upcoming
            ),
        ]
    }

    /// Le jour du premier prélèvement, écrit comme on le dirait : « 28 août ».
    static func billingDateText(
        from date: Date = .now,
        calendar: Calendar = .current,
        locale: UiLocale = .fr
    ) -> String {
        let billingDate = calendar.date(byAdding: .day, value: freeDays, to: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.calendar = calendar
        // Le fuseau vient du calendrier, et pas du système : sans lui, un minuit calculé à
        // Paris s'écrit « la veille » dès que l'appareil est réglé plus à l'ouest.
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter.string(from: billingDate)
    }
}
