import Foundation

/// **Des diapositives deviennent du texte, sur le téléphone** (`docs/supports.md`).
///
/// Un `.pptx` est un ZIP : chaque diapositive vit dans `ppt/slides/slideN.xml`, ses notes de
/// présentateur dans `ppt/notesSlides/notesSlideN.xml`. On lit le texte des deux, diapo par diapo
/// et dans l'ordre des numéros (l'ordre des fichiers dans l'archive n'est pas celui du
/// diaporama). Les notes comptent : c'est souvent là que le professeur a écrit son cours.
///
/// Un Keynote (`.key`) ou un ancien `.ppt` ne se lit pas sans les applications d'Apple ou de
/// Microsoft : l'élève reçoit une phrase qui lui dit comment l'exporter.
enum SlidesImportService {
    enum ImportError: LocalizedError, Equatable {
        case keynote
        case legacy
        case unreadable
        case empty

        var errorDescription: String? {
            switch self {
            case .keynote: L10n.t("ios.sup.slides.keynote", locale: .resolved())
            case .legacy: L10n.t("ios.sup.slides.legacy", locale: .resolved())
            case .unreadable: L10n.t("ios.sup.slides.unreadable", locale: .resolved())
            case .empty: L10n.t("ios.sup.slides.empty", locale: .resolved())
            }
        }
    }

    /// Une diapositive : son numéro, son texte, ses notes.
    struct Slide: Equatable {
        var number: Int
        var text: String
        var notes: String
    }

    static func extract(from url: URL) throws -> ImportedDocument {
        let name = url.deletingPathExtension().lastPathComponent
        switch url.pathExtension.lowercased() {
        case "key": throw ImportError.keynote
        case "ppt", "pps": throw ImportError.legacy
        default: break
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }
        return try extract(data: data, fileName: name)
    }

    static func extract(data: Data, fileName: String) throws -> ImportedDocument {
        let slides = try Self.slides(in: data)
        let text = TextSanitizer.normalizeExtractedText(plainText(of: slides))
        guard text.count >= 20 else { throw ImportError.empty }
        return ImportedDocument(
            text: text,
            pageImages: [],
            coverImage: nil,
            pageCount: slides.count,
            fileName: fileName,
            source: .pdf,
            extractionNote: nil
        )
    }

    /// Les diapositives d'une archive, dans l'ordre du diaporama.
    static func slides(in archive: Data) throws -> [Slide] {
        guard ZipArchive.looksLikeZip(archive),
              let entries = try? ZipArchive.centralDirectory(of: archive) else {
            throw ImportError.unreadable
        }
        let slideFiles = entries.compactMap { entry -> (Int, String)? in
            guard let number = Self.slideNumber(in: entry.name, folder: "ppt/slides/", prefix: "slide") else { return nil }
            return (number, entry.name)
        }
        guard !slideFiles.isEmpty else { throw ImportError.unreadable }
        let notesFiles = Dictionary(
            entries.compactMap { entry -> (Int, String)? in
                guard let number = Self.slideNumber(in: entry.name, folder: "ppt/notesSlides/", prefix: "notesSlide") else { return nil }
                return (number, entry.name)
            },
            uniquingKeysWith: { first, _ in first }
        )

        var slides: [Slide] = []
        for (number, path) in slideFiles.sorted(by: { $0.0 < $1.0 }) {
            guard let xml = try? ZipArchive.data(named: path, in: archive) else { continue }
            var notes = ""
            if let notesPath = notesFiles[number], let notesXML = try? ZipArchive.data(named: notesPath, in: archive) {
                notes = SlideXML.plainText(from: notesXML)
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    // Le numéro de diapo que PowerPoint pose seul dans les notes.
                    .filter { !$0.isEmpty && Int($0) == nil }
                    .joined(separator: "\n")
            }
            slides.append(Slide(number: number, text: SlideXML.plainText(from: xml), notes: notes))
        }
        return slides
    }

    /// Le texte envoyé : chaque diapositive sous son numéro, ses notes à la suite.
    static func plainText(of slides: [Slide]) -> String {
        slides.compactMap { slide -> String? in
            let body = [slide.text, slide.notes]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !body.isEmpty else { return nil }
            return "— \(slide.number) —\n" + body.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    /// `ppt/slides/slide12.xml` → 12 ; rien pour `ppt/slides/_rels/slide12.xml.rels`.
    private static func slideNumber(in path: String, folder: String, prefix: String) -> Int? {
        guard path.hasPrefix(folder), path.hasSuffix(".xml") else { return nil }
        let file = path.dropFirst(folder.count).dropLast(4)
        guard file.hasPrefix(prefix), !file.contains("/") else { return nil }
        return Int(file.dropFirst(prefix.count))
    }
}

/// Le texte d'une diapositive : chaque `<a:t>` à la suite, un paragraphe `<a:p>` par ligne.
enum SlideXML {
    static func plainText(from xml: Data) -> String {
        let parser = XMLParser(data: xml)
        let delegate = Delegate()
        parser.delegate = delegate
        parser.parse()
        return delegate.lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private(set) var lines: [String] = []
        private var line = ""
        private var capture = false

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            switch elementName {
            case "a:t": capture = true
            case "a:br": line += " "
            case "a:tab": line += " "
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if capture { line += string }
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName: String?
        ) {
            switch elementName {
            case "a:t":
                capture = false
            case "a:p":
                lines.append(line)
                line = ""
            default:
                break
            }
        }

        func parserDidEndDocument(_ parser: XMLParser) {
            if !line.isEmpty {
                lines.append(line)
                line = ""
            }
        }
    }
}
