import UIKit

enum PhotoImportError: LocalizedError {
    case empty
    case unreadable

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Aucune page lisible. Réessaie avec des photos plus nettes."
        case .unreadable:
            return "Ces photos n'ont pas pu être lues."
        }
    }
}

/// Photos et scans : OCR Vision sur l'appareil, puis éventuellement une passe visuelle payante.
enum PhotoImportService {
    static func importImages(_ images: [UIImage]) async throws -> ImportedDocument {
        let pages = Array(images.prefix(OnDeviceOCR.pageLimit))
        guard !pages.isEmpty else { throw PhotoImportError.empty }

        let text = await OnDeviceOCR.recognize(images: pages)
        let pageImages = pages.prefix(6).compactMap { ImagePrep.jpeg($0) }
        let cover = ImagePrep.jpeg(pages[0], maxDimension: 900, quality: 0.7)

        guard text.count >= 20 || !pageImages.isEmpty else { throw PhotoImportError.empty }

        let fileName = pages.count == 1
            ? "Photo de cours"
            : "Scan (\(pages.count) pages)"

        return ImportedDocument(
            text: text,
            pageImages: Array(pageImages),
            coverImage: cover,
            pageCount: pages.count,
            fileName: fileName,
            source: .photo,
            extractionNote: text.count >= 200
                ? "Texte lu sur l'appareil (OCR), sans frais."
                : "Peu de texte lu : active l'analyse des schémas si tes pages en contiennent."
        )
    }
}
