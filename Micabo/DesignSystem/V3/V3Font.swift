import SwiftUI

/// **L'échelle typographique V3** : Nunito, affirmée (lot 10).
///
/// display 38 Black · h1 32 Black · h2 26 Black · titre de carte ou de bulle 22 Black · corps 17
/// (SemiBold, ExtraBold pour ce qui se touche) · libellé 15 ExtraBold · légende 13 Bold. Rien
/// d'utile sous 13 pt.
///
/// Chaque taille suit le réglage « Taille du texte » du téléphone, relativement au style du
/// système le plus proche : un titre grossit moins vite que le corps, pour qu'un h1 tienne
/// encore sur 375 pt en très grand texte. Le texte passe à la ligne ; il ne se coupe pas.
enum V3Font {
    /// Le titre d'une story ou d'un grand moment.
    static func display(_ size: CGFloat = 38) -> Font {
        .custom(black, size: size, relativeTo: .largeTitle)
    }

    /// Titre de page.
    static let h1 = Font.custom(black, size: 32, relativeTo: .largeTitle)
    /// Titre d'un écran secondaire, d'une feuille.
    static let h2 = Font.custom(black, size: 26, relativeTo: .title)
    /// Titre de carte, de bulle, de section.
    static let title = Font.custom(black, size: 22, relativeTo: .title2)
    /// Le corps de ce qui se touche.
    static let bodyStrong = Font.custom(extraBold, size: 17, relativeTo: .body)
    /// Le corps.
    static let body = Font.custom(semiBold, size: 17, relativeTo: .body)
    /// Libellé d'une puce, d'un lien, d'un bouton discret.
    static let label = Font.custom(extraBold, size: 15, relativeTo: .subheadline)
    /// Légende : le plus petit texte utile.
    static let caption = Font.custom(bold, size: 13, relativeTo: .footnote)

    // MARK: Les rôles des composants

    /// Le libellé du bouton principal.
    static let button = Font.custom(black, size: 18, relativeTo: .body)
    /// Le libellé d'un bouton discret (« Plus tard »).
    static let ghost = Font.custom(extraBold, size: 18, relativeTo: .body)
    /// Le texte d'une ligne de réponse.
    static let option = Font.custom(extraBold, size: 18, relativeTo: .body)
    /// La ligne de soutien sous un titre de ligne ou de carte.
    static let support = Font.custom(bold, size: 14, relativeTo: .subheadline)
    /// Le libellé d'un onglet.
    static let tab = Font.custom(extraBold, size: 11, relativeTo: .caption2)

    /// Nunito à la taille et à la graisse voulues, qui suit la taille du texte du téléphone.
    static func custom(_ size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(MicaboFont.nunitoName(for: weight), size: size, relativeTo: style)
    }

    private static let black = MicaboFont.nunitoName(for: .black)
    private static let extraBold = MicaboFont.nunitoName(for: .heavy)
    private static let bold = MicaboFont.nunitoName(for: .bold)
    private static let semiBold = MicaboFont.nunitoName(for: .semibold)
}

/// L'interlettrage serré des titres V3.
enum V3Tracking {
    static let display: CGFloat = -0.8
    static let h1: CGFloat = -0.6
    static let h2: CGFloat = -0.4
    static let title: CGFloat = -0.3
}
