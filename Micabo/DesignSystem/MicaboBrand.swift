import SwiftUI

/// **Les couleurs de la marque Micabo**, telles que le kit les définit
/// (`design/micabo-kit-mika/marque/tokens.json`).
///
/// Ce sont des constantes : elles ne changent pas avec le thème. Les jetons de l'interface
/// (`MicaboColor`) en dérivent — l'accent est le bleu Micabo — et ajustent la nuit pour rester
/// lisibles. Ici, on trouve ce qui doit rester exactement la marque : la pastille de Mika,
/// le dégradé de marque, le jaune du crayon pour un petit accent, le rose de la gomme.
enum MicaboBrand {
    /// Bleu Micabo : le fond de l'icône, la couleur principale.
    static let blue = Color(hex: 0x3870FE)
    /// Noir Mika : le corps de la mascotte.
    static let ink = Color(hex: 0x050507)
    /// Jaune crayon : un accent, **avec parcimonie** (XP, série, une étoile).
    static let pencil = Color(hex: 0xF7B41F)
    /// Rose gomme : l'accent secondaire, les erreurs douces.
    static let eraser = Color(hex: 0xE3596C)
    /// Graphite : un gris d'encre chaud.
    static let graphite = Color(hex: 0x2E303B)

    /// La gamme de bleus calculée à partir du bleu Micabo (500).
    static let blue50 = Color(hex: 0xEFF4FF)
    static let blue100 = Color(hex: 0xDFE8FF)
    static let blue200 = Color(hex: 0xBBCEFF)
    static let blue300 = Color(hex: 0x90AFFE)
    static let blue400 = Color(hex: 0x608DFE)
    static let blue500 = blue
    static let blue600 = Color(hex: 0x2F5ED5)
    static let blue700 = Color(hex: 0x264CAD)
    static let blue800 = Color(hex: 0x1C387F)
    static let blue900 = Color(hex: 0x132656)

    /// Les fonds de l'écran de lancement (aussi dans `LaunchBackground.colorset`).
    static let launchLight = Color.white
    static let launchDark = Color(hex: 0x0B0D14)

    /// **Le dégradé de marque**, en aplat sous du texte blanc : du bleu Micabo au 700.
    /// Il remplace l'ancien bleu → violet : une seule teinte, un seul monde.
    static let gradientColors: [Color] = [blue500, blue700]
    static var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
