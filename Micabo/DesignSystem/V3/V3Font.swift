import SwiftUI
import UIKit

/// **Les deux familles de caractères de l'app**, en un seul endroit (V3.3).
///
/// - **La police d'affichage** — titres d'écran, bulles de Mika, boutons, grands chiffres — est
///   **Sofia Sans Condensed**, en Black (ExtraBold pour un bouton secondaire). Elle est
///   embarquée (`Resources/Fonts`, `Info.plist`, `FontLoader`) et écrit le latin étendu, le
///   cyrillique et le grec. Un texte qu'elle ne sait pas écrire (l'arabe) retombe tout seul
///   sur la police système, glyphe par glyphe.
/// - **Le texte** — corps, libellés, lignes de réponse, légendes — est en **police système**
///   (SF Pro), aux styles de texte du système : c'est ce qui la fait suivre le réglage « Taille
///   du texte » du téléphone, et ce qui écrit toutes les langues de l'app sans fichier de plus.
///
/// Toute police de l'app passe par `V3Font`, qui lit ce type : changer une famille se fait ici.
enum V3Typeface {
    /// À partir de cette taille, un texte en gras est un titre : il prend la police d'affichage.
    static let titleThreshold: CGFloat = 19

    /// Les fichiers de la police d'affichage, sans extension : ceux que `FontLoader` enregistre
    /// et que `Info.plist` déclare.
    static let displayFiles = ["SofiaSansCondensed-ExtraBold", "SofiaSansCondensed-Black"]

    /// Le nom PostScript de la police d'affichage, à une graisse donnée. La famille embarquée
    /// n'a que deux graisses : Black, et ExtraBold pour tout ce qui est plus léger.
    static func displayName(for weight: Font.Weight) -> String {
        weight == .black ? "SofiaSansCondensed-Black" : "SofiaSansCondensed-ExtraBold"
    }

    /// Vrai pour les graisses d'un titre : demi-gras et au-delà.
    static func isStrong(_ weight: Font.Weight) -> Bool {
        weight == .semibold || weight == .bold || weight == .heavy || weight == .black
    }
}

/// **L'échelle typographique de l'app** (V3.3, lot 10), et la fabrique de toutes ses polices.
///
/// Titres en Sofia Sans Condensed Black : display 40 · h1 32 · h2 25 · bulle 24 · titre de
/// section 22 · titre de carte et bouton 21. Texte en police système : corps 16-17 (Medium,
/// Semibold), ligne de réponse 17 Bold, libellé 15 Bold, légende 13.
///
/// **Tout passe par ici** : les jetons ci-dessous, `heading` et `text` pour une police hors
/// échelle, et `legacy` pour les écrans d'avant le lot 10 (`MicaboFont.ui`). Changer l'échelle,
/// une graisse ou une famille se fait donc dans ce fichier, et nulle part ailleurs : un écran ne
/// nomme jamais une police.
///
/// Chaque police suit le réglage « Taille du texte » du téléphone. Le texte passe à la ligne ;
/// il ne se coupe pas.
enum V3Font {
    // MARK: Les titres — Sofia Sans Condensed

    /// Le titre d'une story, d'un écran de titre, d'un grand moment.
    static func display(_ size: CGFloat = 40) -> Font {
        heading(size, relativeTo: .largeTitle)
    }

    /// Titre de page.
    static let h1 = heading(32, relativeTo: .largeTitle)
    /// Titre d'un écran secondaire, d'une feuille.
    static let h2 = heading(25, relativeTo: .title)
    /// La bulle de Mika, un titre de carte mis en avant.
    static let title = heading(24, relativeTo: .title2)
    /// Titre de section (« Le parcours »).
    static let section = heading(22, relativeTo: .title2)
    /// Titre d'une carte dans une liste.
    static let cardTitle = heading(21, relativeTo: .title3)
    /// Le libellé du bouton principal.
    static let button = heading(21, relativeTo: .title3)
    /// Le libellé d'un bouton secondaire : un cran moins noir.
    static let buttonSecondary = heading(21, weight: .heavy, relativeTo: .title3)
    /// Le libellé d'un bouton discret (« Plus tard »).
    static let ghost = heading(18, weight: .heavy, relativeTo: .body)
    /// Un chiffre dans un en-tête (la série, l'XP), un prix.
    static let figure = heading(22, relativeTo: .title2)

    // MARK: Le texte — police système

    /// Le corps de ce qui compte : une ligne mise en avant.
    static let bodyStrong = text(.body, weight: .semibold)
    /// Le corps, la ligne de soutien sous un titre.
    static let body = text(.callout, weight: .medium)
    /// Libellé d'une puce, d'un lien, d'une tuile.
    static let label = text(.subheadline, weight: .bold)
    /// Légende.
    static let caption = text(.footnote, weight: .medium)
    /// Le texte d'une ligne de réponse.
    static let option = text(.body, weight: .bold)
    /// La ligne de soutien sous un titre de ligne ou de carte.
    static let support = text(.subheadline, weight: .medium)
    /// Un petit intitulé au-dessus d'un groupe.
    static let eyebrow = text(.footnote, weight: .semibold)
    /// Le texte long d'une leçon.
    static let reading = text(.body, weight: .regular)
    /// Le nom d'un onglet, dans la visionneuse en très grand texte : taille fixe.
    static let tab = Font.system(size: 11, weight: .bold)

    // MARK: La fabrique

