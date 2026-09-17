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
        let layoutManager = SheetMarkerLayoutManager()
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

/// Le surligneur de la fiche.
///
/// TextKit peint un fond de texte sur toute la hauteur de la ligne, interligne compris. Sur
/// un paragraphe de fiche, où l'interligne vaut près de la moitié du corps, ça ne donne pas
/// un surlignage mais un pavé de couleur : la bande touche celle de la ligne du dessus,
/// change d'épaisseur dès qu'une ligne porte un exposant, et écrase le texte qu'elle devait
/// mettre en avant. C'est ce défaut, et lui seul, qui avait fait retirer le surligneur.
///
/// La bande est donc redessinée ici. Elle est calée sur la **hauteur des capitales** de la
/// fonte du passage, pas sur celle de la ligne : elle fait la même épaisseur partout dans la
/// fiche, quelle que soit la façon dont le paragraphe est interligné, et elle descend juste
/// assez sous la ligne de base pour passer derrière les jambages du p et du g.
/// `SheetEditorLayoutManager` en hérite pour y ajouter les puces : le surlignage est le même
/// en lecture et en écriture, et deux copies de ce calcul finiraient par ne plus peindre la
/// même bande.
class SheetMarkerLayoutManager: NSLayoutManager {
    /// Ce qui dépasse du texte, au-dessus des capitales et sous la ligne de base.
    private static let padding = CGFloat(1.5)
    /// Un trait de feutre a les bouts émoussés, pas un angle droit.
    private static let radius = CGFloat(3)

    override func fillBackgroundRectArray(
        _ rectArray: UnsafePointer<CGRect>,
        count rectCount: Int,
        forCharacterRange charRange: NSRange,
        color: UIColor
    ) {
        guard let font = font(at: charRange) else {
            super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
            return
        }

        let widths = markedWidths(forCharacterRange: charRange)

        color.setFill()
        for index in 0..<rectCount {
            var rect = rectArray[index]
            // **La bande s'arrête au dernier mot, pas au bord de la colonne.**
            //
            // TextKit rend, pour chaque ligne d'un fond de texte, un rectangle qui court
            // jusqu'à la fin du fragment de ligne, c'est-à-dire jusqu'à la marge. Sur un
            // passage qui court sur trois lignes, les deux premières étaient donc surlignées
            // jusqu'au bord même quand le dernier mot s'arrêtait bien avant : au rendu, une
            // langue de couleur dépassait dans le blanc et le trait de feutre ressemblait à
            // une sélection mal relâchée.
            if index < widths.count, widths[index] > 0 {
                rect.size.width = min(rect.width, widths[index])
            }
            let band = Self.band(in: rect, font: font)
            UIBezierPath(roundedRect: band, cornerRadius: Self.radius).fill()
        }
    }

    /// Ce que le passage marqué occupe **réellement** sur chaque ligne, dans l'ordre.
    ///
    /// Des largeurs et non des rectangles : les rectangles de `fillBackgroundRectArray` sont
    /// déjà décalés par l'origine du dessin, ceux d'un parcours de fragments ne le sont pas,
    /// et comparer les deux en absolu ferait dépendre le résultat de la position du texte
    /// dans sa vue. Une largeur, elle, est la même dans les deux repères.
    ///
    /// La borne est la plus courte des deux : la fin des glyphes marqués, et la fin du texte
    /// de la ligne. La seconde écarte l'espace de fin de ligne, qui appartient au passage
    /// quand il s'y termine mais ne se voit pas.
    private func markedWidths(forCharacterRange charRange: NSRange) -> [CGFloat] {
        guard let container = textContainers.first else { return [] }
        let glyphs = glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
        guard glyphs.length > 0 else { return [] }

        var widths: [CGFloat] = []
        enumerateLineFragments(forGlyphRange: glyphs) { [weak self] _, used, _, lineGlyphs, _ in
            guard let self else { return }
            let shared = NSIntersectionRange(lineGlyphs, glyphs)
            guard shared.length > 0 else { return }
            let marked = self.boundingRect(forGlyphRange: shared, in: container)
            widths.append(max(CGFloat(0), min(marked.maxX, used.maxX) - marked.minX))
        }
        return widths
    }

    /// La bande, dans le rectangle de ligne que TextKit propose.
    ///
    /// Les glyphes sont posés en haut du rectangle : l'interligne d'un `NSParagraphStyle`
    /// s'ajoute **sous** la ligne. La ligne de base se déduit donc de l'ascendante de la
    /// fonte, et tout le reste s'y accroche.
    static func band(in rect: CGRect, font: UIFont) -> CGRect {
        let baseline = rect.minY + font.ascender
        let top = baseline - font.capHeight - padding
        let bottom = baseline + min(CGFloat(3), abs(font.descender) * CGFloat(0.55))
        let band = CGRect(x: rect.minX, y: top, width: rect.width, height: bottom - top)
        // Une fonte dont les métriques sortent du rectangle proposé n'existe pas en
        // pratique, mais une bande plus haute que sa ligne serait pire que pas de bande.
        return band.height <= rect.height ? band : rect
    }

    private func font(at range: NSRange) -> UIFont? {
        guard let textStorage, range.location < textStorage.length else { return nil }
        return textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
    }
}
