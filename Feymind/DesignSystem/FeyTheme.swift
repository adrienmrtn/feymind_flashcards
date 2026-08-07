import SwiftUI
import UIKit

/// Jetons de style de Feymind. Fond gris neutre, surfaces blanches, une seule couleur d'action : l'encre.
enum FeyColor {
    // Fonds
    static let canvas = Color(hex: 0xEFEFF1)
    static let surface = Color.white
    static let surfaceMuted = Color(hex: 0xF4F4F6)
    static let surfaceSunken = Color(hex: 0xE4E4E8)
    static let stroke = Color(hex: 0xE3E3E7)
    static let strokeStrong = Color(hex: 0xD3D3D9)

    // Encre
    static let ink = Color(hex: 0x121214)
    static let inkSecondary = Color(hex: 0x6B6B75)
    static let inkTertiary = Color(hex: 0x9B9BA4)

    // Sur fond sombre
    static let onInk = Color.white
    static let onInkMuted = Color(hex: 0xAFAFB8)

    // Retours d'information, volontairement désaturés
    static let positive = Color(hex: 0x2E7D63)
    static let caution = Color(hex: 0xA5762F)
    static let negative = Color(hex: 0xB1544E)
    static let info = Color(hex: 0x3C6A93)

    /// Teintes de couverture attribuées aux cours, lisibles avec du texte blanc.
    static let courseAccents: [Color] = [
        Color(hex: 0x2F4858),
        Color(hex: 0x3A5A40),
        Color(hex: 0x6B4E71),
        Color(hex: 0x8C5B3F),
        Color(hex: 0x2C4A6E),
        Color(hex: 0x545460),
        Color(hex: 0x7A4A52),
        Color(hex: 0x3F6B6B)
    ]
}

enum FeySpacing {
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

enum FeyRadius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 34
    static let pill: CGFloat = 999
}

enum FeyLayout {
    /// Hauteur de la barre d'onglets flottante.
    static let tabBarHeight: CGFloat = 62
    /// Espace à réserver en bas des écrans pour ne pas passer sous la barre.
    static let tabBarClearance: CGFloat = 104
    /// Espace à réserver au-dessus d'un bouton d'action ancré en bas.
    static let bottomBarClearance: CGFloat = 108
}

enum FeyFont {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    static let screenTitle = Font.system(size: 27, weight: .semibold)
    static let pageTitle = Font.system(size: 22, weight: .semibold)
    static let sectionTitle = Font.system(size: 18, weight: .semibold)
    static let cardTitle = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodyEmphasis = Font.system(size: 15, weight: .medium)
    static let caption = Font.system(size: 13, weight: .regular)
    static let captionEmphasis = Font.system(size: 13, weight: .medium)
    static let micro = Font.system(size: 11, weight: .medium)
}

enum FeyTracking {
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

struct FeyCardStyle: ViewModifier {
    var padding: CGFloat = FeySpacing.md
    var radius: CGFloat = FeyRadius.lg
    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(
                color: Color.black.opacity(elevated ? 0.05 : 0),
                radius: elevated ? 16 : 0,
                x: 0,
                y: elevated ? 8 : 0
            )
    }
}

extension View {
    func feyCard(padding: CGFloat = FeySpacing.md, radius: CGFloat = FeyRadius.lg, elevated: Bool = true) -> some View {
        modifier(FeyCardStyle(padding: padding, radius: radius, elevated: elevated))
    }

    /// Ombre douce des éléments posés sur le fond, sans passer par une carte complète.
    func feySoftShadow(strength: Double = 0.06) -> some View {
        shadow(color: Color.black.opacity(strength), radius: 16, x: 0, y: 8)
    }

    /// Applique le fond de l'application et masque le fond système du conteneur.
    func feyScreenBackground() -> some View {
        background(FeyColor.canvas.ignoresSafeArea())
    }
}