    /// **Un titre** : Sofia Sans Condensed à la taille voulue (Black, sauf mention), l'interligne
    /// serré. Il grossit avec « Taille du texte », relativement au style donné.
    static func heading(_ size: CGFloat, weight: Font.Weight = .black, relativeTo style: Font.TextStyle? = nil) -> Font {
        Font.custom(V3Typeface.displayName(for: weight), size: size, relativeTo: style ?? textStyle(for: size))
            .leading(.tight)
    }

    /// **Du texte** : la police système, à un style du système et une graisse.
    static func text(_ style: Font.TextStyle, weight: Font.Weight = .medium) -> Font {
        .system(style, design: .default, weight: weight)
    }

    /// **La police la plus proche d'une taille** : un titre à partir de
    /// `V3Typeface.titleThreshold` quand la graisse est forte, sinon la police système au style
    /// le plus proche (elle n'existe qu'à ces tailles-là : 11, 12, 13, 15, 16, 17, 20…).
    static func custom(_ size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle? = nil) -> Font {
        if size >= V3Typeface.titleThreshold, V3Typeface.isStrong(weight) {
            return heading(size, weight: weight, relativeTo: style)
        }
        return text(style ?? textStyle(for: size), weight: weight)
    }

    /// **Une police demandée à l'ancienne échelle** (`MicaboFont.ui`, les écrans d'avant le
    /// lot 10) : `V3LegacyScale` dit si c'est un titre (Sofia, un cran plus grand) ou du texte
    /// (police système). Un écran neuf n'appelle pas cette fonction : il lit un jeton.
    static func legacy(_ size: CGFloat, weight: Font.Weight, reading: Bool = false) -> Font {
        if !reading, V3LegacyScale.isTitle(size: size, weight: weight) {
            let scaled = V3LegacyScale.titleSize(size)
            return heading(scaled, weight: V3LegacyScale.titleWeight(weight), relativeTo: textStyle(for: scaled))
        }
        return text(
            V3LegacyScale.textStyle(for: size),
            weight: reading ? V3LegacyScale.readingWeight(weight) : V3LegacyScale.textWeight(weight)
        )
    }

    /// Le style du système le plus proche d'une taille : c'est lui qui règle de combien elle
    /// grossit avec « Taille du texte ».
    static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 30...: .largeTitle
        case 24..<30: .title
        case 21..<24: .title2
        case 18.5..<21: .title3
        case 16.5..<18.5: .body
        case 15.5..<16.5: .callout
        case 13.75..<15.5: .subheadline
        case 12.75..<13.75: .footnote
        case 11.5..<12.75: .caption
        default: .caption2
        }
    }
}

/// **De l'ancienne échelle à celle d'aujourd'hui.**
///
/// Les écrans d'avant le lot 10 demandent leurs polices par une taille et une graisse
/// (`MicaboFont.ui(14, weight: .medium)`), réglées pour une app tout en Nunito ronde. La
/// correspondance vit ici, en un seul endroit, plutôt que dans cinq cents appels.
///
/// - **Un titre** (19 points et plus, en gras) passe en Sofia Sans Condensed Black, un dixième
///   plus grand : une condensée paraît plus petite qu'une ronde à taille égale.
/// - **Le reste** passe en police système, au style le plus proche. La police système lit plus
///   grand que Nunito à taille égale : 13 points système valent 14 points d'avant.
enum V3LegacyScale {
    /// Vrai si l'ancienne demande était un titre : assez grand, et en gras.
    static func isTitle(size: CGFloat, weight: Font.Weight) -> Bool {
        size >= V3Typeface.titleThreshold && V3Typeface.isStrong(weight)
    }

    /// La taille Sofia d'un ancien titre : un dixième de plus, sauf les très grands chiffres,
    /// qui tiennent déjà leur place.
    static func titleSize(_ size: CGFloat) -> CGFloat {
        size >= 40 ? size : (size * 1.1).rounded()
    }

    /// La graisse d'un ancien titre : Black, sauf un demi-gras, qui reste un cran en dessous.
    static func titleWeight(_ weight: Font.Weight) -> Font.Weight {
        weight == .semibold ? .heavy : .black
    }

    /// Le style système d'un ancien texte.
    static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: .caption2
        case 11.5..<13: .caption
        case 13..<14: .footnote
        case 14..<16: .subheadline
        case 16..<17: .callout
        case 17..<19: .body
        case 19..<21: .title3
        case 21..<26: .title2
        case 26..<32: .title
        default: .largeTitle
        }
    }

    /// La graisse système d'un ancien texte d'interface : le Regular de Nunito devient le
    /// Medium du corps, et rien ne dépasse le Heavy.
    static func textWeight(_ weight: Font.Weight) -> Font.Weight {
        if weight == .black { return .heavy }
        if V3Typeface.isStrong(weight) || weight == .medium { return weight }
        return .medium
    }

    /// La graisse d'un texte **long** (une fiche, des notes) : telle quelle, le Regular compris.
    static func readingWeight(_ weight: Font.Weight) -> Font.Weight {
        weight == .black ? .heavy : weight
    }
}

/// L'interlettrage des titres (`mock11/base.css`) : à peine resserré, la condensée l'est déjà.
enum V3Tracking {
    static let display: CGFloat = -0.2
    static let h1: CGFloat = -0.1
    static let h2: CGFloat = 0
    static let title: CGFloat = 0
    static let button: CGFloat = 0.1

    /// L'interlettrage d'un titre de cette taille.
    static func heading(_ size: CGFloat) -> CGFloat {
        switch size {
        case 36...: display
        case 28..<36: h1
        default: h2
        }
    }
}
