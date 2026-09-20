import Foundation
import SwiftData

/// **Ce qu'une date d'échéance change, et c'est une seule chose.**
///
/// Poser une date sur un deck ne réécrit aucune échéance de carte. Elle ne fait varier que
/// le nombre de **cartes neuves introduites par jour** : assez pour que tout le deck soit
/// passé au moins une fois avant le jour dit, pas une ligne de plus.
///
/// Ce qui vivait ici avant faisait tout autre chose. La replanification d'examen
/// (`ExamPlanner`) recalculait la date de chaque carte pour la faire retomber sur un
/// calendrier de passages, puis gardait une photographie de l'état d'avant pour pouvoir le
/// défaire. C'est un mécanisme qui marche, et qui a deux défauts que ce déplacement
/// corrige : il écrase le travail de la répétition espacée sur des cartes déjà bien placées,
/// et il ne se comprend pas. Un étudiant qui déplace son examen de trois jours voyait
/// quatre-vingts échéances bouger sans savoir laquelle et pourquoi. Ici, il voit un nombre
/// changer, et c'est le seul.
///
/// **Les deux derniers jours ne reçoivent pas de cartes neuves.** Découvrir une notion
/// l'avant-veille d'une épreuve ne laisse pas le temps de la revoir une seule fois : elle
/// occupe la session sans jamais être ancrée. Les deux jours rendus servent aux révisions,
/// qui, elles, ont encore un effet.
///
/// **Sauf quand l'épreuve est dans moins de quatre jours.** Là, retirer deux jours sur trois
/// reviendrait à ne plus rien introduire du tout, et un étudiant qui découvre Micabo
/// l'avant-veille de son contrôle préfère voir ses cartes une fois que pas du tout. La règle
/// de confort cède devant le cas où elle rendrait l'app inutile.
///
/// **Il n'y a pas de jours de repos.** Ils existaient, ils étaient demandés à l'inscription,
/// et ils retiraient des jours de la fenêtre. Ils ne sont plus lus : un jour sauté n'allège
/// pas la charge, il la reporte sur les autres, et c'est très exactement ce qu'un étudiant
/// qui déclare se reposer le dimanche ne veut pas. La table reste synchronisée pour le site,
/// qui s'en sert encore.
enum DeckPace {
    /// En deçà de ce délai, on introduit des cartes neuves jusqu'au dernier jour.
    static let crunchDays = 4
    /// Jours sans cartes neuves avant l'échéance, hors précipitation.
    static let quietDays = 2

