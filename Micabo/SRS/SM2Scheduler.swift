import Foundation

/// Instantané de l'état de programmation d'une carte, indépendant de SwiftData.
struct SM2CardSnapshot: Equatable {
    var state: CardState
    var intervalDays: Double
    var easeFactor: Double
    var repetitions: Int
    var lapses: Int
    var stepIndex: Int
    var dueDate: Date?

    init(
        state: CardState = .new,
        intervalDays: Double = 0,
        easeFactor: Double = SM2Scheduler.Configuration.default.startingEase,
        repetitions: Int = 0,
        lapses: Int = 0,
        stepIndex: Int = 0,
        dueDate: Date? = nil
    ) {
        self.state = state
        self.intervalDays = intervalDays
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.lapses = lapses
        self.stepIndex = stepIndex
        self.dueDate = dueDate
    }

    init(card: Flashcard) {
        self.init(
            state: card.state,
            intervalDays: card.intervalDays,
            easeFactor: card.easeFactor,
            repetitions: card.repetitions,
            lapses: card.lapses,
            stepIndex: card.stepIndex,
            dueDate: card.dueDate
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
            // Anki SM-2 legacy : un seul palier de dix minutes après une rechute.
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

    /// Les quatre boutons d'Anki sur une carte neuve : **1 min, 6 min, 10 min, 4 j.**
    ///
    /// Again revient au premier palier. Hard, au premier palier, est la moyenne des
    /// deux premiers ; ensuite il rejoue le palier courant. Good avance d'un palier
    /// et ne diplôme qu'après le dernier. Easy diplôme tout de suite.
    private static func scheduleLearning(
        snapshot: SM2CardSnapshot,
        rating: ReviewRating,
        now: Date,
        config: Configuration
    ) -> SM2Outcome {
        let steps = config.learningStepsMinutes.isEmpty ? [1.0, 10.0] : config.learningStepsMinutes
        let step = clampedStep(snapshot.stepIndex, steps: steps)

        switch rating {
        case .easy:
            return graduate(
                snapshot: snapshot,
                rating: rating,
                intervalDays: config.easyIntervalDays,
                now: now,
                config: config
            )
        case .good where step >= steps.count - 1:
            return graduate(
                snapshot: snapshot,
                rating: rating,
                intervalDays: config.graduatingIntervalDays,
                now: now,
                config: config
            )
        case .good:
            let next = step + 1
            return stayInSteps(
                snapshot: snapshot,
                rating: rating,
                state: .learning,
                stepIndex: next,
                minutes: steps[next],
                now: now
            )
        case .again:
            return stayInSteps(
                snapshot: snapshot,
                rating: rating,
                state: .learning,
                stepIndex: 0,
                minutes: steps[0],
                now: now
            )
        case .hard:
            return stayInSteps(
                snapshot: snapshot,
                rating: rating,
                state: .learning,
                stepIndex: step,
                minutes: hardStepMinutes(steps, stepIndex: step),
                now: now
            )
        }
    }

    private static func graduate(
        snapshot: SM2CardSnapshot,
        rating: ReviewRating,
        intervalDays: Double,
        now: Date,
        config: Configuration
    ) -> SM2Outcome {
        reviewOutcome(
            snapshot: snapshot,
            rating: rating,
            intervalDays: clampInterval(intervalDays, config: config),
            easeFactor: snapshot.easeFactor,
            now: now,
            config: config
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
            let steps = config.relearningStepsMinutes.isEmpty ? [10.0] : config.relearningStepsMinutes
            let postLapse = constrainedIvl(
                max(config.minimumIntervalDays, previous * config.lapseIntervalMultiplier),
                previous: 0,
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

        let late = daysLate(now: now, due: snapshot.dueDate)
        let ease = snapshot.easeFactor
        let hardIvl = constrainedIvl(previous * config.hardMultiplier, previous: previous, config: config)
        let goodIvl = constrainedIvl((previous + late / 2) * ease, previous: hardIvl, config: config)
        let easyIvl = constrainedIvl((previous + late) * ease * config.easyBonus, previous: goodIvl, config: config)

        var nextEase = ease
        var interval = goodIvl
        switch rating {
        case .hard:
            nextEase = clampEase(ease - 0.15, config: config)
            interval = hardIvl
        case .easy:
            nextEase = clampEase(ease + 0.15, config: config)
            interval = easyIvl
        case .good, .again:
            break
        }

        return reviewOutcome(
            snapshot: snapshot,
            rating: rating,
            intervalDays: interval,
            easeFactor: nextEase,
            now: now,
            config: config
        )
    }

    /// Échéance de révision : Anki stocke l'intervalle déjà dispersé.
    private static func reviewOutcome(
        snapshot: SM2CardSnapshot,
        rating: ReviewRating,
        intervalDays: Double,
        easeFactor: Double,
        now: Date,
        config: Configuration
    ) -> SM2Outcome {
        let shown = fuzzed(intervalDays, config: config)
        return SM2Outcome(
            rating: rating,
            state: .review,
            dueDate: now.addingTimeInterval(shown * day),
            intervalDays: shown,
            easeFactor: clampEase(easeFactor, config: config),
            repetitions: snapshot.repetitions + 1,
            lapses: snapshot.lapses,
            stepIndex: 0
        )
    }

    // MARK: - Réapprentissage

    /// Un seul palier de dix minutes, comme Anki. Good diplôme. Easy ajoute un jour.
    private static func scheduleRelearning(
        snapshot: SM2CardSnapshot,
        rating: ReviewRating,
        now: Date,
        config: Configuration
    ) -> SM2Outcome {
        let steps = config.relearningStepsMinutes.isEmpty ? [10.0] : config.relearningStepsMinutes
        let step = clampedStep(snapshot.stepIndex, steps: steps)
        let postLapse = max(snapshot.intervalDays, config.minimumIntervalDays)

        switch rating {
        case .easy:
            return graduate(
                snapshot: snapshot,
                rating: rating,
                intervalDays: postLapse + 1,
                now: now,
                config: config
            )
        case .good where step >= steps.count - 1:
            return graduate(
                snapshot: snapshot,
                rating: rating,
                intervalDays: postLapse,
                now: now,
                config: config
            )
        case .good:
            let next = step + 1
            return stayInSteps(
                snapshot: snapshot,
                rating: rating,
                state: .relearning,
                stepIndex: next,
                minutes: steps[next],
                now: now
            )
        case .again:
            return stayInSteps(
                snapshot: snapshot,
                rating: rating,
                state: .relearning,
                stepIndex: 0,
                minutes: steps[0],
                now: now
            )
        case .hard:
            return stayInSteps(
                snapshot: snapshot,
                rating: rating,
                state: .relearning,
                stepIndex: step,
                minutes: hardStepMinutes(steps, stepIndex: step),
                now: now
            )
        }
    }

    private static func stayInSteps(
        snapshot: SM2CardSnapshot,
        rating: ReviewRating,
        state: CardState,
        stepIndex: Int,
        minutes: Double,
        now: Date
    ) -> SM2Outcome {
        SM2Outcome(
            rating: rating,
            state: state,
            dueDate: now.addingTimeInterval(minutes * minute),
            intervalDays: snapshot.intervalDays,
            easeFactor: snapshot.easeFactor,
            repetitions: snapshot.repetitions,
            lapses: snapshot.lapses,
            stepIndex: stepIndex
        )
    }

    // MARK: - Utilitaires

    static func isLeech(lapses: Int, config: Configuration = .default) -> Bool {
        lapses >= config.leechThreshold
    }

    private static func clampEase(_ ease: Double, config: Configuration) -> Double {
        max(config.minimumEase, ease)
    }

    private static func clampInterval(_ interval: Double, config: Configuration) -> Double {
        min(config.maximumIntervalDays, max(config.minimumIntervalDays, interval))
    }

    /// Intervalle de révision d'Anki : entier, toujours plus grand que le précédent.
    private static func constrainedIvl(_ raw: Double, previous: Double, config: Configuration) -> Double {
        let ivl = (raw * config.intervalModifier).rounded(.towardZero)
        return clampInterval(max(ivl, previous + 1, 1), config: config)
    }

    /// Hard en apprentissage, tel qu'Anki le documente.
    static func hardStepMinutes(_ steps: [Double], stepIndex: Int) -> Double {
        let step = clampedStep(stepIndex, steps: steps)
        if steps.count <= 1 {
            let only = steps.first ?? 10
            return min(only * 1.5, only + 1_440)
        }
        if step <= 0 { return (steps[0] + steps[1]) / 2 }
        return steps[step]
    }

    private static func clampedStep(_ index: Int, steps: [Double]) -> Int {
        guard !steps.isEmpty else { return 0 }
        return min(max(0, index), steps.count - 1)
    }

    private static func daysLate(now: Date, due: Date?) -> Double {
        guard let due else { return 0 }
        return max(0, (now.timeIntervalSince(due) / day).rounded(.towardZero))
    }

    /// Dispersion d'Anki (`_fuzzIvlRange`) : entier, et c'est cet entier qui est stocké.
    private static func fuzzIvlRange(_ intervalDays: Double) -> (min: Int, max: Int) {
        let ivl = Int(intervalDays.rounded(.towardZero))
        if ivl < 2 { return (1, 1) }
        if ivl == 2 { return (2, 3) }
        var fuzz: Int
        if ivl < 7 { fuzz = Int((Double(ivl) * 0.25).rounded(.towardZero)) }
        else if ivl < 30 { fuzz = max(2, Int((Double(ivl) * 0.15).rounded(.towardZero))) }
        else { fuzz = max(4, Int((Double(ivl) * 0.05).rounded(.towardZero))) }
        fuzz = max(fuzz, 1)
        return (ivl - fuzz, ivl + fuzz)
    }

    private static func fuzzed(_ intervalDays: Double, config: Configuration) -> Double {
        guard config.fuzzEnabled else { return intervalDays }
        let range = fuzzIvlRange(intervalDays)
        return clampInterval(Double(Int.random(in: range.min...range.max)), config: config)
    }

    // MARK: - Aperçu des boutons

    /// Libellés sous les boutons de maîtrise. Sur une neuve : 1 min / 6 min / 10 min / 4 j.
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
