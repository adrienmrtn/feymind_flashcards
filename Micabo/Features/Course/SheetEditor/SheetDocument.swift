import SwiftUI
import UIKit

/// **La fiche, dans les deux sens : des blocs vers le document composé, et retour.**
///
/// C'est le pivot de la fiche modifiable sur l'iPhone, l'équivalent exact de
/// `web/lib/sheet/document.ts`. La fiche se **range** en blocs - c'est ce que le modèle écrit,
/// ce que le site lit et ce que la mise à plat dépouille pour écrire les cartes - mais elle se
/// **modifie** dans un `UITextView`, parce qu'un document est ce que tout le monde sait
/// manipuler. Les deux conversions vivent donc ici, ensemble.
///
/// Le document est un `NSAttributedString` où **chaque paragraphe est un bloc** et porte sa
/// nature dans un attribut (`.sheetKind`). Les marques en ligne sont des attributs aussi :
/// le gras et l'italique dans la fonte, le barré dans `.strikethroughStyle`, le surlignage
/// et la taille dans des clés à nous. Une formule est une pièce jointe composée par le
/// moteur, qui garde son LaTeX : on ne tape pas au milieu des symboles rendus, on la rouvre.
///
/// Le retour ne fait confiance à rien : ce qui n'a pas de nature devient un paragraphe, une
/// ligne vide disparaît, et `sanitized()` repasse derrière. Une fiche enregistrée est une
/// fiche que le modèle aurait pu écrire.
enum SheetDocument {
    // MARK: - Les clés

    /// La nature du paragraphe : `SheetParagraphKind.rawValue`.
    static let kindKey = NSAttributedString.Key("micabo.sheet.kind")
    /// La teinte du surligneur : `SheetHighlight.rawValue`.
    static let highlightKey = NSAttributedString.Key("micabo.sheet.highlight")
    /// La taille du fragment : `SheetTextSize.rawValue`.
    static let sizeKey = NSAttributedString.Key("micabo.sheet.size")
    /// Le LaTeX d'une formule en ligne rendue **en texte**, quand le moteur manque. Sur un
    /// fragment composé en pièce jointe, c'est la pièce jointe qui le porte.
    static let mathKey = NSAttributedString.Key("micabo.sheet.math")

    /// Le caractère d'une pièce jointe.
    static let attachmentCharacter = "\u{FFFC}"

    // MARK: - Des blocs vers le document

    static func attributed(from blocks: [SheetBlock]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var previous: SheetParagraphKind?
        for block in blocks {
            switch block {
            case .heading(let level, let text):
                let kind: SheetParagraphKind = level == 1 ? .heading1 : .heading2
                append(paragraph(text, kind: kind), after: previous, to: result)
                previous = kind
            case .paragraph(let text):
                append(paragraph(text, kind: .paragraph), after: previous, to: result)
                previous = .paragraph
            case .list(let ordered, let items):
                let kind: SheetParagraphKind = ordered ? .number : .bullet
                for item in items {
                    append(paragraph(item, kind: kind), after: previous, to: result)
                    previous = kind
                }
            case .formula(let latex, let caption):
                append(formulaParagraph(latex: latex, caption: caption), after: previous, to: result)
                previous = .formula
            }
        }
        return result
    }

    /// Le retour à la ligne porte les attributs du paragraphe qu'il ferme - **sans** sa pièce
    /// jointe, sinon une formule se dessinerait deux fois.
    private static func append(_ paragraph: NSAttributedString, after previous: SheetParagraphKind?, to result: NSMutableAttributedString) {
        if let previous {
            result.append(NSAttributedString(string: "\n", attributes: baseAttributes(kind: previous)))
        }
        result.append(paragraph)
    }

