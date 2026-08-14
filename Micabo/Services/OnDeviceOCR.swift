import UIKit
import Vision

/// Lecture de texte sur l'appareil, sans appel réseau.
/// C'est le chemin bon marché pour les PDF scannés et les photos de cours :
/// Vision est gratuit, fonctionne hors ligne, et se débrouille très bien en français.
enum OnDeviceOCR {
    /// Au-delà, on s'arrête : un cours de 40 pages suffit largement à produire des cartes.
    static let pageLimit = 40

    static func recognize(in image: UIImage) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let prepared = rasterized(image, maxDimension: 2000)
                guard let cgImage = prepared.cgImage else {
                    continuation.resume(returning: "")
                    return
                }

                let request = VNRecognizeTextRequest { request, _ in
                    let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines.joined(separator: "\n"))
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["fr-FR", "en-US"]

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    /// Réduit les photos 12 Mpx et fige l'orientation EXIF avant Vision.
    private static func rasterized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let size = CGSize(width: max(image.size.width * scale, 1), height: max(image.size.height * scale, 1))
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func recognize(images: [UIImage]) async -> String {
        var pages: [String] = []
        for image in images.prefix(pageLimit) {
            let page = await recognize(in: image)
            if !page.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pages.append(page)
            }
        }
        return TextSanitizer.normalizeExtractedText(pages.joined(separator: "\n\n"))
    }
}

enum ImagePrep {
    static func jpeg(
        _ image: UIImage,
        maxDimension: CGFloat = 1400,
        quality: CGFloat = 0.55
    ) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
