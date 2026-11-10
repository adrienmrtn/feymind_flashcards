import Foundation

/// **Une occurrence** d'un événement : l'événement, posé sur un jour précis, à ses heures.
struct CalendarOccurrence: Equatable, Identifiable {
    var event: CalendarEventSpec
    /// Le jour de l'occurrence, au début de la journée.
    var day: Date
    var start: Date
    var end: Date

    var id: String { "\(event.id.uuidString)-\(Int(day.timeIntervalSince1970))" }
}

/// **Déplier les événements répétés.**
///
/// Un événement hebdomadaire a lieu chaque jour qui tombe à un multiple de sept jours de sa
/// première occurrence, à partir d'elle, sauf les jours sautés. Le calcul se fait en **jours
/// de calendrier** et non en secondes : une semaine qui contient un changement d'heure fait
/// 167 ou 169 heures, et compter en secondes décalait d'un jour le cours du lundi suivant.
enum CalendarRecurrence {
    /// Vrai si l'événement a lieu ce jour-là.
    static func occurs(_ event: CalendarEventSpec, on day: Date, calendar: Calendar = MicaboCalendar.shared) -> Bool {
        let wanted = calendar.startOfDay(for: day)
        let first = calendar.startOfDay(for: event.day)
        if event.skippedDays.contains(where: { calendar.isDate($0, inSameDayAs: wanted) }) { return false }
        guard event.repeatsWeekly else { return wanted == first }
        guard wanted >= first else { return false }
        let days = calendar.dateComponents([.day], from: first, to: wanted).day ?? 0
        return days % 7 == 0
    }

    /// Les occurrences d'un jour, triées par heure de début.
    static func occurrences(
        of events: [CalendarEventSpec],
        on day: Date,
        calendar: Calendar = MicaboCalendar.shared
    ) -> [CalendarOccurrence] {
        let start = calendar.startOfDay(for: day)
        return events
            .filter { occurs($0, on: start, calendar: calendar) }
            .map { event in
                CalendarOccurrence(
                    event: event,
                    day: start,
                    start: CalendarTime.date(minute: event.startMinute, on: start, calendar: calendar),
                    end: CalendarTime.date(minute: event.endMinute, on: start, calendar: calendar)
                )
            }
            .sorted { lhs, rhs in
                if lhs.event.startMinute != rhs.event.startMinute { return lhs.event.startMinute < rhs.event.startMinute }
                return lhs.event.title < rhs.event.title
            }
    }

    /// Les occurrences d'une plage de jours, `from` compris, `through` compris.
    static func occurrences(
        of events: [CalendarEventSpec],
        from: Date,
        through: Date,
        calendar: Calendar = MicaboCalendar.shared
    ) -> [CalendarOccurrence] {
        var result: [CalendarOccurrence] = []
        var day = calendar.startOfDay(for: from)
        let last = calendar.startOfDay(for: through)
        var guardCount = 0
        while day <= last && guardCount < 400 {
            result += occurrences(of: events, on: day, calendar: calendar)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            guardCount += 1
        }
        return result
    }

    /// Les créneaux pris d'un jour, en minutes : ce que le planificateur doit éviter.
    static func busyMinutes(
        of events: [CalendarEventSpec],
        on day: Date,
        calendar: Calendar = MicaboCalendar.shared
    ) -> [ClosedRange<Int>] {
        occurrences(of: events, on: day, calendar: calendar).compactMap { occurrence in
            let start = occurrence.event.startMinute
            let end = max(start, occurrence.event.endMinute)
            return start...end
        }
    }
}

/// **Les heures, écrites comme la langue les écrit.** 14:30 en français, 2:30 PM en anglais
/// américain : le gabarit `jmm` laisse la langue choisir son cycle (12 ou 24 heures).
enum CalendarTime {
    static let dayMinutes = 24 * 60

