import SwiftUI
import UIKit

/// Jetons de style de Micabo.
///
/// Direction : du papier, pas des cartes empilées. Le fond est un ivoire chaud assez
/// marqué pour que les surfaces blanches se détachent seules, sans bordure ni ombre
/// portée. Les listes sont soit posées à même le fond et séparées par un filet, soit
/// regroupées dans un bloc blanc à grands coins. Chaque rangée porte une tuile pastel
/// (emoji ou symbole) qui donne la couleur de l'écran ; l'indigo reste réservé à ce
/// qui est actif ou sélectionné.
enum MicaboColor {
    // Fonds
    static let canvas = Color(hex: 0xF6F4ED)
    static let surface = Color.white
    static let surfaceMuted = Color(hex: 0xEFEBE1)
    static let surfaceSunken = Color(hex: 0xE2DDD0)
    static let stroke = Color(hex: 0xE9E4D7)
    static let strokeStrong = Color(hex: 0xDAD4C5)

    /// Filet de séparation entre deux rangées, dans un bloc blanc ou sur le fond.
    static let hairline = Color(hex: 0xEDEAE2)
    static let hairlineOnCanvas = Color(hex: 0xE6E1D4)

    // Encre
    static let ink = Color(hex: 0x191714)
    static let inkSecondary = Color(hex: 0x6F6A60)
    static let inkTertiary = Color(hex: 0xA6A199)

    /// Encre des longs paragraphes d'une fiche. Un noir de titre tenu sur trente lignes
    /// fatigue : celui-ci est à peine remonté vers le brun du papier.
    static let inkReading = Color(hex: 0x2B2822)

    /// Le surligneur de la fiche. Il est jaune parce qu'un surligneur est jaune, et
    /// surtout parce que l'indigo est réservé à ce qui est actif : un passage surligné
    /// est du contenu, pas un état.
    static let marker = Color(hex: 0xFBEFB8)

    // Sur fond sombre
    static let onInk = Color(hex: 0xF8F6F0)
    static let onInkMuted = Color(hex: 0x9A958A)

    /// Accent unique de l'app : sélection, onglet actif, éléments interactifs.
    static let accent = Color(hex: 0x5B5BD6)
    static let accentSoft = Color(hex: 0xE9E9FB)

    /// Toute progression porte cette couleur, sans exception : jauge du parcours
    /// d'accueil, barre de session, anneaux, curseurs, indicateurs d'attente.
    /// Une seule couleur pour « ça avance », sinon l'utilisateur cherche un sens
    /// derrière chaque nuance.
    static let progress = accent
    static let progressTrack = Color(hex: 0xE4DFD2)

    // Retours d'information, volontairement désaturés
    static let positive = Color(hex: 0x4D7A53)
    static let caution = Color(hex: 0x9A7A2E)
    static let negative = Color(hex: 0xC0392B)
    static let info = Color(hex: 0x4A4AC0)

    // Fonds doux assortis : notation en session, pastilles d'état.
    static let positiveSoft = Color(hex: 0xE6EFE4)
    static let cautionSoft = Color(hex: 0xF6EEDA)
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

    /// Pastels des tuiles d'icône, quand aucune teinte de cours n'est disponible.
    static let tilePastels: [Color] = [
        Color(hex: 0xEDEAF7),
        Color(hex: 0xE7EFE9),
        Color(hex: 0xF5ECE3),
        Color(hex: 0xE8EDF3),
        Color(hex: 0xF3E9EE),
        Color(hex: 0xF1EFE0)
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
    /// Tuile pastel d'une rangée : carré arrondi, emoji ou symbole au centre.
    static let tile: CGFloat = 13
    /// Même valeur que la tuile, pour les vignettes du parcours d'accueil.
    static let cover: CGFloat = 13
    static let sm: CGFloat = 12
    /// Boutons CTA principaux.
    static let button: CGFloat = 16
    static let md: CGFloat = 16
    static let lg: CGFloat = 18
    /// Bloc blanc regroupant plusieurs rangées, et cartes d'appel.
    static let group: CGFloat = 20
    static let card: CGFloat = 20
    static let xl: CGFloat = 22
    static let xxl: CGFloat = 26
    /// Coins des feuilles modales.
    static let sheet: CGFloat = 28
    static let pill: CGFloat = 999
}

enum MicaboLayout {
    /// Espace à réserver au-dessus d'un bouton d'action ancré en bas.
    static let bottomBarClearance: CGFloat = 108
}

/// Typographie de l'app : Hanken Grotesk, embarquée et enregistrée par `FontLoader`.
enum MicaboFont {
    /// Retombe sur la police système si Hanken Grotesk n'a pas pu être enregistrée
    /// (aperçus SwiftUI notamment, où le bundle de test n'est pas toujours celui de l'app).
    static func hanken(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(postscriptName(for: weight), size: size)
    }

