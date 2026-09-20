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
    /// Le dégradé de la carte du jour, du violet au vert en passant par le bleu, et le filet
    /// qui la ferme. Trois teintes très proches du blanc : c'est un lavis, pas un aplat.
    var dayWashStart: Color
    var dayWashMid: Color
    var dayWashEnd: Color
    var dayWashStroke: Color
    var tilePastels: [Color]
    var cardShadow: Double
    var groupShadow: Double

    /// **Le jour, refait pour la refonte.** Quatre décisions, et elles se voient toutes.
    ///
    /// **Le fond devient blanc.** Il était gris-bleu, et les cartes blanches posées dessus
    /// se détachaient par leur clarté. La nouvelle direction fait l'inverse : un fond blanc,
    /// des surfaces blanches, et ce qui se détache se détache par un filet d'un pixel ou par
    /// un aplat de couleur — jamais par une ombre. C'est ce qui laisse les tuiles de matière
    /// porter la couleur de l'écran sans que rien ne leur dispute l'attention.
    ///
    /// **L'accent passe du bleu au violet.** `#6442EF` est un violet franc, qui porte du
    /// blanc à 7,5:1 et qui ne ressemble à aucun bleu système. Il ne dit qu'une chose :
    /// ce qui est actif, sélectionné, ou en cours de progression.
    ///
    /// **Les couleurs des notes de révision ne bougent pas.** `ratingAgain`, `caution`,
    /// `positive`, `info` et leurs quatre fonds pastel sont ceux d'avant, au code
    /// hexadécimal près. La direction artistique des cartes est la seule partie de l'app
    /// que la refonte conserve, et un vert ou un ambre déplacé d'un demi-ton rendrait
    /// illisible le bilan de fin de session, qui rejoue les mêmes couleurs.
    ///
    /// **Les ombres tombent presque à zéro.** Il n'en reste qu'une, sur la carte de
    /// révision, et elle est déjà écrite dans `StudyView`. Partout ailleurs, c'est `stroke`.
    static let day = MicaboPalette(
        canvas: .white,
        surface: .white,
        surfaceMuted: Color(hex: 0xF7F7FA),
        surfaceSunken: Color(hex: 0xF2F2F5),
        stroke: Color(hex: 0xECECF1),
        strokeStrong: Color(hex: 0xE5E5EA),
        hairline: Color(hex: 0xECECF1),
        hairlineOnCanvas: Color(hex: 0xECECF1),
        // L'encre n'est ni noire ni navy : un gris très sombre à peine violacé, qui
        // s'accorde à l'accent sans jamais le concurrencer. 17,3:1 sur le blanc.
        ink: Color(hex: 0x16151A),
        // 4,9:1 sur blanc — au-dessus du seuil, y compris à onze points.
        inkSecondary: Color(hex: 0x6E6E78),
        inkTertiary: Color(hex: 0xA2A2AC),
        inkReading: Color(hex: 0x2E2D36),
        inkBody: Color(hex: 0x4E4D57),
        sheetMarker: Color(hex: 0xFFF0A6),
        sheetHighlights: [
            Color(hex: 0xFFF0A6),
            Color(hex: 0xC9EBD3),
            Color(hex: 0xD6E7FB),
            Color(hex: 0xFBD9E4),
            Color(hex: 0xDCC9FB)
        ],
        onInk: .white,
        onInkMuted: Color(hex: 0x9D95C0),
        canvasSage: .white,
        accent: Color(hex: 0x6442EF),
        accentSoft: Color(hex: 0xEFECFD),
        accentVivid: Color(hex: 0x6442EF),
        progressTrack: Color(hex: 0xE5E5EA),
        // À partir d'ici, et jusqu'à `infoSoft` : les couleurs des notes de révision,
        // reprises telles quelles de l'ancienne palette. Voir le commentaire du type.
        positive: Color(hex: 0x2F7D57),
        caution: Color(hex: 0x8A6410),
        cautionVivid: Color(hex: 0xFFC53D),
        negative: Color(hex: 0xC93B2B),
        ratingAgain: Color(hex: 0xB5573C),
        info: Color(hex: 0x3A6FC4),
        positiveSoft: Color(hex: 0xDEF5E7),
        cautionSoft: Color(hex: 0xFDF1D6),
        negativeSoft: Color(hex: 0xFDE8E2),
        infoSoft: Color(hex: 0xE3EDFC),
        offerWash: Color(hex: 0xDCC9FB),
        offerWashSoft: Color(hex: 0xF4EEFE),
        accentWash: Color(hex: 0xF6F4FE),
        accentPale: Color(hex: 0xCFC4FA),
        track: Color(hex: 0xE5E5EA),
        flame: Color(hex: 0xFF5440),
        flameInk: Color(hex: 0xC0341F),
        flameSoft: Color(hex: 0xFFF0ED),
        dayWashStart: Color(hex: 0xF2EEFE),
        dayWashMid: Color(hex: 0xEBF1FC),
        dayWashEnd: Color(hex: 0xE9F5F1),
        dayWashStroke: Color(hex: 0xE4DDFA),
        // Les teintes de matière. Elles sont franches et non pastel-pâles : à 112 points
        // de côté sur un fond blanc, une teinte trop lavée ne tient pas la tuile.
        tilePastels: [
            Color(hex: 0xFFE2A8),
            Color(hex: 0xC9EBD3),
            Color(hex: 0xDCC9FB),
            Color(hex: 0xBCD8FA),
            Color(hex: 0xFBD9E4),
            Color(hex: 0xF2F2F5)
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
