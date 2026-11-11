import Foundation

/// **Une page web devient du texte, sur le téléphone** (`docs/supports.md`).
///
/// Aucune fonction serveur ne lit une page : l'app la télécharge elle-même, en retire le
/// décor (menus, scripts, pieds de page, publicités), garde l'article quand la page en
/// déclare un, et envoie le texte par le chemin d'un texte collé. Un lien vers un PDF est lu
/// comme un PDF ; un lien YouTube passe par le support YouTube (`LessonImportPickers`).
enum WebPageImportService {
    enum ImportError: LocalizedError, Equatable {
        case invalidLink
        case unreachable
        case unsupported
        case empty

        var errorDescription: String? {
            switch self {
            case .invalidLink: L10n.t("ios.sup.web.invalid", locale: .resolved())
            case .unreachable: L10n.t("ios.sup.web.unreachable", locale: .resolved())
            case .unsupported: L10n.t("ios.sup.web.unsupported", locale: .resolved())
            case .empty: L10n.t("ios.sup.web.empty", locale: .resolved())
            }
        }
    }

    /// Au-delà, ce n'est plus une page de cours : on s'arrête.
    static let maximumBytes = 4_000_000

    /// Le lien tapé ou collé, en adresse `https` ; `nil` s'il n'en est pas une.
    static func url(from raw: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Un lien collé au milieu d'une phrase : le premier mot qui ressemble à une adresse.
        if trimmed.contains(" ") || trimmed.contains("\n") {
            trimmed = trimmed
                .components(separatedBy: .whitespacesAndNewlines)
                .first { $0.lowercased().hasPrefix("http") || $0.lowercased().hasPrefix("www.") } ?? trimmed
        }
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let lowered = trimmed.lowercased()
        let candidate = lowered.hasPrefix("http://") || lowered.hasPrefix("https://") ? trimmed : "https://" + trimmed
        // Un lien collé depuis Safari peut porter des accents (« Photosynthèse ») : encodés.
        var allowed = CharacterSet.urlQueryAllowed
        allowed.insert(charactersIn: "#%")
        guard let components = URLComponents(string: candidate)
                ?? candidate.addingPercentEncoding(withAllowedCharacters: allowed).flatMap({ URLComponents(string: $0) }),
              let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = components.host, host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".")
        else { return nil }
        return components.url
    }

    static func read(_ raw: String) async throws -> ImportedDocument {
        guard let url = Self.url(from: raw) else { throw ImportError.invalidLink }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("text/html,application/xhtml+xml,text/plain,application/pdf;q=0.9,*/*;q=0.5", forHTTPHeaderField: "Accept")
        request.setValue(Locale.preferredLanguages.prefix(3).joined(separator: ","), forHTTPHeaderField: "Accept-Language")

        let fetched: (Data, URLResponse)
        do {
            fetched = try await URLSession.shared.data(for: request)
        } catch {
            throw ImportError.unreachable
        }
        let (data, response) = fetched
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ImportError.unreachable
        }
        guard data.count <= maximumBytes else { throw ImportError.unsupported }

        let host = (response.url ?? url).host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
        let mime = response.mimeType?.lowercased() ?? ""
        if mime == "application/pdf" || data.starts(with: Array("%PDF".utf8)) {
            return try await readPDF(data, name: host)
        }
        guard mime.isEmpty || mime.hasPrefix("text/") || mime.contains("html") || mime.contains("xml") else {
            throw ImportError.unsupported
        }
        let html = decode(data, encodingName: response.textEncodingName)
        let page = mime == "text/plain" ? WebPageText.Page(title: nil, text: TextSanitizer.normalizeExtractedText(html)) : WebPageText.extract(html: html)
        guard page.text.count >= 200 else { throw ImportError.empty }
        return ImportedDocument(
            text: page.text,
            pageImages: [],
            coverImage: nil,
            pageCount: 1,
            fileName: page.title?.nilIfBlank ?? host,
            source: .text,
            extractionNote: nil
        )
    }

    private static func readPDF(_ data: Data, name: String) async throws -> ImportedDocument {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("micabo-web-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        var document = try await PDFImportService.extractWithOCR(from: file)
        document.fileName = name
        return document
    }

    /// Le texte de la page, dans l'encodage qu'elle annonce, sinon UTF-8, sinon Latin-1.
    static func decode(_ data: Data, encodingName: String?) -> String {
        if let encodingName {
            let cf = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
            if cf != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
                if let text = String(data: data, encoding: encoding) { return text }
            }
        }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
    }
}

/// **Le texte d'une page HTML, sans son décor.** Des expressions régulières, pas un moteur de
/// rendu : `NSAttributedString(html:)` ne tourne que sur le fil principal, charge les
/// ressources de la page et bloque l'écran sur une grosse page.
enum WebPageText {
    struct Page: Equatable {
        var title: String?
        var text: String
    }

