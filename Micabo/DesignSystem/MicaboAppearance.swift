import Observation
import SwiftUI
import UIKit

/// **Le thème : clair, sombre, ou celui du téléphone** (`docs/refonte-parcours.md` § 12).
///
/// Les couleurs ne changent pas de palette en route : `MicaboPalette.adaptive` porte les deux,
/// et chaque jeton se résout au moment de peindre. Le réglage ne fait que fixer l'apparence de
/// la fenêtre (`colorScheme`) ; en « Système », c'est le téléphone qui décide.
enum MicaboAppearance: String, CaseIterable, Identifiable {
    case system
    case day
    case night

    var id: String { rawValue }

    /// L'apparence imposée à la fenêtre ; `nil` laisse le téléphone choisir.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .day: .light
        case .night: .dark
        }
    }

    var titleKey: String { "lesson.theme.\(rawValue)" }

    static let storageKey = "micabo.appearance"

    /// Le réglage enregistré. Les anciens appareils ont « day », « night » ou « twilight » :
    /// le crépuscule était une nuit douce, il redevient la nuit. Sans réglage, le téléphone
    /// décide.
    static func fromUnknown(_ value: String?) -> MicaboAppearance {
        switch value {
        case "day": .day
        case "night", "twilight": .night
        default: .system
        }
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


    /// **La nuit** : le même papier retourné. Un fond presque noir, à peine bleuté, des surfaces
    /// un cran plus claires, l'encre devient l'ivoire. Les boutons d'action restent « d'encre » :
    /// ivoire sur la nuit, texte sombre dessus. Les tons d'une leçon gardent leur vif ; leur pâle
    /// passe en lavis sombre, et leur encre s'éclaircit pour se lire dessus.
    static let night = MicaboPalette(
        canvas: Color(hex: 0x121317),
        surface: Color(hex: 0x1C1E24),
        surfaceMuted: Color(hex: 0x23262D),
        surfaceSunken: Color(hex: 0x2A2D35),
        stroke: Color(hex: 0x30333B),
        strokeStrong: Color(hex: 0x3B3F48),
        hairline: Color(hex: 0x2A2D34),
        hairlineOnCanvas: Color(hex: 0x24272E),
        ink: Color(hex: 0xF3F1EA),
        inkSecondary: Color(hex: 0xA4A7AE),
        inkTertiary: Color(hex: 0x6F737B),
        inkReading: Color(hex: 0xE7E5DF),
        inkBody: Color(hex: 0xC9CAC6),
        sheetMarker: Color(hex: 0x5A4A12),
        sheetHighlights: [
            Color(hex: 0x5A4A12),
            Color(hex: 0x1F4A33),
            Color(hex: 0x1E3A5F),
            Color(hex: 0x5A2235),
            Color(hex: 0x3E2C66)
        ],
        onInk: Color(hex: 0x121317),
        onInkMuted: Color(hex: 0x4D5058),
        canvasSage: Color(hex: 0x121317),
        accent: Color(hex: 0x6B9BF2),
        accentSoft: Color(hex: 0x1D2A45),
        accentVivid: Color(hex: 0x60A5FA),
        progressTrack: Color(hex: 0x30333B),
        positive: Color(hex: 0x4CC38A),
        caution: Color(hex: 0xE3B24C),
        cautionVivid: Color(hex: 0xFFC53D),
        negative: Color(hex: 0xF06A5A),
        ratingAgain: Color(hex: 0xE07A5F),
        info: Color(hex: 0x6E9BEA),
        positiveWash: Color(hex: 0x15291F),
        positiveInk: Color(hex: 0x6FD3A0),
        positiveSoft: Color(hex: 0x18301F),
        cautionSoft: Color(hex: 0x33280F),
        negativeSoft: Color(hex: 0x3A1A16),
        infoSoft: Color(hex: 0x1A2740),
        offerWash: Color(hex: 0x3E2C66),
        offerWashSoft: Color(hex: 0x261C3D),
        gradeNear: Color(hex: 0x56575F),
        gradeMid: Color(hex: 0x40414A),
        gradeFar: Color(hex: 0x31323A),
        accentWash: Color(hex: 0x17213A),
        accentPale: Color(hex: 0x2B4677),
        track: Color(hex: 0x2C2F36),
        flame: Color(hex: 0xFF6B57),
        flameInk: Color(hex: 0xFF8A78),
        flameSoft: Color(hex: 0x3A1D19),
        flameTrack: Color(hex: 0x4A2A24),
        warmProse: Color(hex: 0xCBB8AE),
        warmWashStart: Color(hex: 0x2B211B),
        warmWashEnd: Color(hex: 0x2B1C22),
        warmWashStroke: Color(hex: 0x3A2C25),
        dayWashStart: Color(hex: 0x221C33),
        dayWashMid: Color(hex: 0x1B2233),
        dayWashEnd: Color(hex: 0x182A26),
        dayWashStroke: Color(hex: 0x2E2645),
        tilePastels: [
            Color(hex: 0x463A10),
            Color(hex: 0x173D2B),
            Color(hex: 0x1C3352),
            Color(hex: 0x4A1F30),
            Color(hex: 0x33275A),
            Color(hex: 0x23262D)
        ],
        keyword: Color(hex: 0xA78BFA),
        correct: Color(hex: 0x22C55E),
        correctInk: Color(hex: 0x4ADE80),
        correctSoft: Color(hex: 0x13301E),
        wrong: Color(hex: 0xEF4444),
        wrongInk: Color(hex: 0xF87171),
        wrongSoft: Color(hex: 0x3A1717),
        tonePale: [
            Color(hex: 0x3B3112),
            Color(hex: 0x143326),
            Color(hex: 0x182B45),
            Color(hex: 0x3D1A29),
            Color(hex: 0x2A2148)
        ],
        toneVivid: [
            Color(hex: 0xF2B200),
            Color(hex: 0x22B573),
            Color(hex: 0x3B82F6),
            Color(hex: 0xEC5B8F),
            Color(hex: 0x8B5CF6)
        ],
        toneInk: [
            Color(hex: 0xF6CF5A),
            Color(hex: 0x5DD69B),
            Color(hex: 0x8DB8FA),
            Color(hex: 0xF49AB9),
            Color(hex: 0xB9A0FA)
        ],
        cardShadow: 0.0,
        groupShadow: 0.0
    )

    /// **La palette que l'app lit** : chaque jeton suit l'apparence de l'écran qui le dessine,
    /// jour ou nuit. C'est le système qui choisit, au moment de peindre — selon le réglage
    /// « Thème » (`AppearanceStore`) ou, en « Système », selon le téléphone. Les ombres restent
    /// celles du jour : sur la nuit, une ombre ne se voit pas, et les surfaces se détachent par
    /// leur clarté.
    static let adaptive = MicaboPalette(
        canvas: blend(day.canvas, night.canvas),
        surface: blend(day.surface, night.surface),
        surfaceMuted: blend(day.surfaceMuted, night.surfaceMuted),
        surfaceSunken: blend(day.surfaceSunken, night.surfaceSunken),
        stroke: blend(day.stroke, night.stroke),
        strokeStrong: blend(day.strokeStrong, night.strokeStrong),
        hairline: blend(day.hairline, night.hairline),
        hairlineOnCanvas: blend(day.hairlineOnCanvas, night.hairlineOnCanvas),
        ink: blend(day.ink, night.ink),
        inkSecondary: blend(day.inkSecondary, night.inkSecondary),
        inkTertiary: blend(day.inkTertiary, night.inkTertiary),
        inkReading: blend(day.inkReading, night.inkReading),
        inkBody: blend(day.inkBody, night.inkBody),
        sheetMarker: blend(day.sheetMarker, night.sheetMarker),
        sheetHighlights: zip(day.sheetHighlights, night.sheetHighlights).map { blend($0, $1) },
        onInk: blend(day.onInk, night.onInk),
        onInkMuted: blend(day.onInkMuted, night.onInkMuted),
        canvasSage: blend(day.canvasSage, night.canvasSage),
        accent: blend(day.accent, night.accent),
        accentSoft: blend(day.accentSoft, night.accentSoft),
        accentVivid: blend(day.accentVivid, night.accentVivid),
        progressTrack: blend(day.progressTrack, night.progressTrack),
        positive: blend(day.positive, night.positive),
        caution: blend(day.caution, night.caution),
        cautionVivid: blend(day.cautionVivid, night.cautionVivid),
        negative: blend(day.negative, night.negative),
        ratingAgain: blend(day.ratingAgain, night.ratingAgain),
        info: blend(day.info, night.info),
        positiveWash: blend(day.positiveWash, night.positiveWash),
        positiveInk: blend(day.positiveInk, night.positiveInk),
        positiveSoft: blend(day.positiveSoft, night.positiveSoft),
        cautionSoft: blend(day.cautionSoft, night.cautionSoft),
        negativeSoft: blend(day.negativeSoft, night.negativeSoft),
        infoSoft: blend(day.infoSoft, night.infoSoft),
        offerWash: blend(day.offerWash, night.offerWash),
        offerWashSoft: blend(day.offerWashSoft, night.offerWashSoft),
        gradeNear: blend(day.gradeNear, night.gradeNear),
        gradeMid: blend(day.gradeMid, night.gradeMid),
        gradeFar: blend(day.gradeFar, night.gradeFar),
        accentWash: blend(day.accentWash, night.accentWash),
        accentPale: blend(day.accentPale, night.accentPale),
        track: blend(day.track, night.track),
        flame: blend(day.flame, night.flame),
        flameInk: blend(day.flameInk, night.flameInk),
        flameSoft: blend(day.flameSoft, night.flameSoft),
        flameTrack: blend(day.flameTrack, night.flameTrack),
        warmProse: blend(day.warmProse, night.warmProse),
        warmWashStart: blend(day.warmWashStart, night.warmWashStart),
        warmWashEnd: blend(day.warmWashEnd, night.warmWashEnd),
        warmWashStroke: blend(day.warmWashStroke, night.warmWashStroke),
        dayWashStart: blend(day.dayWashStart, night.dayWashStart),
        dayWashMid: blend(day.dayWashMid, night.dayWashMid),
        dayWashEnd: blend(day.dayWashEnd, night.dayWashEnd),
        dayWashStroke: blend(day.dayWashStroke, night.dayWashStroke),
        tilePastels: zip(day.tilePastels, night.tilePastels).map { blend($0, $1) },
        keyword: blend(day.keyword, night.keyword),
        correct: blend(day.correct, night.correct),
        correctInk: blend(day.correctInk, night.correctInk),
        correctSoft: blend(day.correctSoft, night.correctSoft),
        wrong: blend(day.wrong, night.wrong),
        wrongInk: blend(day.wrongInk, night.wrongInk),
        wrongSoft: blend(day.wrongSoft, night.wrongSoft),
        tonePale: zip(day.tonePale, night.tonePale).map { blend($0, $1) },
        toneVivid: zip(day.toneVivid, night.toneVivid).map { blend($0, $1) },
        toneInk: zip(day.toneInk, night.toneInk).map { blend($0, $1) },
        cardShadow: day.cardShadow,
        groupShadow: day.groupShadow
    )

    private static func blend(_ light: Color, _ dark: Color) -> Color {
        let light = UIColor(light)
        let dark = UIColor(dark)
        return Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}

/// Le thème choisi, et la palette que tout le monde lit.
@Observable
final class AppearanceStore {
    static let shared = AppearanceStore()

    var appearance: MicaboAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: MicaboAppearance.storageKey) }
    }

    private let defaults: UserDefaults

    var palette: MicaboPalette { .adaptive }

    /// Vrai quand l'écran qui se dessine en ce moment est en sombre.
    static var isDarkNow: Bool { UITraitCollection.current.userInterfaceStyle == .dark }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = MicaboAppearance.fromUnknown(defaults.string(forKey: MicaboAppearance.storageKey))
    }
}
