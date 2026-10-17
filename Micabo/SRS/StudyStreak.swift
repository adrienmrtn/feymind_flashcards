import Foundation
import SwiftData

extension Notification.Name {
    /// **Un jour de plus dans la série.** Posté quand une journée entre pour la première fois
    /// dans le registre, sur le fil principal. La pastille de Home et la feuille de la série se
    /// relisent dessus, au lieu d'interroger le registre à chaque rendu.
    static let micaboStreakDidChange = Notification.Name("micabo.streak.didChange")
}

/// **La série, comme Duolingo : les jours où l'on a travaillé.**
///
/// Elle se lisait dans le journal des cartes (`StudyStats.streak(reviewDates:)`), du temps où
/// réviser voulait dire noter des flashcards. Depuis la refonte, on apprend surtout dans une
/// leçon : des notes, un quiz, un examen blanc — rien de tout cela n'écrit de `ReviewLog`, et
/// une soirée entière sur un chapitre laissait la flamme éteinte. Le registre note donc **le
/// jour, pas l'activité** : n'importe quel vrai geste d'étude allume la journée, et la série
/// se compte sur les journées allumées.
///
/// **Des chaînes `yyyy-MM-dd`, pas des `Date`**, pour la même raison que `OffDay` : un jour
/// n'a pas d'instant, et un minuit stocké glisse d'un fuseau à l'autre. Le jour est celui du
/// calendrier de l'app (`MicaboCalendar.shared`), celui qu'on voit à l'écran.
///
/// **Quatre cents jours, pas plus**, et la série ne s'arrête pas au bord. C'est plus d'un an
/// et la semaine en cours, et ça tient dans `UserDefaults` sans y peser. Ce qui sort de la
/// fenêtre ne disparaît pas des comptes : le nombre de jours d'affilée qui précédaient le plus
/// ancien jour gardé est noté à part (`carry`), et le record aussi. Sans cela, une série de
/// quatre cent un jours en afficherait quatre cents le lendemain, puis encore quatre cents.
///
/// **Pas d'acteur.** `UserDefaults` se lit et s'écrit de n'importe quel fil, et le Profil
/// calcule ses chiffres hors du fil principal. Le registre et l'instant s'injectent, pour que
/// les tests n'aient ni à attendre minuit ni à salir les réglages de l'app.
enum StudyStreak {
    enum Key {
        /// Les jours travaillés, triés, du plus ancien au plus récent.
        static let days = "micabo.streak.days"
        /// La plus longue série jamais tenue.
        static let best = "micabo.streak.best"
        /// Le plus ancien jour gardé, quand des jours plus anciens sont sortis de la fenêtre…
        static let carryDay = "micabo.streak.carryDay"
        /// … et le nombre de jours d'affilée qui le précédaient.
        static let carry = "micabo.streak.carry"
        /// Le dernier jour dont la série a été fêtée à l'écran.
        static let celebrated = "micabo.streak.celebrated"
        /// Le journal des cartes a déjà été versé dans le registre.
        static let adoptedReviews = "micabo.streak.adoptedReviews"
    }

    static let keptDays = 400

    /// Un jour de la semaine en cours, tel que la rangée des sept ronds le montre.
    struct Day: Identifiable, Equatable {
        let date: Date
        let stamp: String
        let studied: Bool
        let isToday: Bool
        let isFuture: Bool

        var id: String { stamp }
    }

    /// Ce que les écrans montrent, lu en une fois.
    struct Status: Equatable {
        var current: Int
        var best: Int
        var studiedToday: Bool

        static let empty = Status(current: 0, best: 0, studiedToday: false)
    }

    // MARK: Écrire

    /// **Allume la journée.** Rend vrai quand cet appel est la première activité du jour :
    /// la série vient de commencer, ou de grandir d'un jour.
    ///
    /// On l'appelle à chaque vrai geste d'étude — une étape cochée, une réponse de quiz, une
    /// carte notée, une copie rendue. Les suivants ne coûtent qu'une lecture : la journée est
    /// déjà là.
    @discardableResult
    static func record(
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let ledger = Ledger(defaults: defaults)
        var days = ledger.days
        guard days.insert(stamp(now, calendar: calendar)).inserted else { return false }
        save(days, over: ledger, calendar: calendar, defaults: defaults)
        announce()
        return true
    }

    /// **Verse un historique dans le registre** : les dates du journal des cartes, pour qu'un
    /// compte d'avant la refonte garde la série qu'il avait. Sans effet si rien n'est nouveau.
    static func merge(
        _ dates: [Date],
        calendar: Calendar = MicaboCalendar.shared,
        defaults: UserDefaults = .standard
    ) {
        guard !dates.isEmpty else { return }
        let ledger = Ledger(defaults: defaults)
        var days = ledger.days
        for date in dates {
            days.insert(stamp(date, calendar: calendar))
        }
        guard days.count != ledger.days.count else { return }
        if save(days, over: ledger, calendar: calendar, defaults: defaults) {
            announce()
        }
    }

