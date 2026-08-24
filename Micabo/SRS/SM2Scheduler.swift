import Foundation

/// Instantané de l'état de programmation d'une carte, indépendant de SwiftData.
struct SM2CardSnapshot: Equatable {
    var state: CardState
    var intervalDays: Double
    var easeFactor: Double
    var repetitions: Int
    var lapses: Int
    var stepIndex: Int

    init(
        state: CardState = .new,
        intervalDays: Double = 0,
        easeFactor: Double = SM2Scheduler.Configuration.default.startingEase,
        repetitions: Int = 0,
        lapses: Int = 0,
        stepIndex: Int = 0
    ) {
        self.state = state
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.lapses = lapses
        self.stepIndex = stepIndex
    }

    init(card: Flashcard) {
        self.init(
            state: card.state,
            intervalDays: card.intervalDays,
            easeFactor: card.easeFactor,
            repetitions: card.repetitions,
            lapses: card.lapses,
            stepIndex: card.stepIndex
        )
    }
}

/// Résultat d'une réponse : nouvel état, échéance et intervalle.
struct SM2Outcome: Equatable {
    var rating: ReviewRating
    var state: CardState
    var dueDate: Date
    /// Intervalle en jours. Reste à la valeur « post-rechute » pendant le réapprentissage.
    var intervalDays: Double
    var easeFactor: Double
    var repetitions: Int
    var lapses: Int
    var stepIndex: Int

    /// Délai réel avant la prochaine présentation de la carte.
    func delay(from now: Date) -> TimeInterval {
        dueDate.timeIntervalSince(now)
    }
}

/// Planificateur SM-2 aligné sur les réglages par défaut d'Anki.
enum SM2Scheduler {
    struct Configuration: Equatable {
        var learningStepsMinutes: [Double]
        var relearningStepsMinutes: [Double]
        var graduatingIntervalDays: Double
        var easyIntervalDays: Double
        var startingEase: Double
        var easyBonus: Double
        var hardMultiplier: Double
        var intervalModifier: Double
        /// Pourcentage de l'ancien intervalle conservé après une rechute (0 % chez Anki).
        var lapseIntervalMultiplier: Double
        var minimumIntervalDays: Double
        var maximumIntervalDays: Double
        var minimumEase: Double
        var leechThreshold: Int
        /// Dispersion aléatoire des échéances, désactivée dans les tests.
        var fuzzEnabled: Bool

        static let `default` = Configuration(
            learningStepsMinutes: [1, 10],
            relearningStepsMinutes: [10],
            graduatingIntervalDays: 1,
            easyIntervalDays: 4,
            startingEase: 2.5,
            easyBonus: 1.3,
            hardMultiplier: 1.2,
            intervalModifier: 1.0,
            lapseIntervalMultiplier: 0,
            minimumIntervalDays: 1,
            maximumIntervalDays: 36_500,
            minimumEase: 1.3,
            leechThreshold: 8,
            fuzzEnabled: true
        )

        /// Variante déterministe, utilisée pour les aperçus d'intervalle et les tests.
        static let deterministic: Configuration = {
            var config = Configuration.default
            config.fuzzEnabled = false
            return config
        }()
    }

    static let minute: TimeInterval = 60
    static let day: TimeInterval = 86_400

    // MARK: - Calcul principal

    static func schedule(
        snapshot: SM2CardSnapshot,
        rating: ReviewRating,
        now: Date = Date(),
        config: Configuration = .default
    ) -> SM2Outcome {
        switch snapshot.state {
        case .new, .learning:
            return scheduleLearning(snapshot: snapshot, rating: rating, now: now, config: config)
        case .review:
            return scheduleReview(snapshot: snapshot, rating: rating, now: now, config: config)
        case .relearning:
            return scheduleRelearning(snapshot: snapshot, rating: rating, now: now, config: config)
        }
    }

    // MARK: - Apprentissage

