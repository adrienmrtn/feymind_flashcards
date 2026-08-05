import SwiftUI
import UIKit

/// Texte de cours sélectionnable : « Demander à l'IA » et surlignages colorés.
struct SelectableTextView: UIViewRepresentable {
    let attributed: NSAttributedString
    var onAsk: (String) -> Void
    var onHighlight: ((NSRange, HighlightColor) -> Void)?
    var onClearHighlights: ((NSRange) -> Void)?
    var hasOverlappingHighlight: ((NSRange) -> Bool)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onAsk: onAsk,
            onHighlight: onHighlight,
            onClearHighlights: onClearHighlights,
            hasOverlappingHighlight: hasOverlappingHighlight
        )
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.dataDetectorTypes = []
        textView.tintColor = UIColor(FeyColor.accent)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.attributedText = attributed
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.onAsk = onAsk
        context.coordinator.onHighlight = onHighlight
        context.coordinator.onClearHighlights = onClearHighlights
        context.coordinator.hasOverlappingHighlight = hasOverlappingHighlight
        if uiView.attributedText != attributed {
            uiView.attributedText = attributed
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width - 2 * FeySpacing.screen
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitting.height))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onAsk: (String) -> Void
        var onHighlight: ((NSRange, HighlightColor) -> Void)?
        var onClearHighlights: ((NSRange) -> Void)?
        var hasOverlappingHighlight: ((NSRange) -> Bool)?

        init(
            onAsk: @escaping (String) -> Void,
            onHighlight: ((NSRange, HighlightColor) -> Void)?,
            onClearHighlights: ((NSRange) -> Void)?,
            hasOverlappingHighlight: ((NSRange) -> Bool)?
        ) {
            self.onAsk = onAsk
            self.onHighlight = onHighlight
            self.onClearHighlights = onClearHighlights
            self.hasOverlappingHighlight = hasOverlappingHighlight
        }

        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            guard range.length > 0 else { return UIMenu(children: suggestedActions) }

            let selected = (textView.text as NSString).substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selected.isEmpty else { return UIMenu(children: suggestedActions) }

            var custom: [UIMenuElement] = []

            let ask = UIAction(
                title: "Demander à l'IA",
                image: UIImage(systemName: "sparkles")
            ) { [weak textView] _ in
                textView?.selectedTextRange = nil
                self.onAsk(selected)
            }
            custom.append(ask)

            if onHighlight != nil {
                let colorActions = HighlightColor.allCases.map { color in
                    UIAction(
                        title: color.label,
                        image: UIImage(systemName: color.systemImage)
                    ) { [weak textView] _ in
                        textView?.selectedTextRange = nil
                        self.onHighlight?(range, color)
                    }
                }
                custom.append(UIMenu(
                    title: "Surligner",
                    image: UIImage(systemName: "highlighter"),
                    children: colorActions
                ))
            }

            if hasOverlappingHighlight?(range) == true, onClearHighlights != nil {
                custom.append(UIAction(
                    title: "Effacer le surlignage",
                    image: UIImage(systemName: "eraser"),
                    attributes: .destructive
                ) { [weak textView] _ in
                    textView?.selectedTextRange = nil
                    self.onClearHighlights?(range)
                })
            }

            return UIMenu(children: custom + suggestedActions)
        }
    }
}

/// Enveloppe pratique : applique le balisage, les surlignages, puis rend le texte sélectionnable.
struct CourseText: View {
    let source: String
    var options: InlineMarkup.RenderOptions = .courseBody
    var overlays: [InlineMarkup.OverlayHighlight] = []
    var onAsk: (String) -> Void
    var onHighlight: ((NSRange, HighlightColor) -> Void)? = nil
    var onClearHighlights: ((NSRange) -> Void)? = nil

    var body: some View {
        SelectableTextView(
            attributed: InlineMarkup.attributed(source, options: options, overlays: overlays),
            onAsk: onAsk,
            onHighlight: onHighlight,
            onClearHighlights: onClearHighlights,
            hasOverlappingHighlight: { range in
                overlays.contains {
                    NSIntersectionRange(NSRange(location: $0.start, length: $0.length), range).length > 0
                }
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
