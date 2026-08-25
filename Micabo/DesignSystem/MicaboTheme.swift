import SwiftUI
import UIKit

/// Jetons de style de Micabo.
///
/// Direction : du papier, pas des cartes empilées. Le fond est un ivoire chaud assez
/// marqué pour que les surfaces blanches se détachent seules, sans bordure ni ombre
/// portée. Les listes sont soit posées à même le fond et séparées par un filet, soit
/// regroupées dans un bloc blanc à grands coins. Chaque rangée porte une tuile pastel
/// (emoji ou symbole) qui donne la couleur de l'écran ; l'accent reste réservé à ce
/// qui est actif ou sélectionné.
///
/// **L'accent est passé de l'indigo au vert de Micabo.** L'indigo était le violet d'une app
/// de productivité : sérieux, un peu froid, et sans rapport avec le logo, qui porte un rond
/// vert menthe depuis le premier jour. Une app qu'on ouvre pour réviser gagne à être vive :
/// le vert est celui du logo, il dit « c'est acquis » dans la même langue que les boutons de
/// notation, et il rend le crème du papier plus chaud au lieu de le refroidir.
///
/// Deux verts, et la distinction compte : `accent` est assez sombre pour porter du texte de
/// onze points sur un fond pastel, `accentVivid` est le vert du logo et ne sert qu'aux
/// surfaces sur lesquelles rien n'est écrit — jauges, barres, remplissages.
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

    /// La couleur des passages que la fiche met en avant.
    ///
    /// **Le surligneur jaune a été retiré.** Un fond posé derrière le texte se battait avec
    /// lui : la bande débordait sous les jambages, changeait d'épaisseur d'une ligne à
    /// l'autre, et sur un paragraphe à interligne serré elle écrasait ce qu'elle voulait
    /// mettre en valeur. Un `NSLayoutManager` entier ne servait qu'à en arrondir les coins.
    ///
    /// C'est maintenant la couleur du texte lui-même. Un vert plus dense que l'accent,
    /// parce qu'un mot en couleur au milieu d'un paragraphe doit se voir sans qu'on le
    /// cherche, et rester lisible à quatorze points sur l'ivoire.
    static let sheetEmphasis = Color(hex: 0x0A6E52)

    // Sur fond sombre
    static let onInk = Color(hex: 0xF8F6F0)
    static let onInkMuted = Color(hex: 0x9A958A)

    /// Le crème, teinté de vert : le fond des écrans qui ne sont ni une liste ni une lecture.
    ///
    /// **C'est ce qui a remplacé l'encre sur l'accroche.** Un premier écran entièrement noir
    /// annonce une app d'outillage, pas une app d'école : il pose un contraste maximal avant
    /// qu'on ait rien à lire, il oblige tout le parcours à s'inverser dès le deuxième écran,
    /// et il fait du blanc des cartes la seule chose qu'on voie. Ce vert-là est un papier
    /// dans la palette de Micabo — assez proche du crème pour que le passage à l'écran
    /// suivant ne se voie pas comme une rupture, assez teinté pour ne pas passer pour du
    /// gris sale.
    ///
    /// Il se distingue de `accentSoft`, qui est plus franc et sert l'attente : le menthe
    /// veut qu'on remarque qu'il se passe quelque chose, la sauge veut se faire oublier.
    static let canvasSage = Color(hex: 0xE8EFE6)

    /// Accent unique de l'app : sélection, onglet actif, éléments interactifs.
    ///
    /// Assez sombre pour qu'une pastille de onze points reste lisible sur `accentSoft` :
    /// c'est cette contrainte, et non le goût, qui l'empêche d'être le menthe du logo.
    static let accent = Color(hex: 0x0B8A66)
    static let accentSoft = Color(hex: 0xDFF4EC)

    /// Le vert du logo, celui de son rond.
    ///
    /// Il ne porte jamais de texte, et il ne sert qu'aux **grandes** surfaces : un curseur,
    /// un histogramme, un remplissage. Sur un filet de quatre points posé sur le crème, il
    /// n'a pas assez de contraste avec sa piste pour qu'on voie où en est la barre — c'est
    /// `accent` qui prend le relais dans ce cas, et cette règle vaut mieux qu'un vert vif
    /// qu'on ne distingue pas.
    static let accentVivid = Color(hex: 0x16C08C)

    /// Toute progression porte cette couleur, sans exception : jauge du parcours
    /// d'accueil, barre de session, anneaux, curseurs, indicateurs d'attente.
    /// Une seule couleur pour « ça avance », sinon l'utilisateur cherche un sens
    /// derrière chaque nuance.
    static let progress = accent
    static let progressTrack = Color(hex: 0xE4DFD2)

    /// Retours d'information. Ils étaient désaturés au point de se ressembler tous ; ils
    /// sont remontés d'un cran, parce qu'un écran de révision doit dire « juste » et
    /// « faux » sans qu'on plisse les yeux. `positive` reste plus forestier que l'accent :
    /// deux verts qui veulent dire deux choses ne peuvent pas être le même vert.
    static let positive = Color(hex: 0x3F7D53)
    static let caution = Color(hex: 0xB3872B)
    static let negative = Color(hex: 0xC93B2B)
    static let info = Color(hex: 0x3A6FC4)

    // Fonds doux assortis : notation en session, pastilles d'état.
    static let positiveSoft = Color(hex: 0xE3F1E2)
    static let cautionSoft = Color(hex: 0xFAF0D8)
    static let negativeSoft = Color(hex: 0xFAE6E1)
    static let infoSoft = Color(hex: 0xE2ECF9)

    /// Teintes de couverture attribuées aux cours, lisibles avec du texte blanc.
    ///
    /// Remontées en saturation, et le violet indigo a laissé la place au vert de Micabo :
    /// une étagère de cours doit ressembler à une étagère de manuels, pas à un camaïeu de
    /// gris colorés.
    static let courseAccents: [Color] = [
        Color(hex: 0x2E7D63),
        Color(hex: 0x9A5B36),
        Color(hex: 0x3F5F8A),
        Color(hex: 0x8A4A6B),
        Color(hex: 0x0B8A66),
        Color(hex: 0xB07A2E),
        Color(hex: 0x4C7A3A),
        Color(hex: 0x6B4E8A)
    ]

    /// Pastels des tuiles d'icône, quand aucune teinte de cours n'est disponible.
    /// Un cran plus francs qu'avant : six gris teintés ne donnaient pas de couleur à l'écran,
    /// ils lui donnaient une brume.
    static let tilePastels: [Color] = [
        Color(hex: 0xDFF2E8),
        Color(hex: 0xE4F0DC),
        Color(hex: 0xFBEBDA),
        Color(hex: 0xDFEAF8),
        Color(hex: 0xF8E4EC),
        Color(hex: 0xF6F0D6)
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
    /// deux pages d'onglet qui ancrent quelque chose en bas passent par `safeAreaInset`,
    /// qui réserve la hauteur exacte de son contenu au lieu de la deviner, et surtout la
    /// pose au-dessus de la barre d'onglets au lieu de dessous.
    static let bottomBarClearance: CGFloat = 108

    /// Hauteur de la barre d'onglets, hors zone sûre.
    ///
    /// Elle est déclarée ici et pas déduite du contenu : c'est cette hauteur que
    /// `safeAreaInset` réserve aux pages, et une barre qui se mesure elle-même donne une
    /// réserve qui change avec la longueur des libellés.
    static let tabBarHeight: CGFloat = 60

    /// Air laissé entre la barre d'onglets et ce qu'une page ancre juste au-dessus d'elle :
    /// le « + » de Cours, le bouton de session de Réviser.
    ///
    /// Sans cet air, les deux se touchent, et un bouton collé sous une barre translucide se
    /// lit comme un bouton à moitié caché — c'est exactement ce qu'on nous a signalé.
    static let tabBarGap: CGFloat = 12

    /// **Tout ce que la barre d'onglets occupe**, de son air du dessus au bord de la zone
    /// sûre : c'est la hauteur qu'une page racine doit se réserver.
    ///
    /// Elle est déclarée ici parce qu'il faut la réserver **à la main**, et ce n'est pas un
    /// choix. La barre est posée par la racine, à l'extérieur des trois pages, et chaque
    /// page est un `NavigationStack` : or un `safeAreaInset` **ne franchit pas** la frontière
    /// d'un `NavigationStack`, qui rétablit sa zone sûre depuis la fenêtre. L'inset de la
    /// racine dessine donc la barre sans jamais rien réserver à l'intérieur des pages, et
    /// tout ce qu'une page ancrait en bas se retrouvait sous la barre.
    ///
    /// La somme suit exactement ce que `MicaboTabBar` dessine : son air du dessus, sa
    /// hauteur, et les quatre points qui l'empêchent de buter sur le bord d'un téléphone
    /// sans zone sûre.
    static var tabBarSpace: CGFloat { tabBarGap + tabBarHeight + MicaboSpacing.xxs }
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

    /// **Les chiffres qu'on lit comme un résultat**, et eux seuls : le compte de cartes du
    /// jour, la série, les statistiques d'une session, les minutes d'un objectif.
    ///
    /// C'est du SF Rounded, la seule fonte arrondie du système, et c'est un choix
    /// d'intention : un grand nombre en grotesque serré ressemble à un indicateur de tableau
    /// de bord, le même nombre en arrondi ressemble à un score. Micabo est une app d'école,
    /// et un élève doit avoir envie de faire monter ce chiffre.
    ///
    /// Le texte, lui, reste en Hanken Grotesk. Deux familles sur une même page ne tiennent
    /// que si chacune a un domaine net : ici, l'une écrit les mots, l'autre les nombres.
    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
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