    private static func scheduleLearning(
        snapshot: SM2CardSnapshot,
        rating: ReviewRating,
        now: Date,
        config: Configuration
    ) -> SM2Outcome {
        let steps = config.learningStepsMinutes.isEmpty ? [10] : config.learningStepsMinutes
        var result = SM2Outcome(
            rating: rating,
            state: .learning,
            dueDate: now,
            intervalDays: snapshot.intervalDays,
            easeFactor: snapshot.easeFactor,
            repetitions: snapshot.repetitions,
            lapses: snapshot.lapses,
            stepIndex: snapshot.stepIndex
        )

        switch rating {
        case .again:
            result.stepIndex = 0
            result.dueDate = now.addingTimeInterval(steps[0] * minute)

        case .hard:
            let index = min(snapshot.stepIndex, steps.count - 1)
            // Un seul palier : Anki attend 1,5x ce palier plutôt que de le rejouer à l'identique.
            let delay = steps.count == 1 ? steps[index] * 1.5 : steps[index]
            result.stepIndex = index
            result.dueDate = now.addingTimeInterval(delay * minute)

        case .good:
            let nextIndex = snapshot.stepIndex + 1
            if nextIndex >= steps.count {
                return graduate(
                    snapshot: snapshot,
                    rating: rating,
                    intervalDays: config.graduatingIntervalDays,
                    now: now,
                    config: config
                )
            }
            result.stepIndex = nextIndex
            result.dueDate = now.addingTimeInterval(steps[nextIndex] * minute)

        case .easy:
            return graduate(
                snapshot: snapshot,
                rating: rating,
                intervalDays: config.easyIntervalDays,
                now: now,
                config: config
            )
        }

        return result
    }

    private static func graduate(
        snapshot: SM2CardSnapshot,
        rating: ReviewRating,
        intervalDays: Double,
        now: Date,
        config: Configuration
    ) -> SM2Outcome {
        let interval = clampInterval(intervalDays, config: config)
        return SM2Outcome(
            rating: rating,
            state: .review,
            dueDate: now.addingTimeInterval(fuzzed(interval, config: config) * day),
            intervalDays: interval,
            easeFactor: clampEase(snapshot.easeFactor, config: config),
            repetitions: snapshot.repetitions + 1,
            lapses: snapshot.lapses,
            stepIndex: 0
        )
    }

    // MARK: - Révision

    private static func scheduleReview(
        snapshot: SM2CardSnapshot,
        rating: ReviewRating,
        now: Date,
        config: Configuration
    ) -> SM2Outcome {
        let previous = max(snapshot.intervalDays, config.minimumIntervalDays)

        if rating == .again {
            let steps = config.relearningStepsMinutes.isEmpty ? [10] : config.relearningStepsMinutes
            let postLapse = clampInterval(
                max(config.minimumIntervalDays, previous * config.lapseIntervalMultiplier),
                config: config
            )
            return SM2Outcome(
                rating: rating,
                state: .relearning,
                dueDate: now.addingTimeInterval(steps[0] * minute),
                intervalDays: postLapse,
                easeFactor: clampEase(snapshot.easeFactor - 0.20, config: config),
                repetitions: snapshot.repetitions,
                lapses: snapshot.lapses + 1,
                stepIndex: 0
            )
        }

        var ease = snapshot.easeFactor
        var interval: Double

        switch rating {
        case .hard:
            ease = clampEase(ease - 0.15, config: config)
            interval = previous * config.hardMultiplier * config.intervalModifier
        case .good:
            ease = clampEase(ease, config: config)
            interval = previous * ease * config.intervalModifier
        case .easy:
            ease = clampEase(ease + 0.15, config: config)
            interval = previous * ease * config.easyBonus * config.intervalModifier
        case .again:
            interval = previous
        }

        // Anki garantit qu'une réponse positive fait toujours grandir l'intervalle d'au moins un jour.
        interval = clampInterval(max(interval, previous + 1), config: config)

        return SM2Outcome(
            rating: rating,
            state: .review,
            dueDate: now.addingTimeInterval(fuzzed(interval, config: config) * day),
            intervalDays: interval,
            easeFactor: ease,
            repetitions: snapshot.repetitions + 1,
            lapses: snapshot.lapses,
            stepIndex: 0
        )
    }

    // MARK: - Réapprentissage

