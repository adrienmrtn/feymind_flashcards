import SwiftUI
import UIKit

/// Jetons de style de Micabo.
///
/// **Direction V3.3 (lot 10) : « marine, net, adulte ».** L'app s'ouvre en marine ; le clair
/// est une option, sur un fond teinté. Une carte est une surface à filet de 1,5 point — ni
/// lèvre, ni ombre : seul le bouton principal a une lèvre. Les titres sont dans la police
/// d'affichage, tout le reste en police système. Ces jetons portent les valeurs de `V3Color`,
/// `V3Font` et `V3Metric` : un écran d'avant le lot 10 prend la direction sans changer une
/// ligne, et elle se règle en un seul endroit.
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
    /// Le texte d'un aplat de l'accent : blanc, le jour comme la nuit.
    static var onAccent: Color { palette.onAccent }
    /// La lèvre d'une surface touchable : le bord plein sous une carte, une rangée, un bouton
    /// secondaire (`micaboSurface`).
    static var edge: Color { palette.edge }
    static var onInk: Color { palette.onInk }
    static var onInkMuted: Color { palette.onInkMuted }

    /// Fond des écrans qui ne sont ni une liste ni une lecture.
    static var canvasSage: Color { palette.canvasSage }

    /// Accent unique de l'app : sélection, onglet actif, éléments interactifs.
    ///
    /// Le bleu Micabo. Un libellé gras se lit dessus et en dessous ; une pastille de onze
    /// points sur `accentSoft` prend `accentInk`.
    static var accent: Color { palette.accent }
    static var accentSoft: Color { palette.accentSoft }

    /// Le bleu des **grandes** surfaces, et d'elles seules : un curseur, un histogramme,
    /// un remplissage. Il ne porte jamais de texte.
    static var accentVivid: Color { palette.accentVivid }

    /// L'accent pour du **petit texte** sur un lavis bleu (`accentSoft`, `accentWash`) :
    /// le 600 de la gamme le jour, le 300 la nuit.
    static var accentInk: Color { palette.accentInk }

    /// **Le dégradé de marque** : le bleu Micabo vers son 700 (la nuit, du 400 au 500).
    /// Il remplace l'ancien bleu → violet partout où un aplat porte la marque.
    static var accentDeep: Color { palette.accentDeep }
    static var brandGradient: [Color] { [accent, accentDeep] }

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
    static var positiveWash: Color { palette.positiveWash }
    static var positiveInk: Color { palette.positiveInk }
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
    /// Le choix est déterministe — `StableHash`, et non `hashValue`, que Swift re-sale à
    /// chaque lancement : le même deck garde sa couleur d'une ouverture à l'autre et d'un
    /// téléphone à l'autre.
    static func pastel(for id: UUID) -> Color {
        let slot = Int(StableHash.of(id.uuidString) % UInt64(tilePastels.count))
        return tilePastels[slot]
    }

    static func pastel(forName name: String) -> Color {
        let slot = Int(StableHash.of(name) % UInt64(tilePastels.count))
        return tilePastels[slot]
    }

    // MARK: La refonte « parcours »

    /// Les mots-clés et les termes définis des notes. Le seul violet d'une leçon.
    static var keyword: Color { palette.keyword }
    /// Bonne réponse : le plein, l'encre lisible, le lavis.
    static var correct: Color { palette.correct }
    static var correctInk: Color { palette.correctInk }
    static var correctSoft: Color { palette.correctSoft }
    /// Mauvaise réponse : le plein, l'encre lisible, le lavis.
    static var wrong: Color { palette.wrong }
    static var wrongInk: Color { palette.wrongInk }
    static var wrongSoft: Color { palette.wrongSoft }

    /// Le pastel d'un rang, pour une grille dont on choisit l'ordre des couleurs. Deux
    /// tuiles voisines tirées au hasard peuvent tomber sur le même ; par rang, jamais.
    static func pastel(at index: Int) -> Color {
        tilePastels[((index % tilePastels.count) + tilePastels.count) % tilePastels.count]
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

    /// Marge horizontale standard des écrans : celle de la V3.
    static let screen: CGFloat = V3Metric.screenMargin
}