    /// La date d'une minute de la journée. `bySettingHour` plutôt qu'un ajout de minutes : le
    /// jour du changement d'heure, ajouter 480 minutes à minuit ne donne pas 8 h.
    static func date(minute: Int, on day: Date, calendar: Calendar = MicaboCalendar.shared) -> Date {
        let clamped = max(0, min(dayMinutes - 1, minute))
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: clamped / 60, minute: clamped % 60, second: 0, of: start)
            ?? start.addingTimeInterval(TimeInterval(clamped * 60))
    }

    /// La minute de la journée d'une date.
    static func minute(of date: Date, calendar: Calendar = MicaboCalendar.shared) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// « 14:30 », « 2:30 PM ».
    static func label(minute: Int, locale: UiLocale = .resolved()) -> String {
        label(date(minute: minute, on: Date(timeIntervalSince1970: 0)), locale: locale)
    }

    static func label(_ date: Date, locale: UiLocale = .resolved()) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.calendar = MicaboCalendar.shared
        formatter.timeZone = MicaboCalendar.shared.timeZone
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: date)
    }

    /// « 14:30 – 15:30 ».
    static func range(start: Int, end: Int, locale: UiLocale = .resolved()) -> String {
        "\(label(minute: start, locale: locale)) – \(label(minute: end, locale: locale))"
    }

    /// Une durée : « 45 min », « 1 h 30 min », « 2 Std. » — chaque unité écrite par le système,
    /// dans la langue de l'app. Le style court du formateur, unité par unité : son style
    /// abrégé colle les unités au nombre en français (« 15min »), et son style court les relie
    /// par une virgule en anglais (« 1 hr, 30 min »).
    static func duration(minutes: Int, locale: UiLocale = .resolved()) -> String {
        let total = max(0, minutes)
        let hours = total / 60
        let rest = total % 60
        var parts: [String] = []
        if hours > 0 { parts.append(unit(hours, .hour, locale: locale)) }
        if rest > 0 || hours == 0 { parts.append(unit(rest, .minute, locale: locale)) }
        return parts.joined(separator: " ")
    }

    private static func unit(_ value: Int, _ unit: NSCalendar.Unit, locale: UiLocale) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale.foundation
        formatter.calendar = calendar
        formatter.unitsStyle = .short
        formatter.allowedUnits = [unit]
        formatter.zeroFormattingBehavior = .pad
        let seconds = unit == .hour ? value * 3600 : value * 60
        return formatter.string(from: TimeInterval(seconds)) ?? "\(value)"
    }

    /// « HH:mm » strict, tel que Mika l'écrit dans un emploi du temps, ou ses variantes
    /// courantes (« 8h30 », « 8.30 », « 8 »). `nil` si l'heure n'existe pas.
    static func parse(_ text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return nil }
        let separators = CharacterSet(charactersIn: ":h.")
        let parts = cleaned.components(separatedBy: separators).filter { !$0.isEmpty }
        guard let first = parts.first, let hour = Int(first) else { return nil }
        let minute = parts.count > 1 ? Int(parts[1].prefix(2)) : 0
        guard let minute, (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }
}

extension MicaboCalendar {
    /// Les sept jours de la semaine d'une date, du lundi au dimanche.
    static func week(of date: Date, calendar: Calendar = shared) -> [Date] {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let monday = calendar.date(byAdding: .day, value: -offset, to: start) else { return [start] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// Le rang d'un jour dans la semaine de Micabo : 1 pour lundi, 7 pour dimanche.
    static func isoWeekday(of date: Date, calendar: Calendar = shared) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7 + 1
    }

    /// Les jours d'une grille de mois, semaines entières : du lundi avant le 1er au dimanche
    /// après le dernier jour.
    static func monthGrid(of date: Date, calendar: Calendar = shared) -> [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let first = week(of: interval.start, calendar: calendar).first ?? interval.start
        let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        let last = week(of: lastDay, calendar: calendar).last ?? lastDay
        var days: [Date] = []
        var day = first
        while day <= last && days.count < 42 {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    /// « lun. », « Mo. », « пн » : le nom court d'un jour, dans la langue de l'app.
    static func shortWeekday(_ date: Date, locale: UiLocale = .resolved()) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.calendar = shared
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    /// Les noms très courts des jours (« L », « M »…) pour l'en-tête de la grille, du lundi au
    /// dimanche, dans la langue de l'app.
    static func veryShortWeekdays(locale: UiLocale = .resolved()) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else { return ["1", "2", "3", "4", "5", "6", "7"] }
        return Array(symbols[1...]) + [symbols[0]]
    }

    /// Le nom complet d'un jour de la semaine (1 = lundi), pour un sélecteur.
    static func weekdayName(_ isoWeekday: Int, locale: UiLocale = .resolved()) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        let symbols = formatter.standaloneWeekdaySymbols ?? []
        guard symbols.count == 7, (1...7).contains(isoWeekday) else { return "\(isoWeekday)" }
        return symbols[isoWeekday % 7].capitalizedFirstLetter
    }

    /// « novembre » : le mois seul.
    static func monthName(_ date: Date, locale: UiLocale = .resolved()) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.calendar = shared
        formatter.setLocalizedDateFormatFromTemplate("LLLL")
        return formatter.string(from: date).capitalizedFirstLetter
    }

    /// Le numéro du jour, dans les chiffres de la langue.
    static func dayNumber(_ date: Date, locale: UiLocale = .resolved()) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.calendar = shared
        formatter.setLocalizedDateFormatFromTemplate("d")
        return formatter.string(from: date)
    }
}
