import Compression
import Foundation
import XCTest
@testable import Micabo

final class ImportExtractionTests: XCTestCase {
    func testWordXMLJoinsParagraphsAndBreaks() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p><w:r><w:t>Les fonctions affines</w:t></w:r></w:p>
            <w:p><w:r><w:t>Une fonction</w:t><w:tab/><w:t>s'écrit f(x)</w:t><w:br/><w:t>ax + b</w:t></w:r></w:p>
          </w:body>
        </w:document>
        """

        let text = WordXML.plainText(from: Data(xml.utf8))

        XCTAssertTrue(text.contains("Les fonctions affines"))
        XCTAssertTrue(text.contains("Une fonction"))
        XCTAssertTrue(text.contains("s'écrit f(x)"))
        XCTAssertTrue(text.contains("ax + b"))
        XCTAssertTrue(text.contains("\n"))
    }

    func testDocxStoreArchiveYieldsDocumentText() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p><w:r><w:t>Les fonctions affines du cours de première.</w:t></w:r></w:p>
          </w:body>
        </w:document>
        """
        let zip = TestZip.archive(files: ["word/document.xml": Data(xml.utf8)], method: .store)
        let document = try DocxImportService.extract(data: zip, fileName: "cours.docx")

        XCTAssertEqual(document.source, .docx)
        XCTAssertTrue(document.text.contains("fonctions affines"))
        XCTAssertTrue(document.hasUsableText == false || document.text.count >= 20)
        XCTAssertGreaterThanOrEqual(document.text.count, 20)
    }

    func testDocxDeflatedArchiveYieldsDocumentText() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p><w:r><w:t>Le coefficient directeur mesure la pente de la droite.</w:t></w:r></w:p>
          </w:body>
        </w:document>
        """
        let zip = TestZip.archive(files: ["word/document.xml": Data(xml.utf8)], method: .deflate)
        let document = try DocxImportService.extract(data: zip, fileName: "pente.docx")

        XCTAssertTrue(document.text.contains("coefficient directeur"))
    }

    func testMissingDocumentXmlIsRejected() {
        let zip = TestZip.archive(files: ["word/styles.xml": Data("<w/>".utf8)], method: .store)
        XCTAssertThrowsError(try DocxImportService.extract(data: zip, fileName: "vide.docx"))
    }

    func testPlainBytesAreNotDocx() {
        XCTAssertThrowsError(try DocxImportService.extract(data: Data("pas un zip".utf8), fileName: "notes.txt"))
    }

    func testImportedDocumentThreshold() {
        var document = ImportedDocument(
            text: String(repeating: "a", count: 199),
            pageImages: [],
            coverImage: nil,
            pageCount: 1,
            fileName: "scan",
            source: .photo
        )
        XCTAssertFalse(document.hasUsableText)

        document.text = String(repeating: "a", count: 200)
        XCTAssertTrue(document.hasUsableText)
    }
}

private enum TestZip {
    enum Method {
        case store
        case deflate
    }

    static func archive(files: [String: Data], method: Method) -> Data {
        var locals = Data()
        var centrals = Data()
        var records: [(name: String, offset: Int, compressed: Data, size: Int, compression: UInt16)] = []

        for (name, content) in files {
            let compressed: Data
            let compression: UInt16
            switch method {
            case .store:
                compressed = content
                compression = 0
            case .deflate:
                compressed = rawDeflate(content)
                compression = 8
            }
            records.append((name, locals.count, compressed, content.count, compression))

            let nameData = Data(name.utf8)
            locals.appendU32(0x0403_4b50)
            locals.appendU16(20)
            locals.appendU16(0)
            locals.appendU16(compression)
            locals.appendU16(0)
            locals.appendU16(0)
            locals.appendU32(0)
            locals.appendU32(UInt32(compressed.count))
            locals.appendU32(UInt32(content.count))
            locals.appendU16(UInt16(nameData.count))
            locals.appendU16(0)
            locals.append(nameData)
            locals.append(compressed)
        }

        let centralStart = locals.count
        for record in records {
            let nameData = Data(record.name.utf8)
            centrals.appendU32(0x0201_4b50)
            centrals.appendU16(20)
            centrals.appendU16(20)
            centrals.appendU16(0)
            centrals.appendU16(record.compression)
            centrals.appendU16(0)
            centrals.appendU16(0)
            centrals.appendU32(0)
            centrals.appendU32(UInt32(record.compressed.count))
            centrals.appendU32(UInt32(record.size))
            centrals.appendU16(UInt16(nameData.count))
            centrals.appendU16(0)
            centrals.appendU16(0)
            centrals.appendU16(0)
            centrals.appendU16(0)
            centrals.appendU32(0)
            centrals.appendU32(UInt32(record.offset))
            centrals.append(nameData)
        }

        var eocd = Data()
        eocd.appendU32(0x0605_4b50)
        eocd.appendU16(0)
        eocd.appendU16(0)
        eocd.appendU16(UInt16(records.count))
        eocd.appendU16(UInt16(records.count))
        eocd.appendU32(UInt32(centrals.count))
        eocd.appendU32(UInt32(centralStart))
        eocd.appendU16(0)

        return locals + centrals + eocd
    }

    private static func rawDeflate(_ input: Data) -> Data {
        let bound = max(input.count + 64, 128)
        var output = Data(count: bound)
        let written = output.withUnsafeMutableBytes { dest in
            input.withUnsafeBytes { source in
                compression_encode_buffer(
                    dest.bindMemory(to: UInt8.self).baseAddress!,
                    bound,
                    source.bindMemory(to: UInt8.self).baseAddress!,
                    input.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard written > 0 else { return input }
        output.removeSubrange(written..<output.count)
        if output.count > 6, output.first == 0x78 {
            return output.subdata(in: 2..<(output.count - 4))
        }
        return output
    }
}

private extension Data {
    mutating func appendU16(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8(value >> 8))
    }

    mutating func appendU32(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
