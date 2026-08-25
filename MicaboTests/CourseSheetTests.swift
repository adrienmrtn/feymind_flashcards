import Foundation
import SwiftData
import XCTest
@testable import Micabo

/// Le balisage en ligne d'une fiche : ce qui se met en forme, et ce qui ne doit surtout
/// pas se mettre en forme.
final class SheetMarkupTests: XCTestCase {
    func testBoldItalicAndHighlightAreParsed() {
        let spans = SheetMarkup.spans("Le **chloroplaste** est *cloisonné* et ==tout se joue là==.")

        XCTAssertEqual(spans.first { $0.isBold }?.text, "chloroplaste")
        XCTAssertEqual(spans.first { $0.isItalic }?.text, "cloisonné")
        XCTAssertEqual(spans.first { $0.isHighlighted }?.text, "tout se joue là")
    }

    func testPlainTextDropsTheMarkupItself() {
        XCTAssertEqual(
            SheetMarkup.plain("Le **chloroplaste** est *cloisonné* et ==tout se joue là==."),
            "Le chloroplaste est cloisonné et tout se joue là."
        )
    }

    /// Un délimiteur seul est un caractère comme un autre. Sans cette règle, un cours de
    /// statistiques où l'astérisque signale un résultat significatif partirait en italique
    /// jusqu'au bout du paragraphe.
    func testUnclosedDelimiterStaysLiteral() {
        XCTAssertEqual(SheetMarkup.plain("Le seuil p < 0,05 est noté *"), "Le seuil p < 0,05 est noté *")
        XCTAssertFalse(SheetMarkup.containsMarkup("2 * 3 donne 6"))
    }

    func testDoubleStarIsNotReadAsTwoItalics() {
        let spans = SheetMarkup.spans("**gras**")

        XCTAssertEqual(spans.count, 1)
        XCTAssertTrue(spans[0].isBold)
        XCTAssertFalse(spans[0].isItalic)
    }

    /// Une formule est opaque au balisage : elle passe par le même transpositeur que les
    /// cartes, et l'astérisque d'un exposant n'y ouvre pas d'italique.
    func testFormulasGoThroughTheFormulaRenderer() {
        let spans = SheetMarkup.spans("On écrit $H_2O$ pour l'eau.")

        XCTAssertEqual(spans.first { $0.isMath }?.text, "H₂O")
        XCTAssertEqual(SheetMarkup.plain("On écrit $H_2O$ pour l'eau."), "On écrit H₂O pour l'eau.")
    }

    func testMarkupInsideAHighlightIsKept() {
        let spans = SheetMarkup.spans("==le **carbone** de l'air==")

        XCTAssertTrue(spans.allSatisfy(\.isHighlighted))
        XCTAssertEqual(spans.first { $0.isBold }?.text, "carbone")
    }
}

/// Le décodage d'une fiche venue du serveur, et ce qu'on en jette.
final class CourseSheetDecodingTests: XCTestCase {
    private func sheet(_ json: String) throws -> CourseSheet {
        try JSONDecoder().decode(CourseSheet.self, from: Data(json.utf8))
    }

    func testEveryBlockTypeIsDecoded() throws {
        let decoded = try sheet("""
        {"blocks": [
          {"type": "heading", "level": 1, "text": "Partie"},
          {"type": "paragraph", "text": "Un paragraphe assez long pour être gardé tel quel."},
          {"type": "definition", "term": "Stroma", "text": "Le liquide qui baigne les thylakoïdes."},
          {"type": "callout", "tone": "attention", "text": "La phase sombre n'a pas lieu la nuit."},
          {"type": "steps", "title": "Trois temps", "items": ["Fixation", "Réduction", "Régénération"]},
          {"type": "table", "headers": ["A", "B"], "rows": [["1", "2"], ["3", "4"]]},
          {"type": "chart", "unit": "%", "bars": [{"label": "CO2", "value": 45}, {"label": "Lumière", "value": 11}]},
          {"type": "formula", "latex": "E = mc^2", "caption": "Légende"}
        ]}
        """)

        XCTAssertEqual(decoded.blocks.count, 8)
    }

