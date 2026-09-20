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
    private static var palette: MicaboPalette { AppearanceStore.shared.palette }

    // Fonds
    static var canvas: Color { palette.canvas }
    static var surface: Color { palette.surface }
    static var surfaceMuted: Color { palette.surfaceMuted }
    static var surfaceSunken: Color { palette.surfaceSunken }
    static var stroke: Color { palette.stroke }
    static var strokeStrong: Color { palette.strokeStrong }

    /// Filet de séparation entre deux rangées, dans un bloc blanc ou sur le fond.
    static var hairline: Color { palette.hairline }
    static var hairlineOnCanvas: Color { palette.hairlineOnCanvas }

    // Encre
    static var ink: Color { palette.ink }
    static var inkSecondary: Color { palette.inkSecondary }
    static var inkTertiary: Color { palette.inkTertiary }

    /// Encre des longs paragraphes d'une fiche. Un noir de titre tenu sur trente lignes
    /// fatigue : celui-ci est un cran plus doux, sans retomber dans le brun.
    static var inkReading: Color { palette.inkReading }

    /// Encre des versos de carte et des puces non sélectionnées.
    static var inkBody: Color { palette.inkBody }

    /// Le jaune du surligneur de la fiche.
    ///
    /// Le passage mis en avant a été du texte bleu pendant une version, parce qu'un fond
    /// posé derrière le texte débordait sous les jambages et changeait d'épaisseur d'une
    /// ligne à l'autre. Mais du texte bleu au milieu d'un paragraphe ne se lit pas comme un
    /// surlignage : ça se lit comme un lien, d'autant que le bleu est déjà l'accent de
    /// l'app. La bande est donc revenue, et le défaut qui l'avait fait partir est traité là
    /// où il devait l'être : `SheetMarkerLayoutManager` dessine une bande d'épaisseur
    /// constante, calée sur la hauteur des capitales, au lieu de laisser TextKit peindre
    /// toute la hauteur de ligne, interligne compris.
    ///
    /// Le texte surligné garde son encre : un fond jaune **et** une encre de couleur, ce
    /// sont deux marques pour une seule intention.
    static var sheetMarker: Color { palette.sheetMarker }

    /// Le surligneur d'une teinte donnée. C'est l'étudiant qui choisit la couleur, sur le
    /// site comme dans l'app ; un nom inconnu retombe sur le jaune plutôt que sur rien.
    static func sheetHighlight(_ highlight: SheetHighlight) -> Color {
        let colors = palette.sheetHighlights
        guard let index = SheetHighlight.allCases.firstIndex(of: highlight),
              colors.indices.contains(index)
        else { return palette.sheetMarker }
        return colors[index]
    }

    // Sur fond d'accent / de bouton plein
    static var onInk: Color { palette.onInk }
    static var onInkMuted: Color { palette.onInkMuted }

    /// Fond des écrans qui ne sont ni une liste ni une lecture.
    static var canvasSage: Color { palette.canvasSage }

    /// Accent unique de l'app : sélection, onglet actif, éléments interactifs.
    ///
    /// Assez sombre pour qu'une pastille de onze points reste lisible sur `accentSoft`.
    static var accent: Color { palette.accent }
    static var accentSoft: Color { palette.accentSoft }

    /// Le bleu des **grandes** surfaces, et d'elles seules : un curseur, un histogramme,
    /// un remplissage. Il ne porte jamais de texte.
    static var accentVivid: Color { palette.accentVivid }

    /// Toute progression porte cette couleur, sans exception : jauge du parcours
    /// d'accueil, barre de session, anneaux, curseurs, indicateurs d'attente.
    /// Une seule couleur pour « ça avance », sinon l'utilisateur cherche un sens
    /// derrière chaque nuance.
    static var progress: Color { accent }
    static var progressTrack: Color { palette.progressTrack }

    /// Retours d'information. Ils étaient désaturés au point de se ressembler tous ; ils
    /// sont remontés d'un cran, parce qu'un écran de révision doit dire « juste » et
    /// « faux » sans qu'on plisse les yeux. `positive` reste plus forestier que l'accent :
    /// deux verts qui veulent dire deux choses ne peuvent pas être le même vert.
    static var positive: Color { palette.positive }
    static var caution: Color { palette.caution }
    /// Le jaune des **grandes** surfaces, et d'elles seules : la cloche du rappel d'essai.
    ///
    /// Même partage que `accent` et `accentVivid`. `caution` est assombri pour porter du
    /// texte de onze points sur un fond pastel, ce qui en fait un ocre terne dès qu'on le
    /// tient sur cent points de haut ; celui-ci est le jaune qu'on attend d'une cloche, et
    /// il ne porte jamais rien d'écrit.
    static var cautionVivid: Color { palette.cautionVivid }
    static var negative: Color { palette.negative }
    /// Le rouge du bouton « À revoir » : plus terre que `negative`, pour
    /// rester dans le papier plutôt que dans l'alerte système.
    static var ratingAgain: Color { palette.ratingAgain }
    static var info: Color { palette.info }

    // Fonds doux assortis : notation en session, pastilles d'état.
    static var positiveSoft: Color { palette.positiveSoft }
    static var cautionSoft: Color { palette.cautionSoft }
    static var negativeSoft: Color { palette.negativeSoft }
    static var infoSoft: Color { palette.infoSoft }

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
    static var offerWash: Color { palette.offerWash }
    static var offerWashSoft: Color { palette.offerWashSoft }

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
    static var tilePastels: [Color] { palette.tilePastels }
    static var accentWash: Color { palette.accentWash }
    static var gradeNear: Color { palette.gradeNear }
    static var gradeMid: Color { palette.gradeMid }
    static var gradeFar: Color { palette.gradeFar }
    static var accentPale: Color { palette.accentPale }
    static var track: Color { palette.track }
    static var flame: Color { palette.flame }
    static var flameInk: Color { palette.flameInk }
    static var flameSoft: Color { palette.flameSoft }
    static var flameTrack: Color { palette.flameTrack }
    static var warmProse: Color { palette.warmProse }
    static var warmWashStart: Color { palette.warmWashStart }
    static var warmWashEnd: Color { palette.warmWashEnd }
    static var warmWashStroke: Color { palette.warmWashStroke }
    static var dayWashStart: Color { palette.dayWashStart }
    static var dayWashMid: Color { palette.dayWashMid }
    static var dayWashEnd: Color { palette.dayWashEnd }
    static var dayWashStroke: Color { palette.dayWashStroke }

    /// **Le pastel d'un deck**, tiré de son identité et non de sa teinte d'accent.
    ///
    /// Les six pastels sont ceux de la maquette, et le choix est déterministe : le même deck
    /// garde sa couleur d'un lancement à l'autre, et deux decks voisins dans la grille en
    /// ont presque toujours deux différentes. Tirer la teinte de `accentHex` aurait donné
    /// des carrés délavés, parce que cette teinte a été choisie pour un filet de fiche.
    static func pastel(for id: UUID) -> Color {
        let slot = abs(id.uuidString.hashValue) % tilePastels.count
        return tilePastels[slot]
    }

    static func pastel(forName name: String) -> Color {
        let slot = abs(name.hashValue) % tilePastels.count
        return tilePastels[slot]
    }
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