    /// Un paragraphe de texte balisé, composé.
    static func paragraph(_ markup: String, kind: SheetParagraphKind) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for segment in mathSegments(of: markup) {
            if let latex = segment.latex {
                result.append(inlineMath(latex, kind: kind))
                continue
            }
            for span in SheetMarkup.spans(segment.text) {
                result.append(NSAttributedString(string: span.text, attributes: attributes(for: span, kind: kind)))
            }
        }
        if result.length == 0 {
            // Un paragraphe vide garde sa nature : sans un seul attribut, le curseur n'aurait
            // rien à hériter et le paragraphe ne saurait plus ce qu'il est.
            return NSAttributedString(string: "", attributes: baseAttributes(kind: kind))
        }
        return result
    }

    /// Une formule posée seule : un paragraphe qui ne contient que sa pièce jointe.
    static func formulaParagraph(latex: String, caption: String?) -> NSAttributedString {
        let attachment = SheetMathAttachment(latex: latex, caption: caption, isBlock: true)
        attachment.render(fontSize: SheetTypography.formula * SheetPreferences.readingScale)
        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttributes(baseAttributes(kind: .formula), range: NSRange(location: 0, length: result.length))
        return result
    }

    /// Une formule prise dans la phrase.
    static func inlineMath(_ latex: String, kind: SheetParagraphKind) -> NSAttributedString {
        let attachment = SheetMathAttachment(latex: latex, caption: nil, isBlock: false)
        let size = kind.fontSize * SheetPreferences.readingScale
        if attachment.render(fontSize: size + 1) {
            let result = NSMutableAttributedString(attachment: attachment)
            result.addAttributes(baseAttributes(kind: kind), range: NSRange(location: 0, length: result.length))
            return result
        }
        // Sans moteur, la formule reste du texte transposé, avec son LaTeX en attribut pour
        // que l'enregistrement ne le perde pas.
        var attributes = baseAttributes(kind: kind)
        attributes[.font] = mathFont(size: size + 1)
        attributes[mathKey] = latex
        return NSAttributedString(string: FormulaRenderer.plain(latex), attributes: attributes)
    }

    // MARK: - Du document vers les blocs

    static func blocks(from text: NSAttributedString) -> [SheetBlock] {
        var drafted: [SheetBlock] = []
        var pendingList: (ordered: Bool, items: [String])?

        func closeList() {
            if let list = pendingList, !list.items.isEmpty {
                drafted.append(.list(ordered: list.ordered, items: list.items))
            }
            pendingList = nil
        }

        let string = text.string as NSString
        var location = 0
        while location < string.length {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let content = Self.contentRange(of: paragraphRange, in: string)
            let paragraphKind = Self.kind(at: paragraphRange, in: text)

            if paragraphKind == .formula, let attachment = blockAttachment(in: content, of: text) {
                closeList()
                if let latex = attachment.latex.nilIfBlank {
                    drafted.append(.formula(latex: latex, caption: attachment.caption?.nilIfBlank))
                }
            } else {
                let markup = inlineMarkup(in: content, of: text)
                if !markup.isEmpty {
                    switch paragraphKind {
                    case .heading1: closeList(); drafted.append(.heading(level: 1, text: markup))
                    case .heading2: closeList(); drafted.append(.heading(level: 2, text: markup))
                    case .paragraph, .formula: closeList(); drafted.append(.paragraph(text: markup))
                    case .bullet, .number:
                        let ordered = paragraphKind == .number
                        if pendingList?.ordered != ordered { closeList(); pendingList = (ordered, []) }
                        pendingList?.items.append(markup)
                    }
                }
            }

            if paragraphRange.length == 0 { break }
            location = NSMaxRange(paragraphRange)
        }
        closeList()
        return drafted
    }

    /// Le texte balisé d'un paragraphe : ses fragments relus, marque par marque.
    static func inlineMarkup(in range: NSRange, of text: NSAttributedString) -> String {
        guard range.length > 0 else { return "" }
        var out = ""
        text.enumerateAttributes(in: range, options: []) { attributes, runRange in
            if let attachment = attributes[.attachment] as? SheetMathAttachment {
                if let latex = attachment.latex.nilIfBlank { out += "$\(latex)$" }
                return
            }
            if let latex = attributes[mathKey] as? String, let clean = latex.nilIfBlank {
                out += "$\(clean)$"
                return
            }
            let run = (text.string as NSString).substring(with: runRange)
                .replacingOccurrences(of: attachmentCharacter, with: "")
                .replacingOccurrences(of: "\n", with: "")
            guard !run.isEmpty else { return }
            let font = attributes[.font] as? UIFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let span = SheetMarkup.Span(
                text: run,
                isBold: traits.contains(.traitBold),
                isItalic: traits.contains(.traitItalic),
                isHighlighted: attributes[highlightKey] != nil,
                isStruck: (attributes[.strikethroughStyle] as? Int ?? 0) != 0,
                highlight: (attributes[highlightKey] as? String).flatMap(SheetHighlight.init(rawValue:)),
                size: (attributes[sizeKey] as? String).flatMap(SheetTextSize.init(rawValue:))
            )
            out += SheetMarkup.markup(from: [span])
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    static func kind(at paragraphRange: NSRange, in text: NSAttributedString) -> SheetParagraphKind {
        guard paragraphRange.location < text.length else { return .paragraph }
        let raw = text.attribute(kindKey, at: paragraphRange.location, effectiveRange: nil) as? String
        return raw.flatMap(SheetParagraphKind.init(rawValue:)) ?? .paragraph
    }

    /// Le paragraphe sans son retour à la ligne.
    static func contentRange(of paragraphRange: NSRange, in string: NSString) -> NSRange {
        var range = paragraphRange
        if range.length > 0, string.character(at: NSMaxRange(range) - 1) == 0x0A { range.length -= 1 }
        return range
    }

    private static func blockAttachment(in range: NSRange, of text: NSAttributedString) -> SheetMathAttachment? {
        var found: SheetMathAttachment?
        guard range.length > 0 else { return nil }
        text.enumerateAttribute(.attachment, in: range, options: []) { value, _, stop in
            if let attachment = value as? SheetMathAttachment, attachment.isBlock {
                found = attachment
                stop.pointee = true
            }
        }
        return found
    }

    // MARK: - Les attributs

    /// Les attributs d'un paragraphe nu : sa nature, sa fonte, sa couleur, ses espaces.
    static func baseAttributes(kind: SheetParagraphKind) -> [NSAttributedString.Key: Any] {
        [
            kindKey: kind.rawValue,
            .font: font(kind: kind, bold: false, italic: false, size: nil),
            .foregroundColor: kind.color,
            .paragraphStyle: paragraphStyle(kind: kind)
        ]
    }

    static func attributes(for span: SheetMarkup.Span, kind: SheetParagraphKind) -> [NSAttributedString.Key: Any] {
        var attributes = baseAttributes(kind: kind)
        attributes[.font] = span.isMath
            ? mathFont(size: kind.fontSize * SheetPreferences.readingScale * (span.size?.scale ?? 1) + 1)
            : font(kind: kind, bold: span.isBold, italic: span.isItalic, size: span.size)
        if let highlight = span.highlight {
            attributes[highlightKey] = highlight.rawValue
            attributes[.backgroundColor] = UIColor(MicaboColor.sheetHighlight(highlight))
        }
        if let size = span.size { attributes[sizeKey] = size.rawValue }
        if span.isStruck {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = UIColor(MicaboColor.inkTertiary)
            attributes[.foregroundColor] = UIColor(MicaboColor.inkTertiary)
        }
        return attributes
    }

    static func font(kind: SheetParagraphKind, bold: Bool, italic: Bool, size: SheetTextSize?) -> UIFont {
        let base = kind.fontSize * SheetPreferences.readingScale * (size?.scale ?? 1)
        let weight: Font.Weight = bold ? (kind.weight == .regular ? .semibold : .bold) : kind.weight
        return MicaboFont.uiFont(base.rounded(), weight: weight, italic: italic)
    }

    static func mathFont(size: CGFloat) -> UIFont {
        let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withDesign(.serif)
        let serif = descriptor.map { UIFont(descriptor: $0, size: size) } ?? UIFont.systemFont(ofSize: size)
        guard let italic = serif.fontDescriptor.withSymbolicTraits(.traitItalic) else { return serif }
        return UIFont(descriptor: italic, size: size)
    }

    static func paragraphStyle(kind: SheetParagraphKind) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = kind.lineSpacing
        style.paragraphSpacingBefore = kind.spaceBefore
        style.lineBreakMode = .byWordWrapping
        style.alignment = kind == .formula ? .center : .natural
        if kind.isList {
            style.headIndent = SheetParagraphKind.listIndent
            style.firstLineHeadIndent = SheetParagraphKind.listIndent
        }
        return style
    }

    // MARK: - Le découpage `$…$`

    struct MathSegment {
        var text: String
        /// Le LaTeX brut, quand le fragment est une formule.
        var latex: String?
    }

    /// Les formules d'un texte, **brutes**. `FormulaRenderer.segments` les transpose déjà en
    /// Unicode, et une formule transposée ne se recompose pas : ici on garde le LaTeX.
    static func mathSegments(of source: String) -> [MathSegment] {
        let pieces = source.components(separatedBy: "$")
        guard pieces.count > 1 else { return [MathSegment(text: source)] }
        let hasOpenFragment = pieces.count % 2 == 0
        var segments: [MathSegment] = []
        for (index, piece) in pieces.enumerated() {
            let isLast = index == pieces.count - 1
            let isMath = index % 2 == 1 && !(isLast && hasOpenFragment)
            guard !piece.isEmpty else { continue }
            if isMath {
                segments.append(MathSegment(text: piece, latex: piece.trimmingCharacters(in: .whitespaces)))
            } else {
                segments.append(MathSegment(text: (isLast && hasOpenFragment && index > 0) ? "$" + piece : piece))
            }
        }
        return segments
    }
}

