import UIKit

#if canImport(SwiftMath)
import SwiftMath
#endif

/// Construction du `UITextView` **modifiable** de la fiche, sans SwiftUI dans le fichier :
/// voir `SheetTextViewFactory` pour la raison.
enum SheetEditorTextViewFactory {
    private static let unlimitedHeight = CGFloat(10_000)

    static func makeView() -> UITextView {
        let storage = NSTextStorage()
        let layoutManager = SheetEditorLayoutManager()
        storage.addLayoutManager(layoutManager)

        let container = NSTextContainer(size: CGSize(width: CGFloat(0), height: unlimitedHeight))
        container.widthTracksTextView = true
        container.lineFragmentPadding = CGFloat(0)
        layoutManager.addTextContainer(container)

        let view = UITextView(frame: CGRect.zero, textContainer: container)
        view.isEditable = true
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = UIColor.clear
        view.textContainerInset = UIEdgeInsets.zero
        view.dataDetectorTypes = []
        // Les attributs sont à nous : le menu système ne doit pas poser son propre gras.
        view.allowsEditingTextAttributes = false
        view.autocorrectionType = UITextAutocorrectionType.default
        view.spellCheckingType = UITextSpellCheckingType.default
        view.smartDashesType = UITextSmartDashesType.no
        view.keyboardDismissMode = UIScrollView.KeyboardDismissMode.interactive
        view.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: NSLayoutConstraint.Axis.horizontal)
        return view
    }

    static func measuredSize(of view: UITextView, width: CGFloat) -> CGSize {
        let fitting = view.sizeThatFits(CGSize(width: width, height: unlimitedHeight))
        return CGSize(width: width, height: ceil(fitting.height))
    }
}

/// Le surligneur de la fiche, **et les puces**.
///
/// Une puce ou un numéro n'est pas un caractère du texte : si c'en était un, un retour
/// arrière en début d'entrée l'effacerait, et il partirait dans la fiche enregistrée. Ils
/// sont dessinés ici, dans la gouttière que le retrait de paragraphe laisse à gauche, et
/// le texte n'en sait rien.
final class SheetEditorLayoutManager: SheetMarkerLayoutManager {
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage, storage.length > 0 else { return }

        let string = storage.string as NSString
        let characterRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        var location = characterRange.location
        var numbering: [Int: Int] = [:]

        while location < NSMaxRange(characterRange) {
            let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
            defer { location = max(NSMaxRange(paragraph), location + 1) }
            guard paragraph.location < storage.length else { break }
            let raw = storage.attribute(SheetDocument.kindKey, at: paragraph.location, effectiveRange: nil) as? String
            guard let kind = raw.flatMap(SheetParagraphKind.init(rawValue:)), kind.isList else { continue }

            let font = (storage.attribute(NSAttributedString.Key.font, at: paragraph.location, effectiveRange: nil) as? UIFont)
                ?? UIFont.systemFont(ofSize: SheetTypography.body)
            let glyph = glyphIndexForCharacter(at: paragraph.location)
            let line = lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let baseline = origin.y + line.minY + font.ascender
            let gutter = CGRect(
                x: origin.x + line.minX,
                y: baseline - font.capHeight,
                width: SheetParagraphKind.listIndent - CGFloat(6),
                height: font.capHeight
            )

            if kind == .bullet {
                let diameter = CGFloat(4.5)
                let dot = CGRect(
                    x: gutter.midX - diameter / 2 - CGFloat(2),
                    y: gutter.midY - diameter / 2 + CGFloat(1),
                    width: diameter,
                    height: diameter
                )
                markerColor.withAlphaComponent(CGFloat(0.65)).setFill()
                UIBezierPath(ovalIn: dot).fill()
            } else {
                let number = ordinal(of: paragraph, in: string, storage: storage, cache: &numbering)
                let label = "\(number)." as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: font.pointSize, weight: UIFont.Weight.semibold),
                    NSAttributedString.Key.foregroundColor: markerColor
                ]
                let size = label.size(withAttributes: attributes)
                label.draw(at: CGPoint(x: gutter.maxX - size.width, y: baseline - font.ascender), withAttributes: attributes)
            }
        }
    }

    /// La teinte des puces : celle du cours, posée par l'éditeur.
    var markerColor: UIColor = UIColor.label

    /// Le rang d'une entrée numérotée : on remonte les paragraphes numérotés qui la
    /// précèdent sans interruption.
    private func ordinal(
        of paragraph: NSRange,
        in string: NSString,
        storage: NSTextStorage,
        cache: inout [Int: Int]
    ) -> Int {
        if let known = cache[paragraph.location] { return known }
        var count = 1
        var cursor = paragraph.location
        while cursor > 0 {
            let previous = string.paragraphRange(for: NSRange(location: cursor - 1, length: 0))
            guard previous.location < storage.length,
                  (storage.attribute(SheetDocument.kindKey, at: previous.location, effectiveRange: nil) as? String)
                    == SheetParagraphKind.number.rawValue
            else { break }
            count += 1
            cursor = previous.location
        }
        cache[paragraph.location] = count
        return count
    }
}

