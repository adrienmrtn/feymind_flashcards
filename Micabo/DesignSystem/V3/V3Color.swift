import SwiftUI
import UIKit

/// **Les valeurs brutes de la direction artistique V3.3 — « marine, net, adulte »**, une table
/// par apparence (`mock11/base.css` : `:root` = marine, `.light` = thème clair).
///
/// C'est **le seul endroit de l'app où une couleur de la direction artistique s'écrit en
/// hexadécimal**. Tout le reste en est tiré :
/// - `V3Color` : les jetons adaptatifs que lisent les composants et les écrans V3 ;
/// - `MicaboPalette` (`MicaboColor`) : les jetons d'avant le lot 10, que lisent encore les
///   écrans qui n'ont pas été réécrits — ils pointent ici, champ par champ.
///
/// Changer une valeur ici change donc toute l'app, sans toucher un écran. Un test
/// (`Look10Tests`) tient les deux familles de jetons égales.
///
/// **Le marine est le thème par défaut** (`night`) ; le clair (`day`) est une option des
/// réglages, sur un fond teinté — jamais de blanc pur en fond de page.
struct V3Palette: Equatable {
    // Fonds
    var bg: UInt32
    var surface: UInt32
    /// La surface haute : ce qui se pose sur une surface (une pastille dans une carte).
    var soft: UInt32
    var line: UInt32
    /// Un filet plus soutenu : le cercle d'une case vide.
    var lip: UInt32
    // Encre
    var ink: UInt32
    var ink2: UInt32
    var ink3: UInt32
    // Accent — sélection, progression, mot-clé
    var accent: UInt32
    /// Le bleu clair : le mot-clé d'un titre ou d'une bulle.
    var accentBright: UInt32
    var accentDeep: UInt32
    var accentWash: UInt32
    var accentWash2: UInt32
    var accentInk: UInt32
    // Le bouton principal : une pilule blanche sur le marine, encre sur le clair
    var cta: UInt32
    var ctaLip: UInt32
    var ctaInk: UInt32
    // Jaune — « PRO », l'offre, la série, l'examen, la récompense
    var yellow: UInt32
    var yellowDeep: UInt32
    var yellowWash: UInt32
    var yellowInk: UInt32
    // Vert — juste, objectif, gratuit
    var green: UInt32
    var greenWash: UInt32
    var greenInk: UInt32
    // Rouge — faux, en retard seulement
    var red: UInt32
    var redWash: UInt32
    var redInk: UInt32
    // Rose, lilas, orange — les tons d'accompagnement
    var pink: UInt32
    var pinkWash: UInt32
    var pinkInk: UInt32
    var lilac: UInt32
    var lilacWash: UInt32
    var lilacInk: UInt32
    var orange: UInt32
    var orangeWash: UInt32
    var orangeInk: UInt32
    // Les sept teintes d'icône : une couleur par idée
    var iconBlue: UInt32
    var iconPink: UInt32
    var iconGreen: UInt32
    var iconYellow: UInt32
    var iconLilac: UInt32
    var iconOrange: UInt32
    var iconRed: UInt32

    /// **Le marine** : le thème par défaut de l'app.
    static let night = V3Palette(
        bg: 0x0B0F1C,
        surface: 0x171C2C,
        soft: 0x20263A,
        line: 0x262D42,
        lip: 0x3A4260,
        ink: 0xF5F6FB,
        ink2: 0xA9B1C6,
        ink3: 0x6E7791,
        accent: 0x5C88FF,
        accentBright: 0x7FA2FF,
        accentDeep: 0x3F6BE8,
        accentWash: 0x18224A,
        accentWash2: 0x22306A,
        accentInk: 0x7FA2FF,
        cta: 0xFFFFFF,
        ctaLip: 0xBFC6D9,
        ctaInk: 0x0B0F1C,
        yellow: 0xF7B41F,
        yellowDeep: 0xB07C08,
        yellowWash: 0x2B2412,
        yellowInk: 0xF7B41F,
        green: 0x34D399,
        greenWash: 0x0F2E26,
        greenInk: 0x34D399,
        red: 0xF87171,
        redWash: 0x3A1820,
        redInk: 0xFCA5A5,
        pink: 0xFF8FA8,
        pinkWash: 0x3A1A28,
        pinkInk: 0xFF8FA8,
        lilac: 0xA78BFA,
        lilacWash: 0x241D45,
        lilacInk: 0xC4B5FD,
        orange: 0xFB923C,
        orangeWash: 0x3A2210,
        orangeInk: 0xFDBA74,
        iconBlue: 0x60A5FA,
        iconPink: 0xF472B6,
        iconGreen: 0x34D399,
        iconYellow: 0xFBBF24,
        iconLilac: 0xA78BFA,
        iconOrange: 0xFB923C,
        iconRed: 0xF87171
    )

