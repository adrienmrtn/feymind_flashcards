import Foundation
import SwiftData
import UIKit
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

    /// Une couleur nommée avant la barre change la teinte, sans entrer dans le texte.
    func testANamedColourChangesTheHighlight() {
        let spans = SheetMarkup.spans("==menthe|ce passage== et ==celui-ci==")

        XCTAssertEqual(spans.first { $0.isHighlighted }?.text, "ce passage")
        XCTAssertEqual(spans.first { $0.isHighlighted }?.highlight, .menthe)
        XCTAssertEqual(spans.last { $0.isHighlighted }?.highlight, .jaune)
        XCTAssertEqual(SheetMarkup.plain("==menthe|ce passage=="), "ce passage")
    }

    /// Un nom qui n'est pas une couleur reste du texte, barre comprise : « a | b » veut dire
    /// quelque chose dans un cours d'informatique.
    func testAnUnknownColourNameStaysInTheText() {
        XCTAssertEqual(SheetMarkup.plain("==a | b=="), "a | b")
    }

    /// Le chemin inverse, celui de l'éditeur : des fragments vers le texte balisé.
    func testSpansGoBackToMarkup() {
        let source = "Le **chloroplaste** porte ==menthe|l'essentiel==."

        XCTAssertEqual(SheetMarkup.markup(from: SheetMarkup.spans(source)), source)
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
          {"type": "list", "ordered": true, "items": ["Fixation", "Réduction"]},
          {"type": "formula", "latex": "E = mc^2", "caption": "Légende"}
        ]}
        """)

        XCTAssertEqual(decoded.blocks.count, 4)
        guard case .list(let ordered, let items) = decoded.blocks[2] else {
            return XCTFail("La liste doit être décodée")
        }
        XCTAssertTrue(ordered)
        XCTAssertEqual(items, ["Fixation", "Réduction"])
    }

    /// **Les fiches déjà en base ne sont pas perdues.** Les blocs d'avant sont convertis à la
    /// lecture, exactement comme le serveur les convertit : une définition devient sa phrase,
    /// un tableau ses lignes, un graphe ses valeurs.
    func testTheBlocksFromBeforeAreConvertedRatherThanDropped() throws {
        let decoded = try sheet("""
        {"blocks": [
          {"type": "definition", "term": "Stroma", "text": "Le liquide qui baigne les thylakoïdes."},
          {"type": "callout", "tone": "attention", "text": "La phase sombre n'a pas lieu la nuit."},
          {"type": "steps", "title": "Trois temps", "items": ["Fixation", "Réduction"]},
          {"type": "table", "headers": ["A", "B"], "rows": [["1", "2"]]},
          {"type": "chart", "unit": "%", "bars": [{"label": "CO2", "value": 45}]},
          {"type": "figure", "page": 2, "caption": "Cycle de Krebs"}
        ]}
        """)

        let texts = decoded.blocks.flatMap { block -> [String] in
            switch block {
            case .paragraph(let text): [text]
            case .list(_, let items): items
            default: []
            }
        }

        XCTAssertTrue(texts.contains("**Stroma** : Le liquide qui baigne les thylakoïdes."))
        XCTAssertTrue(texts.contains("La phase sombre n'a pas lieu la nuit."))
        XCTAssertTrue(texts.contains("**Trois temps**"))
        XCTAssertTrue(texts.contains("Fixation"))
        XCTAssertTrue(texts.contains("**A** : 1, **B** : 2"))
        XCTAssertTrue(texts.contains("**CO2** : 45 %"))
        XCTAssertTrue(texts.contains("Cycle de Krebs"))

        // Une suite d'étapes vaut deux blocs : son titre, puis la liste numérotée.
        guard case .list(let ordered, _) = decoded.blocks[3] else {
            return XCTFail("Les étapes doivent devenir une liste numérotée")
        }
        XCTAssertTrue(ordered)
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
          {"type": "list", "items": ["1885", 68, true]},
          {"type": "chart", "bars": [{"label": "A", "value": "40"}]}
        ]}
        """)

        guard case .list(_, let items) = decoded.blocks.first else {
            return XCTFail("La liste doit être décodée")
        }
        XCTAssertEqual(items, ["1885", "68", "oui"])

        guard case .list(_, let values) = decoded.blocks.last else {
            return XCTFail("Le graphe doit devenir une liste")
        }
        XCTAssertEqual(values, ["**A** : 40"])
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
            .paragraph(text: "Trop court."),
            .list(ordered: false, items: []),
            .formula(latex: "  ", caption: nil),
            .heading(level: 1, text: "   "),
            .paragraph(text: "Le seul bloc qui tient debout, et qui a la longueur qu'il faut.")
        ]).sanitized()

        XCTAssertEqual(sheet.blocks.count, 1)
    }

    /// Une puce seule est acceptée : sur une fiche qu'on modifie à la main, elle est le
    /// premier point d'une liste qu'on est en train d'écrire, pas une erreur du modèle.
    func testASingleBulletIsKeptOnAnEditableSheet() {
        let sheet = CourseSheet(blocks: [.list(ordered: false, items: ["Fixation"])]).sanitized()

        XCTAssertEqual(sheet.blocks.count, 1)
    }
}