/// **Le bouton est moins rond que la carte, et c'est voulu.**
///
/// Les deux étaient à seize et vingt, assez proches pour que l'œil les range ensemble. Un
/// écart net — quatorze contre vingt-deux — leur redonne deux natures : une carte est une
/// **surface** sur laquelle quelque chose est posé, un bouton est une **commande** qu'on
/// presse. Plus la surface est grande, plus elle peut s'arrondir sans mollir ; un bouton
/// trop rond, lui, perd ses angles d'appui et se met à ressembler à une pastille.
enum MicaboRadius {
    /// Tuile pastel d'une rangée : carré arrondi, emoji ou symbole au centre.
    static let tile: CGFloat = 14
    /// **La grande tuile d'un deck**, dans la grille à deux colonnes. Elle fait 112 points
    /// de haut et porte son emoji à quarante-quatre : à ce format, le rayon d'une tuile de
    /// rangée la ferait paraître carrée.
    static let deck: CGFloat = 26
    /// Même valeur que la tuile, pour les vignettes du parcours d'accueil.
    static let cover: CGFloat = 14
    static let sm: CGFloat = 12
    /// Boutons CTA principaux, et champs de saisie.
    static let button: CGFloat = 14
    static let md: CGFloat = 16
    /// Rangée-carte, encadré d'une fiche, rangée de choix du parcours d'accueil.
    static let lg: CGFloat = 18
    /// **La carte à lavis** : série du profil, et tout encadré qui porte une couleur de fond
    /// plutôt qu'un filet. Vingt points — entre l'encadré à filet et la grande tuile.
    static let card: CGFloat = 20
    /// Bloc blanc regroupant plusieurs rangées, et cartes d'appel.
    static let group: CGFloat = 22
    static let card: CGFloat = 22
    static let xl: CGFloat = 24
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
/// **Deux familles, et chacune a son domaine.**
///
/// Outfit écrit l'interface : titres d'écran, intitulés de rangée, libellés de bouton,
/// sur-titres, onglets, et tous les nombres qui se lisent comme un résultat. C'est une
/// géométrique large, qui tient le gras sans s'épaissir — ce qu'on veut d'un titre de
/// trente points et d'un compteur de cinquante-quatre.
///
/// Hanken Grotesk écrit **ce qu'on lit vraiment** : le corps d'une fiche de cours, ses
/// encadrés, le verso d'une carte. Plus étroite, plus sobre, elle tient l'œil d'une ligne
/// à l'autre sur une page dense — ce qu'une géométrique ne fait pas au-delà de quelques
/// lignes.
///
/// Deux familles sur une page ne tiennent que si chacune a un domaine net. Le partage est
/// donc celui-là, et pas « la plus jolie pour les titres » : **l'une nomme, l'autre
/// raconte.**
///
/// Les deux étaient déjà dans le dépôt, et aucune des deux ne servait : `hanken()`
/// renvoyait `.system()`, donc l'app entière était en San Francisco et les quatre fichiers
/// Hanken voyageaient dans le bundle sans jamais être appelés.
enum MicaboFont {
    // MARK: Les deux familles

