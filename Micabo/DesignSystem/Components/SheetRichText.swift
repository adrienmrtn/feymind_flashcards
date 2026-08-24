import SwiftUI
import UIKit

/// Style d'un fragment de texte de fiche : de quoi composer un paragraphe, un encadré ou
/// une cellule de tableau à partir du même balisage.
struct SheetTextStyle {
    var size: CGFloat = SheetTypography.body
    var weight: Font.Weight = .regular
    var color: Color = MicaboColor.inkReading
    var lineSpacing: CGFloat = SheetTypography.lineSpacing
    var tracking: CGFloat = 0
    var isCentered: Bool = false

    /// Le corps du texte courant d'une fiche.
    static let prose = SheetTextStyle()

    /// Le chapeau, sous le titre du cours : un cran plus grand, un cran plus sombre.
    static let lead = SheetTextStyle(
        size: SheetTypography.lead,
        weight: .medium,
        color: MicaboColor.ink,
        lineSpacing: 6
    )

    /// Corps d'un encadré : à peine plus petit que le texte courant, il ne doit pas
    /// concurrencer la page.
    static let callout = SheetTextStyle(size: 15.5, color: MicaboColor.ink, lineSpacing: 6)

    /// Corps d'une définition, d'une étape, d'une explication.
    static let compact = SheetTextStyle(size: 15.5, lineSpacing: 5.5)

    /// Cellule de tableau.
    static func cell(emphasized: Bool = false) -> SheetTextStyle {
        SheetTextStyle(
            size: 13.5,
            weight: emphasized ? .semibold : .regular,
            color: emphasized ? MicaboColor.ink : MicaboColor.inkReading,
            lineSpacing: 3
        )
    }

    /// Légende sous un tableau, un graphe ou une formule.
    static let caption = SheetTextStyle(size: 12.5, color: MicaboColor.inkTertiary, lineSpacing: 3)

    func with(size: CGFloat? = nil, weight: Font.Weight? = nil, color: Color? = nil, centered: Bool? = nil) -> SheetTextStyle {
        SheetTextStyle(
            size: size ?? self.size,
            weight: weight ?? self.weight,
            color: color ?? self.color,
            lineSpacing: lineSpacing,
            tracking: tracking,
            isCentered: centered ?? isCentered
        )
    }

    /// Titre de partie ou de sous-partie. Les grands titres de Micabo sont resserrés :
    /// ceux de la fiche le sont aussi, sinon la page changerait de voix en cours de route.
    static func heading(level: Int) -> SheetTextStyle {
        level == 1
            ? SheetTextStyle(
                size: SheetTypography.headingLarge,
                weight: .bold,
                color: MicaboColor.ink,
                lineSpacing: 2,
                tracking: MicaboTracking.tight
            )
            : SheetTextStyle(
                size: SheetTypography.headingSmall,
                weight: .semibold,
                color: MicaboColor.ink,
                lineSpacing: 2
            )
    }

    /// Intitulé d'un objet : titre d'un tableau, d'un graphe, d'une suite d'étapes.
    static let objectTitle = SheetTextStyle(size: 15, weight: .semibold, color: MicaboColor.ink, lineSpacing: 2)
}

// MARK: - Rendu non sélectionnable

/// Texte balisé rendu par SwiftUI : gras, italique, surlignage et formules, sans sélection.
///
/// C'est le rendu des titres, des cellules de tableau, des étiquettes et des légendes,
/// partout où l'on ne sélectionne pas de passage. Il passe par une `AttributedString`
/// plutôt que par une concaténation de `Text`, parce que c'est la seule façon d'obtenir un
/// fond de surlignage qui suive le texte au retour à la ligne.
struct SheetInlineText: View {
    let markup: String
    var style: SheetTextStyle = .prose

    var body: some View {
        Text(SheetAttributedText.attributedString(markup, style: style))
            .tracking(style.tracking)
            .multilineTextAlignment(style.isCentered ? .center : .leading)
            .lineSpacing(style.lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: style.isCentered ? .center : .leading)
    }
}

// MARK: - Rendu sélectionnable

