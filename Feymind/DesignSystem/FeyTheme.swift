import SwiftUI
import UIKit

/// Jetons de style de Feymind. Palette claire, papier chaud, accent indigo.
enum FeyColor {
    // Fonds
    static let canvas = Color(hex: 0xFBFAF8)
    static let surface = Color.white
    static let surfaceMuted = Color(hex: 0xF4F2EE)
    static let surfaceSunken = Color(hex: 0xF0EEEA)
    static let stroke = Color(hex: 0xE8E4DC)
    static let strokeStrong = Color(hex: 0xD8D3C9)

    // Texte
    static let ink = Color(hex: 0x1A1A20)
    static let inkSecondary = Color(hex: 0x5B5B68)
    static let inkTertiary = Color(hex: 0x9797A5)

    // Accent
    static let accent = Color(hex: 0x5B54E8)
    static let accentDeep = Color(hex: 0x413AC4)
    static let accentSoft = Color(hex: 0xEEEDFE)
    static let accentTint = Color(hex: 0xDCD9FC)

    // Sémantique
    static let amber = Color(hex: 0xE8930C)
    static let amberSoft = Color(hex: 0xFDF1DC)
    static let mint = Color(hex: 0x11A97F)
    static let mintSoft = Color(hex: 0xDFF5EE)
    static let coral = Color(hex: 0xE05260)
    static let coralSoft = Color(hex: 0xFCE7E9)
    static let sky = Color(hex: 0x2C8FD6)
    static let skySoft = Color(hex: 0xE2F0FB)

    // Surlignage de texte dans les cours
    static let highlightYellow = Color(hex: 0xFFE9A8)
    static let highlightMint = Color(hex: 0xC9F0E1)
    static let highlightLilac = Color(hex: 0xE1DEFF)

    /// Couleurs d'accent attribuées aux cours.
    static let courseAccents: [Color] = [
        Color(hex: 0x5B54E8),
        Color(hex: 0x11A97F),
        Color(hex: 0xE8930C),
        Color(hex: 0xE05260),
        Color(hex: 0x2C8FD6),
        Color(hex: 0x9B51E0),
        Color(hex: 0xD6336C),
        Color(hex: 0x1F9E8F)
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
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let xl: CGFloat = 26
    static let pill: CGFloat = 999
}

enum FeyFont {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static let screenTitle = Font.system(size: 30, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 19, weight: .semibold, design: .rounded)
    static let cardTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular)
    static let bodyEmphasis = Font.system(size: 16, weight: .semibold)
    static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
    static let micro = Font.system(size: 11, weight: .semibold, design: .rounded)

    /// Corps de texte des cours : légèrement plus grand et plus aéré.
    static let courseBody = Font.system(size: 17, weight: .regular)
    static let courseH1 = Font.system(size: 26, weight: .bold, design: .rounded)
    static let courseH2 = Font.system(size: 21, weight: .bold, design: .rounded)
    static let courseH3 = Font.system(size: 18, weight: .semibold, design: .rounded)
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

    /// Décode `#RRGGBB` (ou `RRGGBB`) et retombe sur l'accent en cas d'échec.
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        if let value = UInt32(cleaned, radix: 16), cleaned.count == 6 {
            self.init(hex: value)
        } else {
            self.init(hex: 0x5B54E8)
        }
    }

    var hexString: String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        let red = Int((components.count > 0 ? components[0] : 0) * 255)
        let green = Int((components.count > 1 ? components[1] : 0) * 255)
        let blue = Int((components.count > 2 ? components[2] : 0) * 255)
        return String(format: "%02X%02X%02X", red, green, blue)
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
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(FeyColor.stroke, lineWidth: 1)
            }
            .shadow(
                color: elevated ? Color.black.opacity(0.045) : .clear,
                radius: elevated ? 14 : 0,
                x: 0,
                y: elevated ? 6 : 0
            )
    }
}

extension View {
    func feyCard(padding: CGFloat = FeySpacing.md, radius: CGFloat = FeyRadius.lg, elevated: Bool = true) -> some View {
        modifier(FeyCardStyle(padding: padding, radius: radius, elevated: elevated))
    }

    /// Applique le fond de l'application et masque le fond système du conteneur.
    func feyScreenBackground() -> some View {
        background(FeyColor.canvas.ignoresSafeArea())
    }
}
