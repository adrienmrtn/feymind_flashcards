import Foundation

/// Statistiques dérivées de l'historique de révision.
enum StudyStats {
    /// Nombre de jours consécutifs avec au moins une révision, aujourd'hui inclus ou non.
    static func streak(reviewDates: [Date], calendar: Calendar = .current, now: Date = Date()) -> Int {
        guard !reviewDates.isEmpty else { return 0 }

        let days = Set(reviewDates.map { calendar.startOfDay(for: $0) })
        var cursor = calendar.startOfDay(for: now)

        // Une série reste valide tant que la veille a été travaillée.
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), days.contains(yesterday) else {
                return 0
            }
            cursor = yesterday
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func reviewsToday(reviewDates: [Date], calendar: Calendar = .current, now: Date = Date()) -> Int {
        let today = calendar.startOfDay(for: now)
        return reviewDates.filter { calendar.startOfDay(for: $0) == today }.count
    }

    /// Nombre de cartes travaillées par jour sur les `days` derniers jours, du plus ancien au plus récent.
    static func dailyCounts(
        reviewDates: [Date],
        days: Int,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [Int] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return reviewDates.filter { calendar.startOfDay(for: $0) == day }.count
        }
    }

    static func greeting(for date: Date = Date(), calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: "Bonjour"
        case 12..<18: "Bon après-midi"
        default: "Bonsoir"
        }
    }

    static func formattedDate(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date).capitalizedFirstLetter
    }
}

extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