    /// **Outfit** — l'interface. Voir la note de l'énumération pour le partage.
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(outfitName(for: weight), size: size)
    }

    /// **Hanken Grotesk** — le texte qu'on lit.
    static func reading(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(hankenName(for: weight), size: size)
    }

    /// La police de lecture côté UIKit : la fiche compose ses paragraphes dans un
    /// `UITextView` pour que la sélection d'un passage soit celle du système, et il lui
    /// faut donc des `UIFont`.
    ///
    /// **Hanken n'a pas d'italique dessiné.** On demande donc l'inclinaison au descripteur,
    /// et on retombe sur le droit si le système refuse de la synthétiser — un faux italique
    /// absent vaut mieux qu'une police qui disparaît au milieu d'un paragraphe.
    static func uiFont(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> UIFont {
        let base = UIFont(name: hankenName(for: weight), size: size)
            ?? UIFont.systemFont(ofSize: size, weight: uiWeight(for: weight))
        guard italic else { return base }
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(.traitItalic) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// La police d'interface côté UIKit, pour les rares vues qui en sont faites.
    static func uiDisplayFont(_ size: CGFloat, weight: Font.Weight = .regular) -> UIFont {
        UIFont(name: outfitName(for: weight), size: size)
            ?? UIFont.systemFont(ofSize: size, weight: uiWeight(for: weight))
    }

    // MARK: Noms PostScript

    /// Les quatre coupes embarquées, et rien d'autre : une graisse plus fine ou plus grasse
    /// retombe sur la plus proche plutôt que sur une police absente.
    private static func outfitName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: "Outfit-Bold"
        case .semibold: "Outfit-SemiBold"
        case .medium: "Outfit-Medium"
        default: "Outfit-Regular"
        }
    }