    /// Un bloc inconnu ou vide ne doit pas emporter la fiche entière : c'est la différence
    /// entre une fiche à laquelle il manque un encadré et un écran vide.
    func testUnknownBlocksAreSkippedWithoutLosingTheRest() throws {
        let decoded = try sheet("""
        {"blocks": [
          {"type": "paragraph", "text": "Premier paragraphe, bien réel."},
          {"type": "carrousel", "text": "Un bloc que l'app ne sait pas afficher."},
          {"type": "paragraph", "text": "Second paragraphe, tout aussi réel."}
        ]}
        """)

        XCTAssertEqual(decoded.blocks.count, 2)
    }

    /// Les modèles écrivent régulièrement `12` là où le format attend `"12"`.
    func testNumericCellsAndValuesSurviveTheirQuotes() throws {
        let decoded = try sheet("""
        {"blocks": [
          {"type": "table", "headers": ["Année", "Valeur"], "rows": [["1885", 68], ["1978", 42]]},
          {"type": "chart", "bars": [{"label": "A", "value": "40"}, {"label": "B", "value": 12}]}
        ]}
        """)

        guard case .table(let table) = decoded.blocks.first else {
            return XCTFail("Le tableau doit être décodé")
        }
        XCTAssertEqual(table.rows.first, ["1885", "68"])

        guard case .chart(let chart) = decoded.blocks.last else {
            return XCTFail("Le graphe doit être décodé")
        }
        XCTAssertEqual(chart.bars.first?.value, 40)
    }

    func testCalloutToneFallsBackInsteadOfFailing() throws {
        let decoded = try sheet("""
        {"blocks": [
          {"type": "callout", "tone": "piège", "text": "Une confusion fréquente sur ce point."},
          {"type": "callout", "tone": "n'importe quoi", "text": "Ce qu'il faut retenir de la partie."}
        ]}
        """)

        guard case .callout(let first, _) = decoded.blocks.first,
              case .callout(let second, _) = decoded.blocks.last else {
            return XCTFail("Les deux encadrés doivent être décodés")
        }
        XCTAssertEqual(first, .attention)
        XCTAssertEqual(second, .essentiel)
    }

    func testRoundTripKeepsTheSheetIdentical() throws {
        let original = SampleData.photosynthesisSheet
        let data = try XCTUnwrap(original.encoded())

        XCTAssertEqual(CourseSheet.decode(from: data), original)
    }
}

/// Le nettoyage d'une fiche. La règle est étroite : le balisage reste, les marques d'un
/// texte laissé tel que l'IA l'a rendu partent.
final class CourseSheetSanitizationTests: XCTestCase {
    func testMarkupSurvivesWhereItWouldBeStrippedOnACard() {
        let sheet = CourseSheet(blocks: [
            .paragraph(text: "Le **chloroplaste** porte ==l'essentiel==.")
        ]).sanitized()

        guard case .paragraph(let text) = sheet.blocks.first else {
            return XCTFail("Le paragraphe doit être gardé")
        }
        XCTAssertEqual(text, "Le **chloroplaste** porte ==l'essentiel==.")
        // La même phrase sur une carte perdrait son balisage, puisque rien ne le rend.
        XCTAssertEqual(TextSanitizer.clean(text), "Le chloroplaste porte l'essentiel.")
    }

    func testEmDashesAndStrayBulletsAreRemoved() {
        let sheet = CourseSheet(blocks: [
            .paragraph(text: "- Le cours — voici la suite"),
            .paragraph(text: "## Un titre de markdown égaré")
        ]).sanitized()

        XCTAssertEqual(sheet.blocks.count, 2)
        XCTAssertEqual(sheet.plainText(), "Le cours, voici la suite\nUn titre de markdown égaré")
    }

    /// Une astérisque en tête de paragraphe est de l'italique, pas une puce.
    func testLeadingItalicIsNotMistakenForABullet() {
        let sheet = CourseSheet(blocks: [.paragraph(text: "*Phase sombre* est un nom trompeur.")]).sanitized()

        guard case .paragraph(let text) = sheet.blocks.first else {
            return XCTFail("Le paragraphe doit être gardé")
        }
        XCTAssertEqual(text, "*Phase sombre* est un nom trompeur.")
    }

