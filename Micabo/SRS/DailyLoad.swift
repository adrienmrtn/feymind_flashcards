import Foundation

/// Le lien entre le temps que l'utilisateur accepte de donner chaque jour et ce que
/// l'app lui sert. Sans ce lien, le curseur de l'onboarding ne serait qu'un décor.
///
/// Une carte neuve ne coûte pas un seul passage : elle revient
/// `LearningProjection.repetitionsPerCard` fois avant d'être acquise. Le plafond de
/// nouvelles cartes par jour est donc le nombre de cartes qu'on peut *introduire*
/// sans faire déborder les sessions des jours suivants.
enum DailyLoad {
    /// Paliers du curseur : 5 minutes jusqu'à une demi-heure, puis 15 minutes jusqu'à 2 h.
    static let steps: [Int] = [5, 10, 15, 20, 25, 30, 45, 60, 75, 90, 105, 120]

    static var minimumMinutes: Int { steps.first ?? 5 }
    static var maximumMinutes: Int { steps.last ?? 120 }

    /// Plafond de cartes neuves par jour pour que la charge tienne dans le temps choisi.
    static func newCardsPerDay(dailyMinutes: Int) -> Int {
        let cardsSeen = Double(dailyMinutes) * LearningProjection.cardsPerMinute
        let introduced = cardsSeen / LearningProjection.repetitionsPerCard
        return max(2, Int(introduced.rounded()))
    }

    /// Palier le plus proche d'une valeur quelconque : les réponses enregistrées avant
    /// l'ajout des paliers longs doivent retomber sur un cran existant.
    static func nearestStep(to minutes: Int) -> Int {
        steps.min { abs($0 - minutes) < abs($1 - minutes) } ?? minimumMinutes
    }

    /// Position du palier dans le curseur, qui glisse sur les index et non sur les minutes.
    static func stepIndex(for minutes: Int) -> Int {
        steps.firstIndex(of: nearestStep(to: minutes)) ?? 0
    }

    static func minutes(atStepIndex index: Int) -> Int {
        guard steps.indices.contains(index) else { return minimumMinutes }
        return steps[index]
    }

    /// « 15 min », « 1 h », « 1 h 30 » : au-delà de l'heure on ne parle plus en minutes.
    static func label(forMinutes minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest)"
    }

    /// Rythme annoncé sous le curseur.
    static func pace(forDailyMinutes minutes: Int) -> Pace {
        switch minutes {
        case ..<15: .gentle
        case 15..<30: .cruising
        case 30..<60: .solid
        default: .intense
        }
    }

    enum Pace {
        case gentle
        case cruising
        case solid
        case intense

        var label: String {
            switch self {
            case .gentle: "le rythme tranquille"
            case .cruising: "le rythme de croisière"
            case .solid: "le rythme soutenu"
            case .intense: "le rythme intensif"
            }
        }

        var systemImage: String {
            switch self {
            case .gentle: "leaf"
            case .cruising: "figure.walk"
            case .solid: "flame"
            case .intense: "bolt.fill"
            }
        }
    }
}

/// Projection annuelle affichée après le choix du rythme quotidien.
/// Les constantes sont volontairement affichées à l'écran : rien n'est sorti d'un chapeau.
enum LearningProjection {
    /// Cartes parcourues en une minute de révision.
    static let cardsPerMinute = 4.0
    /// Passages nécessaires, en moyenne, pour ancrer durablement une carte.
    static let repetitionsPerCard = 8.0
    static let daysPerYear = 365.0

    static func cardsPerYear(dailyMinutes: Int) -> Int {
        let raw = Double(dailyMinutes) * daysPerYear * cardsPerMinute / repetitionsPerCard
        return Int((raw / 10).rounded()) * 10
    }
}