    private static func scheduleRelearning(
        snapshot: SM2CardSnapshot,
        rating: ReviewRating,
        now: Date,
        config: Configuration
    ) -> SM2Outcome {
        let steps = config.relearningStepsMinutes.isEmpty ? [10] : config.relearningStepsMinutes
        let postLapse = max(snapshot.intervalDays, config.minimumIntervalDays)

        var result = SM2Outcome(
            rating: rating,
            state: .relearning,
            dueDate: now,
            intervalDays: postLapse,
            easeFactor: clampEase(snapshot.easeFactor, config: config),
            repetitions: snapshot.repetitions,
            lapses: snapshot.lapses,
            stepIndex: snapshot.stepIndex
        )

        switch rating {
        case .again:
            result.stepIndex = 0
            result.dueDate = now.addingTimeInterval(steps[0] * minute)

        case .hard:
            let index = min(snapshot.stepIndex, steps.count - 1)
            let delay = steps.count == 1 ? steps[index] * 1.5 : steps[index]
            result.stepIndex = index
            result.dueDate = now.addingTimeInterval(delay * minute)

        case .good:
            let nextIndex = snapshot.stepIndex + 1
            if nextIndex >= steps.count {
                let interval = clampInterval(postLapse, config: config)
                result.state = .review
                result.stepIndex = 0
                result.intervalDays = interval
                result.repetitions = snapshot.repetitions + 1
                result.dueDate = now.addingTimeInterval(fuzzed(interval, config: config) * day)
            } else {
                result.stepIndex = nextIndex
                result.dueDate = now.addingTimeInterval(steps[nextIndex] * minute)
            }

        case .easy:
            let interval = clampInterval(postLapse + 1, config: config)
            result.state = .review
            result.stepIndex = 0
            result.intervalDays = interval
            result.repetitions = snapshot.repetitions + 1
            result.dueDate = now.addingTimeInterval(fuzzed(interval, config: config) * day)
        }

        return result
    }

    // MARK: - Utilitaires

    static func isLeech(lapses: Int, config: Configuration = .default) -> Bool {
        lapses >= config.leechThreshold
    }

    private static func clampEase(_ ease: Double, config: Configuration) -> Double {
        max(config.minimumEase, ease)
    }

    private static func clampInterval(_ interval: Double, config: Configuration) -> Double {
        let rounded = (interval * 100).rounded() / 100
        return min(config.maximumIntervalDays, max(config.minimumIntervalDays, rounded))
    }

    /// Dispersion d'Anki : évite que des paquets entiers retombent le même jour.
    private static func fuzzed(_ intervalDays: Double, config: Configuration) -> Double {
        guard config.fuzzEnabled, intervalDays >= 2.5 else { return intervalDays }
        let spread: Double
        switch intervalDays {
        case ..<7: spread = max(1, intervalDays * 0.15)
        case ..<30: spread = max(2, intervalDays * 0.10)
        default: spread = max(4, intervalDays * 0.05)
        }
        let offset = Double.random(in: -spread...spread)
        return max(config.minimumIntervalDays, intervalDays + offset)
    }

    // MARK: - Aperçu des boutons

    /// Libellés « 1 min / 10 min / 1 j / 4 j » affichés sous les boutons de maîtrise.
    ///
    /// La date butoir d'un examen, quand il y en a une, est appliquée avant l'affichage : un
    /// bouton qui annonce trois semaines alors que la carte reviendra dans quatre jours ment
    /// à l'utilisateur, et c'est le seul endroit de l'app où il lit un intervalle.
    static func previewLabels(
        for snapshot: SM2CardSnapshot,
        now: Date = Date(),
        config: Configuration = .deterministic,
        deadline: Date? = nil
    ) -> [ReviewRating: String] {
        var labels: [ReviewRating: String] = [:]
        for rating in ReviewRating.allCases {
            let outcome = schedule(snapshot: snapshot, rating: rating, now: now, config: config)
                .clamped(to: deadline, now: now)
            labels[rating] = format(delay: outcome.delay(from: now))
        }
        return labels
    }

    static func format(delay: TimeInterval) -> String {
        let minutes = delay / minute
        if minutes < 1 { return "< 1 min" }
        if minutes < 60 { return "\(Int(minutes.rounded())) min" }

        let hours = minutes / 60
        if hours < 24 { return "\(Int(hours.rounded())) h" }

        let days = hours / 24
        if days < 31 { return "\(Int(days.rounded())) j" }

        let months = days / 30.4
        if months < 12 { return "\(Int(months.rounded())) mois" }

        let years = days / 365
        let value = (years * 10).rounded() / 10
        return value == value.rounded() ? "\(Int(value)) an\(value >= 2 ? "s" : "")" : "\(value) an\(value >= 2 ? "s" : "")"
    }
}
