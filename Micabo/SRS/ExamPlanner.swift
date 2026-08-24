import Foundation

/// Une carte vue par le planificateur d'examen.
///
/// Le planificateur ne connaît pas SwiftData : il prend des valeurs et rend des jours. Ça
/// rend l'algorithme vérifiable sans base de données, ce qui est le minimum pour du code
/// qui déplace les échéances de tout un jeu de cartes.
struct ExamCard: Equatable, Identifiable {
    var id: UUID
    var state: CardState
    var intervalDays: Double
    var dueDate: Date

    init(id: UUID, state: CardState, intervalDays: Double, dueDate: Date) {
        self.id = id
        self.state = state
        self.intervalDays = intervalDays
        self.dueDate = dueDate
    }

    init(card: Flashcard) {
        self.init(
            id: card.id,
            state: card.state,
            intervalDays: card.intervalDays,
            dueDate: card.dueDate
        )
    }

    /// Une carte « mûre » au sens d'Anki : son intervalle a dépassé trois semaines, donc
    /// elle est acquise et demande un passage de moins.
    var isMature: Bool {
        intervalDays >= 21
    }
}

/// Ce que la replanification donnera, annoncé **avant** de l'appliquer.
///
/// C'est le contrat de l'écran de confirmation : on ne demande pas à l'utilisateur
/// d'accepter une réorganisation de son planning sans lui dire ce qu'elle lui coûtera par
/// jour, et quel sera le pire jour.
struct ExamProjection: Equatable {
    var cardCount: Int
    /// Jours entiers d'ici l'examen. 0 signifie « aujourd'hui ».
    var daysRemaining: Int
    /// Nombre total de passages de cartes prévus.
    var totalReviews: Int
    /// Charge par jour, indexée par décalage depuis aujourd'hui.
    var load: [Int]

    var averageDailyLoad: Int {
        guard !load.isEmpty else { return 0 }
        return Int((Double(totalReviews) / Double(load.count)).rounded())
    }

    /// Décalage du jour le plus chargé, et sa charge.
    var busiest: (offset: Int, count: Int)? {
        guard let index = load.indices.max(by: { load[$0] < load[$1] }), load[index] > 0 else { return nil }
        return (index, load[index])
    }

    var isEmpty: Bool {
        cardCount == 0 || totalReviews == 0
    }

    static let empty = ExamProjection(cardCount: 0, daysRemaining: 0, totalReviews: 0, load: [])
}

/// Le plan complet : à quels jours chaque carte repassera.
struct ExamPlan: Equatable {
    /// Le jour de l'examen, au début de la journée.
    var examDay: Date
    /// Le premier jour de révision possible, c'est-à-dire aujourd'hui.
    var firstDay: Date
    /// Le dernier jour de révision, c'est-à-dire la veille de l'examen.
    var lastReviewDay: Date
    /// Nombre de journées utilisables, veille comprise. Toujours au moins 1.
    var windowDays: Int
    /// Par carte, ses jours de passage en décalage depuis `firstDay`.
    var days: [UUID: [Int]]
    var projection: ExamProjection

    /// La première échéance d'une carte, celle qu'on écrit vraiment. Les suivantes sont
    /// tenues par le plafond d'intervalle du mode examen, pas par une écriture d'avance.
    func firstOffset(for card: UUID) -> Int? {
        days[card]?.first
    }

    func date(atOffset offset: Int, calendar: Calendar = MicaboCalendar.shared) -> Date {
        calendar.date(byAdding: .day, value: offset, to: firstDay) ?? firstDay
    }

    var isEmpty: Bool {
        days.isEmpty
    }
}

/// Répartit les révisions d'un jeu de cartes d'ici un examen.
///
/// **Le problème.** La répétition espacée optimise la mémoire à long terme : elle repousse
/// les cartes de plus en plus loin, et se fiche de la date du contrôle. Une carte revue
/// hier avec un intervalle de vingt jours retombera trois semaines après l'examen, au pire
/// moment possible.
///
/// **Le principe.** On garde la répétition espacée, mais on lui donne une date butoir. Deux
/// mécanismes s'en chargent, et ils sont complémentaires :
///
/// 1. **La replanification initiale**, ici : on redistribue les prochaines échéances sur
///    les jours qui restent, de façon que la charge soit à peu près plate et que le dernier
///    passage de chaque carte tombe dans les tout derniers jours.
/// 2. **Le plafond d'intervalle** (`ExamDeadlines`) : tant que l'examen approche, aucune
///    carte concernée ne se replanifie au delà du jour J. Sans lui, la première note
///    donnée renverrait la carte à trois semaines et le plan serait défait au premier
///    passage.
enum ExamPlanner {
    /// Sur combien de jours de fin les derniers passages s'étalent.
    ///
    /// Tout mettre sur la veille garantirait le pic de rétention, et une session de trois
    /// cents cartes que personne ne fait. Trois jours laissent la rétention très haute le
    /// jour J tout en gardant des sessions faisables.
    static let closingDays = 3