    /// Les blocs qui ne sont jamais le contenu : retirés avec ce qu'ils contiennent.
    private static let noise = ["script", "style", "noscript", "svg", "nav", "header", "footer", "aside", "form", "iframe", "template", "button", "select", "figure"]
    /// Les balises qui finissent une ligne.
    private static let blocks = ["p", "div", "section", "article", "main", "br", "tr", "table", "blockquote", "pre", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "dl", "dt", "dd", "hr", "figcaption", "caption"]

    static func extract(html: String) -> Page {
        let title = metaTitle(in: html) ?? firstMatch(#"<title[^>]*>([\s\S]*?)</title>"#, in: html).map { clean(inline: $0) }

        var body = html
        body = replace(#"<!--[\s\S]*?-->"#, in: body, with: " ")
        for tag in noise {
            body = replace("<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)\\s*>", in: body, with: "\n")
        }
        // L'article quand la page en a un et qu'il dit quelque chose ; sinon le contenu
        // principal ; sinon le corps entier.
        if let article = largestMatch(#"<article\b[^>]*>([\s\S]*?)</article\s*>"#, in: body), visibleLength(article) >= 400 {
            body = article
        } else if let main = largestMatch(#"<main\b[^>]*>([\s\S]*?)</main\s*>"#, in: body), visibleLength(main) >= 400 {
            body = main
        } else if let content = firstMatch(#"<body\b[^>]*>([\s\S]*)</body\s*>"#, in: body) {
            body = content
        }

        body = replace(#"<li\b[^>]*>"#, in: body, with: "\n• ")
        body = replace(#"<(?:td|th)\b[^>]*>"#, in: body, with: " ")
        let blockPattern = "</?(?:" + blocks.joined(separator: "|") + ")\\b[^>]*>"
        body = replace(blockPattern, in: body, with: "\n")
        body = replace(#"<[^>]+>"#, in: body, with: "")
        body = decodeEntities(body)

        var lines: [String] = []
        for raw in body.components(separatedBy: .newlines) {
            let line = raw.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\u{00A0}" }).joined(separator: " ")
            if line.isEmpty || line == "•" {
                if lines.last?.isEmpty == false { lines.append("") }
                continue
            }
            lines.append(line)
        }
        let text = TextSanitizer.normalizeExtractedText(lines.joined(separator: "\n"))
        return Page(title: title?.nilIfBlank, text: text)
    }

    /// `og:title`, plus propre que `<title>` qui traîne souvent le nom du site.
    private static func metaTitle(in html: String) -> String? {
        let patterns = [
            #"<meta[^>]+property=["']og:title["'][^>]*content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]*property=["']og:title["']"#,
        ]
        for pattern in patterns {
            if let value = firstMatch(pattern, in: html) { return clean(inline: value) }
        }
        return nil
    }

    private static func clean(inline text: String) -> String {
        decodeEntities(replace(#"<[^>]+>"#, in: text, with: ""))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func visibleLength(_ html: String) -> Int {
        replace(#"<[^>]+>"#, in: html, with: "").filter { !$0.isWhitespace }.count
    }

    // MARK: Les entités

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "laquo": "«", "raquo": "»", "hellip": "…", "mdash": "—", "ndash": "–",
        "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“", "bull": "•", "middot": "·",
        "eacute": "é", "egrave": "è", "ecirc": "ê", "agrave": "à", "acirc": "â", "ccedil": "ç",
        "ocirc": "ô", "ucirc": "û", "ugrave": "ù", "icirc": "î", "iuml": "ï", "euml": "ë",
        "auml": "ä", "ouml": "ö", "uuml": "ü", "szlig": "ß", "ntilde": "ñ", "aacute": "á",
        "iacute": "í", "oacute": "ó", "uacute": "ú", "Eacute": "É", "Agrave": "À", "deg": "°",
        "times": "×", "divide": "÷", "euro": "€", "copy": "©", "reg": "®", "shy": "",
    ]

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        guard let regex = try? NSRegularExpression(pattern: #"&(#x[0-9a-fA-F]+|#[0-9]+|[A-Za-z]+);"#) else { return text }
        let source = text as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let token = source.substring(with: match.range(at: 1))
            var replacement: String?
            if token.hasPrefix("#x") || token.hasPrefix("#X") {
                replacement = UInt32(token.dropFirst(2), radix: 16).flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
            } else if token.hasPrefix("#") {
                replacement = UInt32(token.dropFirst()).flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
            } else {
                replacement = named[token]
            }
            result += replacement ?? source.substring(with: match.range)
            cursor = match.range.location + match.range.length
        }
        result += source.substring(from: cursor)
        return result
    }

    // MARK: Les expressions

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = regex(pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: NSRegularExpression.escapedTemplate(for: template)
        )
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = regex(pattern),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)),
              match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound
        else { return nil }
        return (text as NSString).substring(with: match.range(at: 1))
    }

    private static func largestMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = regex(pattern) else { return nil }
        let source = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: source.length))
            .filter { $0.numberOfRanges > 1 && $0.range(at: 1).location != NSNotFound }
            .map { source.substring(with: $0.range(at: 1)) }
            .max { visibleLength($0) < visibleLength($1) }
    }
}
