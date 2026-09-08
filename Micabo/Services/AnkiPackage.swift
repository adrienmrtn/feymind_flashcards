import Foundation
import SQLite3

/// Reprendre un paquet Anki, comme sur le web.
///
/// Un `.apkg` est un ZIP qui porte la collection SQLite. On en tire les notes, leur paquet
/// d'origine, et rien d'autre : pas l'ordonnancement, pas les médias. Tout repart neuf.
enum AnkiImportError: Error {
    case notPackage
    case noCollection
    case unreadableCollection
    case noZstd
    case empty
}

struct AnkiImportedCard: Equatable {
    var kind: String
    var front: String
    var back: String
    var hint: String?
    var deck: String
}

struct AnkiDeckSummary: Equatable {
    var name: String
    var cards: Int
}

struct AnkiImportedPackage: Equatable {
    var title: String
    var decks: [AnkiDeckSummary]
    var cards: [AnkiImportedCard]
    var skipped: Int
}

enum AnkiPackageReader {
    static let cardLimit = 4_000
    private static let gap = "…"
    private static let maxSide = 2_000

    static func isAnkiFileName(_ name: String) -> Bool {
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return [".apkg", ".colpkg", ".anki2", ".anki21", ".anki21b"].contains { lower.hasSuffix($0) }
    }

