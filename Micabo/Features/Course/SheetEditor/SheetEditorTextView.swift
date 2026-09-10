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
/// compose donc hors écran et on dessine la vue dans un contexte. Sans le paquet, ou quand
/// le LaTeX ne s'analyse pas, on rend `nil` et l'appelant retombe sur du texte transposé :
/// une fiche écrite par un modèle contiendra du LaTeX incomplet, et le choix est entre un
/// cadre vide et une formule un peu moins belle.
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
        label.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: padding, y: padding)
            label.layer.render(in: context.cgContext)
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
        #else
        return nil
        #endif
    }
}