/// Paragraphe de fiche, **sélectionnable**, avec « Expliquer » dans le menu du système.
///
/// C'est la raison d'être de ce composant. Sélectionner un passage et demander ce qu'il
/// veut dire est le geste central de la fiche, et il n'existe pas de façon d'obtenir la
/// sélection d'un `Text` SwiftUI : `.textSelection(.enabled)` autorise le copier, mais ne
/// dit jamais ce qui a été sélectionné. On compose donc dans un `UITextView`, ce qui a
/// trois avantages : la sélection est celle du système (poignées, loupe, double appui),
/// « Expliquer » se pose dans le menu d'édition natif, et le surlignage se dessine sous
/// les glyphes au lieu d'entourer les mots.
struct SheetProse: UIViewRepresentable {
    let markup: String
    var style: SheetTextStyle = .prose
    /// Appelé avec le passage sélectionné quand l'utilisateur choisit « Expliquer ».
    var onExplain: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onExplain: onExplain)
    }

    func makeUIView(context: Context) -> UITextView {
        // TextKit 1 explicitement : le surligneur est dessiné par un gestionnaire de mise
        // en page à nous, et TextKit 2 ne donne pas la main sur le fond d'un fragment.
        let storage = NSTextStorage()
        let layoutManager = MarkerLayoutManager()
        storage.addLayoutManager(layoutManager)

        let container = NSTextContainer(size: CGSize(width: 0, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)

        let view = UITextView(frame: .zero, textContainer: container)
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.dataDetectorTypes = []
        view.tintColor = UIColor(MicaboColor.accent)
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.onExplain = onExplain
        let attributed = SheetAttributedText.make(markup, style: style)
        if view.attributedText != attributed {
            view.attributedText = attributed
        }
    }

    /// Un paragraphe prend la largeur qu'on lui propose et en déduit sa hauteur.
    ///
    /// SwiftUI mesure aussi la souplesse d'une vue en lui proposant une largeur absente ou
    /// infinie. Y répondre par la mesure d'une ligne interminable ferait croire au
    /// conteneur qu'un paragraphe veut trois mètres de large : on répond par la largeur
    /// d'une colonne de fiche, qui est la seule qu'un paragraphe occupe jamais.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let proposed = proposal.width, proposed.isFinite else {
            return measured(uiView, width: Self.columnWidth)
        }
        return measured(uiView, width: max(1, proposed))
    }

    private func measured(_ view: UITextView, width: CGFloat) -> CGSize {
        let fitting = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitting.height))
    }

    /// Largeur de référence d'une colonne de fiche : un écran de téléphone, marges de
    /// l'app retirées. Elle ne sert qu'à mesurer, jamais à dessiner.
    private static let columnWidth: CGFloat = 390 - MicaboSpacing.screen * 2

    final class Coordinator: NSObject, UITextViewDelegate {
        var onExplain: ((String) -> Void)?

        init(onExplain: ((String) -> Void)?) {
            self.onExplain = onExplain
        }

        /// « Expliquer » passe **devant** les actions du système : c'est l'action que la
        /// fiche propose, copier garde sa place juste après.
        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            guard let onExplain, range.length > 1 else {
                return UIMenu(children: suggestedActions)
            }

            let selection = (textView.attributedText.string as NSString).substring(with: range)
            guard SheetSelection.isExplainable(selection) else {
                return UIMenu(children: suggestedActions)
            }

            let explain = UIAction(title: "Expliquer", image: UIImage(systemName: "sparkles")) { _ in
                textView.selectedTextRange = nil
                Haptics.selection()
                onExplain(selection)
            }
            return UIMenu(children: [explain] + suggestedActions)
        }
    }
}

/// Ce qui mérite qu'on dépense un appel : un mot ou une phrase, pas une page entière ni
/// deux caractères attrapés par erreur.
enum SheetSelection {
    static let minimumCharacters = 2
    static let maximumCharacters = 600

    static func isExplainable(_ selection: String) -> Bool {
        let trimmed = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumCharacters, trimmed.count <= maximumCharacters else { return false }
        return trimmed.contains(where: \.isLetter)
    }

    /// Le passage tel qu'on le cite dans la feuille d'explication.
    static func trimmed(_ selection: String) -> String {
        selection
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,;:"))
    }
}

// MARK: - Composition

/// Traduit le balisage d'une fiche en texte composé, pour UIKit comme pour SwiftUI.
enum SheetAttributedText {
    static func make(_ markup: String, style: SheetTextStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = style.lineSpacing
        paragraph.alignment = style.isCentered ? .center : .natural
        paragraph.lineBreakMode = .byWordWrapping

        for span in SheetMarkup.spans(markup) {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: uiFont(for: span, style: style),
                .foregroundColor: UIColor(style.color),
                .paragraphStyle: paragraph
            ]
            if style.tracking != 0 {
                attributes[.kern] = style.tracking
            }
            if span.isHighlighted {
                attributes[.backgroundColor] = UIColor(MicaboColor.marker)
            }
            result.append(NSAttributedString(string: span.text, attributes: attributes))
        }

        return result
    }

    static func attributedString(_ markup: String, style: SheetTextStyle) -> AttributedString {
        var result = AttributedString()

        for span in SheetMarkup.spans(markup) {
            var piece = AttributedString(span.text)
            piece.font = font(for: span, style: style)
            piece.foregroundColor = style.color
            if span.isHighlighted {
                piece.backgroundColor = MicaboColor.marker
            }
            result.append(piece)
        }

        return result
    }

    // MARK: Fontes

    private static func font(for span: SheetMarkup.Span, style: SheetTextStyle) -> Font {
        if span.isMath {
            return .system(
                size: style.size + 1,
                weight: span.isBold ? .semibold : style.weight,
                design: .serif
            ).italic()
        }

        let base = MicaboFont.hanken(style.size, weight: span.isBold ? .semibold : style.weight)
        return span.isItalic ? base.italic() : base
    }

    private static func uiFont(for span: SheetMarkup.Span, style: SheetTextStyle) -> UIFont {
        if span.isMath {
            let size = style.size + 1
            let serifDescriptor = UIFont.systemFont(ofSize: size, weight: span.isBold ? .semibold : .regular)
                .fontDescriptor
                .withDesign(.serif)
            let serif = serifDescriptor.map { UIFont(descriptor: $0, size: size) } ?? UIFont.systemFont(ofSize: size)
            guard let italic = serif.fontDescriptor.withSymbolicTraits(.traitItalic) else { return serif }
            return UIFont(descriptor: italic, size: size)
        }

        return MicaboFont.uiFont(
            style.size,
            weight: span.isBold ? .semibold : style.weight,
            italic: span.isItalic
        )
    }
}

/// Dessine le surligneur.
///
/// Le fond d'un fragment attribué est, par défaut, un rectangle qui prend toute la hauteur
/// de ligne : posé sur un paragraphe à interligne généreux, ça donne une bande grasse qui
/// écrase le texte. On le remplace par un rectangle arrondi, resserré en hauteur et
/// débordant de quelques points sur les côtés, ce qui est exactement la trace que laisse un
/// marqueur passé à la main.
private final class MarkerLayoutManager: NSLayoutManager {
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