/// Le rendu d'un passage mis en avant, et l'échelle typographique de la fiche.
final class SheetRenderingTests: XCTestCase {
    /// Le passage marqué porte **une bande, et garde son encre**. Il a été de l'encre bleue
    /// pendant une version, le temps de savoir dessiner la bande correctement : mais du texte
    /// bleu au milieu d'un paragraphe se lit comme un lien, pas comme un surlignage.
    func testAnEmphasisedPassageCarriesTheMarkerAndKeepsItsInk() throws {
        let composed = SheetAttributedText.make("Un ==passage marqué== dans une phrase.", style: .prose)
        let text = composed.string as NSString

        let marked = text.range(of: "passage marqué")
        let plain = text.range(of: "dans une phrase")
        XCTAssertNotEqual(marked.location, NSNotFound)
        XCTAssertNotEqual(plain.location, NSNotFound)

        let band = composed.attribute(.backgroundColor, at: marked.location, effectiveRange: nil) as? UIColor
        XCTAssertEqual(band, UIColor(MicaboColor.sheetHighlight(.jaune)))
        XCTAssertNil(
            composed.attribute(.backgroundColor, at: plain.location, effectiveRange: nil),
            "La bande s'arrête au passage marqué"
        )

        let markedInk = try XCTUnwrap(
            composed.attribute(.foregroundColor, at: marked.location, effectiveRange: nil) as? UIColor
        )
        let plainInk = try XCTUnwrap(
            composed.attribute(.foregroundColor, at: plain.location, effectiveRange: nil) as? UIColor
        )
        XCTAssertEqual(markedInk, plainInk, "Une bande et une encre de couleur font deux marques pour une")
    }

    /// **Le défaut qui avait fait retirer le surligneur, tenu par un test.**
    ///
    /// TextKit peint un fond sur toute la hauteur de la ligne, interligne compris : la bande
    /// grossissait donc avec l'interligne du paragraphe. Celle qu'on dessine se cale sur la
    /// hauteur des capitales, ce qui lui donne la même épaisseur partout dans la fiche.
    func testTheMarkerBandDoesNotGrowWithTheLineSpacing() {
        let font = MicaboFont.uiFont(SheetTypography.body, weight: .regular, italic: false)
        let tight = SheetMarkerLayoutManager.band(
            in: CGRect(x: 0, y: 0, width: 300, height: font.lineHeight),
            font: font
        )
        let airy = SheetMarkerLayoutManager.band(
            in: CGRect(x: 0, y: 0, width: 300, height: font.lineHeight + 12),
            font: font
        )

        XCTAssertEqual(tight.height, airy.height, accuracy: 0.01)
        XCTAssertEqual(tight.minY, airy.minY, accuracy: 0.01)
        XCTAssertLessThan(tight.height, font.lineHeight, "Une bande plus haute que sa ligne toucherait sa voisine")
    }

