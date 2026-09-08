import XCTest
@testable import Micabo

final class AnkiImportTests: XCTestCase {
    func testFileNames() {
        XCTAssertTrue(AnkiPackageReader.isAnkiFileName("vocab.apkg"))
        XCTAssertTrue(AnkiPackageReader.isAnkiFileName("pack.COLPKG"))
        XCTAssertTrue(AnkiPackageReader.isTextExportName("notes.txt"))
        XCTAssertFalse(AnkiPackageReader.isAnkiFileName("cours.pdf"))
    }

    func testBasicNoteBecomesOneCard() {
        let cards = AnkiPackageReader.notesToCards(
            fields: ["la maison", "the house"],
            deck: "Anglais",
            tags: []
        )
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].kind, "basic")
        XCTAssertEqual(cards[0].front, "la maison")
        XCTAssertEqual(cards[0].back, "the house")
        XCTAssertEqual(cards[0].deck, "Anglais")
    }

    func testClozeMakesOneCardPerHole() {
        let cards = AnkiPackageReader.notesToCards(
            fields: ["Le {{c1::fémur}} s'articule avec le {{c2::tibia}}."],
            deck: "Anatomie",
            tags: []
        )
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[0].kind, "cloze")
        XCTAssertTrue(cards[0].front.contains("…"))
        XCTAssertEqual(cards[0].back, "fémur")
        XCTAssertEqual(cards[1].back, "tibia")
    }

    func testEmptyFrontIsSkipped() {
        XCTAssertTrue(
            AnkiPackageReader.notesToCards(fields: ["", "verso"], deck: "x", tags: []).isEmpty
        )
    }

    func testTextExportReadsTabSeparatedNotes() throws {
        let source = """
        #separator:tab
        maison\thouse
        chien\tdog
        """
        let parsed = try AnkiPackageReader.readTextExport(source, fileName: "anglais.txt")
        XCTAssertEqual(parsed.cards.count, 2)
        XCTAssertEqual(parsed.cards[0].front, "maison")
        XCTAssertEqual(parsed.cards[1].back, "dog")
    }

    func testCleanFieldStripsHtmlAndSound() {
        let cleaned = AnkiPackageReader.cleanField("un <b>mot</b> [sound:a.mp3] <br>suite")
        XCTAssertFalse(cleaned.contains("<"))
        XCTAssertFalse(cleaned.contains("sound"))
        XCTAssertTrue(cleaned.contains("mot"))
        XCTAssertTrue(cleaned.contains("suite"))
    }
}
