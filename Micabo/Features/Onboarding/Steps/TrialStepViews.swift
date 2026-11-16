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
    ///
    /// **Les mêmes dates que le paywall qui suit** (lot 13) : la durée de l'essai est celle du
    /// produit (`trialDays`, lue sur la boutique), la fin vient de `PaywallTimeline.endDate`, le
    /// rappel de `TrialEndReminder.fireDate`, et les deux s'écrivent par
    /// `PaywallTimeline.dayText`. Une seule source, un seul calcul.
    static func milestones(
        from date: Date = .now,
        calendar: Calendar = .current,
        locale: UiLocale = .fr,
        remindersOn: Bool = true,
        trialDays: Int = OnboardingTrial.days
    ) -> [Milestone] {
        let dateText = billingDateText(from: date, calendar: calendar, locale: locale, trialDays: trialDays)
        let reminderText = reminderDateText(from: date, calendar: calendar, locale: locale, trialDays: trialDays)
        return [
            Milestone(
                title: L10n.t("ios.onb5.trial.today", locale: locale),
                // Lot 14 : sans « illimitées » — le serveur plafonne.
                detail: L10n.t("ios.onb17.tl.today", locale: locale),
                systemImage: "lock.open.fill",
                tone: .current
            ),
            Milestone(
                // **Des dates, plus des « jour 2 / jour 3 »** (lot 7) : « Jour 2 » se lisait le
                // lendemain, alors que le rappel part le surlendemain, la veille de la fin.
                // Lot 17 : la date seule en titre, ce qui s'y passe dessous.
                title: reminderText,
                // Le rappel part 24 h avant la fin (`TrialEndReminder.fireDate`) : « demain » est
                // exact. Sans notifications, l'étape dit comment l'activer.
                detail: L10n.t(remindersOn ? "ios.onb17.tl.reminder" : "ios.onb5.trial.reminderOff", locale: locale),
                systemImage: "bell.fill",
                tone: .upcoming
            ),
            Milestone(
                title: dateText,
                detail: L10n.t("ios.onb17.tl.billing", locale: locale),
                systemImage: "star.fill",
                tone: .upcoming
            ),
        ]
    }

    /// Le jour du premier prélèvement, écrit comme on le dirait : « 28 août ». Le même calcul
    /// que la chronologie du paywall (`PaywallTimeline.endDate`).
    static func billingDateText(
        from date: Date = .now,
        calendar: Calendar = .current,
        locale: UiLocale = .fr,
        trialDays: Int = OnboardingTrial.days
    ) -> String {
        PaywallTimeline.dayText(PaywallTimeline.endDate(from: date, trialDays: trialDays), locale: locale, calendar: calendar)
    }

    /// Le jour du rappel, la veille de la fin : « 27 août ». Le jour exact où le rappel est
    /// posé (`TrialEndReminder.fireDate`).
    static func reminderDateText(
        from date: Date = .now,
        calendar: Calendar = .current,
        locale: UiLocale = .fr,
        trialDays: Int = OnboardingTrial.days
    ) -> String {
        let end = PaywallTimeline.endDate(from: date, trialDays: trialDays)
        let fire = TrialEndReminder.fireDate(purchasedAt: date, trialDays: trialDays) ?? end.addingTimeInterval(-86_400)
        return PaywallTimeline.dayText(fire, locale: locale, calendar: calendar)
    }
}
