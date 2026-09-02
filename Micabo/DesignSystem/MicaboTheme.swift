import SwiftUI
import UIKit

/// Jetons de style de Micabo.
///
/// Direction : blanc sur gris, avec du bleu pour ce qui est actif. Le fond est le
/// gris groupé d'iOS ; les surfaces sont blanches. Les listes sont soit posées à
/// même le fond et séparées par un filet, soit regroupées dans un bloc blanc.
/// L'accent bleu est réservé à ce qui est actif ou sélectionné.
///
/// Deux bleus, et la distinction compte : `accent` est assez sombre pour porter du
/// texte de onze points sur un fond pastel, `accentVivid` ne sert qu'aux surfaces
/// sur lesquelles rien n'est écrit — jauges, barres, remplissages.
enum MicaboColor {
    // Fonds
    static let canvas = Color(hex: 0xF2F4F7)
    static let surface = Color.white
    static let surfaceMuted = Color(hex: 0xE8ECF1)
    static let surfaceSunken = Color(hex: 0xDEE3EA)
    static let stroke = Color(hex: 0xE5E7EB)
    static let strokeStrong = Color(hex: 0xD1D5DB)

    /// Filet de séparation entre deux rangées, dans un bloc blanc ou sur le fond.
    static let hairline = Color(hex: 0xE5E7EB)
    static let hairlineOnCanvas = Color(hex: 0xD8DCE3)

    // Encre
    static let ink = Color(hex: 0x111827)
    static let inkSecondary = Color(hex: 0x6B7280)
    static let inkTertiary = Color(hex: 0x6B7280)

    /// Encre des longs paragraphes d'une fiche. Un noir de titre tenu sur trente lignes
    /// fatigue : celui-ci est un cran plus doux, sans retomber dans le brun.
    static let inkReading = Color(hex: 0x1F2937)

    /// Encre des versos de carte et des puces non sélectionnées.
    static let inkBody = Color(hex: 0x4B5563)

    /// La couleur des passages que la fiche met en avant.
    ///
    /// **Le surligneur jaune a été retiré.** Un fond posé derrière le texte se battait avec
    /// lui : la bande débordait sous les jambages, changeait d'épaisseur d'une ligne à
    /// l'autre, et sur un paragraphe à interligne serré elle écrasait ce qu'elle voulait
    /// mettre en valeur. Un `NSLayoutManager` entier ne servait qu'à en arrondir les coins.
    ///
    /// C'est maintenant la couleur du texte lui-même. Un bleu plus dense que l'accent,
    /// parce qu'un mot en couleur au milieu d'un paragraphe doit se voir sans qu'on le
    /// cherche, et rester lisible à quatorze points sur le gris.
    static let sheetEmphasis = Color(hex: 0x1D4ED8)

    // Sur fond sombre
    static let onInk = Color.white
    static let onInkMuted = Color(hex: 0x9CA3AF)

    /// Fond des écrans qui ne sont ni une liste ni une lecture. Même gris que `canvas` :
    /// plus de papier teinté.
    static let canvasSage = canvas

    /// Accent unique de l'app : sélection, onglet actif, éléments interactifs.
    ///
    /// Assez sombre pour qu'une pastille de onze points reste lisible sur `accentSoft`.
    static let accent = Color(hex: 0x2563EB)
    static let accentSoft = Color(hex: 0xDBEAFE)

    /// Le bleu des **grandes** surfaces, et d'elles seules : un curseur, un histogramme,
    /// un remplissage. Il ne porte jamais de texte.
    static let accentVivid = Color(hex: 0x3B82F6)

    /// Toute progression porte cette couleur, sans exception : jauge du parcours
    /// d'accueil, barre de session, anneaux, curseurs, indicateurs d'attente.
    /// Une seule couleur pour « ça avance », sinon l'utilisateur cherche un sens
    /// derrière chaque nuance.
    static let progress = accent
    static let progressTrack = Color(hex: 0xE5E7EB)

    /// Retours d'information. Ils étaient désaturés au point de se ressembler tous ; ils
    /// sont remontés d'un cran, parce qu'un écran de révision doit dire « juste » et
    /// « faux » sans qu'on plisse les yeux. `positive` reste plus forestier que l'accent :
    /// deux verts qui veulent dire deux choses ne peuvent pas être le même vert.
    static let positive = Color(hex: 0x3F7D53)
    static let caution = Color(hex: 0xB3872B)
    /// Le jaune des **grandes** surfaces, et d'elles seules : la cloche du rappel d'essai.
    ///
    /// Même partage que `accent` et `accentVivid`. `caution` est assombri pour porter du
    /// texte de onze points sur un fond pastel, ce qui en fait un ocre terne dès qu'on le
    /// tient sur cent points de haut ; celui-ci est le jaune qu'on attend d'une cloche, et
    /// il ne porte jamais rien d'écrit.
    static let cautionVivid = Color(hex: 0xE8B23C)
    static let negative = Color(hex: 0xC93B2B)
    /// Le rouge du bouton « À revoir » : plus terre que `negative`, pour
    /// rester dans le papier plutôt que dans l'alerte système.
    static let ratingAgain = Color(hex: 0xB5573C)
    static let info = Color(hex: 0x3A6FC4)

