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

    /// **Le texte d'une page, avec la place de chaque ligne** : « x y | texte », x et y en
    /// pourcentage de la largeur et de la hauteur, depuis le coin haut gauche, triés de haut en
    /// bas puis de gauche à droite.
    ///
    /// C'est ce que demande un emploi du temps : lu ligne à ligne, un tableau perd ses
    /// colonnes, et « Maths » ne dit plus s'il tombe le lundi ou le jeudi. Avec sa place, Mika
    /// retrouve la colonne du jour et la rangée de l'heure.
    static func recognizeLayout(in image: UIImage) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let prepared = rasterized(image, maxDimension: 2400)
                guard let cgImage = prepared.cgImage else {
                    continuation.resume(returning: "")
                    return
                }
                let request = VNRecognizeTextRequest { request, _ in
                    let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                    let placed = observations.compactMap { observation -> (x: Int, y: Int, text: String)? in
                        guard let text = observation.topCandidates(1).first?.string,
                              !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                        // Vision compte depuis le bas : on retourne l'axe vertical.
                        let box = observation.boundingBox
                        return (Int((box.minX * 100).rounded()), Int(((1 - box.maxY) * 100).rounded()), text)
                    }
                    let lines = placed
                        .sorted { $0.y != $1.y ? $0.y < $1.y : $0.x < $1.x }
                        .map { "\($0.x) \($0.y) | \($0.text)" }
                    continuation.resume(returning: lines.joined(separator: "\n"))
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["fr-FR", "en-US", "de-DE", "es-ES", "it-IT", "pt-BR"]
                if #available(iOS 16.0, *) {
                    request.automaticallyDetectsLanguage = true
                }
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    /// **Un énoncé d'exercice** (le scanner d'exercices) : une seule photo déjà recadrée, lue
    /// dans la langue de l'app d'abord, puis celles que Vision reconnaît de lui-même. Les
    /// autres appelants gardent `recognize(in:)`, en français et en anglais.
    static func recognizeExercise(in image: UIImage, preferred: [String]) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let prepared = rasterized(image, maxDimension: 2400)
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
                let supported = (try? request.supportedRecognitionLanguages()) ?? ["fr-FR", "en-US"]
                let wanted = (preferred + ["fr-FR", "en-US", "de-DE", "es-ES", "it-IT", "pt-BR"])
                    .filter { supported.contains($0) }
                var unique: [String] = []
                for language in wanted where !unique.contains(language) { unique.append(language) }
                request.recognitionLanguages = unique.isEmpty ? ["en-US"] : unique
                if #available(iOS 16.0, *) {
                    request.automaticallyDetectsLanguage = true
                }
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
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