    /// **Le clair** : une option des réglages. Le fond est teinté ; les tons s'assombrissent
    /// pour rester lisibles sur du blanc.
    static let day = V3Palette(
        bg: 0xEEF1F8,
        surface: 0xFFFFFF,
        soft: 0xF4F6FB,
        line: 0xDCE1EC,
        lip: 0xC2C9D8,
        ink: 0x0F1324,
        ink2: 0x566078,
        ink3: 0x97A0B4,
        accent: 0x3870FE,
        accentBright: 0x3870FE,
        accentDeep: 0x1F47B8,
        accentWash: 0xE4ECFF,
        accentWash2: 0xD0DDFF,
        accentInk: 0x2452D0,
        cta: 0x0F1324,
        ctaLip: 0x000000,
        ctaInk: 0xFFFFFF,
        yellow: 0xF7B41F,
        yellowDeep: 0xB07C08,
        yellowWash: 0xFFF4D6,
        yellowInk: 0x8A5A00,
        green: 0x059669,
        greenWash: 0xDDF7EA,
        greenInk: 0x047857,
        red: 0xDC2626,
        redWash: 0xFFE7EC,
        redInk: 0xB91C1C,
        pink: 0xDB2777,
        pinkWash: 0xFFE4EF,
        pinkInk: 0xBE185D,
        lilac: 0x7C3AED,
        lilacWash: 0xEEE9FF,
        lilacInk: 0x6D28D9,
        orange: 0xF97316,
        orangeWash: 0xFFEDD5,
        orangeInk: 0xC2410C,
        iconBlue: 0x3870FE,
        iconPink: 0xDB2777,
        iconGreen: 0x059669,
        iconYellow: 0xD97706,
        iconLilac: 0x7C3AED,
        iconOrange: 0xF97316,
        iconRed: 0xDC2626
    )

    /// Les couleurs fixes : les mêmes dans les deux apparences.
    enum Fixed {
        /// Le texte posé sur le jaune : un brun très sombre.
        static let onYellow: UInt32 = 0x2A1D00
        /// Les fonds pleins des premières maquettes de stories, gardés pour qui les lit encore.
        static let storyBlue: UInt32 = 0x3870FE
        static let storyYellow: UInt32 = 0xFFC531
        static let storyCoral: UInt32 = 0xFF6B81
        static let storyNavy: UInt32 = 0x0B0F1C
    }

    /// La couleur fixe d'un champ de cette table (pour `MicaboPalette`, qui a ses deux tables).
    func color(_ token: KeyPath<V3Palette, UInt32>) -> Color {
        Color(hex: self[keyPath: token])
    }
}

/// **Les couleurs de la direction artistique** (V3.3, lot 10) : les jetons adaptatifs.
///
/// Chaque jeton se résout au moment de peindre, selon l'apparence de l'écran qui le dessine ;
/// ses deux valeurs viennent de `V3Palette.night` (le marine, par défaut) et `V3Palette.day`
/// (le clair). Aucun écran n'écrit une couleur en dur : il lit un jeton d'ici (ou un jeton
/// `MicaboColor`, qui en dérive).
///
/// **La couleur a un sens** : le **bleu clair** (`accentBright`) pour le mot-clé d'un titre ou
/// d'une bulle, et l'accent pour la sélection et la progression ; le **jaune** pour « PRO »,
/// l'offre, la série, l'examen, la récompense ; le vert pour ce qui est juste, l'objectif, le
/// gratuit ; le rouge pour ce qui est faux ou en retard seulement.
///
/// **Trois rôles à ne pas confondre** pour un ton :
/// - le plein (`accent`, `green`, `yellow`…) : un aplat, une icône, un trait, un grand texte ;
/// - le lavis (`accentWash`, `greenWash`…) : un fond, sous du texte ;
/// - l'encre (`accentInk`, `greenInk`, `yellowInk`…) : du **petit texte** posé sur le lavis du
///   même ton — c'est elle qui reste lisible en thème clair.
enum V3Color {
    // MARK: Fonds

    /// Le fond d'une page : marine par défaut, clair teinté en option.
    static let bg = adaptive(\.bg)
    /// Une carte, une ligne de réponse, une puce, la bulle de Mika.
    static let surface = adaptive(\.surface)
    /// La surface haute : ce qui se pose sur une surface.
    static let soft = adaptive(\.soft)
    /// Le filet de 1,5 pt d'une surface.
    static let line = adaptive(\.line)
    /// Un filet plus soutenu : le cercle d'une case vide.
    static let lip = adaptive(\.lip)

    // MARK: Encre