// MARK: - La nature d'un paragraphe

/// Ce qu'un paragraphe du document est. C'est le `<h1>`, `<p>`, `<li>` du site.
enum SheetParagraphKind: String, CaseIterable {
    case heading1
    case heading2
    case paragraph
    case bullet
    case number
    case formula

    /// Le retrait d'une entrée de liste, où la puce ou le numéro se dessine.
    static let listIndent: CGFloat = 22

    var isList: Bool { self == .bullet || self == .number }

    var fontSize: CGFloat {
        switch self {
        case .heading1: SheetTypography.headingLarge
        case .heading2: SheetTypography.headingSmall
        case .formula: SheetTypography.formula
        default: SheetTypography.body
        }
    }

    var weight: Font.Weight {
        switch self {
        case .heading1: .bold
        case .heading2: .semibold
        default: .regular
        }
    }

    var color: UIColor {
        switch self {
        case .heading1, .heading2: UIColor(MicaboColor.ink)
        default: UIColor(MicaboColor.inkReading)
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .heading1, .heading2: SheetTypography.tightLineSpacing
        default: SheetTypography.lineSpacing
        }
    }

    var spaceBefore: CGFloat {
        switch self {
        case .heading1: SheetTypography.spaceBeforeLargeHeading
        case .heading2: SheetTypography.spaceBeforeSmallHeading
        case .bullet, .number: SheetTypography.spaceBeforeList
        default: SheetTypography.blockSpacing
        }
    }

