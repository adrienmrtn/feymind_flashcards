import SwiftUI
import UIKit

/// **Les couleurs V3 : « franc, joueur, lumineux »** (lot 10).
///
/// Les valeurs du jour sont celles des maquettes (`base.css`) : une page BLANCHE, une encre
/// bleu-noir, un accent bleu, et quatre couleurs qui ont chacune un sens — jaune pour la série,
/// l'XP, la récompense et l'offre ; vert pour ce qui est juste ; rose-rouge pour ce qui est
/// faux ou en retard ; lilas pour le reste. La nuit garde le marine de Micabo et la même
/// hiérarchie : fond `#0B0F1C`, surfaces `#161B2B`, filets `#252B3E`.
///
/// Chaque jeton se résout au moment de peindre, selon l'apparence de l'écran qui le dessine.
///
/// **Trois rôles à ne pas confondre** pour un ton (accent, vert, jaune, rose, lilas) :
/// - le plein (`accent`, `green`…) : un aplat, une icône, un trait ;
/// - le lavis (`accentWash`, `greenWash`…) : un fond, sous du texte ;
/// - l'encre (`accentInk`, `greenInk`…) : du **texte** posé sur le lavis du même ton. Le jour,
///   `accentInk` vaut `accentDeep` ; la nuit, `accentDeep` reste la lèvre sombre du bouton, et
///   seule l'encre s'éclaircit — pour du texte, c'est donc toujours `…Ink`.
enum V3Color {
    // MARK: Fonds

    /// Le fond d'une page : blanc le jour.
    static let bg = adaptive(0xFFFFFF, 0x0B0F1C)
    /// Une carte, une ligne de réponse, une pastille : blanc le jour, un cran au-dessus du
    /// fond la nuit.
    static let surface = adaptive(0xFFFFFF, 0x161B2B)
    /// Le fond doux d'une bulle ou d'un champ.
    static let soft = adaptive(0xF5F7FB, 0x1E2436)
    /// Le filet : le bord de 2 pt d'une surface, et sa lèvre.
    static let line = adaptive(0xE3E8F2, 0x252B3E)
    /// Un gris plus soutenu : le cercle d'une coche vide, la lèvre d'un bouton éteint.
    static let lip = adaptive(0xCDD5E3, 0x343B54)

    // MARK: Encre

    static let ink = adaptive(0x12162A, 0xF4F6FC)
    static let ink2 = adaptive(0x5A6378, 0xA3AABD)
    static let ink3 = adaptive(0x9AA3B5, 0x6C7389)

    // MARK: Accent — agir, progresser

    static let accent = adaptive(0x3870FE, 0x5C88FF)
    /// La lèvre du bouton principal, et son état pressé.
    static let accentDeep = adaptive(0x1F47B8, 0x2F5BE0)
    static let accentWash = adaptive(0xEEF3FF, 0x131D38)
    static let accentWash2 = adaptive(0xDCE6FF, 0x1B2A55)
    /// Du texte sur un lavis d'accent : `#1F47B8` le jour, un bleu clair la nuit.
    static let accentInk = adaptive(0x1F47B8, 0x9DB7FF)

    // MARK: Jaune — série, XP, récompense, offre

    static let yellow = adaptive(0xF7B41F, 0xF7B41F)
    static let yellowWash = adaptive(0xFFF4D6, 0x33280C)
    static let yellowInk = adaptive(0x8A5A00, 0xF8CC5C)

    // MARK: Rose-rouge — faux, en retard

    static let pink = adaptive(0xE3596C, 0xF0707F)
    static let pinkWash = adaptive(0xFFE7EC, 0x3A1620)
    static let pinkInk = adaptive(0xB02A45, 0xF59BB0)

    // MARK: Vert — juste

    static let green = adaptive(0x1FB573, 0x22C083)
    static let greenWash = adaptive(0xDDF7EA, 0x0F3326)
    static let greenInk = adaptive(0x0B7A4B, 0x5DDBA4)

    // MARK: Lilas

    static let lilac = adaptive(0x8B6CF0, 0x9B7DF5)
    static let lilacWash = adaptive(0xEEE9FF, 0x2B2050)
    static let lilacInk = adaptive(0x5B3FC4, 0xBCA4FF)

    // MARK: Fonds pleins des stories — les mêmes le jour et la nuit

    static let storyBlue = Color(hex: 0x3870FE)
    static let storyYellow = Color(hex: 0xFFC531)
    static let storyCoral = Color(hex: 0xFF6B81)
    static let storyNavy = Color(hex: 0x12162A)