    // Fonds doux assortis : notation en session, pastilles d'état.
    static let positiveSoft = Color(hex: 0xDCFCE7)
    static let cautionSoft = Color(hex: 0xFEF3C7)
    static let negativeSoft = Color(hex: 0xFEE2E2)
    static let infoSoft = Color(hex: 0xDBEAFE)

    /// **Les couleurs de l'offre cadeau**, et d'elle seule.
    ///
    /// Les seules couleurs de l'app qui ne sont ni le vert de Micabo ni son papier, et c'est
    /// assumé : l'offre est un **événement**, pas un écran de plus. Un tarif réduit peint
    /// dans la palette de l'app se lit comme une fonctionnalité, donc comme quelque chose
    /// qui sera encore là demain — ce qui est exactement ce qu'il ne faut pas dire d'une
    /// remise qui expire.
    ///
    /// Les mêmes valeurs sont dans `web/app/globals.css` : c'est la même offre, et la voir
    /// bleu ciel sur le téléphone puis indigo sur le site ferait douter du prix.
    static let offerSky = Color(hex: 0x12A3F2)
    static let offerSkyDeep = Color(hex: 0x0B8FDC)
    static let offerWash = Color(hex: 0xC4E7FA)
    static let offerWashSoft = Color(hex: 0xEAF7FE)
    /// Le violet de la minuterie, et rien d'autre : c'est la seule chose de la carte qui
    /// compte à rebours, et elle ne doit pas se confondre avec le bleu qui vend.
    static let offerUrgency = Color(hex: 0x5B46E5)

    /// Teintes de couverture attribuées aux cours, lisibles avec du texte blanc.
    ///
    /// Remontées en saturation, et le violet indigo a laissé la place au vert de Micabo :
    /// une étagère de cours doit ressembler à une étagère de manuels, pas à un camaïeu de
    /// gris colorés.
    static let courseAccents: [Color] = [
        Color(hex: 0x2563EB),
        Color(hex: 0x1D4ED8),
        Color(hex: 0x3B82F6),
        Color(hex: 0x1E3A8A),
        Color(hex: 0x0F766E),
        Color(hex: 0x7C3AED),
        Color(hex: 0x0369A1),
        Color(hex: 0x4F46E5)
    ]

    /// Pastels des tuiles d'icône, quand aucune teinte de cours n'est disponible.
    static let tilePastels: [Color] = [
        Color(hex: 0xDBEAFE),
        Color(hex: 0xE0E7FF),
        Color(hex: 0xE5E7EB),
        Color(hex: 0xE0F2FE),
        Color(hex: 0xF3E8FF),
        Color(hex: 0xF1F5F9)
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
    ///
    /// Ne vaut que pour les écrans qui masquent la barre d'onglets et posent la leur en
    /// `overlay` ou dans un `ZStack` : une feuille, un plein écran, un écran poussé. Les
    /// pages d'onglet qui ancrent quelque chose en bas passent par `tabBarClearance`.
    static let bottomBarClearance: CGFloat = 108

    /// Hauteur de la barre d'onglets, hors zone sûre.
    ///
    /// Elle est déclarée ici et pas déduite du contenu : c'est cette hauteur que
    /// `safeAreaInset` réserve aux pages, et une barre qui se mesure elle-même donne une
    /// réserve qui change avec la longueur des libellés.
    static let tabBarHeight: CGFloat = 49

    /// Air laissé entre la barre d'onglets et ce qu'une page ancre juste au-dessus d'elle :
    /// le « + » de Cours, le bouton de session de Réviser.
    ///
    /// La barre n'est plus en verre : elle est opaque, collée au bas, comme un `UITabBar`.
    /// Un bouton collé dessus se lit encore comme un bouton à moitié caché, d'où ces
    /// huit points — pas les douze du flottement d'avant.
    static let tabBarGap: CGFloat = 8

    /// **Tout ce que la barre d'onglets occupe**, hors zone sûre : c'est la hauteur
    /// qu'une page racine doit se réserver, et celle dont un overlay de la racine
    /// doit s'écarter.
    ///
    /// La somme suit exactement ce que `MicaboTabBar` dessine : la rangée d'onglets,
    /// et l'air au-dessus pour les boutons de page.
    static var tabBarSpace: CGFloat { tabBarGap + tabBarHeight }
}

/// Typographie de l'app : San Francisco, la police native d'iOS.
enum MicaboFont {
    static func hanken(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// La même police, côté UIKit : la fiche compose ses paragraphes dans un `UITextView`
    /// pour que la sélection d'un passage soit celle du système, et il lui faut donc des
    /// `UIFont`.
    static func uiFont(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight(for: weight))
        guard italic else { return base }
        return UIFont(
            descriptor: base.fontDescriptor.withSymbolicTraits(.traitItalic) ?? base.fontDescriptor,
            size: size
        )
    }

