import UIKit

enum PhotoImportError: LocalizedError {
    case empty
    case unreadable

    var errorDescription: String? {
        switch self {
        case .empty:
            return L10n.t("ios.photo.empty", locale: .resolved())
        case .unreadable:
            return L10n.t("ios.photo.unreadable", locale: .resolved())
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
            ? L10n.t("ios.photo.courseName", locale: .resolved())
            : L10n.t("ios.photo.scanName", locale: .resolved(), vars: ["count": "\(pages.count)"])

        return ImportedDocument(
            text: text,
            pageImages: Array(pageImages),
            coverImage: cover,
            pageCount: pages.count,
            fileName: fileName,
            source: .photo,
            extractionNote: text.count >= 200
                ? L10n.t("ios.photo.ocrNote", locale: .resolved())
                : L10n.t("ios.photo.littleText", locale: .resolved())
        )
    }
}