    /// La bande passe derrière les jambages du p et du g, sinon elle couperait le texte
    /// qu'elle met en avant, et elle laisse les capitales dépasser d'un cheveu.
    func testTheMarkerBandCoversTheDescendersAndTheCapitals() {
        let font = MicaboFont.uiFont(SheetTypography.body, weight: .regular, italic: false)
        let line = CGRect(x: 0, y: 0, width: 300, height: font.lineHeight)
        let band = SheetMarkerLayoutManager.band(in: line, font: font)
        let baseline = line.minY + font.ascender

        XCTAssertGreaterThan(band.maxY, baseline)
        XCTAssertLessThan(band.minY, baseline - font.capHeight)
    }

    /// La couleur ne s'accompagne pas d'un changement de poids : le gras est déjà une marque,
    /// et deux marques sur le même passage n'en font aucune.
    func testEmphasisLeavesTheWeightAlone() throws {
        let composed = SheetAttributedText.make("Un ==passage marqué== ici.", style: .prose)

        var fonts: Set<UIFont> = []
        composed.enumerateAttribute(.font, in: NSRange(location: 0, length: composed.length)) { value, _, _ in
            if let font = value as? UIFont { fonts.insert(font) }
        }

        XCTAssertEqual(fonts.count, 1, "Une seule fonte : seule l'encre change")
        XCTAssertEqual(try XCTUnwrap(fonts.first).pointSize, SheetTypography.body, accuracy: 0.01)
    }

    /// Le gras, l'italique et les formules continuent de vivre à l'intérieur d'un passage
    /// marqué : la couleur s'ajoute au style, elle ne le remplace pas.
    func testBoldSurvivesInsideAnEmphasisedPassage() {
        let spans = SheetMarkup.spans("==La **condensation** referme la boucle==.")

        XCTAssertTrue(spans.contains { $0.isHighlighted && $0.isBold })
    }

    /// Toute l'échelle a perdu un dixième, corps comme titres : ce qui compte sur une page,
    /// c'est le rapport entre les tailles. Réduire le corps seul aurait fait grossir les
    /// titres par contraste.
    func testTheWholeScaleLostATenth() {
        XCTAssertEqual(SheetTypography.body, 16.5 * 0.9, accuracy: 0.01)
        XCTAssertEqual(SheetTypography.headingLarge, 22 * 0.9, accuracy: 0.01)
        XCTAssertEqual(SheetTypography.formula, 20 * 0.9, accuracy: 0.01)
    }

    /// La hiérarchie tient après la réduction, et elle est monotone : du titre de partie à la
    /// légende, chaque cran est plus petit que le précédent. Un intitulé d'objet plus petit
    /// que le texte qu'il introduit n'introduirait rien.
    func testTheHierarchyStillHolds() {
        let scale = [
            SheetTypography.headingLarge,
            SheetTypography.body,
            SheetTypography.objectTitle,
            SheetTypography.secondary,
            SheetTypography.cell,
            SheetTypography.caption
        ]

        XCTAssertEqual(scale, scale.sorted(by: >), "L'échelle doit descendre sans remonter")
        XCTAssertEqual(SheetTypography.headingSmall, SheetTypography.body)
    }

    /// Les espaces ont baissé plus que les tailles : une fiche se relit la veille au soir, et
    /// le blanc qui aère un écran d'accueil fait ici scroller pour rien.
    func testTheVerticalRhythmIsTighterThanTheTypeScale() {
        XCTAssertLessThan(SheetTypography.lineSpacing, 7.5 * 0.9)
        XCTAssertLessThan(SheetTypography.blockSpacing, 15 * 0.9)
        XCTAssertLessThan(SheetTypography.spaceBeforeLargeHeading, 26 * 0.9)
        XCTAssertLessThanOrEqual(SheetTypography.spaceBeforeSmallHeading, 16)
    }

    /// Un sous-titre a la taille du corps : c'est l'air au-dessus de lui qui dit qu'une
    /// sous-partie commence. Un point de plus qu'un bloc ordinaire ne se verrait pas, et il
    /// n'y aurait plus de plan.
    func testASubHeadingGetsRealAirAboveIt() {
        XCTAssertGreaterThan(SheetTypography.spaceBeforeLargeHeading, SheetTypography.spaceBeforeSmallHeading)
        XCTAssertGreaterThanOrEqual(
            SheetTypography.spaceBeforeSmallHeading,
            SheetTypography.blockSpacing + 3,
            "À un point près, un sous-titre ne se distinguerait plus d'un paragraphe"
        )
    }
}

