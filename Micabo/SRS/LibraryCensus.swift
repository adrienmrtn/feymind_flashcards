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
    /// Une seule lecture de la table des cartes, puis des totaux par cours.
    static func load(in context: ModelContext, now: Date = Date()) -> [UUID: CourseStats] {
        let cards = (try? context.fetch(FetchDescriptor<Flashcard>())) ?? []
        return summarize(cards, now: now)
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