/// **Le bouton est moins rond que la carte, et c'est voulu.**
///
/// Les deux étaient à seize et vingt, assez proches pour que l'œil les range ensemble. Un
/// écart net — quatorze contre vingt-deux — leur redonne deux natures : une carte est une
/// **surface** sur laquelle quelque chose est posé, un bouton est une **commande** qu'on
/// presse. Plus la surface est grande, plus elle peut s'arrondir sans mollir ; un bouton
/// trop rond, lui, perd ses angles d'appui et se met à ressembler à une pastille.
///
/// **Lot 10 : les valeurs sont celles de `V3Metric`** (12 / 14 / 18 / 22 / 24 / 28), le seul
/// endroit où un rayon de la direction artistique s'écrit.
enum MicaboRadius {
    /// Tuile pastel d'une rangée : carré arrondi, emoji ou symbole au centre.
    static let tile: CGFloat = V3Metric.radiusTile
    /// **La grande tuile d'un deck**, dans la grille à deux colonnes. Elle fait 112 points
    /// de haut et porte son emoji à quarante-quatre : à ce format, le rayon d'une tuile de
    /// rangée la ferait paraître carrée.
    static let deck: CGFloat = 26
    /// Même valeur que la tuile, pour les vignettes du parcours d'accueil.
    static let cover: CGFloat = V3Metric.radiusTile
    static let sm: CGFloat = V3Metric.radiusBadge
    /// Boutons (principaux, secondaires, connexion) et champs de saisie : la même forme pour
    /// tout ce qu'on touche pour agir. Voir `MicaboButtonMetrics`.
    static let button: CGFloat = V3Metric.radiusButton
    /// Un bloc à l'intérieur d'une carte, un champ.
    static let md: CGFloat = V3Metric.radiusInner
    /// Rangée-carte, encadré d'une fiche, rangée de choix du parcours d'accueil : le rayon de
    /// la ligne de réponse.
    static let lg: CGFloat = V3Metric.radiusInner
    /// **La carte à lavis** : série du profil, graphe de progression, et tout encadré qui
    /// porte une couleur de fond plutôt qu'un filet. Le rayon de la bulle V3 — un cran sous
    /// `card`, qui sert aux cartes à bord et à lèvre.
    static let wash: CGFloat = V3Metric.radiusBubble
    /// Bloc blanc regroupant plusieurs rangées, et cartes d'appel : le rayon de la carte V3.
    static let group: CGFloat = V3Metric.radiusCard
    static let card: CGFloat = V3Metric.radiusCard
    static let xl: CGFloat = V3Metric.radiusCard
    static let xxl: CGFloat = 26
    /// Coins des feuilles modales.
    static let sheet: CGFloat = V3Metric.radiusSheet
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
    static let tabBarHeight: CGFloat = V3Metric.tabBarHeight

    /// Air laissé entre la barre d'onglets et ce qu'une page ancre juste au-dessus d'elle :
    /// le « + » de Cours, le bouton de session de Réviser.
    ///
    /// La barre est pleine largeur, sur le fond du thème (lot 10) : huit points d'air au-dessus
    /// d'elle suffisent pour qu'un bouton de page ne se colle pas à ses icônes.
    static let tabBarGap: CGFloat = 8

    /// **Tout ce que la barre d'onglets occupe**, hors zone sûre : c'est la hauteur
    /// qu'une page racine doit se réserver, et celle dont un overlay de la racine
    /// doit s'écarter.
    ///
    /// La somme suit exactement ce que `MicaboTabBar` dessine : la rangée d'onglets,
    /// et l'air au-dessus pour les boutons de page.
    static var tabBarSpace: CGFloat { tabBarGap + tabBarHeight }
}

/// **Deux familles : Sofia Sans Condensed pour les titres, la police système pour le texte**
/// (V3.3, lot 10).
///
/// L'app a eu deux familles — Outfit pour nommer, Hanken Grotesk pour raconter —, puis une
/// seule, la Nunito ronde de la refonte « parcours ». Ses terminaisons rondes faisaient
/// enfantin : la V3.3 prend une condensée franche, **Sofia Sans Condensed**, pour ce qui se
/// lit de loin (titres, bulles de Mika, boutons, grands chiffres), et passe tout le reste en
/// **police système**. Nunito a quitté l'app.
///
/// **Tout ce type passe par `V3Font`**, la fabrique unique des polices de l'app.
/// - Les jetons nommés (`screenTitle`, `body`, `caption`…) **sont** des jetons `V3Font`.
/// - `ui(_:weight:)`, que cinq cents appels d'écran utilisent avec les tailles et les graisses
///   de l'ancienne app, est **réparti entre les deux familles** par `V3LegacyScale` : un titre
///   (19 points et plus, en gras) en Sofia Sans Condensed, le reste en police système au style
///   le plus proche. Un écran d'avant le lot 10 prend donc la typographie d'aujourd'hui sans qu'on y
///   touche, et elle se règle en un seul endroit. Un écran neuf n'appelle pas `ui` : il lit un
///   jeton `V3Font`.
enum MicaboFont {
    // MARK: La famille

