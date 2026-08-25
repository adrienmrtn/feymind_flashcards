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
        let layoutManager = NSLayoutManager()
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

// Il y avait ici un `MarkerLayoutManager`, une sous-classe entière dont le seul rôle était
// d'arrondir les coins du fond de surlignage : le rectangle par défaut prend toute la hauteur
// de ligne, ce qui donnait une bande grasse posée sur le texte. Le surlignage a été retiré au
// profit d'une couleur d'encre, et cette classe avec : un gestionnaire de mise en page
// standard suffit.
