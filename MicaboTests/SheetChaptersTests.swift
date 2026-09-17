import Foundation
import XCTest
@testable import Micabo

/// **Le découpage en chapitres, et la propriété dont tout l'écran dépend.**
///
/// Un chapitre se modifie seul, dans son propre éditeur, et la fiche entière se réécrit à
/// partir de tous les chapitres. Si le recollage n'est pas l'inverse exact du découpage, une
/// faute de frappe corrigée dans la deuxième partie réécrit la fiche de travers — et c'est le
/// genre de perte qu'on ne voit qu'après la synchro.
final class SheetChaptersTests: XCTestCase {
    private let fiche: [SheetBlock] = [
        .paragraph(text: "La crise de 1929 éclate à New York et gagne l'Europe en deux ans."),
        .heading(level: 1, text: "Les causes de la crise"),
        .paragraph(text: "Les industries produisent plus que les ménages ne peuvent acheter."),
        .heading(level: 2, text: "La surproduction"),
        .list(ordered: false, items: ["Les prix agricoles chutent", "Les salaires stagnent"]),
        .heading(level: 1, text: "Les conséquences sociales"),
        .paragraph(text: "Le chômage de masse s'installe dans les pays industrialisés."),
    ]

    func testAChapterStartsAtEveryPartTitle() {
        let chapters = SheetChapters.split(fiche)

        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters.map(\.title), [nil, "Les causes de la crise", "Les conséquences sociales"])
        XCTAssertEqual(chapters.map(\.index), [0, 1, 2])
    }

    /// Un titre de sous-partie est le plan **dans** une partie. Replier à ce niveau donnerait
    /// vingt accordéons d'une ligne au lieu du plan qu'on vient chercher.
    func testASubtitleDoesNotOpenAChapter() {
        let chapters = SheetChapters.split(fiche)

        XCTAssertEqual(chapters[1].blocks.count, 4)
        XCTAssertTrue(chapters[1].blocks.contains(.heading(level: 2, text: "La surproduction")))
    }

    /// Le titre reste **dans** le texte : c'est ce qui permet de continuer à le corriger,
    /// comme le reste de la fiche.
    func testTheTitleStaysInsideItsChapter() {
        let chapters = SheetChapters.split(fiche)

        XCTAssertEqual(chapters[1].blocks.first, .heading(level: 1, text: "Les causes de la crise"))
        XCTAssertEqual(chapters[2].blocks.first, .heading(level: 1, text: "Les conséquences sociales"))
    }

    func testTheDisplayedTitleDropsItsMarkup() {
        let chapters = SheetChapters.split([
            .heading(level: 1, text: "La **réplication** de l'ADN"),
            .paragraph(text: "Elle se déroule en trois temps, chacun porté par une enzyme."),
        ])

        XCTAssertEqual(chapters.first?.title, "La réplication de l'ADN")
        // Le bloc, lui, garde son balisage : c'est le texte de la fiche.
        XCTAssertEqual(chapters.first?.blocks.first, .heading(level: 1, text: "La **réplication** de l'ADN"))
    }

    func testJoinIsTheExactInverseOfSplit() {
        XCTAssertEqual(SheetChapters.join(SheetChapters.split(fiche)), fiche)
    }

    /// Une fiche sans le moindre titre de partie n'a qu'un chapitre, qui est elle-même.
    func testASheetWithoutTitlesIsOneChapter() {
        let nue: [SheetBlock] = [
            .paragraph(text: "Le cours tient en deux paragraphes, et il n'a pas de plan."),
            .paragraph(text: "Le second dit ce que le premier laissait entendre sans le dire."),
        ]
        let chapters = SheetChapters.split(nue)

        XCTAssertEqual(chapters.count, 1)
        XCTAssertNil(chapters[0].title)
        XCTAssertEqual(SheetChapters.join(chapters), nue)
    }

    func testAnEmptySheetHasNoChapter() {
        XCTAssertTrue(SheetChapters.split([]).isEmpty)
        XCTAssertTrue(SheetChapters.join([]).isEmpty)
    }

    /// Une fiche qui ouvre sur un titre n'a pas de chapitre d'introduction vide devant lui.
    func testASheetOpeningOnATitleHasNoEmptyPreamble() {
        let chapters = SheetChapters.split([
            .heading(level: 1, text: "Première partie"),
            .paragraph(text: "Le cours commence directement par son premier titre de partie."),
        ])

        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters[0].title, "Première partie")
    }

    func testReplacingRewritesOnlyItsOwnChapter() {
        let chapters = SheetChapters.split(fiche)
        let corrige: [SheetBlock] = [
            .heading(level: 1, text: "Les causes de la crise"),
            .paragraph(text: "Les industries produisent plus que les ménages ne peuvent absorber."),
        ]

        let next = SheetChapters.replacing(chapters, at: 1, with: corrige)

        XCTAssertEqual(Array(next.prefix(1)), Array(fiche.prefix(1)))
        XCTAssertEqual(Array(next.suffix(2)), Array(fiche.suffix(2)))
        XCTAssertTrue(next.contains(.paragraph(text: "Les industries produisent plus que les ménages ne peuvent absorber.")))
    }

    func testReplacingAnUnknownChapterChangesNothing() {
        let chapters = SheetChapters.split(fiche)

        XCTAssertEqual(SheetChapters.replacing(chapters, at: 9, with: []), fiche)
    }
}

