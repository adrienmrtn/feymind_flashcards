import Foundation
import PDFKit
import UIKit

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
        /// Nombre maximal de pages envoyées au modèle de vision, si l'utilisateur le demande.
        var maxImagePages: Int = 6
        var maxImageDimension: CGFloat = 1400
        var jpegQuality: CGFloat = 0.55
        var includeImages: Bool = true
        var coverDimension: CGFloat = 900
        var coverQuality: CGFloat = 0.7
        /// Pages lues par Vision quand le PDF n'a presque pas de calque texte.
        var ocrPageLimit: Int = OnDeviceOCR.pageLimit
        var ocrDimension: CGFloat = 1800

        static let `default` = Options()
    }

    /// Texte embarqué + couverture. Les pages JPEG ne sont rendues que si `includeImages`.
    static func extract(from url: URL, options: Options = .default) throws -> ImportedDocument {
        let opened = try open(url)
        defer { opened.stopAccessing() }

        var text = ""
        for index in 0..<opened.document.pageCount {
            guard let page = opened.document.page(at: index), let pageText = page.string else { continue }
            text += pageText + "\n\n"
        }
        text = TextSanitizer.normalizeExtractedText(text)

        var images: [Data] = []
        if options.includeImages {
            images = renderPages(of: opened.document, options: options)
        }

        guard !text.isEmpty || !images.isEmpty || opened.document.pageCount > 0 else {
            throw PDFImportError.empty
        }

        let cover = opened.document.page(at: 0).flatMap {
            render($0, maxDimension: options.coverDimension, quality: options.coverQuality)
        }

        return ImportedDocument(
            text: text,
            pageImages: images,
            coverImage: cover,
            pageCount: opened.document.pageCount,
            fileName: opened.fileName,
            source: .pdf,
            extractionNote: text.count >= 200
                ? "Texte extrait du PDF, sans OCR ni appel réseau."
                : "Peu de texte dans le fichier : un scan, probablement."
        )
    }

    /// Si PDFKit n'a presque rien lu, Vision OCR les pages sur l'appareil (gratuit, hors ligne).
    static func extractWithOCR(from url: URL, options: Options = .default) async throws -> ImportedDocument {
        var document = try extract(from: url, options: options)
        guard !document.hasUsableText else { return document }

        let opened = try open(url)
        defer { opened.stopAccessing() }

        let limit = min(opened.document.pageCount, options.ocrPageLimit)
        var pageImages: [UIImage] = []
        pageImages.reserveCapacity(limit)
        for index in 0..<limit {
            if let image = renderUIImage(opened.document.page(at: index), maxDimension: options.ocrDimension) {
                pageImages.append(image)
            }
        }

        let ocrText = await OnDeviceOCR.recognize(images: pageImages)
        if ocrText.count > document.text.count {
            document.text = ocrText
            document.extractionNote = ocrText.count >= 200
                ? "PDF scanné : texte lu sur l'appareil (OCR), sans frais."
                : "OCR incomplet : tu peux activer l'analyse des schémas."
        }

        guard document.hasUsableText || !document.pageImages.isEmpty else {
            throw PDFImportError.empty
        }
        return document
    }

    // MARK: - Ouverture

    private struct OpenedPDF {
        let document: PDFDocument
        let fileName: String
        let stopAccessing: () -> Void
    }

    private static func open(_ url: URL) throws -> OpenedPDF {
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        guard let document = PDFDocument(url: url) else {
            if needsScopedAccess { url.stopAccessingSecurityScopedResource() }
            throw PDFImportError.unreadable
        }
        guard !document.isLocked else {
            if needsScopedAccess { url.stopAccessingSecurityScopedResource() }
            throw PDFImportError.protected
        }
        guard document.pageCount > 0 else {
            if needsScopedAccess { url.stopAccessingSecurityScopedResource() }
            throw PDFImportError.empty
        }
        return OpenedPDF(
            document: document,
            fileName: url.deletingPathExtension().lastPathComponent,
            stopAccessing: {
                if needsScopedAccess { url.stopAccessingSecurityScopedResource() }
            }
        )
    }

    // MARK: - Rendu

    private static func renderPages(of document: PDFDocument, options: Options) -> [Data] {
        let indices = sampledPageIndices(pageCount: document.pageCount, limit: options.maxImagePages)
        return indices.compactMap { index in
            document.page(at: index).flatMap {
                render($0, maxDimension: options.maxImageDimension, quality: options.jpegQuality)
            }
        }
    }

    private static func render(_ page: PDFPage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        renderUIImage(page, maxDimension: maxDimension)?.jpegData(compressionQuality: quality)
    }

    private static func renderUIImage(_ page: PDFPage?, maxDimension: CGFloat) -> UIImage? {
        guard let page else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = min(maxDimension / max(bounds.width, bounds.height), 2.0)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    private static func sampledPageIndices(pageCount: Int, limit: Int) -> [Int] {
        guard pageCount > limit else { return Array(0..<pageCount) }
        let stride = Double(pageCount - 1) / Double(limit - 1)
        return (0..<limit).map { Int((Double($0) * stride).rounded()) }
    }
}
