import Observation
import SwiftUI

/// **Une seule apparence, et c'est le jour.**
///
/// Il y en avait trois — jour, nuit, crépuscule — soit trois palettes complètes à tenir
/// pour un sélecteur que presque personne n'ouvrait, et trois fois le travail à chaque
/// jeton ajouté. La refonte n'en garde qu'une et la règle au pixel. Le mode sombre
/// reviendra quand la palette claire aura cessé de bouger : une palette qu'on retouche
/// chaque semaine ne se décline pas.
///
/// Le type survit à un seul cas parce que `AppearanceStore` est lu depuis le thème, et
/// qu'un jeton de couleur qui s'appellerait `MicaboPalette.day` en dur dans trente fichiers
/// serait exactement ce qu'il faudrait défaire le jour où la nuit revient.
enum MicaboAppearance: String, CaseIterable, Identifiable {
    case day

    var id: String { rawValue }

    var isDark: Bool { false }

    var colorScheme: ColorScheme { .light }

    static let storageKey = "micabo.appearance"

    /// Les anciens appareils ont « night » ou « twilight » en réglage. Ils retombent sur le
    /// jour sans erreur, et la clé est réécrite au premier enregistrement.
    static func fromUnknown(_ value: String?) -> MicaboAppearance {
        MicaboAppearance(rawValue: value ?? "") ?? .day
    }
}

/// Les jetons de couleur de l'app, en une seule palette.
struct MicaboPalette: Equatable {
    var canvas: Color
    var surface: Color
    var surfaceMuted: Color
    var surfaceSunken: Color
    var stroke: Color
    var strokeStrong: Color
    var hairline: Color
    var hairlineOnCanvas: Color
    var ink: Color
    var inkSecondary: Color
    var inkTertiary: Color
    var inkReading: Color
    var inkBody: Color
    var sheetMarker: Color
    /// Les cinq surligneurs d'une fiche, dans l'ordre de `SheetHighlight.allCases`.
    var sheetHighlights: [Color]
    var onInk: Color
    var onInkMuted: Color
    var canvasSage: Color
    var accent: Color
    var accentSoft: Color
    var accentVivid: Color
    var progressTrack: Color
    var positive: Color
    var caution: Color
    var cautionVivid: Color
    var negative: Color
    var ratingAgain: Color
    var info: Color
    /// Le lavis vert de la zone de maintien, et l'encre lisible dessus. `positiveSoft` est
    /// déjà pris par les notes de session : le réutiliser ferait qu'un fond de graphe et une
    /// note « correct » porteraient le même vert.
    var positiveWash: Color
    var positiveInk: Color
    var positiveSoft: Color
    var cautionSoft: Color
    var negativeSoft: Color
    var infoSoft: Color
    var offerWash: Color
    var offerWashSoft: Color
    /// **Le violet pâle des cartes neuves.** Il ne sert qu'à opposer les neuves aux cartes
    /// en cours dans une même jauge : deux teintes d'un même violet disent « deux parts de
    /// la même chose », là où un second accent aurait dit « deux choses ».
    /// Le fond d'une réponse choisie : un violet si pâle qu'il se lit comme du blanc teinté.
    /// `accentSoft` était trop présent pour six rangées empilées.
    /// Les trois gris d'un rouleau de notes, du plus proche du choix au plus lointain. Ils
    /// ne servent qu'à ça : partout ailleurs, `inkTertiary` suffit.
    var gradeNear: Color
    var gradeMid: Color
    var gradeFar: Color
    var accentWash: Color
    var accentPale: Color
    /// Le creux d'une barre de progression fine. Plus sombre que `progressTrack`, qui sert
    /// aux jauges épaisses : à cinq points de haut, un gris trop clair disparaît.
    var track: Color
    /// La flamme de la série, son encre lisible et son lavis. C'est la seule chose de l'app
    /// qui ne se compte pas en cartes, et la seule qui a droit à l'orange.
    var flame: Color
    var flameInk: Color
    var flameSoft: Color
    /// Le creux des segments de série, et la prose sur le lavis chaud : deux teintes tirées
    /// de l'orange plutôt que du gris, pour que la carte reste d'une seule pièce.
    var flameTrack: Color
    var warmProse: Color
    var warmWashStart: Color
    var warmWashEnd: Color
    var warmWashStroke: Color
    /// Le dégradé de la carte du jour, du violet au vert en passant par le bleu, et le filet
    /// qui la ferme. Trois teintes très proches du blanc : c'est un lavis, pas un aplat.
    var dayWashStart: Color
    var dayWashMid: Color
    var dayWashEnd: Color
    var dayWashStroke: Color
    var tilePastels: [Color]
    /// **Les mots-clés des notes**, et les termes définis. C'est le seul usage du violet dans
    /// une leçon : un mot violet est un mot à retenir, nulle part ailleurs.
    var keyword: Color
    /// Bonne et mauvaise réponse, **et rien d'autre** : un quiz, la question de fin d'un
    /// thème. Le plein pour la case choisie, l'encre pour la phrase qui explique, le lavis
    /// pour le fond.
    var correct: Color
    var correctInk: Color
    var correctSoft: Color
    var wrong: Color
    var wrongInk: Color
    var wrongSoft: Color
    /// Les cinq tons d'une leçon, dans l'ordre de `LessonTone.allCases` : pâle pour les
    /// encadrés, vif pour les cercles cochés, le trait et la barre, encre pour ce qui
    /// s'écrit sur le pâle. Voir `LessonTone`.
    var tonePale: [Color]
    var toneVivid: [Color]
    var toneInk: [Color]
    var cardShadow: Double
    var groupShadow: Double