/// **Le découpeur de pavés**, jumeau de `splitParagraph` côté serveur.
final class SheetTextSplitTests: XCTestCase {
    /// Huit phrases d'environ quatre-vingt-dix caractères : le pavé type d'une fiche.
    private let pave = [
        "La seconde industrialisation commence en 1897 et court jusqu'à la veille de la guerre.",
        "Les États-Unis et l'Allemagne y deviennent les centres majeurs de l'innovation technique.",
        "Le Royaume-Uni, qui dominait la première industrialisation, perd son avance relative.",
        "Les industries chimiques et électriques y prennent la place de la sidérurgie et du textile.",
        "L'aspirine déposée par Bayer en 1899 témoigne de la vigueur de la recherche appliquée.",
        "Les grands magasins comme Le Bon Marché font baisser les prix unitaires et la consommation monte.",
        "Schumpeter théorise ces vagues d'innovation sous le nom de cycles économiques longs.",
        "La croissance reste soutenue malgré des crises sectorielles en Allemagne et aux États-Unis.",
    ].joined(separator: " ")

    func testANormalParagraphIsLeftAlone() {
        let court = "La crise de 1929 éclate à New York et gagne l'Europe en moins de deux ans."

        XCTAssertLessThan(court.count, SheetLimits.paragraphChars)
        XCTAssertEqual(SheetText.split(court), [court])
    }

    func testAWallOfTextIsCutAndLosesNothing() {
        XCTAssertGreaterThan(pave.count, SheetLimits.paragraphChars)

        let parts = SheetText.split(pave)

        XCTAssertGreaterThan(parts.count, 1)
        // Recollés, ils redonnent le texte : le découpeur ne réécrit rien.
        XCTAssertEqual(parts.joined(separator: " "), pave)
    }

    func testEveryCutFallsAtTheEndOfASentence() {
        for part in SheetText.split(pave) {
            XCTAssertTrue(".!?…".contains(part.last ?? " "), "« \(part) » ne finit pas une phrase")
            XCTAssertGreaterThanOrEqual(part.count, 60)
        }
    }

    /// Une phrase plus longue que le plafond à elle seule sort telle quelle : tranchée en deux
    /// blocs, elle se lirait comme un bug d'affichage.
    func testASingleLongSentenceIsNeverCut() {
        let seule = String(repeating: "une proposition de plus, ", count: 40) + "et voilà la fin."

        XCTAssertGreaterThan(seule.count, SheetLimits.paragraphChars)
        XCTAssertEqual(SheetText.split(seule), [seule])
    }

    func testAFormulaKeepsItsDollarsTogether() {
        let avecFormule = [
            "Le rendement de conversion se calcule à partir de la mesure de puissance électrique.",
            "On pose $\\eta = 0.92$ Pour une installation nominale, et la valeur chute en modulé.",
            "Les pertes thermiques expliquent l'essentiel de cet écart entre les deux régimes.",
            "Une installation bien dimensionnée récupère une part de cette chaleur en aval du cycle.",
            "Le gain net dépend alors de la température de la source froide disponible sur le site.",
            "Les exploitants retiennent en pratique une fourchette de quatre-vingts à quatre-vingt-dix.",
        ].joined(separator: " ")

        for part in SheetText.split(avecFormule) {
            XCTAssertEqual(part.filter { $0 == "$" }.count % 2, 0, "« \(part) » coupe une formule")
        }
    }

    func testAnInitialIsNotTheEndOfASentence() {
        let avecInitiale = [
            "Le modèle de la double hélice est publié dans la revue Nature au printemps de 1953.",
            "J. Watson et F. Crick s'appuient sur les clichés de diffraction de Rosalind Franklin.",
            "La structure explique d'un coup la réplication fidèle et la nature du code génétique.",
            "Elle vaut à ses auteurs le prix Nobel de physiologie ou médecine quelques années après.",
            "Franklin, morte en 1958, n'a pas pu figurer parmi les lauréats de cette distinction.",
            "Son rôle a longtemps été minoré dans les récits que la discipline a faits d'elle-même.",
        ].joined(separator: " ")

        for part in SheetText.split(avecInitiale) {
            XCTAssertFalse(part.hasSuffix(" J."), "« \(part) » a coupé sur une initiale")
            XCTAssertFalse(part.hasSuffix(" F."), "« \(part) » a coupé sur une initiale")
        }
    }

    /// Ce que le serveur fait à la génération, l'app le fait à la lecture : les fiches déjà
    /// en base profitent du découpage sans qu'on les réécrive.
    func testDecodingSplitsAWallOfText() {
        let json = """
        {"blocks":[{"type":"paragraph","text":"\(pave)"}]}
        """
        let sheet = CourseSheet.decode(from: Data(json.utf8))

        XCTAssertNotNil(sheet)
        XCTAssertGreaterThan(sheet?.blocks.count ?? 0, 1)
    }
}