    static let ink = adaptive(\.ink)
    static let ink2 = adaptive(\.ink2)
    static let ink3 = adaptive(\.ink3)

    // MARK: Accent — sélection, progression, mot-clé

    static let accent = adaptive(\.accent)
    /// **Le bleu clair du mot-clé** : le groupe de mots qu'un titre ou une bulle fait ressortir
    /// (`V3Title`, `MikaAsk`), un chiffre ou un lien posé sur le marine.
    static let accentBright = adaptive(\.accentBright)
    /// L'ancien nom du bleu clair.
    static let accentHi = accentBright
    /// L'accent assombri : un état pressé, l'ombre du corps de Mika.
    static let accentDeep = adaptive(\.accentDeep)
    /// Le lavis d'une ligne ou d'une carte choisie.
    static let accentWash = adaptive(\.accentWash)
    static let accentWash2 = adaptive(\.accentWash2)
    /// Du petit texte sur un lavis d'accent.
    static let accentInk = adaptive(\.accentInk)

    // MARK: Le bouton principal

    /// Le fond du bouton principal : une pilule blanche sur le marine, encre sur le clair.
    /// `V3Button` et les boutons d'avant le lot 10 lisent ces trois jetons.
    static let cta = adaptive(\.cta)
    /// Sa lèvre, discrète.
    static let ctaLip = adaptive(\.ctaLip)
    /// Son texte.
    static let ctaInk = adaptive(\.ctaInk)

    // MARK: Jaune — « PRO », offre, série, examen, récompense

    /// **Le jaune** : la pastille « PRO », le bouton et le chiffre de l'offre, le compte à
    /// rebours de l'examen, la flamme d'un jour tenu. Un aplat, le même dans les deux thèmes ;
    /// pour du petit texte jaune sur son lavis, `yellowInk`.
    static let yellow = adaptive(\.yellow)
    /// La lèvre du bouton d'offre.
    static let yellowDeep = adaptive(\.yellowDeep)
    static let yellowWash = adaptive(\.yellowWash)
    /// Du petit texte sur le lavis jaune (la pastille de l'examen) : il s'assombrit en clair.
    static let yellowInk = adaptive(\.yellowInk)
    /// Le texte posé sur le jaune.
    static let onYellow = Color(hex: V3Palette.Fixed.onYellow)

    /// Les noms de la version précédente du jaune.
    static let pencil = yellow
    static let pencilDeep = yellowDeep
    static let pencilWash = yellowWash
    static let pencilInk = yellowInk
    static let pencilBright = yellow
    static let onPencil = onYellow

    // MARK: Vert — juste, objectif, gratuit

    static let green = adaptive(\.green)
    static let greenWash = adaptive(\.greenWash)
    static let greenInk = adaptive(\.greenInk)

    // MARK: Rouge — faux, en retard seulement

    static let red = adaptive(\.red)
    static let redWash = adaptive(\.redWash)
    static let redInk = adaptive(\.redInk)

    // MARK: Rose, lilas, orange

    static let pink = adaptive(\.pink)
    static let pinkWash = adaptive(\.pinkWash)
    static let pinkInk = adaptive(\.pinkInk)
    static let lilac = adaptive(\.lilac)
    static let lilacWash = adaptive(\.lilacWash)
    static let lilacInk = adaptive(\.lilacInk)
    static let orange = adaptive(\.orange)
    static let orangeWash = adaptive(\.orangeWash)
    static let orangeInk = adaptive(\.orangeInk)

    // MARK: Les teintes d'icône — une couleur par idée

    static let iconBlue = adaptive(\.iconBlue)
    static let iconPink = adaptive(\.iconPink)
    static let iconGreen = adaptive(\.iconGreen)
    static let iconYellow = adaptive(\.iconYellow)
    static let iconLilac = adaptive(\.iconLilac)
    static let iconOrange = adaptive(\.iconOrange)
    static let iconRed = adaptive(\.iconRed)

    // MARK: Fonds pleins des premières stories — les mêmes dans les deux apparences

    static let storyBlue = Color(hex: V3Palette.Fixed.storyBlue)
    static let storyYellow = Color(hex: V3Palette.Fixed.storyYellow)
    static let storyCoral = Color(hex: V3Palette.Fixed.storyCoral)
    static let storyNavy = Color(hex: V3Palette.Fixed.storyNavy)

    /// Le texte posé sur un aplat d'accent : blanc, dans les deux apparences.
    static let onAccent = Color.white

    // MARK: Fabrique

    /// Le jeton adaptatif d'un champ de `V3Palette`.
    static func adaptive(_ token: KeyPath<V3Palette, UInt32>) -> Color {
        adaptive(day: V3Palette.day[keyPath: token], night: V3Palette.night[keyPath: token])
    }