/// La formule, composée en image par le moteur.
///
/// `MTMathUILabel` est une vue ; le document, lui, veut une image à poser sur la ligne. On
/// compose donc hors écran, puis on dessine **la formule composée** dans un contexte - pas la
/// vue. Sans le paquet, ou quand le LaTeX ne s'analyse pas, on rend `nil` et l'appelant
/// retombe sur du texte transposé : une fiche écrite par un modèle contiendra du LaTeX
/// incomplet, et le choix est entre un cadre vide et une formule un peu moins belle.
///
/// **Pourquoi pas `label.layer.render(in:)`.** SwiftMath dessine dans le repère de Quartz,
/// l'origine en bas et les y vers le haut. À l'écran, c'est le `isGeometryFlipped` que la vue
/// pose sur son calque qui remet la formule à l'endroit, au moment où Core Animation compose
/// l'écran. `render(in:)` ne l'applique pas, et le contexte d'un `UIGraphicsImageRenderer` a
/// les y vers le bas : chaque formule de la fiche sortait en miroir vertical. Retournées, les
/// lettres en imitaient d'autres - un `b` devenait un `ρ`, un `/` un `\`, l'exposant passait
/// sous la ligne - et ça se lisait comme des glyphes pris dans une mauvaise fonte, alors que
/// la fonte était la bonne. Le retournement est donc écrit ici, une fois et explicitement,
/// comme le fait `MTMathImage` dans le paquet ; il ne dépend plus de ce qu'un rendu de
/// calque veut bien appliquer.
enum SheetFormulaImage {
    static func render(latex: String, caption: String?, fontSize: CGFloat, color: UIColor, isDisplayMode: Bool) -> UIImage? {
        #if canImport(SwiftMath)
        guard MathTypesetter.canTypeset(latex) else { return nil }
        let label = MTMathUILabel()
        label.latex = latex
        label.fontSize = fontSize
        label.textColor = color
        label.labelMode = isDisplayMode ? .display : .text
        label.textAlignment = isDisplayMode ? .center : .left
        label.displayErrorInline = false
        label.backgroundColor = UIColor.clear
        let size = label.intrinsicContentSize
        guard size.width > 0, size.height > 0, size.width < 4000, size.height < 4000 else { return nil }

        let padding = isDisplayMode ? CGFloat(16) : CGFloat(1)
        let captionFont = UIFont.systemFont(ofSize: SheetTypography.caption * SheetPreferences.readingScale)
        let captionText = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let captionHeight = captionText.isEmpty ? CGFloat(0) : ceil(captionFont.lineHeight) + CGFloat(8)
        let width = ceil(size.width) + padding * 2
        let height = ceil(size.height) + padding * 2 + captionHeight
        label.frame = CGRect(x: padding, y: padding, width: ceil(size.width), height: ceil(size.height))
        // La mise en page de la vue compose la formule et la place dans ses bornes : c'est
        // cette liste qu'on dessine, exactement comme la vue la dessinerait à l'écran.
        label.layoutIfNeeded()
        guard let display = label.displayList else { return nil }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            context.cgContext.saveGState()
            // Le repère de la vue, les y vers le haut : l'origine descend au bas de la formule,
            // puis l'axe vertical se retourne. Voir plus haut pourquoi ce n'est pas le calque.
            context.cgContext.translateBy(x: padding, y: padding + label.bounds.height)
            context.cgContext.scaleBy(x: CGFloat(1), y: CGFloat(-1))
            display.draw(context.cgContext)
            context.cgContext.restoreGState()
            if !captionText.isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [
                    NSAttributedString.Key.font: captionFont,
                    NSAttributedString.Key.foregroundColor: color.withAlphaComponent(CGFloat(0.55))
                ]
                let measured = (captionText as NSString).size(withAttributes: attributes)
                let x = max(CGFloat(0), (width - measured.width) / 2)
                (captionText as NSString).draw(
                    at: CGPoint(x: x, y: height - captionHeight + CGFloat(4)),
                    withAttributes: attributes
                )
            }
        }
        // La ligne de base de la formule, depuis le bas de l'image : c'est sur elle qu'une
        // formule en ligne se pose. La vue centre la formule dans sa hauteur, sans la tasser
        // sous une demi-taille de fonte ; la même règle, relue ici, dit où tombe la ligne.
        let typesetHeight = max(display.ascent + display.descent, fontSize / CGFloat(2))
        let baseline = captionHeight + padding + (label.bounds.height - typesetHeight) / CGFloat(2) + display.descent
        return image.withBaselineOffset(fromBottom: baseline)
        #else
        return nil
        #endif
    }
}
