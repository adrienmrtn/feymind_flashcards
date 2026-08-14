import Foundation

/// Extraie le texte d'un `.docx` (ZIP + `word/document.xml`) sans dépendance.
enum DocxImportService {
    enum ImportError: LocalizedError {
        case notADocx
        case missingDocument
        case empty

        var errorDescription: String? {
            switch self {
            case .notADocx:
                return "Ce fichier n'est pas un document Word (.docx)."
            case .missingDocument:
                return "Le document Word est incomplet ou corrompu."
            case .empty:
                return "Aucun texte n'a été trouvé dans ce document."
            }
        }
    }

    static func extract(from url: URL) throws -> ImportedDocument {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        return try extract(data: data, fileName: url.lastPathComponent)
    }

    static func extract(data: Data, fileName: String) throws -> ImportedDocument {
        let xml: Data
        do {
            xml = try ZipArchive.data(named: "word/document.xml", in: data)
        } catch ZipArchive.ArchiveError.notFound {
            throw ImportError.missingDocument
        } catch {
            throw ZipArchive.looksLikeZip(data) ? ImportError.missingDocument : ImportError.notADocx
        }

        let text = TextSanitizer.normalizeExtractedText(WordXML.plainText(from: xml))

        guard text.count >= 20 else { throw ImportError.empty }

        return ImportedDocument(
            text: text,
            pageImages: [],
            coverImage: nil,
            pageCount: max(1, text.split(separator: "\n").count / 40),
            fileName: URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent,
            source: .docx,
            extractionNote: "Texte extrait du document Word, sans envoi au serveur."
        )
    }
}

enum WordXML {
    static func plainText(from xml: Data) -> String {
        let parser = XMLParser(data: xml)
        let delegate = Delegate()
        parser.delegate = delegate
        parser.parse()
        return delegate.output
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private var parts: [String] = []
        private var capture = false
        private var buffer = ""

        var output: String { parts.joined() }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            switch elementName {
            case "w:t":
                capture = true
                buffer = ""
            case "w:tab":
                parts.append("\t")
            case "w:br", "w:cr":
                parts.append("\n")
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if capture { buffer += string }
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?
        ) {
            switch elementName {
            case "w:t":
                parts.append(buffer)
                capture = false
                buffer = ""
            case "w:p":
                parts.append("\n")
            default:
                break
            }
        }
    }
}
