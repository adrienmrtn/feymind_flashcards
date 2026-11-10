import Foundation
import Observation

/// **Ce qui rapporte de l'XP** (`XP_REWARDS` côté site). Le nombre vient de `XPRules`.
enum XPReason: String, CaseIterable {
    case correctAnswer
    case wrongAnswer
    case cardReviewed
    case circleCompleted
    case lessonCreated
    case mockExamFinished
    case mikaAnswer
    case exerciseSolved
    case focusSession

    var points: Int {
        switch self {
        case .correctAnswer: XPRules.correctAnswer
        case .wrongAnswer: XPRules.wrongAnswer
        case .cardReviewed: XPRules.cardReviewed
        case .circleCompleted: XPRules.circleCompleted
        case .lessonCreated: XPRules.lessonCreated
        case .mockExamFinished: XPRules.mockExamFinished
        case .mikaAnswer: XPRules.mikaAnswer
        case .exerciseSolved: XPRules.exerciseSolved
        case .focusSession: XPRules.focusSession
        }
    }
}

/// **Le calcul de l'XP**, sans état : le journal par jour local, la semaine du lundi, le
/// plafond, les ligues. Le jumeau des fonctions de `web/packages/core/src/xp.ts`.
enum XPMath {
    /// Le journal : XP par jour local, `["2026-11-10": 120]`.
    typealias Ledger = [String: Int]

    /// La date `AAAA-MM-JJ` d'un jour local.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Le lundi de la semaine de `date`, à minuit local : la semaine de la ligue commence là.
    /// `weekday` vaut 1 le dimanche, quel que soit le premier jour du calendrier.
    static func mondayDate(_ date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let offset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: start) ?? start
    }

    static func weekStart(_ date: Date, calendar: Calendar = .current) -> String {
        dayKey(mondayDate(date, calendar: calendar), calendar: calendar)
    }

    /// Les jours qui restent avant lundi minuit, aujourd'hui compris (1 le dimanche).
    static func daysLeftInWeek(_ date: Date, calendar: Calendar = .current) -> Int {
        let monday = mondayDate(date, calendar: calendar)
        let next = calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: next).day ?? 1
        return max(1, days)
    }

    /// Ajoute `amount` au jour de `at`, sans dépasser le plafond du jour.
    static func add(_ ledger: Ledger, _ amount: Int, at date: Date, calendar: Calendar = .current) -> Ledger {
        let key = dayKey(date, calendar: calendar)
        var next = ledger
        next[key] = min(XPRules.dailyCap, (ledger[key] ?? 0) + max(0, amount))
        return next
    }

    static func today(_ ledger: Ledger, now: Date, calendar: Calendar = .current) -> Int {
        ledger[dayKey(now, calendar: calendar)] ?? 0
    }

    /// L'XP de la semaine en cours, du lundi à aujourd'hui.
    static func thisWeek(_ ledger: Ledger, now: Date, calendar: Calendar = .current) -> Int {
        let start = weekStart(now, calendar: calendar)
        let end = dayKey(now, calendar: calendar)
        return ledger.filter { $0.key >= start && $0.key <= end }.values.reduce(0, +)
    }

    /// Le journal ne garde que les quinze derniers jours ; le total vit à part.
    static func prune(_ ledger: Ledger, now: Date, keepDays: Int = 15, calendar: Calendar = .current) -> Ledger {
        let start = calendar.startOfDay(for: now)
        let limit = calendar.date(byAdding: .day, value: -keepDays, to: start) ?? start
        let floor = dayKey(limit, calendar: calendar)
        return ledger.filter { $0.key > floor }
    }

    static func league(for weeklyXP: Int) -> XPLeague {
        var current = XPRules.leagues[0]
        for league in XPRules.leagues where weeklyXP >= league.floor {
            current = league
        }
        return current
    }

    /// Ce qui manque pour la ligue suivante, ou `nil` en Diamant.
    static func nextLeague(for weeklyXP: Int) -> (league: XPLeague, missing: Int)? {
        guard let next = XPRules.leagues.first(where: { $0.floor > weeklyXP }) else { return nil }
        return (next, next.floor - weeklyXP)
    }
}

extension XPLeague {
    /// L'emoji de la pastille XP de Home.
    var emoji: String {
        switch id {
        case "silver": "🥈"
        case "gold": "🥇"
        case "sapphire": "🔷"
        case "diamond": "💎"
        default: "🥉"
        }
    }

    /// Le nom de la ligue, dans la langue de l'app.
    var name: String {
        L10n.t("ios.kx.league.\(id)", locale: .resolved())
    }
}

/// Ce qu'un gain a donné : les points vraiment ajoutés (le plafond peut en rogner), et si
/// l'objectif du jour vient d'être atteint pour la première fois aujourd'hui.
struct XPAward: Equatable {
    var added: Int
    var reachedGoal: Bool

    static let zero = XPAward(added: 0, reachedGoal: false)
}

