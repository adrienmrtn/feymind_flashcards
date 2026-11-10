import Foundation
import SwiftData
import UserNotifications

/// **Ce qu'une séance laisse derrière elle**, qu'elle aille au bout ou non : sa ligne dans
/// `FocusSession`, son temps dans `FocusLog` (les heures de Home), l'XP de chaque bloc de
/// 25 minutes terminé, la journée de la série, et la séance de révision du calendrier cochée.
@MainActor
enum FocusRecorder {
    /// En dessous d'une minute de travail, une séance n'a rien à compter.
    static let minimumSeconds: TimeInterval = 60

    @discardableResult
    static func record(
        plan: FocusPlan,
        startedAt: Date,
        endedAt: Date = Date(),
        workSeconds: TimeInterval,
        completed: Bool,
        in context: ModelContext,
        xp: XPStore = .shared
    ) -> XPAward {
        guard workSeconds >= minimumSeconds else { return .zero }
        let points = FocusPhases.xp(forWorkSeconds: workSeconds)
        let award = points > 0 ? xp.award(points: points, celebrates: false) : .zero
        context.insert(FocusSession(
            startedAt: startedAt,
            endedAt: endedAt,
            focusedSeconds: workSeconds,
            mode: plan.mode,
            plannedMinutes: plan.totalWorkMinutes,
            cycles: plan.effectiveCycles,
            completed: completed,
            courseID: plan.courseID,
            eventID: plan.eventID,
            xpEarned: award.added
        ))
        if completed, let eventID = plan.eventID {
            let events = (try? context.fetch(FetchDescriptor<CalendarEvent>(predicate: #Predicate { $0.id == eventID }))) ?? []
            for event in events {
                event.isDone = true
                event.updatedAt = Date()
            }
        }
        try? context.save()
        FocusLog.add(workSeconds)
        StudyStreak.record()
        StudyNotifications.refresh(in: context)
        Analytics.track(completed ? .focusCompleted : .focusStopped, [
            "mode": .text(plan.mode.rawValue),
            "minutes": .number(Double(Int(workSeconds / 60))),
            "goal": .flag(plan.courseID != nil),
            "planned": .flag(plan.eventID != nil),
        ])
        return award
    }
}

/// **Les fins de phase, quand l'app dort** : une notification par fin de travail ou de pause,
/// posée au départ en arrière-plan et retirée au retour. Seulement si l'élève a déjà dit oui
/// aux notifications.
enum FocusPhaseAlerts {
    static let identifierPrefix = "micabo.focus."

    static func schedule(plan: FocusPlan, elapsed: TimeInterval, now: Date = Date()) {
        let boundaries = FocusPhases.upcomingBoundaries(in: plan.phases, elapsed: elapsed, now: now)
        let locale = UiLocale.resolved()
        Task {
            let center = UNUserNotificationCenter.current()
            await clear()
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional || status == .ephemeral else { return }
            for (index, boundary) in boundaries.prefix(10).enumerated() {
                let content = UNMutableNotificationContent()
                switch (boundary.endedPhase.kind, boundary.next) {
                case (.work, .some(let next)):
                    content.title = L10n.t("ios.focus.notif.breakTitle", locale: locale)
                    content.body = L10n.t("ios.focus.notif.breakBody", locale: locale, vars: ["minutes": "\(Int(next.seconds / 60))"])
                case (.rest, _):
                    content.title = L10n.t("ios.focus.notif.workTitle", locale: locale)
                    content.body = L10n.t("ios.focus.notif.workBody", locale: locale)
                case (.work, .none):
                    content.title = L10n.t("ios.focus.notif.doneTitle", locale: locale)
                    content.body = L10n.t("ios.focus.notif.doneBody", locale: locale)
                }
                content.sound = .default
                let interval = max(1, boundary.date.timeIntervalSince(now))
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: identifierPrefix + "\(index)", content: content, trigger: trigger))
            }
        }
    }

    static func cancel() {
        Task { await clear() }
    }

    private static func clear() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
    }
}