    /// Le texte posé sur un aplat d'accent : blanc, le jour comme la nuit.
    static let onAccent = Color.white

    // MARK: Fabrique

    /// Une couleur qui suit l'apparence : `day` en clair, `night` en sombre.
    static func adaptive(_ day: UInt32, _ night: UInt32) -> Color {
        let light = uiColor(day)
        let dark = uiColor(night)
        return Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    // MARK: Un ton quelconque

    /// **Le lavis d'un ton.** On peut lui donner un lavis (`greenWash`), qu'il rend tel quel,
    /// ou un plein (`green`), qu'il délaie sur la surface : une carte ou une pastille « dans
    /// un ton » se lit pareil, quel que soit celui des deux qu'on lui a passé.
    static func wash(of tone: Color) -> Color {
        let source = UIColor(tone)
        return Color(UIColor { traits in
            let resolved = source.resolvedColor(with: traits)
            guard isVivid(resolved) else { return resolved }
            let dark = traits.userInterfaceStyle == .dark
            return mix(uiColor(dark ? 0x161B2B : 0xFFFFFF), resolved, dark ? 0.22 : 0.14)
        })
    }

    /// **Le bord (et la lèvre) d'une surface teintée** : le lavis du ton, un cran plus
    /// soutenu — plus sombre le jour, plus clair la nuit.
    static func edge(of tone: Color) -> Color {
        let source = UIColor(tone)
        return Color(UIColor { traits in
            let resolved = source.resolvedColor(with: traits)
            let dark = traits.userInterfaceStyle == .dark
            if isVivid(resolved) {
                return mix(uiColor(dark ? 0x161B2B : 0xFFFFFF), resolved, dark ? 0.5 : 0.36)
            }
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            resolved.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            if dark {
                return UIColor(
                    hue: hue,
                    saturation: saturation * 0.9,
                    brightness: min(1, brightness + 0.16),
                    alpha: alpha
                )
            }
            return UIColor(
                hue: hue,
                saturation: min(1, saturation * 1.9 + 0.02),
                brightness: brightness * 0.95,
                alpha: alpha
            )
        })
    }

    /// Vrai pour un plein (saturé et lumineux), faux pour un lavis, un gris ou un ton sombre.
    private static func isVivid(_ color: UIColor) -> Bool {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return saturation > 0.4 && brightness > 0.5
    }

    private static func mix(_ base: UIColor, _ top: UIColor, _ amount: CGFloat) -> UIColor {
        var baseRed: CGFloat = 0
        var baseGreen: CGFloat = 0
        var baseBlue: CGFloat = 0
        var baseAlpha: CGFloat = 0
        var topRed: CGFloat = 0
        var topGreen: CGFloat = 0
        var topBlue: CGFloat = 0
        var topAlpha: CGFloat = 0
        base.getRed(&baseRed, green: &baseGreen, blue: &baseBlue, alpha: &baseAlpha)
        top.getRed(&topRed, green: &topGreen, blue: &topBlue, alpha: &topAlpha)
        return UIColor(
            red: baseRed + (topRed - baseRed) * amount,
            green: baseGreen + (topGreen - baseGreen) * amount,
            blue: baseBlue + (topBlue - baseBlue) * amount,
            alpha: 1
        )
    }
}

/// **Les mesures V3**, lues dans `base.css` (px = pt).
enum V3Metric {
    /// Marge horizontale d'un écran.
    static let screenMargin: CGFloat = 20
    /// Le bord de tout ce qui se touche.
    static let border: CGFloat = 2
    /// La lèvre d'une carte et d'une ligne de réponse.
    static let lip: CGFloat = 4
    /// La lèvre du bouton principal.
    static let buttonLip: CGFloat = 5
    /// La lèvre d'une puce.
    static let chipLip: CGFloat = 3

    static let buttonHeight: CGFloat = 58
    static let ghostHeight: CGFloat = 48
    static let optionHeight: CGFloat = 64
    static let chipHeight: CGFloat = 44

    /// Boutons et lignes de réponse.
    static let radiusButton: CGFloat = 18
    /// Bulle de Mika, champ de saisie.
    static let radiusBubble: CGFloat = 22
    /// Cartes.
    static let radiusCard: CGFloat = 24

    /// La pastille d'icône d'une ligne de réponse.
    static let badge: CGFloat = 40
    /// La coche ronde.
    static let check: CGFloat = 26

    static let topBarHeight: CGFloat = 44
    static let backSize: CGFloat = 40
    static let progressHeight: CGFloat = 10
}
