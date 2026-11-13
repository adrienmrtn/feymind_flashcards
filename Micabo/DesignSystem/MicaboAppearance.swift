import Observation
import SwiftUI
import UIKit

/// **Le thème : clair, sombre, ou celui du téléphone** (`docs/refonte-parcours.md` § 12).
///
/// Les couleurs ne changent pas de palette en route : `MicaboPalette.adaptive` porte les deux,
/// et chaque jeton se résout au moment de peindre. Le réglage ne fait que fixer l'apparence de
/// la fenêtre (`colorScheme`) ; en « Système », c'est le téléphone qui décide.
///
/// **Micabo s'ouvre en marine** (lot 10, V3.3) : c'est le thème de la direction artistique, et
/// celui de tout le monde — un appareil neuf comme un élève qui n'avait rien choisi. Le clair
/// (« Jour », sur un fond teinté) et « Comme le téléphone » restent au choix dans le Profil, et
/// un élève qui a choisi l'un des deux le garde.
///
/// Le lot 7 avait fait l'inverse — clair par défaut — parce que la nuit d'alors était un
/// graphite terne, que l'élève trouvait « trop sombre ». Le marine d'aujourd'hui est une
/// couleur, pas une absence de lumière : c'est lui que l'utilisateur a validé.
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

    /// L'ancienne clé, écrite jusqu'au lot 7. Elle n'est plus que lue, pour la migration.
    static let storageKey = "micabo.appearance"

    /// **Le choix de l'élève**, écrit seulement quand il touche au sélecteur du Profil. C'est
    /// la seule source de vérité depuis le lot 7 : sans elle, l'app est dans son thème par
    /// défaut.
    static let choiceKey = "micabo.appearance.choice"

    /// Le thème d'un élève qui n'a rien choisi : le marine.
    static let defaultAppearance: MicaboAppearance = .night

    /// Un choix enregistré, lu tel quel : « Jour », « Nuit » et « Comme le téléphone » sont
    /// trois choix, et chacun se garde. Un nom inconnu retombe sur le thème par défaut.
    static func fromUnknown(_ value: String?) -> MicaboAppearance {
        switch value {
        case "system": .system
        case "day": .day
        case "night", "twilight": .night
        default: defaultAppearance
        }
    }

    /// **Le thème d'un appareil qui n'a pas de choix enregistré** (`choiceKey`) : le marine,
    /// quoi que dise l'ancienne clé.
    ///
    /// L'ancienne clé (`storageKey`, écrite jusqu'au lot 7) ne dit pas ce que l'élève a
    /// voulu : « system » et « day » ont pu y être écrits sans qu'il touche à rien, et rien ne
    /// les distingue d'un vrai choix. Seul `choiceKey` est un geste. Un élève qui tenait au
    /// clair le retrouve en un geste dans le Profil, et ce geste-là est gardé pour de bon ;
    /// celui qui avait demandé la nuit y est déjà.
    static func migrated(legacy value: String?) -> MicaboAppearance {
        defaultAppearance
    }

    /// Le thème au lancement : le choix enregistré, sinon la migration de l'ancienne clé.
    static func stored(in defaults: UserDefaults) -> MicaboAppearance {
        if let choice = defaults.string(forKey: choiceKey) {
            return fromUnknown(choice)
        }
        return migrated(legacy: defaults.string(forKey: storageKey))
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
    /// Le bleu de l'accent, assez sombre (le jour) ou assez clair (la nuit) pour du petit
    /// texte sur un lavis : une pastille de onze points sur `accentSoft`.
    var accentInk: Color
    /// Le bout sombre du dégradé de marque (`accent` → `accentDeep`).
    var accentDeep: Color
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
    /// **Le dessin d'une icône** dans le ton d'une leçon (lot 9) : assez soutenu pour un trait
    /// de deux points sur le pâle du même ton, assez clair la nuit pour se lire sur le marine.
    var toneGlyph: [Color]
    /// **La lèvre** d'une surface touchable (lot 9) : le bord plein de trois points sous une
    /// carte, une rangée, un bouton secondaire. Elle remplace l'ombre floue : c'est elle qui
    /// pose l'objet, le jour comme la nuit, où une ombre ne se voit plus.
    var edge: Color
    /// Le texte posé sur l'accent : blanc, le jour comme la nuit (lot 9). `onInk` reste le
    /// texte posé sur l'encre, qui s'inverse avec elle.
    var onAccent: Color
    var cardShadow: Double
    var groupShadow: Double

    /// **Le jour : blanc frais, encre, bleu** (lot 7).
    ///
    /// Le fond est un blanc cassé à peine bleuté (`#F5F7FB`), et les surfaces sont blanches :
    /// une carte se détache par sa clarté, un filet froid très léger et une ombre douce.
    /// L'ivoire d'avant (`#F6F4ED`) et ses filets beiges faisaient paraître l'app jaunie et
    /// terne à côté du bleu ; tous les gris du jour sont maintenant de la même famille froide
    /// que l'accent. L'accent est le bleu Micabo `#3870FE`, celui
    /// de l'icône et de Mika — le violet a été l'accent de l'app pendant une version, mais la refonte le
    /// réserve aux mots-clés des notes, et un violet qui voudrait dire « bouton » et « à
    /// retenir » ne dirait plus rien.
    ///
    /// **Lot 9** : l'encre descend vers le bleu-noir (`#0F1324`) pour des titres qui tiennent,
    /// les tons remontent vers les couleurs de la marque (le jaune du crayon `#F7B41F`), et les
    /// cartes se posent sur une lèvre (`edge`) au lieu d'une ombre floue. Le bouton d'action
    /// principal est l'aplat de l'accent, une lèvre plus sombre dessous ; le bleu dit aussi ce
    /// qui est actif ou sélectionné. Vert et rouge ne disent que juste et faux. Chaque leçon porte un
    /// des cinq tons de Micabo (`LessonTone`).
    ///
    /// **Lot 10 — V3.3, « marine, net, adulte »** : le clair n'est plus le thème par défaut,
    /// c'est une option. Sa page est **teintée** (`#EEF1F8`, jamais de blanc pur) et ses cartes
    /// sont blanches, à filet (`#DCE1EC`) ; ni lèvre, ni ombre floue. L'encre est `#0F1324`, le
    /// secondaire `#566078`, le tertiaire `#97A0B4`. Les couleurs ont un sens, le même
    /// partout : l'accent pour la sélection et la progression, le jaune pour l'offre et la
    /// récompense, l'orange pour la série, le vert pour ce qui est juste, le rouge pour ce qui
    /// est faux ou en retard. Les valeurs sont celles de `V3Color` (un test les tient égales).
    ///
    /// Les quatre notes de révision (`ratingAgain`, `caution`, `positive`, `info` et leurs
    /// fonds) sont dans cette même famille : rouge, jaune, vert, bleu.
    ///
    /// **Les valeurs ne s'écrivent plus ici** : tout ce qui a un équivalent dans la direction
    /// artistique se lit dans `V3Palette.day` (`V3Palette.night` pour la nuit), la seule table
    /// de couleurs de l'app. Ne restent en dur que les teintes propres aux anciens écrans —
    /// surligneurs d'une fiche, lavis chauds, offre —, qui n'ont pas de jeton V3.
    static let day = MicaboPalette(
        canvas: V3Palette.day.color(\.bg),
        surface: V3Palette.day.color(\.surface),
        surfaceMuted: V3Palette.day.color(\.soft),
        surfaceSunken: Color(hex: 0xE2E7F1),
        stroke: V3Palette.day.color(\.line),
        strokeStrong: V3Palette.day.color(\.lip),
        hairline: Color(hex: 0xE8ECF3),
        hairlineOnCanvas: V3Palette.day.color(\.line),
        // Un bleu-noir : 17:1 sur le blanc.
        ink: V3Palette.day.color(\.ink),
        // 6:1 sur le blanc — au-dessus du seuil, y compris à treize points.
        inkSecondary: V3Palette.day.color(\.ink2),
        inkTertiary: V3Palette.day.color(\.ink3),
        inkReading: Color(hex: 0x1E2338),
        inkBody: Color(hex: 0x3D4459),
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
        canvasSage: V3Palette.day.color(\.bg),
        // Le bleu Micabo (`MicaboBrand.blue`) : 4,3:1 sur le blanc, assez pour un libellé
        // gras ; le petit texte sur un lavis prend `accentInk` (`#1F47B8`, 7:1 sur
        // `accentSoft`).
        accent: V3Palette.day.color(\.accent),
        accentSoft: V3Palette.day.color(\.accentWash2),
        accentVivid: V3Palette.day.color(\.accent),
        accentInk: V3Palette.day.color(\.accentInk),
        accentDeep: V3Palette.day.color(\.accentDeep),
        progressTrack: V3Palette.day.color(\.line),
        // À partir d'ici, et jusqu'à `infoSoft` : les couleurs des notes de révision, dans
        // la famille V3 (vert, jaune, rose-rouge, bleu). Voir le commentaire du type.
        positive: V3Palette.day.color(\.green),
        caution: V3Palette.day.color(\.yellowInk),
        cautionVivid: V3Palette.day.color(\.yellow),
        negative: V3Palette.day.color(\.red),
        ratingAgain: V3Palette.day.color(\.red),
        info: V3Palette.day.color(\.accentInk),
        positiveWash: V3Palette.day.color(\.greenWash),
        positiveInk: V3Palette.day.color(\.greenInk),
        positiveSoft: V3Palette.day.color(\.greenWash),
        cautionSoft: V3Palette.day.color(\.yellowWash),
        negativeSoft: V3Palette.day.color(\.redWash),
        infoSoft: V3Palette.day.color(\.accentWash),
        offerWash: Color(hex: 0xDCC9FB),
        offerWashSoft: Color(hex: 0xF4EEFE),
        gradeNear: Color(hex: 0xB7BCC7),
        gradeMid: Color(hex: 0xD2D6DE),
        gradeFar: Color(hex: 0xE5E8EE),
        accentWash: V3Palette.day.color(\.accentWash),
        accentPale: Color(hex: 0xBBCEFF),
        track: V3Palette.day.color(\.line),
        // **La série est dans le jaune du crayon**, pas dans le rouge : le rouge de l'app dit
        // « erreur » ou « en retard », et une série tenue n'est ni l'un ni l'autre. L'encre
        // reste assez sombre pour un texte de treize points sur le lavis (5:1).
        flame: V3Palette.day.color(\.orange),
        flameInk: V3Palette.day.color(\.orangeInk),
        flameSoft: V3Palette.day.color(\.orangeWash),
        flameTrack: Color(hex: 0xFBD9B5),
        warmProse: Color(hex: 0x6B5A52),
        warmWashStart: Color(hex: 0xFFF8EA),
        warmWashEnd: Color(hex: 0xFFF0D4),
        warmWashStroke: Color(hex: 0xF2E3C3),
        dayWashStart: Color(hex: 0xF2EEFE),
        dayWashMid: Color(hex: 0xEBF1FC),
        dayWashEnd: Color(hex: 0xE9F5F1),
        dayWashStroke: Color(hex: 0xE4DDFA),
        // Les tuiles : les cinq tons pâles, et un gris de papier.
        tilePastels: [
            V3Palette.day.color(\.yellowWash),
            V3Palette.day.color(\.greenWash),
            V3Palette.day.color(\.accentWash),
            V3Palette.day.color(\.pinkWash),
            V3Palette.day.color(\.lilacWash),
            V3Palette.day.color(\.soft)
        ],
        keyword: Color(hex: 0x7C3AED),
        correct: V3Palette.day.color(\.green),
        correctInk: V3Palette.day.color(\.greenInk),
        correctSoft: V3Palette.day.color(\.greenWash),
        wrong: V3Palette.day.color(\.red),
        wrongInk: V3Palette.day.color(\.redInk),
        wrongSoft: V3Palette.day.color(\.redWash),
        // jaune, menthe, bleu, rose, lilas
        tonePale: [
            V3Palette.day.color(\.yellowWash),
            V3Palette.day.color(\.greenWash),
            V3Palette.day.color(\.accentWash),
            V3Palette.day.color(\.pinkWash),
            V3Palette.day.color(\.lilacWash)
        ],
        toneVivid: [
            V3Palette.day.color(\.iconYellow),
            V3Palette.day.color(\.iconGreen),
            V3Palette.day.color(\.iconBlue),
            V3Palette.day.color(\.iconPink),
            V3Palette.day.color(\.iconLilac)
        ],
        toneInk: [
            V3Palette.day.color(\.yellowInk),
            V3Palette.day.color(\.greenInk),
            V3Palette.day.color(\.accentInk),
            V3Palette.day.color(\.pinkInk),
            V3Palette.day.color(\.lilacInk)
        ],
        toneGlyph: [
            V3Palette.day.color(\.iconYellow),
            V3Palette.day.color(\.iconGreen),
            V3Palette.day.color(\.iconBlue),
            V3Palette.day.color(\.iconPink),
            V3Palette.day.color(\.iconLilac)
        ],
        edge: V3Palette.day.color(\.line),
        onAccent: .white,
        cardShadow: 0.05,
        groupShadow: 0.035
    )


    /// **La nuit : le marine de Micabo** (lot 9), **thème par défaut depuis le lot 10**. Les
    /// valeurs de la direction artistique V3.3 se lisent dans `V3Palette.night` : fond
    /// `#0B0F1C`, surfaces `#171C2C`, filet `#262D42`, texte `#F5F6FB`, accent `#5C88FF`.
    ///
    /// Un bleu-noir (`#0B0F1C`), plus un graphite : le gris faisait une nuit terne, sans
    /// famille avec le bleu de l'accent. Les surfaces montent d'un seul cran net (`#161B2B`),
    /// sans ombre — la nuit, la profondeur vient de la clarté et de la lèvre (`edge`), pas d'un
    /// flou qui ne se voit pas. L'encre est un blanc à peine bleuté. L'accent se relève
    /// (`#5C88FF`) et porte du texte **blanc** (`onAccent`), comme le jour. Les tons d'une leçon
    /// gardent leur vif ; leur pâle passe en lavis sombre, leur encre s'éclaircit.
    static let night = MicaboPalette(
        canvas: V3Palette.night.color(\.bg),
        surface: V3Palette.night.color(\.surface),
        surfaceMuted: V3Palette.night.color(\.soft),
        surfaceSunken: Color(hex: 0x0F1424),
        stroke: V3Palette.night.color(\.line),
        strokeStrong: V3Palette.night.color(\.lip),
        hairline: Color(hex: 0x20263A),
        hairlineOnCanvas: V3Palette.night.color(\.line),
        ink: V3Palette.night.color(\.ink),
        inkSecondary: V3Palette.night.color(\.ink2),
        inkTertiary: V3Palette.night.color(\.ink3),
        inkReading: Color(hex: 0xE9ECF5),
        inkBody: Color(hex: 0xC9CEDD),
        sheetMarker: Color(hex: 0x5A4A12),
        sheetHighlights: [
            Color(hex: 0x5A4A12),
            Color(hex: 0x1F4A33),
            Color(hex: 0x1E3A5F),
            Color(hex: 0x5A2235),
            Color(hex: 0x3E2C66)
        ],
        onInk: V3Palette.night.color(\.bg),
        onInkMuted: Color(hex: 0x4A5066),
        canvasSage: V3Palette.night.color(\.bg),
        // Le 400 de la gamme : 5,4:1 sur la carte de nuit, 4,6:1 sur `accentSoft`.
        accent: V3Palette.night.color(\.accent),
        accentSoft: V3Palette.night.color(\.accentWash2),
        accentVivid: V3Palette.night.color(\.accent),
        accentInk: V3Palette.night.color(\.accentInk),
        accentDeep: V3Palette.night.color(\.accentDeep),
        progressTrack: V3Palette.night.color(\.line),
        positive: V3Palette.night.color(\.green),
        caution: V3Palette.night.color(\.yellowInk),
        cautionVivid: V3Palette.night.color(\.yellow),
        negative: V3Palette.night.color(\.red),
        ratingAgain: V3Palette.night.color(\.red),
        info: V3Palette.night.color(\.accentInk),
        positiveWash: V3Palette.night.color(\.greenWash),
        positiveInk: V3Palette.night.color(\.greenInk),
        positiveSoft: V3Palette.night.color(\.greenWash),
        cautionSoft: V3Palette.night.color(\.yellowWash),
        negativeSoft: V3Palette.night.color(\.redWash),
        infoSoft: V3Palette.night.color(\.accentWash),
        offerWash: Color(hex: 0x3E2C66),
        offerWashSoft: Color(hex: 0x261C3D),
        gradeNear: Color(hex: 0x545B70),
        gradeMid: Color(hex: 0x3E4458),
        gradeFar: Color(hex: 0x2E3446),
        accentWash: V3Palette.night.color(\.accentWash),
        accentPale: Color(hex: 0x1E3A85),
        track: V3Palette.night.color(\.line),
        flame: V3Palette.night.color(\.orange),
        flameInk: V3Palette.night.color(\.orangeInk),
        flameSoft: V3Palette.night.color(\.orangeWash),
        flameTrack: Color(hex: 0x4A2C12),
        warmProse: Color(hex: 0xCBB8AE),
        warmWashStart: Color(hex: 0x241F14),
        warmWashEnd: Color(hex: 0x2A2212),
        warmWashStroke: Color(hex: 0x3A3020),
        dayWashStart: Color(hex: 0x1C1A33),
        dayWashMid: Color(hex: 0x15203A),
        dayWashEnd: Color(hex: 0x12282A),
        dayWashStroke: Color(hex: 0x2A2848),
        tilePastels: [
            V3Palette.night.color(\.yellowWash),
            V3Palette.night.color(\.greenWash),
            V3Palette.night.color(\.accentWash),
            V3Palette.night.color(\.pinkWash),
            V3Palette.night.color(\.lilacWash),
            V3Palette.night.color(\.soft)
        ],
        keyword: Color(hex: 0xA78BFA),
        correct: V3Palette.night.color(\.green),
        correctInk: V3Palette.night.color(\.greenInk),
        correctSoft: V3Palette.night.color(\.greenWash),
        wrong: V3Palette.night.color(\.red),
        wrongInk: V3Palette.night.color(\.redInk),
        wrongSoft: V3Palette.night.color(\.redWash),
        tonePale: [
            V3Palette.night.color(\.yellowWash),
            V3Palette.night.color(\.greenWash),
            V3Palette.night.color(\.accentWash),
            V3Palette.night.color(\.pinkWash),
            V3Palette.night.color(\.lilacWash)
        ],
        toneVivid: [
            V3Palette.night.color(\.iconYellow),
            V3Palette.night.color(\.iconGreen),
            V3Palette.night.color(\.iconBlue),
            V3Palette.night.color(\.iconPink),
            V3Palette.night.color(\.iconLilac)
        ],
        toneInk: [
            V3Palette.night.color(\.yellowInk),
            V3Palette.night.color(\.greenInk),
            V3Palette.night.color(\.accentInk),
            V3Palette.night.color(\.pinkInk),
            V3Palette.night.color(\.lilacInk)
        ],
        toneGlyph: [
            V3Palette.night.color(\.iconYellow),
            V3Palette.night.color(\.iconGreen),
            V3Palette.night.color(\.iconBlue),
            V3Palette.night.color(\.iconPink),
            V3Palette.night.color(\.iconLilac)
        ],
        edge: V3Palette.night.color(\.line),
        onAccent: .white,
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
        accentInk: blend(day.accentInk, night.accentInk),
        accentDeep: blend(day.accentDeep, night.accentDeep),
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
        toneGlyph: zip(day.toneGlyph, night.toneGlyph).map { blend($0, $1) },
        edge: blend(day.edge, night.edge),
        onAccent: blend(day.onAccent, night.onAccent),
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

    /// Le thème appliqué. Il ne s'écrit que par `choose(_:)` : un thème posé au lancement
    /// n'est pas un choix, et ne doit pas en devenir un sur le disque.
    private(set) var appearance: MicaboAppearance

    private let defaults: UserDefaults

    var palette: MicaboPalette { .adaptive }

    /// Vrai quand l'écran qui se dessine en ce moment est en sombre.
    static var isDarkNow: Bool { UITraitCollection.current.userInterfaceStyle == .dark }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = MicaboAppearance.stored(in: defaults)
    }

    /// **L'élève choisit un thème dans le Profil** : appliqué tout de suite, et retenu comme
    /// un choix, qui ne sera plus jamais migré.
    func choose(_ mode: MicaboAppearance) {
        appearance = mode
        defaults.set(mode.rawValue, forKey: MicaboAppearance.choiceKey)
    }
}