    func testBlocksThatCannotBeDisplayedDisappear() {
        let sheet = CourseSheet(blocks: [
            .steps(title: "Une seule étape", items: ["Fixation"]),
            .table(SheetTable(headers: ["Seule colonne"], rows: [["a"], ["b"]])),
            .chart(SheetChart(bars: [SheetChart.Bar(label: "Unique", value: 12)])),
            .chart(SheetChart(bars: [
                SheetChart.Bar(label: "A", value: 0),
                SheetChart.Bar(label: "B", value: 0)
            ])),
            .paragraph(text: "Le seul bloc qui tient debout.")
        ]).sanitized()

        XCTAssertEqual(sheet.blocks.count, 1)
    }

    func testIncompleteTableRowsArePaddedRatherThanDropped() {
        let sheet = CourseSheet(blocks: [
            .table(SheetTable(
                headers: ["A", "B", "C"],
                rows: [["1", "2", "3"], ["4"]]
            ))
        ]).sanitized()

        guard case .table(let table) = sheet.blocks.first else {
            return XCTFail("Le tableau doit être gardé")
        }
        XCTAssertEqual(table.rows.last, ["4", "", ""])
    }
}

/// Le surligneur garanti par le code. Le prompt le réclame depuis longtemps et les fiches
/// arrivaient nues : ce plancher ne dépend plus du modèle.
final class SheetHighlighterTests: XCTestCase {
    private func highlightCount(_ sheet: CourseSheet) -> Int {
        sheet.blocks.reduce(0) { total, block in
            let texts: [String]
            switch block {
            case .paragraph(let text), .callout(_, let text), .heading(_, let text):
                texts = [text]
            case .definition(let term, let text):
                texts = [term, text]
            default:
                texts = []
            }
            return total + texts.reduce(0) { $0 + ($1.components(separatedBy: "==").count - 1) / 2 }
        }
    }

    func testAnUnmarkedSheetGetsItsMarker() {
        let sheet = CourseSheet(blocks: [
            .paragraph(text: "L'eau change d'état sans jamais quitter la planète, et c'est tout le sujet du chapitre."),
            .heading(level: 1, text: "Les trois temps"),
            .paragraph(text: "L'évaporation précède la condensation, puis la précipitation referme la boucle du cycle."),
            .definition(
                term: "Condensation",
                text: "Passage de la vapeur à l'état liquide, autour de noyaux de condensation minuscules."
            ),
            .callout(
                tone: .essentiel,
                text: "Le cycle de l'eau est fermé : la quantité totale d'eau sur Terre ne varie jamais."
            )
        ])

        XCTAssertEqual(highlightCount(sheet), 0)
        XCTAssertGreaterThanOrEqual(highlightCount(sheet.highlighted()), SheetHighlighter.minimumHighlights)
    }

    /// L'encadré « essentiel » tient tout le chapitre : c'est le premier passage marqué.
    func testTheEssentialCalloutIsMarkedFirst() {
        let sheet = CourseSheet(blocks: [
            .callout(
                tone: .essentiel,
                text: "La quantité totale d'eau sur Terre ne varie pas : le cycle est entièrement fermé."
            ),
            .paragraph(text: "L'évaporation précède la condensation, puis la précipitation referme la boucle.")
        ])

        let marked = CourseSheet(blocks: SheetHighlighter.ensuring(sheet.blocks, minimum: 1))

        guard case .callout(_, let callout) = marked.blocks[0],
              case .paragraph(let paragraph) = marked.blocks[1] else {
            return XCTFail("Les deux blocs doivent être gardés")
        }
        XCTAssertTrue(callout.contains("=="))
        XCTAssertFalse(paragraph.contains("=="))
    }