    static func isTextExportName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return [".txt", ".csv", ".tsv"].contains { lower.hasSuffix($0) }
    }

    static func read(data: Data, fileName: String) throws -> AnkiImportedPackage {
        if looksLikeSqlite(data) {
            return try readCollection(data, fileName: fileName)
        }
        if ZipArchive.looksLikeZip(data) {
            let collection = try extractCollection(from: data)
            return try readCollection(collection, fileName: fileName)
        }
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            return try readTextExport(text, fileName: fileName)
        }
        throw AnkiImportError.notPackage
    }

    // MARK: - Collection

    private static func extractCollection(from archive: Data) throws -> Data {
        let raw: Data
        do {
            raw = try ZipArchive.firstData(
                suffixes: ["collection.anki21b", "collection.anki21", "collection.anki2"],
                in: archive
            )
        } catch ZipArchive.ArchiveError.notFound {
            throw AnkiImportError.noCollection
        } catch {
            throw AnkiImportError.notPackage
        }

        if looksLikeSqlite(raw) { return raw }
        return try decompressZstd(raw)
    }

    private static func looksLikeSqlite(_ data: Data) -> Bool {
        guard data.count >= 16 else { return false }
        return Array(data.prefix(15)) == Array("SQLite format 3".utf8) && data[15] == 0
    }

    /// Apple n'expose pas `COMPRESSION_ZSTD` dans Compression.framework.
    /// On décode avec l'amalgame officiel de zstd, comme `fzstd` côté web.
    private static let zstdUnknownSize = UInt64.max
    private static let zstdErrorSize = UInt64.max - 1
    private static let zstdMaxOutput = 256 * 1024 * 1024

    private static func decompressZstd(_ data: Data) throws -> Data {
        guard data.count >= 4,
              data[0] == 0x28, data[1] == 0xB5, data[2] == 0x2F, data[3] == 0xFD
        else {
            throw AnkiImportError.unreadableCollection
        }

        let contentSize = data.withUnsafeBytes { raw -> UInt64 in
            guard let base = raw.baseAddress else { return zstdErrorSize }
            return MicaboZstdFrameContentSize(base, data.count)
        }
        if contentSize == zstdErrorSize {
            throw AnkiImportError.unreadableCollection
        }

        if contentSize != zstdUnknownSize {
            guard contentSize > 0, contentSize <= UInt64(zstdMaxOutput) else {
                throw AnkiImportError.noZstd
            }
            return try inflateZstd(data, capacity: Int(contentSize))
        }

        var size = max(data.count * 8, 64 * 1024)
        for _ in 0..<8 {
            guard size <= zstdMaxOutput else { throw AnkiImportError.noZstd }
            do {
                return try inflateZstd(data, capacity: size)
            } catch AnkiImportError.noZstd {
                size *= 2
            }
        }
        throw AnkiImportError.noZstd
    }

    private static func inflateZstd(_ data: Data, capacity: Int) throws -> Data {
        var destination = Data(count: capacity)
        let written = destination.withUnsafeMutableBytes { dest in
            data.withUnsafeBytes { source in
                MicaboZstdDecompress(
                    dest.baseAddress,
                    capacity,
                    source.baseAddress,
                    data.count
                )
            }
        }
        guard MicaboZstdIsError(written) == 0, written > 0 else {
            throw AnkiImportError.noZstd
        }
        if written < capacity {
            destination.removeSubrange(written..<capacity)
        }
        if looksLikeSqlite(destination) { return destination }
        throw AnkiImportError.unreadableCollection
    }

    private static func readCollection(_ data: Data, fileName: String) throws -> AnkiImportedPackage {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).anki2")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw AnkiImportError.unreadableCollection
        }
        defer { sqlite3_close(db) }

        let notes = query(db, "select id, flds, tags from notes")
        guard !notes.isEmpty else { throw AnkiImportError.unreadableCollection }

        let deckOf = deckIndex(db)
        let suggested = suggestedTitle(from: fileName)
        var cards: [AnkiImportedCard] = []
        var counts: [String: Int] = [:]
        var skipped = 0

        for note in notes {
            let fields = (note["flds"] ?? "").split(separator: "\u{001f}", omittingEmptySubsequences: false)
                .map { cleanField(String($0)) }
            let tags = (note["tags"] ?? "").split(whereSeparator: { $0.isWhitespace }).map(String.init)
            let noteId = Int(note["id"] ?? "") ?? 0
            let deck = deckOf(noteId) ?? suggested
            let written = notesToCards(fields: fields, deck: deck, tags: tags)
            if written.isEmpty {
                skipped += 1
                continue
            }
            for card in written {
                cards.append(card)
                counts[card.deck, default: 0] += 1
                if cards.count >= cardLimit { break }
            }
            if cards.count >= cardLimit { break }
        }

        if cards.isEmpty { throw AnkiImportError.empty }
        return package(titleHint: suggested, cards: cards, counts: counts, skipped: skipped)
    }

    private static func deckIndex(_ db: OpaquePointer) -> (Int) -> String? {
        var names: [Int: String] = [:]
        let fromTable = query(db, "select id, name from decks")
        if !fromTable.isEmpty {
            for row in fromTable {
                let id = Int(row["id"] ?? "") ?? 0
                names[id] = deckName(row["name"] ?? "")
            }
        } else if let col = query(db, "select decks from col").first,
                  let data = (col["decks"] ?? "").data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
        {
            for (id, deck) in parsed {
                if let name = deck["name"] as? String {
                    names[Int(id) ?? 0] = deckName(name)
                }
            }
        }

        var perNote: [Int: String] = [:]
        for card in query(db, "select nid, did, odid from cards") {
            let noteId = Int(card["nid"] ?? "") ?? 0
            if perNote[noteId] != nil { continue }
            let original = Int(card["odid"] ?? "") ?? 0
            let did = original > 0 ? original : (Int(card["did"] ?? "") ?? 0)
            if let name = names[did] { perNote[noteId] = name }
        }

        return { perNote[$0] }
    }

    // MARK: - Text export

    static func readTextExport(_ source: String, fileName: String) throws -> AnkiImportedPackage {
        var body: [String] = []
        var separator: String?
        var deckColumn = -1
        var tagsColumn = -1

        for line in source.split(whereSeparator: \.isNewline).map(String.init) {
            if line.hasPrefix("#") {
                let trimmed = String(line.drop(while: { $0 == "#" || $0.isWhitespace }))
                guard let colon = trimmed.firstIndex(of: ":") else { continue }
                let key = trimmed[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                if key == "separator" { separator = separatorFor(value) }
                if key == "deck column" { deckColumn = (Int(value) ?? 0) - 1 }
                if key == "tags column" { tagsColumn = (Int(value) ?? 0) - 1 }
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            body.append(line)
        }

        let cut = separator ?? sniffSeparator(body)
        let suggested = suggestedTitle(from: fileName)
        var cards: [AnkiImportedCard] = []
        var counts: [String: Int] = [:]
        var skipped = 0

        for line in body {
            let row = line.components(separatedBy: cut)
            let deck = deckColumn >= 0 ? deckName(row[safe: deckColumn] ?? "") : suggested
            let tags = tagsColumn >= 0
                ? (row[safe: tagsColumn] ?? "").split(whereSeparator: { $0.isWhitespace }).map(String.init)
                : []
            let fields = row.enumerated().compactMap { index, value -> String? in
                if index == deckColumn || index == tagsColumn { return nil }
                return cleanField(value)
            }
            let written = notesToCards(fields: fields, deck: deck.isEmpty ? suggested : deck, tags: tags)
            if written.isEmpty {
                skipped += 1
                continue
            }
            for card in written {
                cards.append(card)
                counts[card.deck, default: 0] += 1
                if cards.count >= cardLimit { break }
            }
            if cards.count >= cardLimit { break }
        }

        if cards.isEmpty { throw AnkiImportError.empty }
        return package(titleHint: suggested, cards: cards, counts: counts, skipped: skipped)
    }

    // MARK: - Notes → cards

        static func notesToCards(fields: [String], deck: String, tags _: [String]) -> [AnkiImportedCard] {
        let filled = fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let clozeAt = filled.firstIndex(where: { !clozeOrdinals($0).isEmpty }) {
            let text = filled[clozeAt]
            let extra = filled.enumerated().first { $0.offset != clozeAt && !$0.element.isEmpty }?.element
            return clozeOrdinals(text).compactMap { ordinal -> AnkiImportedCard? in
                guard let card = clozeCard(text, ordinal: ordinal) else { return nil }
                let hint = card.hint ?? extra
                return AnkiImportedCard(
                    kind: "cloze",
                    front: cut(card.front),
                    back: cut(card.back),
                    hint: hint.map(cut),
                    deck: deck
                )
            }
        }

        let front = filled.first ?? ""
        let back = filled.dropFirst().filter { !$0.isEmpty }.joined(separator: "\n\n")
        guard !front.isEmpty, !back.isEmpty else { return [] }
        return [AnkiImportedCard(kind: "basic", front: cut(front), back: cut(back), hint: nil, deck: deck)]
    }

    static func clozeOrdinals(_ text: String) -> [Int] {
        let regex = try? NSRegularExpression(pattern: #"\{\{c(\d+)::([\s\S]*?)\}\}"#)
        let range = NSRange(text.startIndex..., in: text)
        var found = Set<Int>()
        regex?.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, let range = Range(match.range(at: 1), in: text) else { return }
            if let value = Int(text[range]) { found.insert(value) }
        }
        return found.sorted()
    }

    static func clozeCard(_ text: String, ordinal: Int) -> (front: String, back: String, hint: String?)? {
        let regex = try? NSRegularExpression(pattern: #"\{\{c(\d+)::([\s\S]*?)\}\}"#)
        let range = NSRange(text.startIndex..., in: text)
        var answers: [String] = []
        var hint: String?
        var front = text

        let matches = regex?.matches(in: text, range: range) ?? []
        for match in matches.reversed() {
            guard let full = Range(match.range, in: text),
                  let indexRange = Range(match.range(at: 1), in: text),
                  let bodyRange = Range(match.range(at: 2), in: text)
            else { continue }
            let index = Int(text[indexRange]) ?? 0
            let split = splitCloze(String(text[bodyRange]))
            if index != ordinal {
                front.replaceSubrange(full, with: split.answer)
                continue
            }
            answers.append(split.answer)
            if let written = split.hint, hint == nil { hint = written }
            front.replaceSubrange(full, with: gap)
        }

        guard !answers.isEmpty else { return nil }
        let unique = answers.filter { !$0.isEmpty }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let back = unique.joined(separator: " / ")
        guard !back.isEmpty else { return nil }
        return (front.trimmingCharacters(in: .whitespacesAndNewlines), back, hint)
    }

    static func cleanField(_ field: String) -> String {
        var value = field
        value = value.replacingOccurrences(of: #"\[sound:[^\]]*\]"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: #"<img\b[^>]*>"#, with: " ", options: [.regularExpression, .caseInsensitive])
        value = value.replacingOccurrences(of: #"\[\$\$\]([\s\S]*?)\[/\$\$\]"#, with: "$$1$", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\[\$\]([\s\S]*?)\[/\$\]"#, with: "$$1$", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\[latex\]([\s\S]*?)\[/latex\]"#, with: "$$1$", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\\\(([\s\S]*?)\\\)"#, with: "$$1$", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\\\[([\s\S]*?)\\\]"#, with: "$$1$", options: .regularExpression)
        value = value.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        value = value.replacingOccurrences(of: #"</(?:div|p|li|tr|h[1-6])>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        value = value.replacingOccurrences(of: #"<li\b[^>]*>"#, with: "\n· ", options: [.regularExpression, .caseInsensitive])
        value = value.replacingOccurrences(of: #"<(?:script|style)\b[^>]*>[\s\S]*?</(?:script|style)>"#, with: " ", options: [.regularExpression, .caseInsensitive])
        value = value.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
        value = value.replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)
        value = value.replacingOccurrences(of: "&amp;", with: "&")
        value = value.replacingOccurrences(of: "&lt;", with: "<")
        value = value.replacingOccurrences(of: "&gt;", with: ">")
        value = value.replacingOccurrences(of: "&quot;", with: "\"")
        value = value.replacingOccurrences(of: "&apos;", with: "'")
        value = value.replacingOccurrences(of: "&#39;", with: "'")
        value = value.replacingOccurrences(of: "\u{00a0}", with: " ")
        value = value.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: #" ?\n ?"#, with: "\n", options: .regularExpression)
        value = value.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private static func package(
        titleHint: String,
        cards: [AnkiImportedCard],
        counts: [String: Int],
        skipped: Int
    ) -> AnkiImportedPackage {
        let decks = counts
            .map { AnkiDeckSummary(name: $0.key, cards: $0.value) }
            .sorted {
                if $0.cards != $1.cards { return $0.cards > $1.cards }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        return AnkiImportedPackage(
            title: decks.count == 1 ? (decks[0].name.isEmpty ? titleHint : decks[0].name) : titleHint,
            decks: decks,
            cards: cards,
            skipped: skipped
        )
    }

    private static func suggestedTitle(from fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        return base.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func deckName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\u{001f}", with: "::").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitCloze(_ body: String) -> (answer: String, hint: String?) {
        if let separator = body.range(of: "::") {
            let answer = String(body[..<separator.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let hint = String(body[separator.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (answer, hint.isEmpty ? nil : hint)
        }
        return (body.trimmingCharacters(in: .whitespacesAndNewlines), nil)
    }

    private static func cut(_ value: String) -> String {
        guard value.count > maxSide else { return value }
        return String(value.prefix(maxSide - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func sniffSeparator(_ lines: [String]) -> String {
        let sample = Array(lines.prefix(40))
        var best = "\t"
        var bestScore = 0
        for candidate in ["\t", ";", ",", "|"] {
            let score = sample.filter { $0.components(separatedBy: candidate).count >= 2 }.count
            if score > bestScore {
                best = candidate
                bestScore = score
            }
        }
        return best
    }

    private static func separatorFor(_ value: String) -> String {
        switch value.lowercased() {
        case "tab": return "\t"
        case "comma": return ","
        case "semicolon": return ";"
        case "space": return " "
        case "pipe": return "|"
        case "colon": return ":"
        default: return value.isEmpty ? "\t" : value
        }
    }

    private static func query(_ db: OpaquePointer, _ sql: String) -> [[String: String]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var rows: [[String: String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: String] = [:]
            let count = sqlite3_column_count(stmt)
            for index in 0..<count {
                let name = String(cString: sqlite3_column_name(stmt, index))
                if sqlite3_column_type(stmt, index) == SQLITE_NULL {
                    row[name] = ""
                } else if let text = sqlite3_column_text(stmt, index) {
                    row[name] = String(cString: text)
                } else {
                    row[name] = "\(sqlite3_column_int64(stmt, index))"
                }
            }
            rows.append(row)
        }
        return rows
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
