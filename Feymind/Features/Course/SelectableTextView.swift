import SwiftUI
import UIKit

/// Texte de cours sélectionnable qui ajoute l'action « Demander à l'IA » au menu d'édition.
struct SelectableTextView: UIViewRepresentable {
    let attributed: NSAttributedString
    var onAsk: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAsk: onAsk)
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

        init(onAsk: @escaping (String) -> Void) {
            self.onAsk = onAsk
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

            let ask = UIAction(
                title: "Demander à l'IA",
                image: UIImage(systemName: "sparkles")
            ) { [weak textView] _ in
                textView?.selectedTextRange = nil
                self.onAsk(selected)
            }

            return UIMenu(children: [ask] + suggestedActions)
        }
    }
}

/// Enveloppe pratique : applique le balisage puis rend le texte sélectionnable.
struct CourseText: View {
    let source: String
    var options: InlineMarkup.RenderOptions = .courseBody
    var onAsk: (String) -> Void

    var body: some View {
        SelectableTextView(
            attributed: InlineMarkup.attributed(source, options: options),
            onAsk: onAsk
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