    /// La même police, côté UIKit : la fiche compose ses paragraphes dans un `UITextView`
    /// pour que la sélection d'un passage soit celle du système, et il lui faut donc des
    /// `UIFont`. Hanken Grotesk n'embarque pas d'italique : elle est penchée à la main,
    /// ce qui reste préférable à un changement de famille en plein paragraphe.
    static func uiFont(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> UIFont {
        let name = postscriptName(for: weight)
        let fallback = UIFont.systemFont(ofSize: size, weight: uiWeight(for: weight))

        guard italic else {
            return UIFont(name: name, size: size) ?? fallback
        }

        guard UIFont(name: name, size: size) != nil else {
            return UIFont(descriptor: fallback.fontDescriptor.withSymbolicTraits(.traitItalic) ?? fallback.fontDescriptor, size: size)
        }

        let descriptor = UIFontDescriptor(fontAttributes: [.name: name, .size: size])
            .withMatrix(CGAffineTransform(a: 1, b: 0, c: SheetTypography.obliqueSlant, d: 1, tx: 0, ty: 0))
        return UIFont(descriptor: descriptor, size: 0)
    }

    private static func uiWeight(for weight: Font.Weight) -> UIFont.Weight {
        if weight == .bold || weight == .heavy || weight == .black { return .bold }
        if weight == .semibold { return .semibold }
        if weight == .medium { return .medium }
        return .regular
    }

    static func postscriptName(for weight: Font.Weight) -> String {
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

    /// Grand titre d'écran, posé à même le fond sous son sur-titre.
    static let screenTitle = hanken(32, weight: .bold)
    static let pageTitle = hanken(22, weight: .bold)
    static let sectionTitle = hanken(18, weight: .semibold)
    static let cardTitle = hanken(16, weight: .semibold)
    static let rowTitle = hanken(15, weight: .semibold)
    static let rowSubtitle = hanken(13, weight: .regular)
    static let body = hanken(15, weight: .regular)
    static let bodyEmphasis = hanken(15, weight: .medium)
    static let caption = hanken(13, weight: .regular)
    static let captionEmphasis = hanken(13, weight: .medium)
    static let micro = hanken(11, weight: .medium)
    /// Sur-titres et intitulés de section, toujours en capitales.
    static let eyebrow = hanken(11, weight: .semibold)
}

/// Le réglage typographique de la fiche d'un cours.
///
/// C'est le seul endroit de l'app où l'on lit vraiment : les autres écrans sont des listes
/// et des rangées. Une fiche demande donc un corps plus grand, un interligne plus généreux
/// et une largeur de colonne tenue, faute de quoi l'œil se perd d'une ligne à l'autre.
enum SheetTypography {
    /// Corps du texte courant.
    static let body: CGFloat = 16.5
    /// Interligne ajouté aux paragraphes.
    static let lineSpacing: CGFloat = 7.5
    /// Chapeau posé sous le titre du cours.
    static let lead: CGFloat = 17.5
    /// Titre de partie.
    static let headingLarge: CGFloat = 22
    /// Titre de sous-partie.
    static let headingSmall: CGFloat = 16.5
    /// Formule mise en valeur dans son bloc.
    static let formula: CGFloat = 20

    /// Espace au-dessus d'un titre de partie, et d'un titre de sous-partie.
    static let spaceBeforeLargeHeading: CGFloat = 26
    static let spaceBeforeSmallHeading: CGFloat = 16
    /// Espace entre deux blocs de même nature.
    static let blockSpacing: CGFloat = 15

    /// Inclinaison de l'italique synthétique, Hanken Grotesk n'ayant pas de fonte penchée.
    static let obliqueSlant: CGFloat = 0.19
}

enum MicaboTracking {
    /// Resserrement appliqué aux grands titres.
    static let tight: CGFloat = -0.5
    /// Resserrement des très grands chiffres et titres d'écran.
    static let display: CGFloat = -0.9
    /// Écartement des textes en capitales.
    static let caps: CGFloat = 1.1
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

/// Surface blanche posée sur le fond ivoire. Le contraste des deux fonds suffit :
/// pas de bordure, et une ombre presque invisible juste pour décoller le bloc.
struct MicaboCardStyle: ViewModifier {
    var padding: CGFloat = MicaboSpacing.md
    var radius: CGFloat = MicaboRadius.card
    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(
                color: Color.black.opacity(elevated ? 0.04 : 0.02),
                radius: elevated ? 14 : 6,
                x: 0,
                y: elevated ? 7 : 2
            )
    }
}

extension View {
    func micaboCard(padding: CGFloat = MicaboSpacing.md, radius: CGFloat = MicaboRadius.card, elevated: Bool = true) -> some View {
        modifier(MicaboCardStyle(padding: padding, radius: radius, elevated: elevated))
    }

    /// Bloc blanc qui regroupe des rangées, à la manière d'une liste encartée.
    /// Le contenu gère ses propres marges pour que les filets aillent d'un bord à l'autre.
    func micaboGroup(radius: CGFloat = MicaboRadius.group) -> some View {
        background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
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

/// Filet de séparation d'une rangée à l'autre. L'entaille de gauche s'aligne
/// sur le texte, pas sur la tuile, comme dans les listes iOS.
struct MicaboHairline: View {
    var inset: CGFloat = 0
    var onCanvas: Bool = false

    var body: some View {
        Rectangle()
            .fill(onCanvas ? MicaboColor.hairlineOnCanvas : MicaboColor.hairline)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}