    func testASheetAlreadyMarkedIsLeftAlone() {
        let sheet = CourseSheet(blocks: [
            .paragraph(text: "==L'eau change d'état== sans jamais quitter la planète, et voilà le sujet."),
            .paragraph(text: "==L'évaporation précède la condensation== puis la précipitation referme.")
        ])

        XCTAssertEqual(CourseSheet(blocks: SheetHighlighter.ensuring(sheet.blocks, minimum: 2)), sheet)
    }

    /// Le marqueur porte sur une phrase, jamais sur un paragraphe entier, et il laisse la
    /// ponctuation finale dehors.
    func testTheMarkerCoversASentenceAndNotThePunctuation() throws {
        let marked = try XCTUnwrap(
            SheetHighlighter.marked(
                "L'eau circule sans jamais quitter la planète, et cette boucle est fermée. "
                    + "La **condensation** transforme la vapeur en gouttelettes autour de noyaux minuscules."
            )
        )

        XCTAssertTrue(marked.contains("==La **condensation**"))
        XCTAssertTrue(marked.contains("minuscules==."))
    }

    func testASentenceTooLongIsCutOnItsFirstClause() throws {
        let long = "La photosynthèse convertit l'énergie lumineuse en énergie chimique, "
            + "ce qui suppose une chaîne de transporteurs, des pigments capables d'absorber "
            + "certaines longueurs d'onde, et une organisation membranaire que seuls les "
            + "thylakoïdes des chloroplastes rendent possible dans la cellule végétale."

        let marked = try XCTUnwrap(SheetHighlighter.marked(long))
        let passage = SheetMarkup.spans(marked).first { $0.isHighlighted }

        XCTAssertNotNil(passage)
        XCTAssertLessThanOrEqual(passage?.text.count ?? .max, 170)
    }

    func testNothingIsMarkedWhenNoSentenceIsWorthIt() {
        XCTAssertNil(SheetHighlighter.marked("Trop court."))
        XCTAssertNil(SheetHighlighter.marked("Un texte ==déjà marqué== et assez long pour être choisi."))
    }

    /// Ni les titres, ni les tableaux : ils portent déjà leur mise en valeur.
    func testHeadingsAndTablesAreNeverMarked() {
        let sheet = CourseSheet(blocks: [
            .heading(level: 1, text: "Un titre qui pourrait tenir une phrase entière sans problème"),
            .table(SheetTable(
                headers: ["Phase", "Lieu"],
                rows: [["Photochimique", "Thylakoïdes"], ["Biochimique", "Stroma"]]
            ))
        ])

        XCTAssertEqual(sheet.highlighted(), sheet)
    }
}

/// La fiche à plat : c'est ce texte qui part au modèle pour écrire des cartes ou expliquer
/// un passage, donc rien de ce qui se mémorise ne doit y disparaître.
final class CourseSheetFlatteningTests: XCTestCase {
    func testTableAndChartValuesAreKeptWithTheirColumnName() {
        let sheet = CourseSheet(blocks: [
            .table(SheetTable(
                headers: ["", "Photochimique", "Biochimique"],
                rows: [["Lieu", "Thylakoïdes", "Stroma"], ["Produit", "ATP", "Glucose"]]
            )),
            .chart(SheetChart(
                bars: [SheetChart.Bar(label: "CO₂ enrichi", value: 45)],
                unit: "%"
            ))
        ])

        let text = sheet.plainText()

        XCTAssertTrue(text.contains("Lieu"))
        XCTAssertTrue(text.contains("Photochimique : Thylakoïdes"))
        // Le chiffre d'un graphe se révise : il ne doit pas être perdu en route.
        XCTAssertTrue(text.contains("45%"))
    }

    func testStepsAreNumberedOnceFlattened() {
        let sheet = CourseSheet(blocks: [
            .steps(title: nil, items: ["Fixation du CO₂", "Réduction en G3P"])
        ])

        XCTAssertEqual(sheet.plainText(), "1. Fixation du CO₂\n2. Réduction en G3P")
    }

    func testReadingTimeIsAnnouncedFromTheSheetItself() {
        XCTAssertGreaterThanOrEqual(SampleData.photosynthesisSheet.readingMinutes, 1)
        XCTAssertLessThanOrEqual(SampleData.photosynthesisSheet.readingMinutes, 6)
    }
}

