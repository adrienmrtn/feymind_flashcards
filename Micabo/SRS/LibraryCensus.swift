import Foundation
import SwiftData

/// Compteurs d'un cours, calculés **une fois** pour tout l'écran.
///
/// Une rangée qui lit `course.cards` ou `course.dueCount` ouvre une requête SwiftData
/// par cours. Dix cours, c'est dix allers-retours SQLite avant le premier cadre, et
/// c'est ça — pas Supabase — qui faisait attendre une demi-seconde chaque ouverture.
struct CourseStats: Equatable, Sendable {
    var cardCount = 0
    var dueCount = 0
    var newCount = 0
    var hasUnsuspended = false
    var nextDue: Date?
}

enum LibraryCensus {
    private static var cache: (key: String, value: [UUID: CourseStats])?

    /// Une seule lecture de la table des cartes, puis des totaux par cours.
    static func load(in context: ModelContext, key: String? = nil, now: Date = Date()) -> [UUID: CourseStats] {
        if let key, let cache, cache.key == key { return cache.value }
        let cards = (try? context.fetch(FetchDescriptor<Flashcard>())) ?? []
        let value = summarize(cards, now: now)
        if let key { cache = (key, value) }
        return value
    }

    /// Après une session ou une synchro : les totaux ne sont plus ceux du cache.
    static func forget() {
        cache = nil
    }

    static func summarize(_ cards: [Flashcard], now: Date = Date()) -> [UUID: CourseStats] {
        var byCourse: [UUID: CourseStats] = [:]
        for card in cards {
            guard let courseID = card.course?.id else { continue }
            var stats = byCourse[courseID] ?? CourseStats()
            stats.cardCount += 1
            if !card.isSuspended {
                stats.hasUnsuspended = true
                if card.isDue(at: now) { stats.dueCount += 1 }
                if card.state == .new { stats.newCount += 1 }
                if stats.nextDue == nil || card.dueDate < stats.nextDue! {
                    stats.nextDue = card.dueDate
                }
            }
            byCourse[courseID] = stats
        }
        return byCourse
    }

    static func totalCards(in census: [UUID: CourseStats]) -> Int {
        census.values.reduce(0) { $0 + $1.cardCount }
    }
}
