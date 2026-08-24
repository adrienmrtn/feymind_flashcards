import UIKit

/// Construction du `UITextView` de fiche, **sans SwiftUI**.
///
/// `SheetProse` importe les deux frameworks, et le compilateur n'arrive plus à dire si
/// `.clear` est une `Color` ou un `UIColor`, si `.zero` est un `CGRect` ou un
/// `UIEdgeInsets`. Ce fichier n'importe que UIKit : chaque type n'a plus qu'un sens.
enum SheetTextViewFactory {
    /// Hauteur « assez grande » pour mesurer un paragraphe. On évite
    /// `greatestFiniteMagnitude` : entre `CGFloat`, `Double` et `Float`, le compilateur
    /// n'arrive pas à choisir quand SwiftUI est dans le même module.
    private static let unlimitedHeight = CGFloat(10_000)

    static func makeView() -> UITextView {
        let storage = NSTextStorage()
        let layoutManager = MarkerLayoutManager()
        storage.addLayoutManager(layoutManager)

        let container = NSTextContainer(
            size: CGSize(width: CGFloat(0), height: unlimitedHeight)
        )
        container.widthTracksTextView = true
        container.lineFragmentPadding = CGFloat(0)
        layoutManager.addTextContainer(container)

        let view = UITextView(frame: CGRect.zero, textContainer: container)
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = UIColor.clear
        view.textContainerInset = UIEdgeInsets.zero
        view.dataDetectorTypes = []
        view.setContentCompressionResistancePriority(
            UILayoutPriority.defaultLow,
            for: NSLayoutConstraint.Axis.horizontal
        )
        return view
    }

    static func measuredSize(of view: UITextView, width: CGFloat) -> CGSize {
        let fitting = view.sizeThatFits(CGSize(width: width, height: unlimitedHeight))
        return CGSize(width: width, height: ceil(fitting.height))
    }
}

/// Dessine le surligneur.
///
/// Le fond d'un fragment attribué est, par défaut, un rectangle qui prend toute la hauteur
/// de ligne : posé sur un paragraphe à interligne généreux, ça donne une bande grasse qui
/// écrase le texte. On le remplace par un rectangle arrondi, resserré en hauteur et
/// débordant de quelques points sur les côtés, ce qui est exactement la trace que laisse un
/// marqueur passé à la main.
final class MarkerLayoutManager: NSLayoutManager {
    override func fillBackgroundRectArray(
        _ rectArray: UnsafePointer<CGRect>,
        count rectCount: Int,
        forCharacterRange charRange: NSRange,
        color: UIColor
    ) {
        guard let context = UIGraphicsGetCurrentContext() else {
            super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
            return
        }

        context.saveGState()
        color.setFill()
        for index in 0..<rectCount {
            let rect = rectArray[index].insetBy(dx: -3, dy: 2.5)
            guard rect.width > 0, rect.height > 0 else { continue }
            UIBezierPath(roundedRect: rect, cornerRadius: 5).fill()
        }
        context.restoreGState()
    }
}
