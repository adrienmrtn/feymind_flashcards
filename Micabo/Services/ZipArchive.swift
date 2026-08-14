import Compression
import Foundation

/// Lecteur ZIP minimal : on n'a besoin que d'extraire `word/document.xml` d'un DOCX.
/// Pas de dépendance tierce, pas d'appel réseau.
enum ZipArchive {
    enum ArchiveError: Error {
        case invalid
        case notFound
        case unsupportedCompression
    }

    static func looksLikeZip(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let signature = data.u32(0)
        return signature == 0x0403_4b50 || signature == 0x0605_4b50 || signature == 0x0807_4b50
    }

    static func data(named path: String, in archive: Data) throws -> Data {
        let entries = try centralDirectory(of: archive)
        guard let entry = entries.first(where: { $0.name == path || $0.name.hasSuffix("/" + path) }) else {
            throw ArchiveError.notFound
        }
        return try extract(entry, from: archive)
    }

    struct Entry {
        let name: String
        let compression: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    static func centralDirectory(of data: Data) throws -> [Entry] {
        guard let eocd = endOfCentralDirectory(in: data) else { throw ArchiveError.invalid }
        var cursor = eocd.offset
        var entries: [Entry] = []

        for _ in 0..<eocd.count {
            guard cursor + 46 <= data.count, data.u32(cursor) == 0x0201_4b50 else {
                throw ArchiveError.invalid
            }
            let compression = data.u16(cursor + 10)
            let compressed = Int(data.u32(cursor + 20))
            let uncompressed = Int(data.u32(cursor + 24))
            let nameLength = Int(data.u16(cursor + 28))
            let extraLength = Int(data.u16(cursor + 30))
            let commentLength = Int(data.u16(cursor + 32))
            let localOffset = Int(data.u32(cursor + 42))
            let nameStart = cursor + 46
            guard nameStart + nameLength <= data.count else { throw ArchiveError.invalid }
            let name = String(data: data.subdata(in: nameStart..<(nameStart + nameLength)), encoding: .utf8) ?? ""
            entries.append(
                Entry(
                    name: name,
                    compression: compression,
                    compressedSize: compressed,
                    uncompressedSize: uncompressed,
                    localHeaderOffset: localOffset
                )
            )
            cursor = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }

    private static func extract(_ entry: Entry, from data: Data) throws -> Data {
        let header = entry.localHeaderOffset
        guard header + 30 <= data.count, data.u32(header) == 0x0403_4b50 else {
            throw ArchiveError.invalid
        }
        let nameLength = Int(data.u16(header + 26))
        let extraLength = Int(data.u16(header + 28))
        let payloadStart = header + 30 + nameLength + extraLength
        let payloadEnd = payloadStart + entry.compressedSize
        guard payloadEnd <= data.count else { throw ArchiveError.invalid }
        let payload = data.subdata(in: payloadStart..<payloadEnd)

        switch entry.compression {
        case 0:
            return payload
        case 8:
            guard let inflated = inflate(payload, uncompressedSize: entry.uncompressedSize) else {
                throw ArchiveError.invalid
            }
            return inflated
        default:
            throw ArchiveError.unsupportedCompression
        }
    }

    private struct EOCD {
        let count: Int
        let offset: Int
    }

    /// L'EOCD est à la fin du fichier, éventuellement suivi d'un commentaire.
    private static func endOfCentralDirectory(in data: Data) -> EOCD? {
        let minimum = 22
        guard data.count >= minimum else { return nil }
        let maxComment = min(65_535, data.count - minimum)
        for comment in 0...maxComment {
            let start = data.count - minimum - comment
            if data.u32(start) == 0x0605_4b50 {
                return EOCD(
                    count: Int(data.u16(start + 10)),
                    offset: Int(data.u32(start + 16))
                )
            }
        }
        return nil
    }

    /// ZIP stocke du DEFLATE brut. `COMPRESSION_ZLIB` le décode ; certains runtimes
    /// attendent un en-tête zlib, d'où le second essai.
    private static func inflate(_ data: Data, uncompressedSize: Int) -> Data? {
        guard uncompressedSize > 0 else { return Data() }
        if let decoded = decodeZlib(data, uncompressedSize: uncompressedSize) {
            return decoded
        }
        var wrapped = Data([0x78, 0x9C])
        wrapped.append(data)
        return decodeZlib(wrapped, uncompressedSize: uncompressedSize)
    }

    private static func decodeZlib(_ data: Data, uncompressedSize: Int) -> Data? {
        var destination = Data(count: uncompressedSize)
        let written = destination.withUnsafeMutableBytes { dest in
            data.withUnsafeBytes { source in
                compression_decode_buffer(
                    dest.bindMemory(to: UInt8.self).baseAddress!,
                    uncompressedSize,
                    source.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard written > 0 else { return nil }
        if written < uncompressedSize {
            destination.removeSubrange(written..<uncompressedSize)
        }
        return destination
    }
}

private extension Data {
    func u16(_ offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func u32(_ offset: Int) -> UInt32 {
        UInt32(self[offset])
            | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16
            | UInt32(self[offset + 3]) << 24
    }
}
