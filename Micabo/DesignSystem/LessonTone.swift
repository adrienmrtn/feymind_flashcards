import SwiftUI

/// **Les cinq tons de Micabo, et la couleur d'une leçon.**
///
/// Chaque leçon reçoit un ton à sa création, et le garde : c'est la couleur de son parcours
/// (cercles cochés, trait, barre de progression) et le fond de ses encadrés « En une phrase »
/// et « À retenir ». Trois nuances par ton, parce qu'aucune ne fait les trois métiers : une
/// coche blanche ne se lit pas sur un pastel, et un fond vif sous trois lignes de texte crie.
///
/// - `pale` : le fond d'un encadré, sous du texte à l'encre.
/// - `vivid` : un aplat sans texte — cercle coché, trait du chemin, barre de progression.
/// - `ink` : ce qui s'écrit dans la couleur de la leçon — un filet de titre, un chiffre.
enum LessonTone: String, CaseIterable, Codable, Identifiable {
    case yellow
    case mint
    case blue
    case pink
    case lilac

    var id: String { rawValue }

    private var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    private var palette: MicaboPalette { AppearanceStore.shared.palette }

    var pale: Color { palette.tonePale[index] }
    var vivid: Color { palette.toneVivid[index] }
    var ink: Color { palette.toneInk[index] }

    /// Un ton lu depuis le stockage ; un nom inconnu (ou absent) retombe sur le bleu.
    init(raw: String?) {
        self = raw.flatMap(LessonTone.init(rawValue:)) ?? .blue
    }

    /// Le ton de la leçon suivante : jamais celui de la précédente, et les cinq tournent.
    static func next(after previous: LessonTone?) -> LessonTone {
        guard let previous else { return .yellow }
        let cases = allCases
        let position = cases.firstIndex(of: previous) ?? 0
        return cases[(position + 1) % cases.count]
    }

    /// Le ton d'une leçon qui n'en a pas encore (un ancien cours), tiré de son identifiant.
    /// Stable d'un lancement à l'autre et d'un appareil à l'autre.
    static func stable(for id: UUID) -> LessonTone {
        let cases = allCases
        return cases[Int(StableHash.of(id.uuidString) % UInt64(cases.count))]
    }
}

/// **Un hachage qui ne change pas d'un lancement à l'autre.**
///
/// `String.hashValue` est re-salé à chaque exécution : une couleur tirée de lui change entre
/// deux ouvertures de l'app et entre deux téléphones. FNV-1a sur les octets UTF-8 donne le
/// même nombre partout.
enum StableHash {
    static func of(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