    private static func hankenName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: "HankenGrotesk-Bold"
        case .semibold: "HankenGrotesk-SemiBold"
        case .medium: "HankenGrotesk-Medium"
        default: "HankenGrotesk-Regular"
        }
    }

    private static func uiWeight(for weight: Font.Weight) -> UIFont.Weight {
        if weight == .bold || weight == .heavy || weight == .black { return .bold }
        if weight == .semibold { return .semibold }
        if weight == .medium { return .medium }
        return .regular
    }

    // MARK: Rôles

    static func display(_ size: CGFloat) -> Font {
        ui(size, weight: .bold)
    }

    /// **Les chiffres qu'on lit comme un résultat**, et eux seuls : le compte de cartes du
    /// jour, la série, les statistiques d'une session, les minutes d'un objectif.
    ///
    /// Ils sont en Outfit comme le reste de l'interface, et c'est tout l'intérêt d'avoir
    /// pris une géométrique : un grand nombre y a des chiffres de même largeur et des
    /// formes assez ouvertes pour se lire comme un score. Poser `.monospacedDigit()` là où
    /// le nombre bouge reste nécessaire — c'est ce qui empêche un compteur de tressauter.
    static func number(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        ui(size, weight: weight)
    }

    /// Grand titre d'écran, posé à même le fond sous son sur-titre.
    ///
    /// Il perd deux points en passant à Outfit : la géométrique est plus large que San
    /// Francisco à corps égal, et « Histoire contemporaine » ne tenait plus sur deux lignes.
    static let screenTitle = ui(30, weight: .bold)
    static let pageTitle = ui(22, weight: .bold)
    static let sectionTitle = ui(18, weight: .semibold)
    static let cardTitle = ui(16, weight: .semibold)
    static let rowTitle = ui(15.5, weight: .semibold)
    static let rowSubtitle = ui(13, weight: .regular)
    static let body = ui(15, weight: .regular)
    static let bodyEmphasis = ui(15, weight: .medium)
    static let caption = ui(13, weight: .regular)
    static let captionEmphasis = ui(13, weight: .medium)
    static let micro = ui(11, weight: .medium)
    /// Sur-titres et intitulés de section, toujours en capitales.
    static let eyebrow = ui(11, weight: .semibold)
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

    /// Corps du texte courant. La même valeur que `.sheet-doc` côté site.
    static let body: CGFloat = 15
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
    ///
    /// Une fois et demie le corps, et pas un tiers de plus comme avant. Un titre à 1,33 fois
    /// le corps ne se voit pas en feuilletant au pouce : c'est la taille qui fait qu'une
    /// partie commence, avant même la capsule teintée qui la précède.
    static let headingLarge: CGFloat = 22
    /// Titre de sous-partie.
    ///
    /// Il a longtemps eu **exactement la taille du corps**, au motif qu'un sous-titre se
    /// distingue par son poids et par l'air au-dessus de lui. Les deux manquaient : le
    /// demi-gras d'Hanken est discret, et l'air valait quatre points de plus qu'un simple
    /// changement de paragraphe. Une sous-partie ne se voyait donc pas, et la fiche se lisait
    /// d'un bloc. Un cran au-dessus du corps suffit à la faire exister.
    static let headingSmall: CGFloat = 17
    /// Formule mise en valeur dans son bloc.
    static let formula: CGFloat = 18

    // MARK: Espaces

    /// Interligne ajouté aux paragraphes. Rend une hauteur de ligne d'environ 1,75 fois le
    /// corps, ce que `.sheet-doc` pose en `line-height` côté site.
    static let lineSpacing: CGFloat = 7
    /// Interligne d'un objet, dont le corps est déjà plus petit.
    static let secondaryLineSpacing: CGFloat = 4.5
    /// Interligne d'une cellule, d'une légende, d'un titre.
    static let tightLineSpacing: CGFloat = 2.5

    /// Espace au-dessus d'un titre de partie, et d'un titre de sous-partie.
    ///
    /// **Le rapport à `blockSpacing` est tout ce qui compte ici.** Un titre de sous-partie
    /// recevait quinze points là où un simple changement de paragraphe en recevait onze :
    /// un rapport de 1,36, que l'œil ne distingue pas d'un paragraphe de plus. La fiche
    /// n'avait donc pas de plan visible, seulement un ruban de texte. À vingt-six contre
    /// quatorze, le rapport passe à 1,85 et la sous-partie se voit en feuilletant.
    ///
    /// Ce sont les valeurs de `.sheet-doc h1` et `.sheet-doc h2` côté site : les deux rendus
    /// doivent donner la même page.
    static let spaceBeforeLargeHeading: CGFloat = 38
    static let spaceBeforeSmallHeading: CGFloat = 26
    /// Espace entre deux blocs de même nature.
    static let blockSpacing: CGFloat = 14
    /// Espace au-dessus d'une énumération à puces.
    ///
    /// Une liste est **la suite du paragraphe qui l'amène**, et non un bloc de plus : à
    /// quatorze points, elle s'en détacherait et se lirait comme un objet posé après. Elle
    /// reste accrochée à sa phrase d'introduction.
    static let spaceBeforeList: CGFloat = 8

    /// Espace **entre deux points** d'une même liste.
    ///
    /// C'est un réglage différent de celui du dessus, et les deux étaient confondus : chaque
    /// point d'une liste est un paragraphe, donc tous recevaient les six points prévus pour
    /// coller la liste à sa phrase d'introduction. Des puces serrées à six points forment un
    /// bloc gris qu'on lit comme un paragraphe — exactement ce qu'une liste est censée
    /// éviter. Une fiche se parcourt à l'œil : ses puces doivent se compter de loin.
    static let listItemSpacing: CGFloat = 9
    /// Marge intérieure d'un objet encarté.
    static let objectPadding: CGFloat = 13

    /// Ce que la capsule d'un titre de partie occupe au-dessus de lui : sa hauteur, plus
    /// l'air qui la sépare du titre.
    ///
    /// Un document ne pose rien au-dessus de son premier bloc — sauf celui-ci : un chapitre
    /// ouvre sur son titre de partie, et sans cette réserve la capsule se dessinerait hors
    /// de la page.
    static let headingRuleClearance: CGFloat = 12

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

    /// Mélange vers le papier : blanc le jour, surface sombre la nuit et au crépuscule.
    func lightened(by amount: Double) -> Color {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        var targetRed: CGFloat = 1
        var targetGreen: CGFloat = 1
        var targetBlue: CGFloat = 1
        if AppearanceStore.shared.appearance.isDark {
            var unused: CGFloat = 1
            UIColor(AppearanceStore.shared.palette.surface)
                .getRed(&targetRed, green: &targetGreen, blue: &targetBlue, alpha: &unused)
        }
        let amount = CGFloat(amount)
        return Color(
            red: red + (targetRed - red) * amount,
            green: green + (targetGreen - green) * amount,
            blue: blue + (targetBlue - blue) * amount,
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

    /// **La même teinte, mais posée en encre.**
    ///
    /// Les teintes de cours sont choisies pour *porter du texte blanc* : elles sont donc
    /// sombres, et deux d'entre elles — le bleu nuit, l'indigo — disparaissent purement et
    /// simplement sur le papier de la nuit. Les employer telles quelles pour un titre de
    /// partie donnerait un plan lisible le jour et invisible le soir, ce qui est pire que
    /// pas de couleur du tout.
    ///
    /// On garde donc **la nuance** et on impose **la clarté** : plafonnée sur le papier
    /// clair pour qu'un bleu vif ne pâlisse pas, relevée sur le papier sombre, où l'on
    /// retire aussi de la saturation parce qu'une couleur pure y vibre. Les huit teintes
    /// de `courseAccents` passent alors le seuil de contraste des trois apparences.
    func readableInk() -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let dark = AppearanceStore.shared.appearance.isDark
        return Color(
            hue: Double(hue),
            saturation: Double(dark ? min(saturation, CGFloat(0.55)) : saturation),
            brightness: Double(dark ? max(brightness, CGFloat(0.86)) : min(brightness, CGFloat(0.72))),
            opacity: Double(alpha)
        )
    }
}