    /// **La police d'un écran d'avant le lot 10**, demandée à l'ancienne échelle :
    /// `V3Font.legacy` en fait un titre Sofia ou du texte système. Voir le commentaire du type.
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        V3Font.legacy(size, weight: weight)
    }

    /// Le contenu d'un cours (question, définition, réponse) : police système à toute taille.
    /// Voir `V3Font.content`.
    static func content(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        V3Font.content(size, weight: weight)
    }

    /// Le texte qu'on lit, demandé à l'ancienne échelle : toujours en police système, et à sa
    /// graisse — un texte long garde son Regular.
    static func reading(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        V3Font.legacy(size, weight: weight, reading: true)
    }

    /// La police de la fiche côté UIKit : elle compose ses paragraphes dans un `UITextView` pour
    /// que la sélection d'un passage soit celle du système, et il lui faut donc des `UIFont`.
    /// Les mêmes deux familles que `V3Font` : la police d'affichage pour un titre (19 points et
    /// plus, en gras), la police système pour le reste — avec son vrai italique.
    static func uiFont(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> UIFont {
        if !italic, V3LegacyScale.isTitle(size: size, weight: weight),
           let display = UIFont(name: V3Typeface.displayName(for: V3LegacyScale.titleWeight(weight)), size: size) {
            return display
        }
        let system = UIFont.systemFont(ofSize: size, weight: uiWeight(for: weight))
        // L'italique s'ajoute aux traits de la police, il ne les remplace pas : un gras italique
        // reste gras.
        let traits = system.fontDescriptor.symbolicTraits.union(.traitItalic)
        guard italic, let slanted = system.fontDescriptor.withSymbolicTraits(traits) else { return system }
        return UIFont(descriptor: slanted, size: size)
    }

    /// La police d'interface côté UIKit, pour les rares vues qui en sont faites.
    static func uiDisplayFont(_ size: CGFloat, weight: Font.Weight = .regular) -> UIFont {
        uiFont(size, weight: weight)
    }

    private static func uiWeight(for weight: Font.Weight) -> UIFont.Weight {
        if weight == .black { return .black }
        if weight == .heavy { return .heavy }
        if weight == .bold { return .bold }
        if weight == .semibold { return .semibold }
        if weight == .medium { return .medium }
        return .regular
    }

    // MARK: Le barème de la refonte — des jetons `V3Font` (lot 10)
    //
    // Chaque rôle d'avant est le jeton `V3Font` qui lui correspond : 32 pour un titre de page,
    // 25 pour un titre d'écran ou de thème, 22 pour un titre de section, 21 pour un titre de
    // carte (Sofia Sans Condensed Black) ; 16-17 pour le corps, 15 pour un libellé, 13 pour une
    // légende (police système).

    /// Titre d'un thème, titre d'une leçon en tête de parcours.
    static let title = V3Font.h2
    /// Sous-titre dans les notes, titre d'une page de quiz.
    static let subtitle = V3Font.title
    /// Corps des notes et des puces : le seul texte long de l'app, un cran plus léger que
    /// l'interface.
    static let notes = V3Font.reading
    /// Un mot-clé dans les notes : gras, et violet (`MicaboColor.keyword`).
    static let keyword = V3Font.bodyStrong
    /// Titre d'un cercle sur le chemin, intitulé d'une rangée.
    static let label = V3Font.bodyStrong
    /// **Le plus petit texte de l'app** : durée, numéro de cercle, palier. Toujours en
    /// capitales, en gris, avec `MicaboTracking.caps`.
    static let small = V3Font.eyebrow

    // MARK: Rôles

    static func display(_ size: CGFloat) -> Font {
        ui(size, weight: .black)
    }

    /// **Les chiffres qu'on lit comme un résultat** : les stats de Home, un score, une
    /// progression. Poser `.monospacedDigit()` là où le nombre bouge reste nécessaire — c'est
    /// ce qui empêche un compteur de tressauter.
    static func number(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        ui(size, weight: weight)
    }

    /// Grand titre d'écran, posé à même le fond : le h1 de la direction artistique.
    static let screenTitle = V3Font.h1
    /// Titre d'un écran poussé ou d'une feuille : son h2.
    static let pageTitle = V3Font.h2
    /// Titre de section.
    static let sectionTitle = V3Font.section
    static let cardTitle = V3Font.cardTitle
    static let rowTitle = V3Font.bodyStrong
    static let rowSubtitle = V3Font.support
    static let body = V3Font.body
    static let bodyEmphasis = V3Font.bodyStrong
    static let caption = V3Font.support
    static let captionEmphasis = V3Font.custom(14, weight: .heavy)
    static let micro = V3Font.caption
    /// Sur-titres et intitulés de section, toujours en capitales.
    static let eyebrow = V3Font.eyebrow
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
    static let tight: CGFloat = V3Tracking.h2
    /// Resserrement des très grands chiffres et titres d'écran.
    static let display: CGFloat = V3Tracking.display
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
        if AppearanceStore.isDarkNow {
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
        let dark = AppearanceStore.isDarkNow
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

    /// **Plus d'ombre floue** (V3.3, lot 10) : sur le marine, une surface se détache par sa
    /// clarté et son filet. Seul ce qui flotte réellement au-dessus de la page — un bouton
    /// d'import posé sur le contenu — garde une ombre ; une rangée et une carte n'en ont plus.
    func body(content: Content) -> some View {
        let contact = level.contact
        let ambient = level.ambient
        let floats = level == .floating
        return content
            .shadow(
                color: MicaboShadow.tint.opacity(floats ? contact.opacity : 0),
                radius: floats ? contact.radius : 0,
                x: 0,
                y: floats ? contact.y : 0
            )
            .shadow(
                color: MicaboShadow.tint.opacity(floats ? level.ambientOpacity : 0),
                radius: floats ? ambient.radius : 0,
                x: 0,
                y: floats ? ambient.y : 0
            )
    }
}

/// **La teinte des ombres de l'app** : un bleu nuit très sombre. Assez proche du noir pour
/// tenir la nuit, assez bleu pour que l'ombre d'une carte blanche ne paraisse pas sale.
enum MicaboShadow {
    static let tint = Color(hex: 0x1A2340)
}

/// **La surface de l'app** : un fond, un rayon, un **filet de 1,5 point** (V3.3, lot 10).
///
/// Sur le marine, une carte se détache par sa clarté et son filet. Elle a eu une ombre floue
/// (qui grisait le blanc et ne se voyait pas la nuit), puis une lèvre de trois points (lot 9) :
/// la V3.3 ne garde de lèvre que sous le bouton principal. Les mesures viennent de `V3Metric`.
enum MicaboSurface {
    /// La hauteur de la lèvre d'une carte et d'une rangée : aucune, depuis la V3.3.
    static let lip: CGFloat = V3Metric.lip
    /// La lèvre d'un bouton plein : c'est elle qui s'enfonce à l'appui.
    static let buttonLip: CGFloat = V3Metric.buttonLip
    /// L'épaisseur du filet.
    static let border: CGFloat = V3Metric.border
}

struct MicaboSurfaceStyle: ViewModifier {
    var radius: CGFloat
    var fill: Color = MicaboColor.surface
    var stroke: Color = MicaboColor.stroke
    /// La lèvre demandée par l'écran. Elle ne dépasse jamais celle de la direction artistique
    /// (`MicaboSurface.lip`) : à zéro, aucune surface de l'app n'en a.
    var lip: CGFloat = MicaboSurface.lip
    /// Coupe le contenu à la forme : pour un Mika ou une image qui sort du bord.
    var clipped: Bool = false

    private var lipHeight: CGFloat { min(lip, MicaboSurface.lip) }

    /// La lèvre a la couleur du bord : le filet par défaut, la teinte d'une surface colorée.
    private var lipColor: Color {
        stroke == MicaboColor.stroke ? MicaboColor.edge : stroke
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return Group {
            if clipped {
                content.clipShape(shape)
            } else {
                content
            }
        }
        .background {
            ZStack {
                if lipHeight > 0 {
                    shape
                        .fill(lipColor)
                        .offset(y: lipHeight)
                }
                shape.fill(fill)
            }
        }
        .overlay {
            shape.strokeBorder(stroke, lineWidth: MicaboSurface.border)
        }
    }
}

/// **La carte de l'app** : la surface (`MicaboSurfaceStyle`) avec ses marges.
///
/// C'est la même que la carte de Home (`homeCard`) et que le bloc de rangées (`micaboGroup`) :
/// une feuille de réglages ressemble à la page qui l'a ouverte.
struct MicaboCardStyle: ViewModifier {
    var padding: CGFloat = MicaboSpacing.md
    var radius: CGFloat = MicaboRadius.card
    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .micaboSurface(radius: radius)
    }
}

extension View {
    /// Pose l'ombre d'un niveau donné, sans toucher au fond ni au rayon.
    func micaboElevation(_ level: MicaboElevation) -> some View {
        modifier(MicaboElevationStyle(level: level))
    }

    /// **La surface de l'app** : fond, filet, lèvre (`MicaboSurfaceStyle`).
    func micaboSurface(
        radius: CGFloat = MicaboRadius.card,
        fill: Color = MicaboColor.surface,
        stroke: Color = MicaboColor.stroke,
        lip: CGFloat = MicaboSurface.lip,
        clipped: Bool = false
    ) -> some View {
        modifier(MicaboSurfaceStyle(radius: radius, fill: fill, stroke: stroke, lip: lip, clipped: clipped))
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
        micaboSurface(radius: radius, clipped: true)
    }

    /// Ombre douce des éléments posés sur le fond, sans passer par une carte complète.
    func micaboSoftShadow(strength: Double = 0.06) -> some View {
        shadow(color: MicaboShadow.tint.opacity(strength), radius: 16, x: 0, y: 8)
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