/// La fiche à plat : c'est ce texte qui part au modèle pour écrire des cartes ou expliquer
/// un passage, donc rien de ce qui se mémorise ne doit y disparaître.
final class CourseSheetFlatteningTests: XCTestCase {
    /// Ce qu'un tableau portait s'écrit maintenant en lignes, et la mise à plat garde les
    /// noms de colonnes qui donnaient leur sens aux valeurs.
    func testValuesAreKeptWithTheirColumnName() {
        let sheet = CourseSheet(blocks: [
            .list(ordered: false, items: [
                "**Lieu** : Thylakoïdes, **Produit** : ATP",
                "**CO₂ enrichi** : 45 %"
            ])
        ])

        let text = sheet.plainText()

        XCTAssertTrue(text.contains("Lieu : Thylakoïdes"))
        // Le chiffre se révise : il ne doit pas être perdu en route.
        XCTAssertTrue(text.contains("45 %"))
    }

    func testAnOrderedListIsNumberedOnceFlattened() {
        let sheet = CourseSheet(blocks: [
            .list(ordered: true, items: ["Fixation du CO₂", "Réduction en G3P"])
        ])

        XCTAssertEqual(sheet.plainText(), "1. Fixation du CO₂\n2. Réduction en G3P")
    }

    func testAnUnorderedListIsNotNumbered() {
        let sheet = CourseSheet(blocks: [.list(ordered: false, items: ["Océans", "Continents"])])

        XCTAssertEqual(sheet.plainText(), "Océans\nContinents")
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
        // Ce qui se relit est exactement ce qui a été enregistré : l'app ne repasse plus
        // derrière le modèle pour marquer des passages qu'il n'a pas marqués.
        XCTAssertEqual(course.decodedSheet(), SampleData.photosynthesisSheet.sanitized())
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

    /// Un paquet de cartes est un cours comme un autre pour le reste de l'app, à ceci près
    /// qu'il n'attend pas de fiche : lui en promettre une serait une impasse.
    func testADeckIsACourseWithoutASheet() throws {
        let deck = try CourseRepository.makeDeck(
            title: "Vocabulaire allemand",
            subject: "Allemand",
            in: context
        )

        XCTAssertEqual(deck.title, "Vocabulaire allemand")
        XCTAssertEqual(deck.subject, "Allemand")
        XCTAssertEqual(deck.source, .deck)
        XCTAssertFalse(deck.hasSheet)
        XCTAssertFalse(deck.source.expectsSheet)
        XCTAssertTrue(deck.cards.isEmpty)
        // Rien n'a été importé : deux paquets du même nom ne sont pas un doublon.
        XCTAssertTrue(deck.fingerprint.isEmpty)
    }

    func testADeckDoesNotKeepTextForTheModel() throws {
        let deck = try CourseRepository.makeDeck(
            title: "Dates de la Révolution",
            subject: "Histoire",
            in: context
        )

        XCTAssertEqual(deck.subject, "Histoire")
        XCTAssertTrue(deck.contextText.isEmpty)
        XCTAssertTrue(deck.rawText.isEmpty)
    }

    func testADeckWithoutANameStillOpens() throws {
        let deck = try CourseRepository.makeDeck(title: "   ", in: context)

        XCTAssertEqual(deck.title, "Nouveau paquet")
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
            if case .paragraph(let text) = block { return text.hasPrefix("**Coefficient directeur** : ") }
            return false
        }

        XCTAssertTrue(hasHeading)
        XCTAssertTrue(hasDefinition)
    }

    /// Rien n'est **surligné** sans avoir lu le cours : le gras du terme d'une définition
    /// est une structure reconnue, pas un jugement sur ce qui compte.
    func testNothingIsHighlightedWithoutHavingReadTheCourse() throws {
        let sheet = try XCTUnwrap(OfflineSheetBuilder.build(from: source, title: "Chapitre 3"))

        XCTAssertFalse(SheetMarkup.containsMarkup(sheet.plainText()))
        for block in sheet.blocks {
            for line in block.plainLines() {
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