// MARK: - Modificateurs partagés

/// **Les ombres, et elles sont en deux couches.**
///
/// Une ombre unique doit choisir : courte, elle pose l'objet mais ne le détache pas du
/// fond ; longue, elle le détache mais le fait léviter. Deux couches font les deux à la
/// fois — un contact d'un point juste sous l'objet, et une diffusion large qui le décolle.
/// C'est ce qui donne leur relief aux cartes sans qu'aucune n'ait l'air de flotter, et
/// c'est ce qui remplace les bordures : un filet posé pour faire de la profondeur est un
/// filet qui ment sur ce qu'il sépare.
///
/// **Elles sont teintées de l'encre, pas de noir.** Une ombre noire sur un fond bleuté vire
/// au gris sale ; la même en navy reste dans la famille du fond.
///
/// Les valeurs sont celles de la planche de style, converties : le rayon SwiftUI vaut la
/// moitié du flou CSS, le décalage est le même.
enum MicaboElevation {
    /// Une rangée-carte, une tuile, un champ de saisie.
    case row
    /// Une carte d'écran, la carte d'une session, une feuille.
    case card
    /// Ce qui est réellement au-dessus de la page : le bouton flottant d'import.
    case floating

    /// La couche de contact : elle dit que l'objet touche le fond.
    fileprivate var contact: (opacity: Double, radius: CGFloat, y: CGFloat) {
        switch self {
        case .row: (0.04, 1, 1)
        case .card: (0.04, 1, 1)
        case .floating: (0.06, 3, 2)
        }
    }