/// Ce que le serveur renvoie, et ce que l'app en fait.
final class GeneratedCourseSheetTests: XCTestCase {
    func testSheetIsDecodedAlongsideTheCourse() throws {
        let json = """
        {
          "title": "La photosynthèse",
          "summary": "Deux phrases.",
          "contextText": "Une notion par ligne",
          "sheet": {"blocks": [{"type": "paragraph", "text": "Un paragraphe de la fiche du cours."}]}
        }
        """

        let course = try JSONDecoder().decode(GeneratedCourse.self, from: Data(json.utf8))

        XCTAssertEqual(course.sheet?.blocks.count, 1)
        XCTAssertEqual(course.contextText, "Une notion par ligne")
    }

    /// Si le serveur envoie la fiche sans sa version à plat, on la reconstitue : sans ça,
    /// le cours arriverait sans contexte et aucune carte ne pourrait être écrite.
    func testContextIsRebuiltFromTheSheetWhenTheServerOmitsIt() throws {
        let json = """
        {
          "title": "T",
          "summary": "S",
          "sheet": {"blocks": [{"type": "paragraph", "text": "Le carbone entre dans le vivant par le cycle de Calvin."}]}
        }
        """

        let course = try JSONDecoder().decode(GeneratedCourse.self, from: Data(json.utf8))

        XCTAssertEqual(course.contextText, "Le carbone entre dans le vivant par le cycle de Calvin.")
    }

    /// Le format d'avant la fiche reste lu : un serveur non redéployé ne doit pas casser
    /// l'import.
    func testTheFormatFromBeforeTheSheetStillImports() throws {
        let json = """
        {"title": "T", "summary": "S", "blocks": [{"type": "paragraph", "text": "Premier"}]}
        """

        let course = try JSONDecoder().decode(GeneratedCourse.self, from: Data(json.utf8))

        XCTAssertNil(course.sheet)
        XCTAssertEqual(course.contextText, "Premier")
    }
}

/// Ce que l'écriture d'une fiche fait au cours enregistré.
final class CourseSheetPersistenceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    func testSavingAnImportKeepsBothTheSheetAndItsFlatVersion() throws {
        let generated = GeneratedCourse(
            title: "La photosynthèse",
            subject: "SVT",
            summary: "Résumé.",
            sheet: SampleData.photosynthesisSheet,
            contextText: ""
        )

        let course = try CourseRepository.save(
            generated,
            source: .pdf,
            rawText: "Texte source du document.",
            in: context
        )

        XCTAssertTrue(course.hasSheet)
        // Ce qui est enregistré est ce que le modèle a écrit ; ce qui se relit porte en plus
        // le surligneur garanti par l'app.
        XCTAssertEqual(course.decodedSheet(), SampleData.photosynthesisSheet.sanitized().highlighted())
        XCTAssertEqual(CourseSheet.decode(from: course.sheetData), SampleData.photosynthesisSheet.sanitized())
        // Sans contexte envoyé par le serveur, il est reconstitué depuis la fiche : c'est
        // lui qui sert à écrire les cartes.
        XCTAssertFalse(course.contextText.isEmpty)
    }

    /// « Refaire la fiche » ne renomme pas le cours : un titre corrigé à la main ne doit
    /// pas être écrasé par celui que le modèle trouve au second passage.
    func testRewritingTheSheetLeavesTheTitleAlone() throws {
        let course = try CourseRepository.save(
            GeneratedCourse(title: "Chapitre 4", summary: "Résumé.", contextText: "Contenu à plat."),
            source: .text,
            rawText: "Texte source du document.",
            in: context
        )
        XCTAssertFalse(course.hasSheet)

        try CourseRepository.updateSheet(
            of: course,
            with: GeneratedCourse(
                title: "Un titre trouvé par le modèle",
                summary: "Autre résumé.",
                sheet: SampleData.affineFunctionsSheet,
                contextText: "Nouveau contenu à plat."
            ),
            in: context
        )

        XCTAssertEqual(course.title, "Chapitre 4")
        XCTAssertTrue(course.hasSheet)
        XCTAssertEqual(course.contextText, "Nouveau contenu à plat.")
    }

    func testAnEmptySheetIsRefusedRatherThanStored() throws {
        let course = try CourseRepository.save(
            GeneratedCourse(title: "Chapitre 4", summary: "Résumé.", contextText: "Contenu à plat."),
            source: .text,
            rawText: "Texte source.",
            in: context
        )

        XCTAssertThrowsError(
            try CourseRepository.updateSheet(
                of: course,
                with: GeneratedCourse(title: "T", summary: "S", contextText: "C"),
                in: context
            )
        )
        XCTAssertFalse(course.hasSheet)
    }
}

