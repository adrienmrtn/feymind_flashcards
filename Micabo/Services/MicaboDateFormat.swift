import Foundation

/// **Les formateurs de date, gardés par gabarit et par langue.**
///
/// Chaque libellé de date du calendrier (« lun. », « 14 », « 14:30 », « novembre ») créait son
/// `DateFormatter` et lui faisait résoudre son gabarit : c'est l'objet le plus cher de
/// Foundation à construire, et la bande des semaines en demandait cinquante-six par pose, la
/// grille du mois une cinquantaine, l'agenda deux par événement.
///
/// Un formateur rendu ici **ne se modifie pas** : on n'en lit que `string(from:)` et ses
/// symboles, ce que `DateFormatter` permet depuis n'importe quel fil. La langue fait partie de
/// la clé (changer de langue dans les réglages lit un autre formateur), et un changement de
/// fuseau du téléphone vide le cache.
enum MicaboDateFormat {
    private static let formatters = MemoCache<String, DateFormatter>(limit: 96)

    private static let zoneWatch: NSObjectProtocol = NotificationCenter.default.addObserver(
        forName: .NSSystemTimeZoneDidChange, object: nil, queue: nil
    ) { _ in formatters.removeAll() }

    /// Le formateur d'un gabarit (`"EEE"`, `"jmm"`, `"d MMM"`…) dans une langue, sur le
    /// calendrier de l'app. `pinsTimeZone` le tient au fuseau de ce calendrier (les heures
    /// d'un événement se lisent dans le fuseau où elles ont été posées).
    static func template(_ template: String, locale: UiLocale, pinsTimeZone: Bool = false) -> DateFormatter {
        _ = zoneWatch
        return formatters.value(for: "\(locale.rawValue)|\(template)|\(pinsTimeZone)") {
            let formatter = DateFormatter()
            formatter.locale = locale.foundation
            formatter.calendar = MicaboCalendar.shared
            if pinsTimeZone { formatter.timeZone = MicaboCalendar.shared.timeZone }
            formatter.setLocalizedDateFormatFromTemplate(template)
            return formatter
        }
    }

    /// Le formateur dont on lit les symboles d'une langue (les noms des jours) : la langue
    /// seule, sans gabarit ni calendrier imposé.
    static func symbols(locale: UiLocale) -> DateFormatter {
        formatters.value(for: "\(locale.rawValue)|symboles") {
            let formatter = DateFormatter()
            formatter.locale = locale.foundation
            return formatter
        }
    }
}