    /// **Le jour de la refonte « parcours » : ivoire, encre, bleu.**
    ///
    /// Le fond redevient l'ivoire de Micabo, et les surfaces restent blanches : une carte se
    /// détache du papier par sa clarté, sans bordure. L'accent revient au bleu `#2563EB`, celui
    /// du site — le violet a été l'accent de l'app pendant une version, mais la refonte le
    /// réserve aux mots-clés des notes, et un violet qui voudrait dire « bouton » et « à
    /// retenir » ne dirait plus rien.
    ///
    /// Les boutons d'action principaux sont **noirs** (l'encre) ; le bleu dit ce qui est
    /// actif ou sélectionné. Vert et rouge ne disent que juste et faux. Chaque leçon porte un
    /// des cinq tons de Micabo (`LessonTone`).
    ///
    /// **Les couleurs des notes de révision ne bougent pas** (`ratingAgain`, `caution`,
    /// `positive`, `info` et leurs fonds) : le bilan de fin de session les rejoue.
    static let day = MicaboPalette(
        canvas: Color(hex: 0xF6F4ED),
        surface: .white,
        surfaceMuted: Color(hex: 0xF0EDE4),
        surfaceSunken: Color(hex: 0xE9E5DA),
        stroke: Color(hex: 0xE7E2D7),
        strokeStrong: Color(hex: 0xDAD4C7),
        hairline: Color(hex: 0xECE8DE),
        hairlineOnCanvas: Color(hex: 0xE3DED2),
        // Un noir à peine bleuté : 16:1 sur l'ivoire. C'est aussi le fond des boutons
        // d'action principaux.
        ink: Color(hex: 0x1B1E24),
        // 5,2:1 sur l'ivoire — au-dessus du seuil, y compris à douze points.
        inkSecondary: Color(hex: 0x63676F),
        inkTertiary: Color(hex: 0x9C9C96),
        inkReading: Color(hex: 0x2A2D33),
        inkBody: Color(hex: 0x464A52),
        sheetMarker: Color(hex: 0xFFF0A6),
        sheetHighlights: [
            Color(hex: 0xFFF0A6),
            Color(hex: 0xC9EBD3),
            Color(hex: 0xD6E7FB),
            Color(hex: 0xFBD9E4),
            Color(hex: 0xDCC9FB)
        ],
        onInk: .white,
        onInkMuted: Color(hex: 0xA8ABB3),
        canvasSage: Color(hex: 0xF6F4ED),
        accent: Color(hex: 0x2563EB),
        accentSoft: Color(hex: 0xDBEAFE),
        accentVivid: Color(hex: 0x3B82F6),
        progressTrack: Color(hex: 0xE7E2D7),
        // À partir d'ici, et jusqu'à `infoSoft` : les couleurs des notes de révision,
        // reprises telles quelles de l'ancienne palette. Voir le commentaire du type.
        positive: Color(hex: 0x2F7D57),
        caution: Color(hex: 0x8A6410),
        cautionVivid: Color(hex: 0xFFC53D),
        negative: Color(hex: 0xC93B2B),
        ratingAgain: Color(hex: 0xB5573C),
        info: Color(hex: 0x3A6FC4),
        positiveWash: Color(hex: 0xE4F6EE),
        positiveInk: Color(hex: 0x16795A),
        positiveSoft: Color(hex: 0xDEF5E7),
        cautionSoft: Color(hex: 0xFDF1D6),
        negativeSoft: Color(hex: 0xFDE8E2),
        infoSoft: Color(hex: 0xE3EDFC),
        offerWash: Color(hex: 0xDCC9FB),
        offerWashSoft: Color(hex: 0xF4EEFE),
        gradeNear: Color(hex: 0xB9B9C2),
        gradeMid: Color(hex: 0xD3D3DA),
        gradeFar: Color(hex: 0xE6E6EB),
        accentWash: Color(hex: 0xEEF4FE),
        accentPale: Color(hex: 0xBFD5FA),
        track: Color(hex: 0xE3DED2),
        flame: Color(hex: 0xFF5440),
        flameInk: Color(hex: 0xC0341F),
        flameSoft: Color(hex: 0xFFF0ED),
        flameTrack: Color(hex: 0xF2D6C9),
        warmProse: Color(hex: 0x6B5A52),
        warmWashStart: Color(hex: 0xFFF3E8),
        warmWashEnd: Color(hex: 0xFDE8EE),
        warmWashStroke: Color(hex: 0xF3E4DC),
        dayWashStart: Color(hex: 0xF2EEFE),
        dayWashMid: Color(hex: 0xEBF1FC),
        dayWashEnd: Color(hex: 0xE9F5F1),
        dayWashStroke: Color(hex: 0xE4DDFA),
        // Les tuiles : les cinq tons pâles, et un gris de papier.
        tilePastels: [
            Color(hex: 0xFFF1B8),
            Color(hex: 0xCDEFDC),
            Color(hex: 0xD6E7FB),
            Color(hex: 0xFBD9E4),
            Color(hex: 0xE4D9FB),
            Color(hex: 0xF0EDE4)
        ],
        keyword: Color(hex: 0x7C3AED),
        correct: Color(hex: 0x16A34A),
        correctInk: Color(hex: 0x15803D),
        correctSoft: Color(hex: 0xDCFCE7),
        wrong: Color(hex: 0xDC2626),
        wrongInk: Color(hex: 0xB91C1C),
        wrongSoft: Color(hex: 0xFEE2E2),
        // jaune, menthe, bleu, rose, lilas
        tonePale: [
            Color(hex: 0xFFF1B8),
            Color(hex: 0xCDEFDC),
            Color(hex: 0xD6E7FB),
            Color(hex: 0xFBD9E4),
            Color(hex: 0xE4D9FB)
        ],
        toneVivid: [
            Color(hex: 0xF2B200),
            Color(hex: 0x22B573),
            Color(hex: 0x3B82F6),
            Color(hex: 0xEC5B8F),
            Color(hex: 0x8B5CF6)
        ],
        toneInk: [
            Color(hex: 0x7A5600),
            Color(hex: 0x146C45),
            Color(hex: 0x1D4ED8),
            Color(hex: 0xA8204F),
            Color(hex: 0x5B21B6)
        ],
        cardShadow: 0.04,
        groupShadow: 0.0
    )

    static func of(_ appearance: MicaboAppearance) -> MicaboPalette {
        switch appearance {
        case .day: .day
        }
    }
}

/// L'apparence en cours.
///
/// Elle n'a plus qu'une valeur, et le type reste pour une seule raison : c'est lui que
/// `MicaboColor` interroge. Le jour où la nuit revient, elle revient ici, et nulle part
/// ailleurs.
@Observable
final class AppearanceStore {
    static let shared = AppearanceStore()

    let appearance: MicaboAppearance = .day

    var palette: MicaboPalette { MicaboPalette.of(appearance) }

    init() {}
}
