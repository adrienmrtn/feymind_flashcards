import XCTest
@testable import Feymind

final class CourseContentTests: XCTestCase {
    func testUnknownBlockTypeIsSkippedWithoutLosingTheRest() throws {
        let json = """
        {
          "title": "Titre",
          "summary": "Résumé",
          "blocks": [
            {"type": "paragraph", "text": "Premier"},
            {"type": "bloc-inconnu", "valeur": 12},
            {"type": "heading", "level": 2, "text": "Second"}
          ]
        }
        """

        let course = try JSONDecoder().decode(GeneratedCourse.self, from: Data(json.utf8))

        XCTAssertEqual(course.blocks.count, 2)
        XCTAssertEqual(course.blocks[0].plainText, "Premier")
        XCTAssertEqual(course.blocks[1].kind, .heading)
    }

    func testBlocksSurviveAnEncodeDecodeRoundTrip() throws {
        let blocks: [CourseBlockPayload] = [
            .heading(HeadingBlock(level: 1, text: "Titre")),
            .callout(CalloutBlock(variant: .memo, title: "À retenir", text: "L'essentiel")),
            .chart(ChartBlock(title: "Rendement", caption: nil, bars: [ChartBar(label: "A", value: 40, unit: "%")])),
            .tree(TreeBlock(title: nil, root: TreeNode(label: "Racine", detail: nil, children: [
                TreeNode(label: "Enfant", detail: "Détail", children: nil)
            ]))),
            .divider
        ]

        let data = try JSONEncoder().encode(blocks)
        let decoded = try JSONDecoder().decode([CourseBlockPayload].self, from: data)

        XCTAssertEqual(decoded, blocks)
    }

    func testMissingTitleFallsBackInsteadOfFailing() throws {
        let json = #"{"summary": "S", "blocks": [{"type": "paragraph", "text": "a"}]}"#
        let course = try JSONDecoder().decode(GeneratedCourse.self, from: Data(json.utf8))

        XCTAssertEqual(course.title, "Cours sans titre")
        XCTAssertEqual(course.blocks.count, 1)
    }

    // MARK: - Balisage

    func testInlineMarkupSplitsStyledRuns() {
        let runs = InlineMarkup.runs(in: "Un **terme** et une ==définition==.")

        XCTAssertEqual(runs.count, 5)
        XCTAssertTrue(runs[1].style.bold)
        XCTAssertEqual(runs[1].text, "terme")
        XCTAssertTrue(runs[3].style.highlighted)
        XCTAssertEqual(runs[3].text, "définition")
    }

    func testPlainTextDropsTheMarkup() {
        XCTAssertEqual(
            InlineMarkup.plainText("Un **terme** et `du code`"),
            "Un terme et du code"
        )
    }

    // MARK: - Nettoyage

    func testEmDashesAreReplaced() {
        XCTAssertEqual(
            TextSanitizer.removeEmDashes("Le cours — voici — la suite"),
            "Le cours, voici, la suite"
        )
        XCTAssertEqual(TextSanitizer.removeEmDashes("mot—mot"), "mot-mot")
    }

    func testSanitizationReachesNestedBlocks() {
        let course = GeneratedCourse(
            title: "A — B",
            summary: "S",
            blocks: [.comparison(ComparisonBlock(title: "T — U", columns: [
                ComparisonColumn(title: "C — D", items: ["E — F"])
            ]))]
        )

        let clean = course.sanitized()

        XCTAssertEqual(clean.title, "A, B")
        guard case .comparison(let block) = clean.blocks[0] else {
            return XCTFail("Le type de bloc a changé pendant le nettoyage.")
        }
        XCTAssertEqual(block.title, "T, U")
        XCTAssertEqual(block.columns[0].items[0], "E, F")
    }
}
