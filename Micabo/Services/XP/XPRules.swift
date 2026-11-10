import Foundation

/// **Le contrat de l'XP, côté iPhone** (`docs/refonte-knowunity.md` § 2).
///
/// Le jumeau de `web/packages/core/src/xp.ts` : `xp-parity.test.ts` relit ce fichier et tombe si
/// un chiffre diverge. Les nombres vivent ici et nulle part ailleurs ; le calcul est dans
/// `XPMath`, l'état dans `XPStore`.
enum XPRules {
    static let correctAnswer = 10
    static let wrongAnswer = 2
    static let cardReviewed = 3
    static let circleCompleted = 25
    static let lessonCreated = 30
    static let mockExamFinished = 60
    static let mikaAnswer = 5
    static let exerciseSolved = 15
    static let focusSession = 40
    static let dailyGoal = 50
    static let dailyCap = 5000
    static let focusMinutes = 25
    static let leagues: [XPLeague] = [
        XPLeague(id: "bronze", floor: 0),
        XPLeague(id: "silver", floor: 200),
        XPLeague(id: "gold", floor: 500),
        XPLeague(id: "sapphire", floor: 1000),
        XPLeague(id: "diamond", floor: 2000),
    ]
}

/// Une ligue : son identifiant (celui du serveur et du site) et l'XP de la semaine qui y fait
/// entrer.
struct XPLeague: Equatable, Hashable, Identifiable {
    let id: String
    let floor: Int
}
