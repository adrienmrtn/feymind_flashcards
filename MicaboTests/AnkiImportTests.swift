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

    func testModernApkgReadsZstdCollection() throws {
        let zst = Data(base64Encoded: "KLUv/WQAT50SAEZaX0AwbdQGwAAF4zYikAdxWhirAhYa3AXSr7/VG7TaTCK7R0ZCKXI61vE1n3r9TbU8d+K+KbCkemNqJaRj4U8rfZkCTgBHAEsAf32u0qN0ABbunA4EjAznZGBwPJsJjvfBn5+XLzo0DAZDkcgN7alwQOEAEar2VEi6m/KwkaBdN0lPutt1t/uDbq0F9ALPj15r+WfZqWAh13PqmiizS4I/27rhMCkgZbKGz/7yi9eblrXZ+umPsTcx9vfaDJ81N6TH7LMMj4WyV5xZem10zZxZ9WxrdU3oQR66j8qL+Q0ii8XiXFMaFVJ1SNW6m8rMj9aqFl7ommlhZFo47QVSu1wwlMaAIxOrBH3s/Hi1lFoIH2N4KjN9+qprJgyCH0WkyAQOmmE4LRynhQMjKKZJw0SJD41yEdcmfbEgUeCj6o9HZcdAZm+HBwXPov98WWJvc4EgyuyinHMNKOcoCHRlKoE4ISJEplR16aUG9u5lOzwkVCrOHWjKNACkapCRaCQaBVGoQZliWE0gEyhJaTKMAZACEZsiMxwSKKMoAzEQAQcRQBzGkwgJJpwJKJjJTb49AAgcH4e/R9AbvpGF/n7YcADaRqhUZOvy4pEdcoUCeJuTe4DekadsqXFOPzQy1F9CDHZz1mSyDDTXb2P0A0nvfVMN539472hKnH8BkZ4JtAfc2H88dM1aCSYaP5gcUWkJNt13MuOR9jsthYKIIJrsTs4CcQ5L1GokAa4sU+3gejmK10FetjmwWLdfc0f75J6b+1h0cGirCBaftmypZIifjEvvqgEDWpta")!
        XCTAssertEqual(zst.prefix(4), Data([0x28, 0xB5, 0x2F, 0xFD]))

        let parsed = try AnkiPackageReader.read(
            data: storeZip(["collection.anki21b": zst]),
            fileName: "export.apkg"
        )
        XCTAssertEqual(parsed.cards.count, 1)
        XCTAssertEqual(parsed.cards[0].front, "Capitale du Pérou")
        XCTAssertEqual(parsed.cards[0].back, "Lima")
        XCTAssertEqual(parsed.title, "Géographie")
    }

    private func storeZip(_ files: [String: Data]) -> Data {
        var locals = Data()
        var centrals = Data()
        var records: [(name: String, offset: Int, payload: Data)] = []

        for (name, payload) in files {
            records.append((name, locals.count, payload))
            let nameData = Data(name.utf8)
            locals.append(contentsOf: u32(0x0403_4b50))
            locals.append(contentsOf: u16(20))
            locals.append(contentsOf: u16(0))
            locals.append(contentsOf: u16(0))
            locals.append(contentsOf: u16(0))
            locals.append(contentsOf: u16(0))
            locals.append(contentsOf: u32(0))
            locals.append(contentsOf: u32(UInt32(payload.count)))
            locals.append(contentsOf: u32(UInt32(payload.count)))
            locals.append(contentsOf: u16(UInt16(nameData.count)))
            locals.append(contentsOf: u16(0))
            locals.append(nameData)
            locals.append(payload)
        }

        let centralStart = locals.count
        for record in records {
            let nameData = Data(record.name.utf8)
            centrals.append(contentsOf: u32(0x0201_4b50))
            centrals.append(contentsOf: u16(20))
            centrals.append(contentsOf: u16(20))
            centrals.append(contentsOf: u16(0))
            centrals.append(contentsOf: u16(0))
            centrals.append(contentsOf: u16(0))
            centrals.append(contentsOf: u16(0))
            centrals.append(contentsOf: u32(0))
            centrals.append(contentsOf: u32(UInt32(record.payload.count)))
            centrals.append(contentsOf: u32(UInt32(record.payload.count)))
            centrals.append(contentsOf: u16(UInt16(nameData.count)))
            centrals.append(contentsOf: u16(0))
            centrals.append(contentsOf: u16(0))
            centrals.append(contentsOf: u16(0))
            centrals.append(contentsOf: u16(0))
            centrals.append(contentsOf: u32(0))
            centrals.append(contentsOf: u32(UInt32(record.offset)))
            centrals.append(nameData)
        }

        var eocd = Data()
        eocd.append(contentsOf: u32(0x0605_4b50))
        eocd.append(contentsOf: u16(0))
        eocd.append(contentsOf: u16(0))
        eocd.append(contentsOf: u16(UInt16(records.count)))
        eocd.append(contentsOf: u16(UInt16(records.count)))
        eocd.append(contentsOf: u32(UInt32(centrals.count)))
        eocd.append(contentsOf: u32(UInt32(centralStart)))
        eocd.append(contentsOf: u16(0))
        return locals + centrals + eocd
    }

    private func u16(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8(value >> 8)]
    }

    private func u32(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF),
        ]
    }
}