/// **L'XP de l'élève, sur l'appareil** (`docs/refonte-knowunity.md` § 2).
///
/// Un journal par jour local (quinze jours), un total à part, dans `UserDefaults` comme les
/// autres petits compteurs de l'app (`MikaQuota`, `StudyStreak`). Créé une fois
/// (`shared`), posé dans l'environnement par `MicaboApp`, et appelé directement par les
/// gestes qui rapportent : une réponse, une carte, un cercle, une leçon, une copie, Mika.
///
/// Le type n'est pas isolé au `MainActor`, comme `Haptics` : les gains partent tous du fil
/// principal, et certains depuis des fonctions qui ne sont pas isolées (`LessonReview.rate`).
@Observable
final class XPStore {
    static let shared = XPStore()

    enum Key {
        static let ledger = "micabo.xp.ledger"
        static let total = "micabo.xp.total"
        static let celebratedDay = "micabo.xp.goalCelebratedDay"
    }

    private(set) var ledger: XPMath.Ledger
    private(set) var lifetime: Int

    /// Ce qui montre un gain à l'écran (`XPOverlayController`) : nil dans les tests.
    @ObservationIgnored var onAward: ((XPAward) -> Void)?
    private let defaults: UserDefaults
    let calendar: Calendar
    let now: () -> Date

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        let stored = (defaults.dictionary(forKey: Key.ledger) as? [String: Int]) ?? [:]
        ledger = XPMath.prune(stored, now: now(), calendar: calendar)
        lifetime = max(defaults.integer(forKey: Key.total), stored.values.reduce(0, +))
    }

    // MARK: Ce qu'on lit

    var today: Int { XPMath.today(ledger, now: now(), calendar: calendar) }
    var week: Int { XPMath.thisWeek(ledger, now: now(), calendar: calendar) }
    var weekStart: String { XPMath.weekStart(now(), calendar: calendar) }
    var league: XPLeague { XPMath.league(for: week) }
    var goalReached: Bool { today >= XPRules.dailyGoal }
    var goalProgress: Double { min(1, Double(today) / Double(XPRules.dailyGoal)) }
    var daysLeftInWeek: Int { XPMath.daysLeftInWeek(now(), calendar: calendar) }

    // MARK: Gagner

    /// Un geste qui rapporte. `celebrates` à faux quand l'écran fête lui-même (le minuteur) :
    /// la fête du jour est alors marquée comme vue, sans s'afficher par-dessus.
    @discardableResult
    func award(_ reason: XPReason, celebrates: Bool = true) -> XPAward {
        award(points: reason.points, celebrates: celebrates)
    }

    @discardableResult
    func award(points: Int, celebrates: Bool = true) -> XPAward {
        let date = now()
        let key = XPMath.dayKey(date, calendar: calendar)
        let before = ledger[key] ?? 0
        let next = XPMath.prune(XPMath.add(ledger, points, at: date, calendar: calendar), now: date, calendar: calendar)
        let added = (next[key] ?? 0) - before
        guard added > 0 else { return .zero }

        ledger = next
        lifetime += added
        var reachedGoal = false
        if before < XPRules.dailyGoal, before + added >= XPRules.dailyGoal,
           defaults.string(forKey: Key.celebratedDay) != key {
            defaults.set(key, forKey: Key.celebratedDay)
            reachedGoal = true
        }
        save()
        let result = XPAward(added: added, reachedGoal: reachedGoal)
        onAward?(celebrates ? result : XPAward(added: added, reachedGoal: false))
        return result
    }

    // MARK: La synchro

    /// Ce qui monte avec la ligne `profiles` : le total, l'XP de la semaine et son lundi.
    /// Bornés comme la contrainte `profiles_xp_bounds`.
    var syncValues: (total: Int, week: Int, weekStart: String) {
        (min(lifetime, 100_000_000), min(week, 35_000), weekStart)
    }

    /// Le total déjà monté par un autre appareil (ou avant une réinstallation) : on garde le
    /// plus grand, pour qu'un téléphone neuf ne remette pas le compteur du compte à zéro.
    func adoptRemote(total: Int?) {
        guard let total, total > lifetime else { return }
        lifetime = total
        save()
    }

    /// Oublie tout : un compte qui s'en va (`LocalWipe`) ou un test.
    func reset() {
        ledger = [:]
        lifetime = 0
        defaults.removeObject(forKey: Key.ledger)
        defaults.removeObject(forKey: Key.total)
        defaults.removeObject(forKey: Key.celebratedDay)
    }

    private func save() {
        defaults.set(ledger, forKey: Key.ledger)
        defaults.set(lifetime, forKey: Key.total)
    }
}

extension SupabaseDatabase.Failure {
    /// Vrai quand le serveur refuse le profil à cause d'une colonne `xp_*` : la colonne
    /// n'existe pas encore (`PGRST204`, « Could not find the 'xp_total' column »), ou la
    /// contrainte `profiles_xp_bounds` dit non. Le profil repart alors sans l'XP.
    var concernsXPColumns: Bool {
        guard case .server(_, let message, _) = self else { return false }
        return message.lowercased().contains("xp_")
    }
}