    /// La couche diffuse : elle dit de combien il est au-dessus.
    fileprivate var ambient: (radius: CGFloat, y: CGFloat) {
        switch self {
        case .row: (8, 6)
        case .card: (14, 10)
        case .floating: (16, 12)
        }
    }

    /// L'opacité de la couche diffuse suit l'apparence : dans le noir, une ombre à cinq
    /// pour cent ne se voit pas.
    fileprivate var ambientOpacity: Double {
        let palette = AppearanceStore.shared.palette
        switch self {
        case .row: return palette.groupShadow
        case .card: return palette.cardShadow
        case .floating: return palette.cardShadow * 1.6
        }
    }
}

private struct MicaboElevationStyle: ViewModifier {
    var level: MicaboElevation

    func body(content: Content) -> some View {
        let contact = level.contact
        let ambient = level.ambient
        return content
            .shadow(color: MicaboColor.ink.opacity(contact.opacity), radius: contact.radius, x: 0, y: contact.y)
            .shadow(color: MicaboColor.ink.opacity(level.ambientOpacity), radius: ambient.radius, x: 0, y: ambient.y)
    }
}

/// Surface blanche posée sur le fond. Le contraste des deux fonds suffit : pas de bordure,
/// et l'ombre en deux couches pour décoller le bloc.
struct MicaboCardStyle: ViewModifier {
    var padding: CGFloat = MicaboSpacing.md
    var radius: CGFloat = MicaboRadius.card
    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .micaboElevation(elevated ? .card : .row)
    }
}

extension View {
    /// Pose l'ombre d'un niveau donné, sans toucher au fond ni au rayon.
    func micaboElevation(_ level: MicaboElevation) -> some View {
        modifier(MicaboElevationStyle(level: level))
    }

    func micaboCard(padding: CGFloat = MicaboSpacing.md, radius: CGFloat = MicaboRadius.card, elevated: Bool = true) -> some View {
        modifier(MicaboCardStyle(padding: padding, radius: radius, elevated: elevated))
    }

    /// Bloc blanc qui regroupe des rangées, à la manière d'une liste encartée.
    /// Le contenu gère ses propres marges pour que les filets aillent d'un bord à l'autre.
    ///
    /// Il reste la mise en page des **Réglages** et des feuilles : une douzaine de lignes
    /// qui appartiennent au même sujet. Les listes d'objets — cours, paquets, ce qu'il y a
    /// au programme — sont passées à la rangée-carte, voir `MicaboRowGroup`.
    func micaboGroup(radius: CGFloat = MicaboRadius.group) -> some View {
        background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .micaboElevation(.row)
    }

    /// Ombre douce des éléments posés sur le fond, sans passer par une carte complète.
    func micaboSoftShadow(strength: Double = 0.06) -> some View {
        shadow(color: MicaboColor.ink.opacity(strength), radius: 16, x: 0, y: 8)
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
