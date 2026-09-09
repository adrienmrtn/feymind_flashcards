import Foundation

/// **Où l'on en est devant une épreuve, et sur quoi l'on se plante.**
///
/// Le pendant de `mastery.ts` et `weakness.ts` : l'état de répétition dit ce que l'algorithme
/// croit, le journal des passages dit ce que l'étudiant a réellement répondu, et la solidité
/// d'une carte part du premier corrigé par le second. Une carte « acquise » ratée trois fois
/// de suite ne l'est pas.
///
/// Le site lit le journal en base ; le téléphone a le sien en local, sur chaque carte. Les
/// formules sont les mêmes, à la constante près.
enum ExamReadiness {
    /// Au-delà, une carte de révision est mûre.
    static let matureDays = 21.0
    /// Combien de jours de journal on regarde.
    static let sinceDays = 120
    /// En dessous, on ne sait rien de la carte : trois réponses ne font pas un verdict.
    static let minReviewsForWeakness = 3
    static let weakThreshold = 0.3
    /// Six passages fictifs, ratés une fois sur sept, tirent le taux vers le neutre.
    static let priorReviews = 6.0
    static let priorFailureRate = 0.15
    /// Rechutes à partir desquelles on prévient que la carte est mal formulée.
    static let stubbornLapses = 5

    /// Ce que le journal dit d'une carte : passages, ratés, difficiles.
    struct Difficulty: Equatable {
        var reviews: Int
        var againCount: Int
        var hardCount: Int
    }

    /// Une carte qu'il faut revoir en priorité avant l'épreuve.
    struct WeakCard: Identifiable, Equatable {
        var id: UUID
        var front: String
        var reviews: Int
        var againCount: Int
        var weakness: Double
        var isStubborn: Bool
    }

    /// Le journal d'une carte sur la fenêtre. `nil` en dessous de deux passages, comme la
    /// fonction SQL du site : une carte vue une fois n'a pas de difficulté, elle a une vue.
    static func difficulty(of card: Flashcard, now: Date = Date()) -> Difficulty? {
        let since = now.addingTimeInterval(-Double(sinceDays) * 86_400)
        let logs = (card.logs ?? []).filter { $0.reviewedAt >= since }
        guard logs.count >= 2 else { return nil }
        return Difficulty(
            reviews: logs.count,
            againCount: logs.filter { $0.rating == .again }.count,
            hardCount: logs.filter { $0.rating == .hard }.count
        )
    }

    /// La fragilité d'une carte, entre 0 et 1 : le taux de ratés, tiré vers un a priori neutre
    /// à proportion du peu qu'on sait. Un « difficile » compte pour un demi-raté.
    static func weakness(_ difficulty: Difficulty) -> Double {
        let reviews = Double(max(0, difficulty.reviews))
        guard reviews > 0 else { return 0 }
        let failures = Double(max(0, difficulty.againCount)) + Double(max(0, difficulty.hardCount)) * 0.5
        let prior = priorReviews * priorFailureRate
        return clamp01((failures + prior) / (reviews + priorReviews))
    }

    static func isWeak(_ difficulty: Difficulty) -> Bool {
        difficulty.reviews >= minReviewsForWeakness && weakness(difficulty) >= weakThreshold
    }

    static func isStubborn(lapses: Int, difficulty: Difficulty?) -> Bool {
        if lapses >= stubbornLapses { return true }
        guard let difficulty else { return false }
        return difficulty.reviews >= 6 && difficulty.againCount >= 4
    }

    /// La solidité d'une carte devant une épreuve, entre 0 et 1.
    static func readiness(of card: Flashcard, difficulty: Difficulty?) -> Double {
        let base: Double
        switch card.state {
        case .new: base = 0
        case .learning, .relearning: base = 0.35
        case .review: base = card.intervalDays >= matureDays ? 0.95 : 0.7
        }
        guard let difficulty, difficulty.reviews >= minReviewsForWeakness else { return base }
        return clamp01(base * (1 - weakness(difficulty) * 0.8))
    }

    /// La moyenne des solidités, sur cent. Pas la part de cartes acquises : une carte à
    /// mi-chemin compte pour la moitié, sinon la barre reste à zéro deux semaines puis saute.
    static func masteryPercent(of cards: [Flashcard], now: Date = Date()) -> Int {
        let usable = cards.filter { !$0.isSuspended }
        guard !usable.isEmpty else { return 0 }
        let sum = usable.reduce(0.0) { $0 + readiness(of: $1, difficulty: difficulty(of: $1, now: now)) }
        return Int((sum / Double(usable.count) * 100).rounded())
    }

    /// Les cartes qui résistent, de la pire à la moins pire. On garde celles réellement
    /// passées plusieurs fois : une carte neuve n'est pas fragile, elle est neuve.
    static func weakCards(in cards: [Flashcard], now: Date = Date(), limit: Int = 6) -> [WeakCard] {
        var found: [WeakCard] = []
        for card in cards where !card.isSuspended {
            guard let difficulty = difficulty(of: card, now: now), isWeak(difficulty) else { continue }
            found.append(WeakCard(
                id: card.id,
                front: card.front,
                reviews: difficulty.reviews,
                againCount: difficulty.againCount,
                weakness: weakness(difficulty),
                isStubborn: isStubborn(lapses: card.lapses, difficulty: difficulty)
            ))
        }
        found.sort { left, right in
            if left.weakness != right.weakness { return left.weakness > right.weakness }
            if left.againCount != right.againCount { return left.againCount > right.againCount }
            return left.id.uuidString < right.id.uuidString
        }
        return Array(found.prefix(limit))
    }

    private static func clamp01(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, min(1, value))
    }
}
