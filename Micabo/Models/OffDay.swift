import Foundation
import SwiftData

/// **Un jour où l'on ne révisera pas.**
///
/// Le plan répartit le travail sur les jours qui restent avant l'épreuve. Sans cette table, il
/// les suppose tous ouverts : il pose du travail le dimanche où l'on ne touchera pas au
/// téléphone, l'étudiant prend un jour de retard dès la première semaine, et le plan qui
/// devait rassurer devient une dette.
///
/// **La disponibilité est globale, pas par épreuve**, et c'est délibéré : un samedi pris n'est
/// pas pris « pour la biologie ». C'est aussi la forme du site (`availability_exceptions`,
/// clé primaire `(user_id, day)`), et les deux plateformes doivent tomber d'accord sur les
/// jours de quelqu'un.
///
/// **Le jour est une chaîne, `yyyy-MM-dd`, et pas une `Date`.** Une date nue n'a pas d'instant :
/// « le 12 septembre » est le même jour à Paris et à Montréal, alors qu'un `Date` ramené à
/// minuit glisse d'un jour d'un fuseau à l'autre - à l'écriture comme à la relecture, et dans
/// des sens opposés selon le signe du décalage. La colonne du serveur est un `date` ; on
/// stocke exactement ce qu'elle stocke, et la comparaison redevient une égalité de chaînes.
@Model
final class OffDay {
    @Attribute(.unique) var stamp: String = ""
    var createdAt: Date = Date()

    init(stamp: String) {
        self.stamp = stamp
        createdAt = Date()
    }
}

/// Lire, poser et retirer des jours de pause.
enum OffDays {
    /// `yyyy-MM-dd`, tel qu'on **voit** ce jour-là dans le calendrier de l'app.
    static func stamp(_ date: Date, in calendar: Calendar = MicaboCalendar.shared) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func all(in context: ModelContext) -> [OffDay] {
        let descriptor = FetchDescriptor<OffDay>(sortBy: [SortDescriptor(\.stamp, order: .forward)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func stamps(in context: ModelContext) -> Set<String> {
        Set(all(in: context).map(\.stamp))
    }

    /// Pose une journée. Une journée qu'on remet efface sa pierre tombale : elle n'est plus
    /// « à effacer au serveur », elle est à y écrire.
    static func insert(_ stamp: String, in context: ModelContext) {
        guard !all(in: context).contains(where: { $0.stamp == stamp }) else { return }
        context.insert(OffDay(stamp: stamp))
        OffDayTombstones.unmark(stamp)
    }

    /// Retire une journée, et **s'en souvient** : la prochaine synchro doit l'effacer au
    /// serveur, et la descente ne doit pas la ramener entre-temps.
    static func remove(_ stamp: String, in context: ModelContext) {
        for row in all(in: context) where row.stamp == stamp {
            context.delete(row)
        }
        OffDayTombstones.mark(stamp)
    }

    /// Pose ou retire une journée. Rend l'état **après** le geste, pour que l'appelant n'ait
    /// pas à relire la base pour savoir ce qu'il vient de faire.
    @discardableResult
    static func toggle(_ stamp: String, in context: ModelContext) -> Bool {
        let present = all(in: context).contains { $0.stamp == stamp }
        if present { remove(stamp, in: context) } else { insert(stamp, in: context) }
        try? context.save()
        return !present
    }

    /// **Les jours de repos de toutes les semaines**, en décalage depuis aujourd'hui.
    ///
    /// `weekly` porte sept valeurs, lundi en premier, et un zéro veut dire « ce jour-là,
    /// rien ». C'est l'habitude déclarée à l'inscription - « jamais le dimanche » - et elle
    /// vaut pour toutes les semaines à venir, là où les pauses ne parlent que de dates. Les
    /// deux se cumulent, exactement comme `weeklyOffOffsets` sur le site.
    static func weeklyOffsets(
        from start: Date,
        window: Int,
        weekly: [Int]?,
        calendar: Calendar = MicaboCalendar.shared
    ) -> [Int] {
        guard let weekly, weekly.count == 7, window > 0 else { return [] }
        let first = calendar.startOfDay(for: start)
        var offsets: [Int] = []
        for offset in 0..<window {
            guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
            // `weekday` compte à partir de dimanche (1) ; la colonne compte à partir de lundi.
            let index = (calendar.component(.weekday, from: date) + 5) % 7
            if weekly[index] == 0 { offsets.append(offset) }
        }
        return offsets
    }

    /// **Les décalages fermés dans une fenêtre de plan.**
    ///
    /// Le planificateur ne raisonne pas en dates mais en décalages depuis aujourd'hui : c'est
    /// ce que `ExamPlanner` attend, et c'est ce que le noyau appelle `offDays`.
    static func offsets(
        from start: Date,
        window: Int,
        stamps: Set<String>,
        calendar: Calendar = MicaboCalendar.shared
    ) -> [Int] {
        guard window > 0, !stamps.isEmpty else { return [] }
        let first = calendar.startOfDay(for: start)
        var offsets: [Int] = []
        for offset in 0..<window {
            guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
            if stamps.contains(stamp(date, in: calendar)) { offsets.append(offset) }
        }
        return offsets
    }

    /// Les jours qu'on propose de cocher : d'aujourd'hui à la veille de l'épreuve, quatre
    /// semaines au plus. Pointer chaque jour d'un semestre n'a plus de sens, et une grille de
    /// cent cases ne se lit pas. C'est la borne du site, à la case près.
    static let horizon = 28

    static func window(from start: Date, daysRemaining: Int, calendar: Calendar = MicaboCalendar.shared) -> [Date] {
        let count = min(horizon, max(0, daysRemaining))
        guard count > 0 else { return [] }
        let first = calendar.startOfDay(for: start)
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }
}

/// **Les journées décochées depuis la dernière synchro.**
///
/// Sans elles, la synchro ne saurait pas distinguer « cette journée n'existe pas ici parce
/// qu'on l'a retirée » de « cette journée n'existe pas ici parce qu'on ne l'a pas encore
/// reçue ». Le premier cas doit effacer au serveur, le second doit écrire en local, et une
/// ligne absente ne dit pas lequel. La pierre tombale le dit.
enum OffDayTombstones {
    private static let key = "micabo.offDays.tombstones"

    static var defaults: UserDefaults = .standard

    static func mark(_ stamp: String) {
        var stamps = all()
        stamps.insert(stamp)
        defaults.set(Array(stamps), forKey: key)
    }

    static func unmark(_ stamp: String) {
        var stamps = all()
        stamps.remove(stamp)
        defaults.set(Array(stamps), forKey: key)
    }

    static func all() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    /// Une fois effacées au serveur, les pierres tombales ont fait leur travail.
    static func clear(_ stamps: Set<String>) {
        defaults.set(Array(all().subtracting(stamps)), forKey: key)
    }
}