    private static func uiWeight(for weight: Font.Weight) -> UIFont.Weight {
        if weight == .bold || weight == .heavy || weight == .black { return .bold }
        if weight == .semibold { return .semibold }
        if weight == .medium { return .medium }
        return .regular
    }

    static func postscriptName(for weight: Font.Weight) -> String {
        if weight == .bold || weight == .heavy || weight == .black {
            return UIFont.systemFont(ofSize: 17, weight: .bold).fontName
        }
        if weight == .semibold {
            return UIFont.systemFont(ofSize: 17, weight: .semibold).fontName
        }
        if weight == .medium {
            return UIFont.systemFont(ofSize: 17, weight: .medium).fontName
        }
        return UIFont.systemFont(ofSize: 17, weight: .regular).fontName
    }

    static func display(_ size: CGFloat) -> Font {
        hanken(size, weight: .bold)
    }

    /// **Les chiffres qu'on lit comme un résultat**, et eux seuls : le compte de cartes du
    /// jour, la série, les statistiques d'une session, les minutes d'un objectif.
    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight)
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
/// et des rangées. Une fiche demande donc un corps tenu, un interligne régulier et une
/// largeur de colonne stable, faute de quoi l'œil se perd d'une ligne à l'autre.
///
/// **Toute l'échelle a perdu un dixième**, et pas seulement le corps du texte. Réduire le
/// corps seul aurait fait grossir les titres par contraste : ce qui compte sur une page,
/// c'est le rapport entre les tailles, pas leur valeur absolue. Chaque taille ci-dessous est
/// donc l'ancienne multipliée par 0,9, arrondie au demi-point.
///
/// **Les espaces verticaux ont baissé plus que ça** — de l'interligne aux marges d'un objet.
/// Une fiche est une page dense par nature : on la relit la veille au soir, et le blanc qui
/// aère un écran d'accueil fait ici scroller pour rien. Toutes les valeurs vivent ici :
/// c'est ce qui permet de resserrer la page d'un cran sans chasser des nombres dans six
/// fichiers.
enum SheetTypography {
    // MARK: Tailles

    /// Corps du texte courant.
    static let body: CGFloat = 14.85
    /// Chapeau posé sous le titre du cours.
    static let lead: CGFloat = 15.75
    /// Corps d'un objet : encadré, définition, étape. Un cran sous la page, pour qu'un
    /// objet n'ait pas l'air de porter le cours à sa place.
    static let secondary: CGFloat = 14
    /// Intitulé d'un objet : titre d'un tableau, d'un graphe, d'une suite d'étapes, terme
    /// d'une définition. Au-dessus du corps de l'objet : un intitulé plus petit que le texte
    /// qu'il introduit n'introduit rien.
    static let objectTitle: CGFloat = 14.5
    /// Cellule de tableau, et étiquette d'un graphe.
    static let cell: CGFloat = 12
    /// Légende sous un tableau, un graphe ou une formule.
    static let caption: CGFloat = 11.5
    /// Titre de partie.
    static let headingLarge: CGFloat = 19.8
    /// Titre de sous-partie. C'est la taille du corps : un sous-titre se distingue par son
    /// poids et par l'air au-dessus de lui, pas en grossissant.
    static let headingSmall: CGFloat = 14.85
    /// Formule mise en valeur dans son bloc.
    static let formula: CGFloat = 18

    // MARK: Espaces

    /// Interligne ajouté aux paragraphes.
    static let lineSpacing: CGFloat = 6
    /// Interligne d'un objet, dont le corps est déjà plus petit.
    static let secondaryLineSpacing: CGFloat = 4.5
    /// Interligne d'une cellule, d'une légende, d'un titre.
    static let tightLineSpacing: CGFloat = 2.5

    /// Espace au-dessus d'un titre de partie, et d'un titre de sous-partie.
    ///
    /// Un sous-titre a la taille du corps : c'est **l'air au-dessus de lui** qui dit qu'une
    /// sous-partie commence, avec son demi-gras. Il lui faut donc nettement plus que
    /// l'espace entre deux blocs ordinaires — à un point près, il n'y aurait plus de plan.
    static let spaceBeforeLargeHeading: CGFloat = 20
    static let spaceBeforeSmallHeading: CGFloat = 15
    /// Espace entre deux blocs de même nature.
    static let blockSpacing: CGFloat = 11
    /// Marge intérieure d'un objet encarté.
    static let objectPadding: CGFloat = 13

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

/// Surface blanche posée sur le fond gris. Le contraste des deux fonds suffit :
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
