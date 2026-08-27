import Foundation

/// Statistiques dérivées de l'historique de révision.
///
/// La salutation de l'écran Réviser et la date du jour vivaient ici, et les deux sont
/// parties avec l'en-tête de cet écran : « Bonsoir » n'apprend rien à quelqu'un qui vient
/// d'ouvrir son téléphone, et la date est écrite deux centimètres plus haut par le système.
/// Un écran qui n'a qu'une chose à dire doit la dire en premier — ici, le nombre de cartes
/// à réviser.
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

    /// La plus longue série jamais tenue, aujourd'hui comprise.
    ///
    /// Elle sert de repère à côté de la série en cours : un chiffre seul ne dit pas s'il est
    /// bon. Elle se calcule sur tout l'historique et non sur une fenêtre, parce que c'est un
    /// record — un record qu'on perdrait en changeant de fenêtre n'en serait pas un.
    static func bestStreak(reviewDates: [Date], calendar: Calendar = .current) -> Int {
        guard !reviewDates.isEmpty else { return 0 }

        let days = Set(reviewDates.map { calendar.startOfDay(for: $0) }).sorted()
        var best = 1
        var run = 1

        for (previous, day) in zip(days, days.dropFirst()) {
            if calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
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

    /// Les quatre niveaux affichés sur le Profil, dans l'ordre des barres.
    enum KnowledgeLevel: String, CaseIterable, Identifiable {
        case new
        case learning
        case review
        case mastered

        var id: String { rawValue }

        var label: String {
            switch self {
            case .new: "Nouvelles"
            case .learning: "En cours"
            case .review: "En révision"
            case .mastered: "Parfaitement maîtrisées"
            }
        }
    }

    static func knowledgeLevel(state: CardState, intervalDays: Double) -> KnowledgeLevel {
        if intervalDays >= 21 { return .mastered }
        switch state {
        case .new: return .new
        case .learning, .relearning: return .learning
        case .review: return .review
        }
    }

    static func knowledgeDistribution(cards: [Flashcard]) -> [(level: KnowledgeLevel, count: Int)] {
        let grouped = Dictionary(grouping: cards) {
            knowledgeLevel(state: $0.state, intervalDays: $0.intervalDays)
        }
        return KnowledgeLevel.allCases.map { level in
            (level, grouped[level]?.count ?? 0)
        }
    }

    static func mostReviewed(from logs: [ReviewLog], limit: Int = 5) -> [(front: String, passes: Int)] {
        var counts: [UUID: (front: String, passes: Int)] = [:]
        for log in logs {
            guard let card = log.card else { continue }
            var entry = counts[card.id] ?? (front: card.front, passes: 0)
            entry.passes += 1
            counts[card.id] = entry
        }
        return counts.values
            .sorted { $0.passes == $1.passes ? $0.front < $1.front : $0.passes > $1.passes }
            .prefix(limit)
            .map { $0 }
    }

}

extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