    /// **Une fois par installation**, le journal des cartes rejoint le registre. Home l'appelle
    /// en s'ouvrant : la pastille doit montrer la vraie série dès le premier lancement après la
    /// mise à jour, pas seulement après un passage par le Profil.
    static func adoptReviewHistoryIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Key.adoptedReviews) else { return }
        defaults.set(true, forKey: Key.adoptedReviews)
        let logs = (try? context.fetch(FetchDescriptor<ReviewLog>())) ?? []
        merge(logs.map(\.reviewedAt), defaults: defaults)
    }

    /// Oublie tout : la série, le record, la fête du jour. Pour les tests et le mode débogage.
    static func reset(defaults: UserDefaults = .standard) {
        for key in [Key.days, Key.best, Key.carryDay, Key.carry, Key.celebrated, Key.adoptedReviews] {
            defaults.removeObject(forKey: key)
        }
        announce()
    }

    // MARK: Lire

    /// Les jours consécutifs qui finissent aujourd'hui — ou hier, tant qu'aujourd'hui n'est pas
    /// encore travaillé : une série ne s'éteint pas au réveil. La même règle que
    /// `StudyStats.streak`.
    static func current(
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        defaults: UserDefaults = .standard
    ) -> Int {
        run(endingAround: now, in: Ledger(defaults: defaults), calendar: calendar)
    }

    /// La plus longue série jamais tenue, celle d'aujourd'hui comprise.
    static func best(
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        defaults: UserDefaults = .standard
    ) -> Int {
        max(defaults.integer(forKey: Key.best), current(now: now, calendar: calendar, defaults: defaults))
    }

    static func hasStudiedToday(
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        defaults: UserDefaults = .standard
    ) -> Bool {
        days(in: defaults).contains(stamp(now, calendar: calendar))
    }

    /// La série, le record et aujourd'hui, en une seule lecture du registre.
    static func status(
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        defaults: UserDefaults = .standard
    ) -> Status {
        let ledger = Ledger(defaults: defaults)
        let length = run(endingAround: now, in: ledger, calendar: calendar)
        return Status(
            current: length,
            best: max(defaults.integer(forKey: Key.best), length),
            studiedToday: ledger.days.contains(stamp(now, calendar: calendar))
        )
    }

    /// **Les sept jours de la semaine en cours**, dans l'ordre du calendrier de l'app (le lundi
    /// d'abord, voir `MicaboCalendar`), chacun allumé ou non.
    static func week(
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        defaults: UserDefaults = .standard
    ) -> [Day] {
        let stored = days(in: defaults)
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        let first = calendar.startOfDay(for: start)
        return (0..<7).compactMap { offset -> Day? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            let key = Self.stamp(date, calendar: calendar)
            return Day(
                date: date,
                stamp: key,
                studied: stored.contains(key),
                isToday: calendar.isDate(date, inSameDayAs: today),
                isFuture: date > today
            )
        }
    }

    // MARK: La fête du jour

    /// Aujourd'hui est travaillé, et la série n'a pas encore été fêtée à l'écran.
    static func celebrationIsDue(
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let today = stamp(now, calendar: calendar)
        return days(in: defaults).contains(today) && defaults.string(forKey: Key.celebrated) != today
    }

    /// **Réserve la fête du jour** : vrai une seule fois par jour, et seulement un jour travaillé.
    ///
    /// La fête ne suit pas le retour de `record` : dans un quiz, c'est la première réponse qui
    /// allume la journée, bien avant que l'étape se coche et que le chemin puisse la montrer.
    /// L'écran demande donc au moment où il peut la montrer, et le registre se souvient qu'elle
    /// a eu lieu.
    static func claimCelebration(
        now: Date = Date(),
        calendar: Calendar = MicaboCalendar.shared,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard celebrationIsDue(now: now, calendar: calendar, defaults: defaults) else { return false }
        defaults.set(stamp(now, calendar: calendar), forKey: Key.celebrated)
        return true
    }

    // MARK: Les jours

    /// `yyyy-MM-dd`, tel qu'on **voit** ce jour-là dans le calendrier de l'app. La même chaîne
    /// que `OffDays.stamp`, sans `DateFormatter` : on en calcule une par réponse de quiz.
    static func stamp(_ date: Date, calendar: Calendar = MicaboCalendar.shared) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(padded(parts.year ?? 0, 4))-\(padded(parts.month ?? 0, 2))-\(padded(parts.day ?? 0, 2))"
    }

    /// Les jours gardés dans la fenêtre.
    static func days(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: Key.days) ?? [])
    }

    // MARK: En coulisse

    /// Le registre tel qu'il est rangé : les jours de la fenêtre, et la série qui la précède.
    private struct Ledger {
        var days: Set<String>
        var carryDay: String?
        var carry: Int

        init(defaults: UserDefaults) {
            days = Set(defaults.stringArray(forKey: Key.days) ?? [])
            carryDay = defaults.string(forKey: Key.carryDay)
            carry = defaults.integer(forKey: Key.carry)
        }

        /// Les jours sortis de la fenêtre qui prolongent une série commençant à `start`.
        func carried(into start: String) -> Int {
            start == carryDay ? carry : 0
        }
    }

    private static func run(endingAround now: Date, in ledger: Ledger, calendar: Calendar) -> Int {
        let stored = ledger.days
        guard !stored.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: now)
        // Une série reste valide tant que la veille a été travaillée.
        if !stored.contains(stamp(cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  stored.contains(stamp(yesterday, calendar: calendar))
            else { return 0 }
            cursor = yesterday
        }
        var count = 0
        var earliest: String?
        var key = stamp(cursor, calendar: calendar)
        while stored.contains(key) {
            count += 1
            earliest = key
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
            key = stamp(cursor, calendar: calendar)
        }
        // Arrivée au bord de la fenêtre, la série continue dans ce qui en est sorti.
        guard let earliest else { return count }
        return count + ledger.carried(into: earliest)
    }

    /// La plus longue suite de jours consécutifs. On ne compte qu'à partir des débuts de série
    /// — les jours dont la veille manque —, ce qui ne parcourt chaque jour qu'une fois.
    private static func longestRun(in days: Set<String>, over ledger: Ledger, calendar: Calendar) -> Int {
        var best = 0
        for start in days {
            guard let eve = previousStamp(of: start, calendar: calendar), !days.contains(eve) else { continue }
            var length = 1
            var cursor = start
            while let next = nextStamp(of: cursor, calendar: calendar), days.contains(next) {
                length += 1
                cursor = next
            }
            best = max(best, length + ledger.carried(into: start))
        }
        return best
    }

    /// Écrit les jours, les plus récents gardés. Rend vrai si la fenêtre a changé.
    ///
    /// Le record se calcule **avant** de couper : c'est la fenêtre entière qui le dit, et un
    /// historique ancien versé d'un coup peut porter une série plus longue que celle
    /// d'aujourd'hui. Puis ce qui sort de la fenêtre laisse sa trace au plus ancien jour
    /// gardé : combien de jours d'affilée le précédaient. Le compte part des jours qu'on coupe,
    /// et reprend celui d'avant quand la chaîne passe par l'ancien bord.
    @discardableResult
    private static func save(
        _ days: Set<String>,
        over ledger: Ledger,
        calendar: Calendar,
        defaults: UserDefaults
    ) -> Bool {
        let previousBest = defaults.integer(forKey: Key.best)
        let best = max(previousBest, longestRun(in: days, over: ledger, calendar: calendar))
        if best != previousBest {
            defaults.set(best, forKey: Key.best)
        }

        let sorted = days.sorted()
        let kept = Array(sorted.suffix(keptDays))
        let dropped = sorted.dropLast(kept.count)
        if let oldest = kept.first, !dropped.isEmpty {
            var chain = 0
            var edge = oldest
            var carry = ledger.carried(into: oldest)
            for day in dropped.reversed() {
                guard day == previousStamp(of: edge, calendar: calendar) else { break }
                chain += 1
                edge = day
                carry = max(carry, chain + ledger.carried(into: day))
            }
            defaults.set(oldest, forKey: Key.carryDay)
            defaults.set(max(carry, chain), forKey: Key.carry)
        }

        guard kept != (defaults.stringArray(forKey: Key.days) ?? []) else { return false }
        defaults.set(kept, forKey: Key.days)
        return true
    }

    /// Toujours sur le fil principal, et jamais pendant l'écriture : une vue qui se relit sur la
    /// notification relit un registre déjà écrit.
    private static func announce() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .micaboStreakDidChange, object: nil)
        }
    }

    private static func previousStamp(of key: String, calendar: Calendar) -> String? {
        shifted(key, by: -1, calendar: calendar)
    }

    private static func nextStamp(of key: String, calendar: Calendar) -> String? {
        shifted(key, by: 1, calendar: calendar)
    }

    private static func shifted(_ key: String, by days: Int, calendar: Calendar) -> String? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              let moved = calendar.date(byAdding: .day, value: days, to: date)
        else { return nil }
        return stamp(moved, calendar: calendar)
    }

    private static func padded(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
