import Foundation
import PDFKit
import UIKit

struct PDFExtraction {
    var text: String
    /// Pages rendues en JPEG pour l'analyse visuelle des schémas.
    var pageImages: [Data]
    /// Première page, conservée comme couverture du cours.
    var coverImage: Data?
    var pageCount: Int
    var fileName: String

    var hasUsableText: Bool {
        text.count >= 200
    }
}

enum PDFImportError: LocalizedError {
    case unreadable
    case protected
    case empty

    var errorDescription: String? {
        switch self {
        case .unreadable: "Ce PDF n'a pas pu être ouvert."
        case .protected: "Ce PDF est protégé par un mot de passe."
        case .empty: "Ce PDF ne contient ni texte ni page exploitable."
        }
    }
}

enum PDFImportService {
    struct Options {
        /// Nombre maximal de pages envoyées au modèle de vision.
        var maxImagePages: Int = 6
        var maxImageDimension: CGFloat = 1400
        var jpegQuality: CGFloat = 0.55
        var includeImages: Bool = true
        /// La couverture est affichée dans l'application : plus petite, mieux compressée.
        var coverDimension: CGFloat = 900
        var coverQuality: CGFloat = 0.7

        static let `default` = Options()
    }

    static func extract(from url: URL, options: Options = .default) throws -> PDFExtraction {
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer { if needsScopedAccess { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else { throw PDFImportError.unreadable }
        guard !document.isLocked else { throw PDFImportError.protected }
        guard document.pageCount > 0 else { throw PDFImportError.empty }

        var text = ""
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let pageText = page.string else { continue }
            text += pageText + "\n\n"
        }
        text = TextSanitizer.normalizeExtractedText(text)

        var images: [Data] = []
        if options.includeImages {
            images = renderPages(of: document, options: options)
        }

        guard !text.isEmpty || !images.isEmpty else { throw PDFImportError.empty }

        let cover = document.page(at: 0).flatMap {
            render($0, maxDimension: options.coverDimension, quality: options.coverQuality)
        }

        return PDFExtraction(
            text: text,
            pageImages: images,
            coverImage: cover,
            pageCount: document.pageCount,
            fileName: url.deletingPathExtension().lastPathComponent
        )
    }

    /// Rend un échantillon de pages réparti sur tout le document.
    private static func renderPages(of document: PDFDocument, options: Options) -> [Data] {
        let indices = sampledPageIndices(pageCount: document.pageCount, limit: options.maxImagePages)
        return indices.compactMap { index in
            document.page(at: index).flatMap {
                render($0, maxDimension: options.maxImageDimension, quality: options.jpegQuality)
            }
        }
    }

    private static func render(_ page: PDFPage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = min(maxDimension / max(bounds.width, bounds.height), 2.0)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        return image.jpegData(compressionQuality: quality)
    }

    private static func sampledPageIndices(pageCount: Int, limit: Int) -> [Int] {
        guard pageCount > limit else { return Array(0..<pageCount) }
        // Toujours garder la première page, puis répartir les suivantes.
        let stride = Double(pageCount - 1) / Double(limit - 1)
        return (0..<limit).map { Int((Double($0) * stride).rounded()) }
    }
}