/// La fiche construite sans IA. Elle structure ce qu'on peut reconnaître sans comprendre,
/// et elle ne met rien en valeur : deviner ce qui compte dans un cours qu'on n'a pas lu
/// produirait une fiche qui souligne n'importe quoi.
final class OfflineSheetBuilderTests: XCTestCase {
    private let source = """
    Les fonctions affines
    Une fonction affine s'écrit toujours sous la forme f(x) = ax + b, où a et b sont deux nombres fixés à l'avance.
    Coefficient directeur : le nombre a, qui mesure la pente de la droite représentative de la fonction.
    Le coefficient directeur mesure la pente de la droite représentative de la fonction affine étudiée.
    """

    func testHeadingsAndDefinitionsAreRecognized() throws {
        let sheet = try XCTUnwrap(OfflineSheetBuilder.build(from: source, title: "Chapitre 3"))

        let hasHeading = sheet.blocks.contains { block in
            if case .heading(_, let text) = block { return text == "Les fonctions affines" }
            return false
        }
        let hasDefinition = sheet.blocks.contains { block in
            if case .definition(let term, _) = block { return term == "Coefficient directeur" }
            return false
        }

        XCTAssertTrue(hasHeading)
        XCTAssertTrue(hasDefinition)
    }

    func testNothingIsEmphasizedWithoutHavingReadTheCourse() throws {
        let sheet = try XCTUnwrap(OfflineSheetBuilder.build(from: source, title: "Chapitre 3"))

        XCTAssertFalse(SheetMarkup.containsMarkup(sheet.plainText()))
        for block in sheet.blocks {
            for line in block.plainLines() {
                XCTAssertFalse(line.contains("**"), "La fiche hors ligne ne met rien en gras")
                XCTAssertFalse(line.contains("=="), "La fiche hors ligne ne surligne rien")
            }
        }
    }

    func testAnOfflineImportStillArrivesWithASheet() {
        let course = OfflineCourseBuilder.build(from: source, hintTitle: "Chapitre 3", sourceName: nil)

        XCTAssertNotNil(course.sheet)
        XCTAssertFalse(course.contextText.isEmpty)
    }

    func testTooLittleTextGivesNoSheetAtAll() {
        XCTAssertNil(OfflineSheetBuilder.build(from: "court", title: "T"))
    }
}

/// La sélection d'un passage : ce qui vaut un appel à l'IA, et ce qui n'en vaut pas.
final class SheetSelectionTests: XCTestCase {
    func testAWordOrASentenceIsExplainable() {
        XCTAssertTrue(SheetSelection.isExplainable("Rubisco"))
        XCTAssertTrue(SheetSelection.isExplainable("La phase biochimique se déroule dans le stroma."))
    }

    func testStraySelectionsAreRefused() {
        XCTAssertFalse(SheetSelection.isExplainable("a"))
        XCTAssertFalse(SheetSelection.isExplainable("  "))
        XCTAssertFalse(SheetSelection.isExplainable("42 ,"))
        XCTAssertFalse(SheetSelection.isExplainable(String(repeating: "mot ", count: 400)))
    }

    func testQuotedPassageLosesItsTrailingPunctuation() {
        XCTAssertEqual(SheetSelection.trimmed(" la photolyse de l'eau. "), "la photolyse de l'eau")
    }
}
