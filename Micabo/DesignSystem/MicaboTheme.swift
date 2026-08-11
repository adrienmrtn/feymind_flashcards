import SwiftUI
import UIKit

/// Jetons de style de Micabo. Fond ivoire chaud, surfaces blanches, encre presque noire,
/// un accent indigo pour les liens et éléments interactifs secondaires.
enum MicaboColor {
    // Fonds
    static let canvas = Color(hex: 0xFAF9F6)
    static let surface = Color.white
    static let surfaceMuted = Color(hex: 0xF2EFE8)
    static let surfaceSunken = Color(hex: 0xE4DFD5)
    static let stroke = Color(hex: 0xEEE7DB)
    static let strokeStrong = Color(hex: 0xDDD7CB)

    // Encre
    static let ink = Color(hex: 0x1A1917)
    static let inkSecondary = Color(hex: 0x8A857B)
    static let inkTertiary = Color(hex: 0xB3ADA2)

    // Sur fond sombre
    static let onInk = Color(hex: 0xFAF9F6)
    static let onInkMuted = Color(hex: 0x9A958A)

    /// Accent unique de l'app : liens, sélections, éléments interactifs secondaires.
    static let accent = Color(hex: 0x5B5BD6)

    // Retours d'information, volontairement désaturés
    static let positive = Color(hex: 0x4D7A53)
    static let caution = Color(hex: 0x9A7A2E)
    static let negative = Color(hex: 0xC0392B)
    static let info = Color(hex: 0x4A4AC0)

    // Fonds doux assortis, utilisés pour les états de notation en session.
    static let positiveSoft = Color(hex: 0xE6EFE4)
    static let cautionSoft = Color(hex: 0xF4ECD9)
    static let negativeSoft = Color(hex: 0xF7E7E2)
    static let infoSoft = Color(hex: 0xE7E7F5)

    /// Teintes de couverture attribuées aux cours, lisibles avec du texte blanc.
    static let courseAccents: [Color] = [
        Color(hex: 0x47665A),
        Color(hex: 0x6B5548),
        Color(hex: 0x4F5A72),
        Color(hex: 0x6E5566),
        Color(hex: 0x5B5BD6),
        Color(hex: 0x8C6A3F),
        Color(hex: 0x4A6741),
        Color(hex: 0x5C4A66)
    ]
}

enum MicaboSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 40

    /// Marge horizontale standard des écrans.
    static let screen: CGFloat = 20
}

enum MicaboRadius {
    /// Couvertures miniatures (52×66 dans la maquette).
    static let cover: CGFloat = 9
    static let sm: CGFloat = 12
    /// Boutons CTA principaux (`.cta` dans la maquette).
    static let button: CGFloat = 14
    static let md: CGFloat = 16
    /// Cartes d'appel (accueil, stats).
    static let card: CGFloat = 18
    static let lg: CGFloat = 18
    static let xl: CGFloat = 22
    static let xxl: CGFloat = 24
    static let pill: CGFloat = 999
}

enum MicaboLayout {
    /// Espace à réserver au-dessus d'un bouton d'action ancré en bas.
    static let bottomBarClearance: CGFloat = 108
    /// Espace sous le FAB flottant de l'accueil.
    static let fabClearance: CGFloat = 88
}

/// Typographie de l'app : Hanken Grotesk, embarquée et enregistrée par `FontLoader`.
enum MicaboFont {
    /// Retombe sur la police système si Hanken Grotesk n'a pas pu être enregistrée
    /// (aperçus SwiftUI notamment, où le bundle de test n'est pas toujours celui de l'app).
    static func hanken(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(postscriptName(for: weight), size: size)
    }

    private static func postscriptName(for weight: Font.Weight) -> String {
        if weight == .bold || weight == .heavy || weight == .black {
            return "HankenGrotesk-Bold"
        }
        if weight == .semibold {
            return "HankenGrotesk-SemiBold"
        }
        if weight == .medium {
            return "HankenGrotesk-Medium"
        }
        return "HankenGrotesk-Regular"
    }

    static func display(_ size: CGFloat) -> Font {
        hanken(size, weight: .bold)
    }

    static let screenTitle = hanken(27, weight: .bold)
    static let pageTitle = hanken(22, weight: .bold)
    static let sectionTitle = hanken(18, weight: .semibold)
    static let cardTitle = hanken(16, weight: .semibold)
    static let body = hanken(15, weight: .regular)
    static let bodyEmphasis = hanken(15, weight: .medium)
    static let caption = hanken(13, weight: .regular)
    static let captionEmphasis = hanken(13, weight: .medium)
    static let micro = hanken(11, weight: .medium)
}

enum MicaboTracking {
    /// Resserrement appliqué aux grands titres.
    static let tight: CGFloat = -0.5
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Décode `#RRGGBB` (ou `RRGGBB`) et retombe sur la première teinte de cours en cas d'échec.
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        if let value = UInt32(cleaned, radix: 16), cleaned.count == 6 {
            self.init(hex: value)
        } else {
            self.init(hex: 0x2F4858)
        }
    }

    var hexString: String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        let red = Int((components.count > 0 ? components[0] : 0) * 255)
        let green = Int((components.count > 1 ? components[1] : 0) * 255)
        let blue = Int((components.count > 2 ? components[2] : 0) * 255)
        return String(format: "%02X%02X%02X", red, green, blue)
    }

    /// Mélange avec du blanc : utilisé pour dériver un fond pastel à partir d'une teinte de cours.
    func lightened(by amount: Double) -> Color {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let amount = CGFloat(amount)
        return Color(
            red: red + (1 - red) * amount,
            green: green + (1 - green) * amount,
            blue: blue + (1 - blue) * amount,
            opacity: alpha
        )
    }

    func darkened(by amount: Double) -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(max(0, brightness * CGFloat(1 - amount))),
            opacity: Double(alpha)
        )
    }
}

// MARK: - Modificateurs partagés

struct MicaboCardStyle: ViewModifier {
    var padding: CGFloat = MicaboSpacing.md
    var radius: CGFloat = MicaboRadius.card
    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                if !elevated {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(MicaboColor.stroke, lineWidth: 1)
                }
            }
            .shadow(
                color: Color.black.opacity(elevated ? 0.05 : 0),
                radius: elevated ? 12 : 0,
                x: 0,
                y: elevated ? 6 : 0
            )
    }
}

extension View {
    func micaboCard(padding: CGFloat = MicaboSpacing.md, radius: CGFloat = MicaboRadius.card, elevated: Bool = true) -> some View {
        modifier(MicaboCardStyle(padding: padding, radius: radius, elevated: elevated))
    }

    /// Ombre douce des éléments posés sur le fond, sans passer par une carte complète.
    func micaboSoftShadow(strength: Double = 0.06) -> some View {
        shadow(color: Color.black.opacity(strength), radius: 16, x: 0, y: 8)
    }

    /// Applique le fond de l'application et masque le fond système du conteneur.
    func micaboScreenBackground() -> some View {
        background(MicaboColor.canvas.ignoresSafeArea())
    }
}