    static func plan(
        cards: [ExamCard],
        examDate: Date,
        now: Date = Date(),
        intensity: ExamIntensity = .standard,
        calendar: Calendar = MicaboCalendar.shared
    ) -> ExamPlan {
        let today = calendar.startOfDay(for: now)
        let examDay = calendar.startOfDay(for: examDate)
        let daysRemaining = calendar.dateComponents([.day], from: today, to: examDay).day ?? 0

        // On révise jusqu'à la veille : le jour de l'examen ne sert plus à apprendre. Un
        // examen aujourd'hui ou demain ne laisse qu'une journée, celle-ci.
        let window = max(1, daysRemaining)
        let lastReviewDay = calendar.date(byAdding: .day, value: window - 1, to: today) ?? today

        var days: [UUID: [Int]] = [:]
        var load = Array(repeating: 0, count: window)
        var total = 0

        for (index, card) in ordered(cards, now: now).enumerated() {
            let offsets = ladder(
                passes: passes(for: card, intensity: intensity),
                window: window,
                phase: index
            )
            days[card.id] = offsets
            total += offsets.count
            for offset in offsets where load.indices.contains(offset) {
                load[offset] += 1
            }
        }

        return ExamPlan(
            examDay: examDay,
            firstDay: today,
            lastReviewDay: lastReviewDay,
            windowDays: window,
            days: days,
            projection: ExamProjection(
                cardCount: cards.count,
                daysRemaining: daysRemaining,
                totalReviews: total,
                load: load
            )
        )
    }

    /// L'ordre décide du décalage de chaque carte, donc du lissage de la charge. Les cartes
    /// en retard passent devant, puis les neuves, puis les moins solides : si le temps
    /// manque, c'est ce qui doit être vu d'abord.
    static func ordered(_ cards: [ExamCard], now: Date) -> [ExamCard] {
        cards.sorted { first, second in
            let firstDue = first.dueDate <= now
            let secondDue = second.dueDate <= now
            if firstDue != secondDue { return firstDue }
            if (first.state == .new) != (second.state == .new) { return first.state == .new }
            if first.intervalDays != second.intervalDays { return first.intervalDays < second.intervalDays }
            return first.id.uuidString < second.id.uuidString
        }
    }

    /// Combien de fois cette carte doit repasser avant l'examen.
    static func passes(for card: ExamCard, intensity: ExamIntensity) -> Int {
        var count = intensity.basePasses
        // Une carte jamais vue doit d'abord être apprise, pas seulement rafraîchie.
        if card.state == .new { count += 1 }
        // Une carte acquise depuis trois semaines n'a pas besoin d'un passage de plus.
        if card.isMature { count -= 1 }
        return max(1, count)
    }

    /// Les jours de passage d'une carte, en décalage depuis aujourd'hui.
    ///
    /// Trois règles, dans cet ordre de priorité. Le **dernier passage** tombe dans les
    /// derniers jours, décalé d'une carte à l'autre pour ne pas empiler tout le jeu sur la
    /// veille. Le **premier** est échelonné lui aussi, pour que le premier jour ne prenne
    /// pas tout. Entre les deux, les passages sont **régulièrement espacés**, ce qui donne
    /// une charge quotidienne à peu près constante, la seule qu'on puisse tenir.
    static func ladder(passes: Int, window: Int, phase: Int) -> [Int] {
        guard window > 0 else { return [] }

        let closing = max(1, min(window, closingDays))
        let last = max(0, (window - 1) - (phase % closing))

        // On ne peut pas voir une carte deux fois le même jour : le nombre de passages est
        // borné par le nombre de jours disponibles avant son dernier.
        let wanted = max(1, min(passes, last + 1))
        guard wanted > 1 else { return [last] }

        let span = max(1, window - wanted + 1)
        let first = min(last, phase % span)
        guard last > first else { return [last] }

        var offsets: [Int] = []
        for step in 0..<wanted {
            let position = Double(first) + Double(last - first) * Double(step) / Double(wanted - 1)
            let day = Int(position.rounded())
            if offsets.last != day { offsets.append(day) }
        }
        if offsets.last != last { offsets.append(last) }
        return offsets
    }
}
