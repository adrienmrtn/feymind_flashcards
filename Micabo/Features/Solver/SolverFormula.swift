import SwiftUI
import UIKit
#if canImport(SwiftMath)
import SwiftMath
#endif

/// **Une formule de solution, composée en image.**
///
/// Le moteur (`MTMathUILabel`, par `MathTypesetter`) compose la formule une fois, et on la
/// dessine dans une image à l'échelle de l'écran, à la couleur du thème. Une image plutôt
/// que la vue UIKit de `MathFormula` : elle se mesure d'elle-même, se réduit quand la
/// formule est plus large que la carte, et se dessine aussi dans les rendus de la CI, où
/// `ImageRenderer` ne peint pas les vues UIKit. Sans moteur, ou sur un LaTeX qu'il refuse,
/// c'est `MathFormula` qui prend le relais (la transposition Unicode).
struct SolverFormula: View {
    let latex: String
    var fontSize: CGFloat = 19
    var color: Color = MicaboColor.ink

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        if let image = Self.image(latex: latex, fontSize: fontSize, color: resolved, scale: max(displayScale, 2)) {
            ViewThatFits(in: .horizontal) {
                Image(uiImage: image)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .accessibilityLabel(Text(FormulaRenderer.stripped("$\(latex)$")))
        } else {
            MathFormula(latex: latex, fontSize: fontSize, color: color, isCentered: true, isDisplayMode: true)
        }
    }

    /// La couleur du thème qui s'affiche, figée : l'image ne suit pas le thème d'elle-même.
    private var resolved: UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light))
    }

    /// Les formules déjà composées : une carte se redessine à chaque étape dévoilée.
    private static let cache = NSCache<NSString, UIImage>()

    static func image(latex: String, fontSize: CGFloat, color: UIColor, scale: CGFloat) -> UIImage? {
        #if canImport(SwiftMath)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let key = "\(latex)|\(fontSize)|\(scale)|\(red),\(green),\(blue),\(alpha)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard MathTypesetter.canTypeset(latex) else { return nil }
        let label = MTMathUILabel()
        label.displayErrorInline = false
        label.latex = latex
        label.fontSize = fontSize
        label.textColor = color
        label.labelMode = .display
        label.textAlignment = .left
        let size = label.intrinsicContentSize
        guard size.width > 0, size.height > 0, size.width.isFinite, size.height.isFinite else { return nil }
        let bounds = CGRect(origin: .zero, size: CGSize(width: ceil(size.width) + 2, height: ceil(size.height) + 2))
        label.frame = bounds
        label.backgroundColor = .clear
        label.setNeedsLayout()
        label.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            // Le label compose dans le repère de Core Text, tête en bas une fois rendu hors
            // d'une fenêtre : on retourne le contexte.
            context.cgContext.translateBy(x: 0, y: bounds.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            label.layer.render(in: context.cgContext)
        }
        cache.setObject(image, forKey: key)
        return image
        #else
        return nil
        #endif
    }
}
