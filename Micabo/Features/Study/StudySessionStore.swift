import Foundation

/// Ce qu'on garde d'une session interrompue : de quoi la reprendre à la carte près.
///
/// On n'enregistre que des identifiants de cartes : les cartes elles-mêmes vivent dans
/// SwiftData, et leur état de répétition espacée a déjà été écrit à chaque note.
struct StudySessionSnapshot: Codable, Equatable {
    var sourceKey: String
    /// La carte en cours d'abord, puis la file, dans l'ordre.
    var remainingCardIDs: [UUID]
    var initialCount: Int
    var answeredCount: Int
    var againCount: Int
    var goodCount: Int
    var elapsed: TimeInterval
    var savedAt: Date

    /// Le détail des notes, ajouté quand le bilan de fin de session a cessé de ranger
    /// « difficile » avec « facile ». Facultatifs, parce qu'une sauvegarde écrite par une
    /// version précédente ne les porte pas : elle se reprend alors avec ses deux chiffres,
    /// et le bilan range tout ce qui n'était pas « à revoir » dans « correct ».
    var hardCount: Int?
    var easyCount: Int?
    var graduatedCount: Int?

    /// « Carte 12 sur 22 » : la position qu'on annonce à la reprise.
    var position: Int {
        min(answeredCount + 1, max(initialCount, 1))
    }

    /// Les notes reconstituées, telles que la session les recompte à la reprise.
    var ratingCounts: [ReviewRating: Int] {
        let hard = hardCount ?? 0
        let easy = easyCount ?? 0
        return [
            .again: againCount,
            .hard: hard,
            .easy: easy,
            .good: max(0, goodCount - hard - easy)
        ]
    }
}

/// Sauvegarde de la session en cours, écrite après chaque note.
///
/// Une session abandonnée hier n'a plus de sens : passé le délai, la reprise n'est plus
/// proposée et les cartes repartent dans la file normale du jour.
enum StudySessionStore {
    static let key = "micabo.session.inProgress"
    /// Au-delà, on ne propose plus de reprendre.
    static let expiry: TimeInterval = 12 * 3_600

    static func save(_ snapshot: StudySessionSnapshot, defaults: UserDefaults = .standard) {
        guard !snapshot.remainingCardIDs.isEmpty else {
            clear(defaults: defaults)
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(
        for sourceKey: String,
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> StudySessionSnapshot? {
        guard
            let data = defaults.data(forKey: key),
            let snapshot = try? JSONDecoder().decode(StudySessionSnapshot.self, from: data),
            snapshot.sourceKey == sourceKey,
            !snapshot.remainingCardIDs.isEmpty,
            now.timeIntervalSince(snapshot.savedAt) < expiry
        else {
            return nil
        }
        return snapshot
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