    /// Ce qu'un retour à la ligne donne : un titre s'ouvre sur du corps, une liste continue,
    /// une formule laisse la place à du texte.
    var next: SheetParagraphKind {
        switch self {
        case .bullet, .number: self
        default: .paragraph
        }
    }

    func title(locale: UiLocale) -> String {
        switch self {
        case .heading1: L10n.t("app.sheet.styleTitle", locale: locale)
        case .heading2: L10n.t("app.sheet.styleSubtitle", locale: locale)
        case .paragraph, .formula: L10n.t("app.sheet.styleBody", locale: locale)
        case .bullet: L10n.t("app.sheet.styleBullets", locale: locale)
        case .number: L10n.t("app.sheet.styleNumbers", locale: locale)
        }
    }
}

// MARK: - La formule composée

/// Une formule dans le document : une image composée par le moteur, qui garde son LaTeX.
///
/// On ne tape pas dedans - c'est une pièce jointe - on la touche pour la rouvrir dans son
/// éditeur. Posée seule (`isBlock`), elle est composée en mode display, avec sa légende
/// dessous ; prise dans la phrase, elle tient sur la ligne du texte.
final class SheetMathAttachment: NSTextAttachment {
    let latex: String
    let caption: String?
    let isBlock: Bool
    private var renderedSize: CGSize = .zero

    init(latex: String, caption: String?, isBlock: Bool) {
        self.latex = latex
        self.caption = caption
        self.isBlock = isBlock
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) {
        latex = coder.decodeObject(forKey: "latex") as? String ?? ""
        caption = coder.decodeObject(forKey: "caption") as? String
        isBlock = coder.decodeBool(forKey: "isBlock")
        super.init(coder: coder)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(latex, forKey: "latex")
        coder.encode(caption, forKey: "caption")
        coder.encode(isBlock, forKey: "isBlock")
    }

    /// Compose l'image. Rend faux quand le moteur manque ou refuse le LaTeX : l'appelant
    /// retombe alors sur du texte.
    @discardableResult
    func render(fontSize: CGFloat) -> Bool {
        guard let rendered = SheetFormulaImage.render(
            latex: latex,
            caption: isBlock ? caption : nil,
            fontSize: fontSize,
            color: UIColor(MicaboColor.ink),
            isDisplayMode: isBlock
        ) else { return false }
        image = rendered
        renderedSize = rendered.size
        return true
    }

    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        guard renderedSize.width > 0 else { return .zero }
        if isBlock {
            let width = max(CGFloat(1), lineFrag.width)
            let scale = min(CGFloat(1), width / renderedSize.width)
            return CGRect(x: 0, y: 0, width: renderedSize.width * scale, height: renderedSize.height * scale)
        }
        // La formule en ligne se pose sur la ligne de base du texte, à mi-hauteur des
        // minuscules : ni flottante au-dessus, ni pendue dessous.
        let descent = -renderedSize.height * 0.3
        return CGRect(x: 0, y: descent, width: renderedSize.width, height: renderedSize.height)
    }
}