    /// Une couleur qui suit l'apparence : `day` en clair, `night` en marine.
    static func adaptive(day: UInt32, night: UInt32) -> Color {
        let light = uiColor(day)
        let dark = uiColor(night)
        return Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }

    /// La même, sans étiquettes : le clair d'abord, le marine ensuite.
    static func adaptive(_ day: UInt32, _ night: UInt32) -> Color {
        adaptive(day: day, night: night)
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// La surface de l'apparence donnée : ce sur quoi un ton se délaie.
    private static func surface(dark: Bool) -> UIColor {
        uiColor(dark ? V3Palette.night.surface : V3Palette.day.surface)
    }

    // MARK: Un ton quelconque

    /// **Le lavis d'un ton.** On peut lui donner un lavis (`greenWash`), qu'il rend tel quel,
    /// ou un plein (`green`), qu'il délaie sur la surface : une carte « dans un ton » se lit
    /// pareil, quel que soit celui des deux qu'on lui a passé.
    static func wash(of tone: Color) -> Color {
        let source = UIColor(tone)
        return Color(UIColor { traits in
            let resolved = source.resolvedColor(with: traits)
            guard isVivid(resolved) else { return resolved }
            let dark = traits.userInterfaceStyle == .dark
            return mix(surface(dark: dark), resolved, dark ? 0.18 : 0.12)
        })
    }

    /// **Le filet d'une surface teintée** : le ton, délayé un cran de moins que son lavis.
    static func edge(of tone: Color) -> Color {
        let source = UIColor(tone)
        return Color(UIColor { traits in
            let resolved = source.resolvedColor(with: traits)
            let dark = traits.userInterfaceStyle == .dark
            if isVivid(resolved) {
                return mix(surface(dark: dark), resolved, dark ? 0.5 : 0.4)
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
                    brightness: min(1, brightness + 0.18),
                    alpha: alpha
                )
            }
            return UIColor(
                hue: hue,
                saturation: min(1, saturation * 1.9 + 0.02),
                brightness: brightness * 0.94,
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

/// **Les mesures de la direction artistique** (V3.3), lues dans `mock11/base.css` (px = pt). Le seul endroit où elles
/// s'écrivent : `MicaboRadius`, `MicaboSurface` et `MicaboButtonMetrics` (les jetons d'avant le
/// lot 10) en sont tirés.
enum V3Metric {
    /// Marge horizontale d'un écran.
    static let screenMargin: CGFloat = 20
    /// Le filet d'une surface.
    static let border: CGFloat = 1.5
    /// La lèvre d'une carte, d'une ligne, d'une puce : aucune. Seuls les boutons pleins en ont une.
    static let lip: CGFloat = 0
    /// La lèvre d'un bouton plein : discrète, elle s'enfonce à l'appui.
    static let buttonLip: CGFloat = 4

    static let buttonHeight: CGFloat = 56
    static let ghostHeight: CGFloat = 44
    static let optionHeight: CGFloat = 58
    static let chipHeight: CGFloat = 44

    /// Une pastille, une petite tuile.
    static let radiusBadge: CGFloat = 12
    /// Une tuile d'icône, un champ dans une ligne.
    static let radiusTile: CGFloat = 14
    /// Une ligne de réponse, une tuile d'outil, un champ.
    static let radiusInner: CGFloat = 16
    /// La bulle de Mika.
    static let radiusBubble: CGFloat = 20
    /// Le petit coin de la bulle, du côté de Mika.
    static let radiusBubbleTail: CGFloat = 6
    /// Cartes.
    static let radiusCard: CGFloat = 22
    /// Coins d'une feuille modale.
    static let radiusSheet: CGFloat = 28
    /// Boutons et puces : des pilules.
    static let radiusPill: CGFloat = 999
    /// Le rayon d'un bouton : une pilule.
    static let radiusButton: CGFloat = radiusPill

    /// La lèvre d'une puce : aucune, depuis la V3.3.
    static let chipLip: CGFloat = 0
    /// Une pastille d'icône, quand un écran en pose une.
    static let badge: CGFloat = 40

    /// L'icône d'une ligne de réponse.
    static let optionIcon: CGFloat = 26
    /// La coche ronde d'une ligne choisie.
    static let check: CGFloat = 24
    /// Le petit Mika qui pose une question.
    static let mikaAsk: CGFloat = 76

    static let topBarHeight: CGFloat = 44
    static let backSize: CGFloat = 36
    static let progressHeight: CGFloat = 8
    /// La barre d'onglets (lot 11) : la pilule flottante de 60 pt et 8 pt d'air sous elle.
    static let tabBarHeight: CGFloat = 68
}
