import UIKit

/// **Le cadre de recadrage, de l'écran à la photo.**
///
/// Le cadre se règle sur ce que l'élève voit : la photo posée dans l'écran, remplie (la
/// visée, comme l'aperçu de l'appareil) ou entière (une photo de la photothèque). Ce fichier
/// fait le chemin inverse, des points de l'écran aux pixels de la photo, et ne lit rien
/// d'autre que des tailles : il se teste sans image.
enum SolverCrop {
    enum Fit {
        /// La photo remplit l'écran et déborde (la visée).
        case fill
        /// La photo tient entière dans l'écran (la photothèque).
        case fit
    }

    /// Où se pose une image de taille `image` dans un écran de taille `container`.
    static func displayedRect(image: CGSize, in container: CGSize, fit: Fit) -> CGRect {
        guard image.width > 0, image.height > 0, container.width > 0, container.height > 0 else { return .zero }
        let ratios = (container.width / image.width, container.height / image.height)
        let scale = fit == .fill ? max(ratios.0, ratios.1) : min(ratios.0, ratios.1)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Le cadre `frame` (en points de l'écran) dans les pixels de l'image, borné à l'image.
    /// `nil` quand le cadre ne recouvre pas l'image.
    static func imageRect(for frame: CGRect, image: CGSize, in container: CGSize, fit: Fit) -> CGRect? {
        let shown = displayedRect(image: image, in: container, fit: fit)
        guard shown.width > 0 else { return nil }
        let scale = image.width / shown.width
        let mapped = CGRect(
            x: (frame.minX - shown.minX) * scale,
            y: (frame.minY - shown.minY) * scale,
            width: frame.width * scale,
            height: frame.height * scale
        )
        let bounded = mapped.intersection(CGRect(origin: .zero, size: image))
        guard !bounded.isNull, bounded.width >= 1, bounded.height >= 1 else { return nil }
        return bounded.integral
    }

    /// Le cadre de départ : centré, un peu plus large que haut, comme une question d'énoncé.
    static func initialFrame(in container: CGSize) -> CGRect {
        let width = container.width * 0.84
        let height = min(container.height * 0.34, width * 0.62)
        return CGRect(
            x: (container.width - width) / 2,
            y: (container.height - height) / 2 - container.height * 0.04,
            width: width,
            height: height
        )
    }

    /// Le cadre ne sort pas de l'écran et ne devient pas plus petit qu'un doigt.
    static func clamped(_ frame: CGRect, in container: CGSize, minimum: CGFloat = 80) -> CGRect {
        var out = frame.standardized
        out.size.width = min(max(out.width, minimum), container.width)
        out.size.height = min(max(out.height, minimum), container.height)
        out.origin.x = min(max(out.minX, 0), container.width - out.width)
        out.origin.y = min(max(out.minY, 0), container.height - out.height)
        return out
    }
}

/// Les gestes sur la photo : la redresser, la recadrer, en faire une vignette.
enum SolverImage {
    /// La photo redressée (l'orientation EXIF appliquée) à l'échelle 1 : sa taille en points
    /// est sa taille en pixels, et `SolverCrop` peut y découper.
    static func normalized(_ image: UIImage, maxDimension: CGFloat = 3000) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let size = CGSize(width: max(1, (image.size.width * scale).rounded()), height: max(1, (image.size.height * scale).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func cropped(_ image: UIImage, to rect: CGRect) -> UIImage {
        guard let cg = image.cgImage?.cropping(to: rect) else { return image }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    /// Une petite vignette pour l'historique.
    static func thumbnail(_ image: UIImage) -> Data? {
        ImagePrep.jpeg(image, maxDimension: 360, quality: 0.6)
    }
}