    /// Le nombre de jours qui séparent aujourd'hui de l'échéance. Zéro veut dire « c'est
    /// aujourd'hui », négatif « c'est passé ».
    static func daysUntil(
        _ deadline: Date,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: deadline)
        return calendar.dateComponents([.day], from: today, to: day).day ?? 0
    }

    /// Les jours où l'on peut encore découvrir quelque chose, aujourd'hui compris.
    ///
    /// Zéro est une réponse possible, et elle est juste : l'épreuve est passée, ou elle est
    /// demain et le deck avait tout le temps de se faire. Elle ne veut pas dire « plus rien à
    /// réviser » — les révisions, elles, continuent jusqu'au bout.
    static func introductionDays(
        until deadline: Date,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> Int {
        let remaining = daysUntil(deadline, now: now, calendar: calendar)
        guard remaining >= 0 else { return 0 }

        // Aujourd'hui compte : une échéance à demain laisse deux jours ouvrables.
        let window = remaining + 1
        guard remaining >= crunchDays else { return window }
        return max(0, window - quietDays)
    }

    /// **Combien de cartes neuves par jour pour tout avoir vu à temps.**
    ///
    /// Arrondi au-dessus, et jamais en dessous d'une carte quand il reste quelque chose à
    /// découvrir : un plan qui annonce « 0,7 carte par jour » ne fait rien avancer, et un
    /// deck de cinq cartes à trois semaines de l'épreuve mérite quand même d'être commencé.
    ///
    /// Sans échéance, on rend le rythme ordinaire des réglages : c'est le cas de l'étudiant
    /// qui apprend sans date, et il n'a aucune raison d'être servi autrement qu'avant.
    static func newCardsPerDay(
        remaining: Int,
        deadline: Date?,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        fallback: Int = DailyLoad.newCardsPerDay(dailyMinutes: OnboardingPreferences.dailyMinutes)
    ) -> Int {
        guard remaining > 0 else { return 0 }
        guard let deadline else { return fallback }

        let days = introductionDays(until: deadline, now: now, calendar: calendar)
        // Plus de jour ouvrable : tout ce qui reste est à voir maintenant ou jamais. On ne
        // rend pas zéro, ce qui fermerait la session la veille de l'épreuve sur un deck
        // qu'on n'a pas fini.
        guard days > 0 else { return remaining }

        return max(1, Int((Double(remaining) / Double(days)).rounded(.up)))
    }

    /// Ce que le plan annonce à l'écran, avant qu'une seule carte n'ait été vue.
    struct Readout: Equatable {
        /// Cartes neuves par jour.
        var perDay: Int
        /// Jours où l'on introduit encore.
        var days: Int
        /// Jours avant l'échéance, aujourd'hui exclu.
        var daysLeft: Int
        /// Vrai quand l'échéance est trop proche pour se permettre les deux jours calmes.
        var isCrunch: Bool
        /// Vrai quand l'échéance est passée, ou qu'il n'y en a pas.
        var isOpenEnded: Bool
    }

    // MARK: - Le budget d'un deck

    /// L'échéance la plus proche qui porte sur ce deck, ou rien.
    ///
    /// Un examen passé ne contraint plus : le lendemain de l'épreuve, le deck retrouve le
    /// rythme ordinaire sans qu'on ait à toucher à quoi que ce soit.
    static func deadline(
        for courseID: UUID,
        exams: [Exam],
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> Date? {
        let today = calendar.startOfDay(for: now)
        return exams
            .filter { exam in
                exam.isPlanned
                    && exam.courseIDs.contains(courseID)
                    && calendar.startOfDay(for: exam.date) >= today
            }
            .map(\.date)
            .min()
    }

    /// **Combien de cartes neuves ce deck peut encore servir aujourd'hui.**
    ///
    /// Le plafond est celui du deck, pas celui du compte : c'est tout l'objet de la date.
    /// Un étudiant qui déclare un contrôle dans cinq jours demande explicitement à voir plus
    /// de cartes par jour que son rythme habituel, et lui servir son rythme habituel
    /// reviendrait à ignorer la réponse qu'on vient de lui demander.
    ///
    /// Sans échéance, on rend le rythme ordinaire, et rien ne change pour les decks qu'on
    /// travaille sans date.
    static func remainingToday(
        for course: Course,
        exams: [Exam],
        logs: [ReviewLog],
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> Int {
        let due = deadline(for: course.id, exams: exams, now: now, calendar: calendar)
        let undiscovered = course.cards.reduce(0) { $0 + (($1.state == .new && !$1.isSuspended) ? 1 : 0) }
        let perDay = newCardsPerDay(remaining: undiscovered, deadline: due, now: now, calendar: calendar)
        return max(0, perDay - introducedToday(for: course.id, logs: logs, now: now, calendar: calendar))
    }

    /// Les cartes de **ce deck-là** découvertes aujourd'hui.
    ///
    /// Le compte est par deck et non global, parce que le plafond l'est aussi. Un étudiant
    /// qui a fait ses douze cartes d'histoire ce matin n'a pas entamé son budget de biologie,
    /// et lui refuser ses cartes de biologie à cause d'une échéance d'histoire serait faire
    /// payer à un deck le calendrier d'un autre.
    static func introducedToday(
        for courseID: UUID,
        logs: [ReviewLog],
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> Int {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return logs.reduce(0) { total, log in
            guard log.stateBeforeRaw == CardState.new.rawValue,
                  log.reviewedAt >= start,
                  log.reviewedAt < end,
                  log.card?.course?.id == courseID
            else { return total }
            return total + 1
        }
    }

    static func readout(
        remaining: Int,
        deadline: Date?,
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> Readout {
        guard let deadline else {
            return Readout(
                perDay: newCardsPerDay(remaining: remaining, deadline: nil, now: now, calendar: calendar),
                days: 0,
                daysLeft: 0,
                isCrunch: false,
                isOpenEnded: true
            )
        }

        let left = daysUntil(deadline, now: now, calendar: calendar)
        return Readout(
            perDay: newCardsPerDay(remaining: remaining, deadline: deadline, now: now, calendar: calendar),
            days: introductionDays(until: deadline, now: now, calendar: calendar),
            daysLeft: left,
            isCrunch: left >= 0 && left < crunchDays,
            isOpenEnded: left < 0
        )
    }
}
