import Combine
import SwiftUI
import UIKit

/// **La fiche, modifiable là où elle se lit.**
///
/// C'est l'équivalent de `SheetDocument.tsx` sur le site : un document, comme un traitement
/// de texte. Pas de bouton Modifier - on touche le texte, le clavier monte, on écrit - et
/// l'enregistrement se fait tout seul, un instant après la dernière frappe. La barre d'outils
/// se pose au-dessus du clavier : le style du bloc, gras, italique, barré, les cinq
/// surligneurs, la taille du passage, la formule, et « Expliquer », qui prend la même
/// sélection que le gras au lieu de se disputer l'écran avec lui.
///
/// Un seul `UITextView` porte toute la partie lisible de la fiche. Les blocs derrière le mur
/// d'abonnement ne sont pas dedans : ils sont recollés derrière ce qui a été écrit, comme sur
/// le site.
struct SheetEditorView: UIViewRepresentable {
    let blocks: [SheetBlock]
    /// Change quand la fiche a été réécrite ailleurs (synchro, nouvelle fiche) : le document
    /// se recharge, sauf si on est en train d'y écrire.
    let revision: Date
    let tint: Color
    @ObservedObject var state: SheetEditorState
    var onSave: ([SheetBlock]) -> Void
    var onExplain: (String) -> Void
    var onFormula: (SheetFormulaTarget) -> Void
    /// Lue pour que le document se recompose quand la taille de lecture change.
    @AppStorage(SheetPreferences.readingSizeKey) private var readingSize = SheetReadingSize.normal.rawValue

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = SheetEditorTextViewFactory.makeView()
        view.tintColor = UIColor(MicaboColor.accent)
        view.delegate = context.coordinator
        context.coordinator.attach(view)
        context.coordinator.load(blocks, revision: revision, readingSize: readingSize)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSave = onSave
        coordinator.onExplain = onExplain
        coordinator.onFormula = onFormula
        (view.layoutManager as? SheetEditorLayoutManager)?.markerColor = UIColor(tint)
        coordinator.load(blocks, revision: revision, readingSize: readingSize)
    }

    static func dismantleUIView(_ view: UITextView, coordinator: Coordinator) {
        coordinator.flush()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width: CGFloat
        if let proposed = proposal.width, proposed.isFinite {
            width = max(CGFloat(1), proposed)
        } else {
            width = 390 - MicaboSpacing.screen * 2
        }
        return SheetEditorTextViewFactory.measuredSize(of: uiView, width: width)
    }

    // MARK: - Le coordinateur

    final class Coordinator: NSObject, UITextViewDelegate {
        let state: SheetEditorState
        var onSave: (([SheetBlock]) -> Void)?
        var onExplain: ((String) -> Void)?
        var onFormula: ((SheetFormulaTarget) -> Void)?

        private weak var textView: UITextView?
        private var loadedRevision: Date?
        private var loadedReadingSize: String?
        private var dirty = false
        private var saveTimer: Timer?
        private var accessory: UIHostingController<SheetToolbar>?
        private var lastSaved: [SheetBlock] = []

        init(state: SheetEditorState) {
            self.state = state
        }

        func attach(_ view: UITextView) {
            textView = view
            state.actions = self
            // La barre au-dessus du clavier : une vue SwiftUI hébergée, dont la hauteur est
            // fixée à la main, parce qu'un accessoire de clavier ne se mesure pas tout seul.
            let host = UIHostingController(rootView: SheetToolbar(state: state))
            host.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: SheetToolbar.height)
            host.view.backgroundColor = UIColor.clear
            host.view.autoresizingMask = [.flexibleWidth]
            accessory = host
            view.inputAccessoryView = host.view
        }

        /// Charge la fiche, une fois par révision. Une fiche qu'on est en train d'écrire ne se
        /// recharge pas sous les doigts : la synchro attendra la prochaine ouverture.
        func load(_ blocks: [SheetBlock], revision: Date, readingSize: String) {
            guard let textView else { return }
            let sameContent = loadedRevision == revision && loadedReadingSize == readingSize
            if sameContent { return }
            if dirty || textView.isFirstResponder { return }
            loadedRevision = revision
            loadedReadingSize = readingSize
            lastSaved = blocks
            textView.attributedText = SheetDocument.attributed(from: blocks)
            textView.typingAttributes = SheetDocument.baseAttributes(kind: .paragraph)
            textView.undoManager?.removeAllActions()
            refreshState()
        }

        // MARK: Enregistrement

        private func touched() {
            dirty = true
            state.isDirty = true
            saveTimer?.invalidate()
            saveTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
                self?.flush()
            }
        }

        /// Écrit la fiche si elle a changé. Appelé après la pause de frappe, quand le clavier
        /// se ferme, et quand l'écran disparaît.
        func flush() {
            saveTimer?.invalidate()
            saveTimer = nil
            guard dirty, let textView else { return }
            let next = SheetDocument.blocks(from: textView.attributedText)
            dirty = false
            state.isDirty = false
            guard next != lastSaved else { return }
            lastSaved = next
            onSave?(next)
        }

        // MARK: UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            touched()
            refreshState()
            scrollCaretIntoView()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            refreshState()
            if textView.isFirstResponder { scrollCaretIntoView() }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            state.isEditing = true
            refreshState()
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            state.isEditing = false
            flush()
        }

        /// Le retour à la ligne, à la main : un titre s'ouvre sur du corps, une liste continue,
        /// et une entrée de liste vide qu'on valide quitte la liste. C'est le comportement de
        /// tous les traitements de texte, et UIKit ne le connaît pas.
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else { return true }
            let storage = textView.textStorage
            let string = storage.string as NSString
            let paragraph = string.paragraphRange(for: NSRange(location: min(range.location, string.length), length: 0))
            let kind = SheetDocument.kind(at: paragraph, in: storage)
            let content = SheetDocument.contentRange(of: paragraph, in: string)

            if kind.isList, content.length == 0 {
                restyle(paragraph: paragraph, to: .paragraph)
                return false
            }

            let nextKind: SheetParagraphKind = kind == .formula ? .paragraph : kind.next
            let newline = NSAttributedString(string: "\n", attributes: SheetDocument.baseAttributes(kind: kind))
            storage.beginEditing()
            storage.replaceCharacters(in: range, with: newline)
            storage.endEditing()
            let caret = NSRange(location: range.location + 1, length: 0)
            textView.selectedRange = caret
            let opened = (storage.string as NSString).paragraphRange(for: caret)
            textView.typingAttributes = SheetDocument.baseAttributes(kind: nextKind)
            if nextKind != kind, opened.length > 0 {
                restyle(paragraph: opened, to: nextKind)
                textView.selectedRange = caret
            }
            textViewDidChange(textView)
            return false
        }

        /// « Expliquer » **devant** les actions du système, comme en lecture.
        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard let onExplain, range.length > 1 else { return UIMenu(children: suggestedActions) }
            let selection = (textView.attributedText.string as NSString).substring(with: range)
            guard SheetSelection.isExplainable(selection) else { return UIMenu(children: suggestedActions) }
            let explain = UIAction(title: L10n.t("ios.explanation", locale: .resolved()), image: UIImage(systemName: "sparkles")) { _ in
                Haptics.selection()
                onExplain(selection)
            }
            return UIMenu(children: [explain] + suggestedActions)
        }

        /// Toucher une formule la rouvre dans son éditeur : c'est la seule façon de la corriger,
        /// puisqu'on ne tape pas au milieu des symboles composés.
        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            guard case .textAttachment(let attachment) = textItem.content,
                  let formula = attachment as? SheetMathAttachment
            else { return defaultAction }
            let range = textItem.range
            return UIAction { [weak self] _ in
                self?.onFormula?(SheetFormulaTarget(
                    range: range,
                    draft: SheetFormulaDraft(latex: formula.latex, caption: formula.caption ?? "", isInline: !formula.isBlock),
                    isExisting: true
                ))
            }
        }

        func textView(_ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu) -> UITextItem.MenuConfiguration? {
            nil
        }

        // MARK: L'état pour la barre

        private func refreshState() {
            guard let textView else { return }
            let storage = textView.textStorage
            let selected = textView.selectedRange
            let paragraph = (storage.string as NSString).paragraphRange(for: NSRange(location: min(selected.location, storage.length), length: 0))
            state.kind = SheetDocument.kind(at: paragraph, in: storage)

            let attributes: [NSAttributedString.Key: Any]
            if selected.length > 0, selected.location < storage.length {
                attributes = storage.attributes(at: selected.location, effectiveRange: nil)
            } else {
                attributes = textView.typingAttributes
            }
            let traits = (attributes[.font] as? UIFont)?.fontDescriptor.symbolicTraits ?? []
            state.isBold = traits.contains(.traitBold)
            state.isItalic = traits.contains(.traitItalic)
            state.isStruck = (attributes[.strikethroughStyle] as? Int ?? 0) != 0
            state.highlight = (attributes[SheetDocument.highlightKey] as? String).flatMap(SheetHighlight.init(rawValue:))
            state.size = (attributes[SheetDocument.sizeKey] as? String).flatMap(SheetTextSize.init(rawValue:))
            state.canExplain = selected.length > 1
                && SheetSelection.isExplainable((storage.string as NSString).substring(with: selected))
            state.canUndo = textView.undoManager?.canUndo ?? false
            state.canRedo = textView.undoManager?.canRedo ?? false
        }

        /// Le curseur reste visible au-dessus du clavier. Le `UITextView` ne défile pas
        /// lui-même ; c'est la page qui défile, et il faut la lui demander.
        private func scrollCaretIntoView() {
            guard let textView, let position = textView.selectedTextRange?.end else { return }
            var scroll: UIView? = textView.superview
            while let candidate = scroll, !(candidate is UIScrollView) { scroll = candidate.superview }
            guard let scrollView = scroll as? UIScrollView else { return }
            let caret = textView.caretRect(for: position)
            guard caret.origin.y.isFinite else { return }
            let target = textView.convert(caret, to: scrollView).insetBy(dx: 0, dy: -72)
            DispatchQueue.main.async {
                scrollView.scrollRectToVisible(target, animated: true)
            }
        }

        // MARK: Les gestes de la barre

        /// Pose ou retire une marque sur la sélection, avec l'aller et le retour : si tout le
        /// passage la porte déjà, elle s'enlève.
        private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
            guard let textView else { return }
            let range = textView.selectedRange
            if range.length == 0 {
                var typing = textView.typingAttributes
                if let font = typing[.font] as? UIFont {
                    typing[.font] = font.withTrait(trait, enabled: !font.fontDescriptor.symbolicTraits.contains(trait))
                }
                textView.typingAttributes = typing
                refreshState()
                return
            }
            let storage = textView.textStorage
            var allMarked = true
            storage.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
                if let font = value as? UIFont, !font.fontDescriptor.symbolicTraits.contains(trait) { allMarked = false }
            }
            edit(range) { storage in
                storage.enumerateAttribute(.font, in: range, options: []) { value, runRange, _ in
                    guard let font = value as? UIFont else { return }
                    storage.addAttribute(.font, value: font.withTrait(trait, enabled: !allMarked), range: runRange)
                }
            }
        }

        func toggleBold() { toggleTrait(.traitBold) }
        func toggleItalic() { toggleTrait(.traitItalic) }

        func toggleStrike() {
            guard let textView else { return }
            let range = textView.selectedRange
            let storage = textView.textStorage
            if range.length == 0 {
                var typing = textView.typingAttributes
                let on = (typing[.strikethroughStyle] as? Int ?? 0) != 0
                if on {
                    typing[.strikethroughStyle] = nil
                    typing[.foregroundColor] = state.kind.color
                } else {
                    typing[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                    typing[.foregroundColor] = UIColor(MicaboColor.inkTertiary)
                }
                textView.typingAttributes = typing
                refreshState()
                return
            }
            var allStruck = true
            storage.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, _, _ in
                if (value as? Int ?? 0) == 0 { allStruck = false }
            }
            let kind = state.kind
            edit(range) { storage in
                if allStruck {
                    storage.removeAttribute(.strikethroughStyle, range: range)
                    storage.removeAttribute(.strikethroughColor, range: range)
                    storage.addAttribute(.foregroundColor, value: kind.color, range: range)
                } else {
                    storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                    storage.addAttribute(.strikethroughColor, value: UIColor(MicaboColor.inkTertiary), range: range)
                    storage.addAttribute(.foregroundColor, value: UIColor(MicaboColor.inkTertiary), range: range)
                }
            }
        }

        /// Le surligneur **remplace** la couleur au lieu de l'empiler, et repasser la couleur
        /// déjà posée la retire : c'est le geste d'un feutre.
        func highlight(_ color: SheetHighlight) {
            guard let textView else { return }
            let range = textView.selectedRange
            let storage = textView.textStorage
            if range.length == 0 {
                var typing = textView.typingAttributes
                if (typing[SheetDocument.highlightKey] as? String) == color.rawValue {
                    typing[SheetDocument.highlightKey] = nil
                    typing[.backgroundColor] = nil
                } else {
                    typing[SheetDocument.highlightKey] = color.rawValue
                    typing[.backgroundColor] = UIColor(MicaboColor.sheetHighlight(color))
                }
                textView.typingAttributes = typing
                refreshState()
                return
            }
            var allSame = true
            storage.enumerateAttribute(SheetDocument.highlightKey, in: range, options: []) { value, _, _ in
                if (value as? String) != color.rawValue { allSame = false }
            }
            edit(range) { storage in
                if allSame {
                    storage.removeAttribute(SheetDocument.highlightKey, range: range)
                    storage.removeAttribute(.backgroundColor, range: range)
                } else {
                    storage.addAttribute(SheetDocument.highlightKey, value: color.rawValue, range: range)
                    storage.addAttribute(.backgroundColor, value: UIColor(MicaboColor.sheetHighlight(color)), range: range)
                }
            }
        }

        /// La taille du passage. `nil` le rend à la taille de son bloc.
        func resize(_ size: SheetTextSize?) {
            guard let textView else { return }
            let range = textView.selectedRange
            let kind = state.kind
            if range.length == 0 {
                var typing = textView.typingAttributes
                let current = (typing[SheetDocument.sizeKey] as? String).flatMap(SheetTextSize.init(rawValue:))
                let next: SheetTextSize? = (size == nil || size == current) ? nil : size
                typing[SheetDocument.sizeKey] = next?.rawValue
                if let font = typing[.font] as? UIFont {
                    typing[.font] = SheetDocument.font(
                        kind: kind,
                        bold: font.fontDescriptor.symbolicTraits.contains(.traitBold),
                        italic: font.fontDescriptor.symbolicTraits.contains(.traitItalic),
                        size: next
                    )
                }
                textView.typingAttributes = typing
                refreshState()
                return
            }
            var allSame = true
            textView.textStorage.enumerateAttribute(SheetDocument.sizeKey, in: range, options: []) { value, _, _ in
                if (value as? String) != size?.rawValue { allSame = false }
            }
            let next: SheetTextSize? = (size == nil || allSame) ? nil : size
            edit(range) { storage in
                storage.enumerateAttributes(in: range, options: []) { attributes, runRange in
                    if attributes[.attachment] != nil { return }
                    if let next { storage.addAttribute(SheetDocument.sizeKey, value: next.rawValue, range: runRange) }
                    else { storage.removeAttribute(SheetDocument.sizeKey, range: runRange) }
                    guard let font = attributes[.font] as? UIFont else { return }
                    let traits = font.fontDescriptor.symbolicTraits
                    if attributes[SheetDocument.mathKey] != nil {
                        storage.addAttribute(.font, value: SheetDocument.mathFont(size: kind.fontSize * SheetPreferences.readingScale * (next?.scale ?? 1) + 1), range: runRange)
                    } else {
                        storage.addAttribute(
                            .font,
                            value: SheetDocument.font(kind: kind, bold: traits.contains(.traitBold), italic: traits.contains(.traitItalic), size: next),
                            range: runRange
                        )
                    }
                }
            }
        }

        /// Change la nature du paragraphe courant : c'est ce que fait le menu des styles.
        func setKind(_ kind: SheetParagraphKind) {
            guard let textView else { return }
            let string = textView.textStorage.string as NSString
            let selected = textView.selectedRange
            // Une sélection qui traverse plusieurs paragraphes les change tous.
            let span = string.paragraphRange(for: selected)
            var location = span.location
            repeat {
                let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
                if SheetDocument.kind(at: paragraph, in: textView.textStorage) != .formula {
                    restyle(paragraph: paragraph, to: kind)
                }
                location = NSMaxRange(paragraph)
            } while location < NSMaxRange(span) && location < string.length
            textView.typingAttributes = SheetDocument.baseAttributes(kind: kind)
            textViewDidChange(textView)
        }

        /// Réécrit un paragraphe dans une autre nature en gardant ses marques.
        private func restyle(paragraph: NSRange, to kind: SheetParagraphKind) {
            guard let textView else { return }
            let storage = textView.textStorage
            guard paragraph.location <= storage.length else { return }
            let selected = textView.selectedRange
            storage.beginEditing()
            if paragraph.length == 0 {
                storage.endEditing()
                textView.typingAttributes = SheetDocument.baseAttributes(kind: kind)
                return
            }
            storage.addAttribute(SheetDocument.kindKey, value: kind.rawValue, range: paragraph)
            storage.addAttribute(.paragraphStyle, value: SheetDocument.paragraphStyle(kind: kind), range: paragraph)
            storage.enumerateAttributes(in: paragraph, options: []) { attributes, runRange in
                if attributes[.attachment] != nil { return }
                let struck = (attributes[.strikethroughStyle] as? Int ?? 0) != 0
                storage.addAttribute(.foregroundColor, value: struck ? UIColor(MicaboColor.inkTertiary) : kind.color, range: runRange)
                guard let font = attributes[.font] as? UIFont else { return }
                let size = (attributes[SheetDocument.sizeKey] as? String).flatMap(SheetTextSize.init(rawValue:))
                if attributes[SheetDocument.mathKey] != nil {
                    storage.addAttribute(.font, value: SheetDocument.mathFont(size: kind.fontSize * SheetPreferences.readingScale * (size?.scale ?? 1) + 1), range: runRange)
                } else {
                    let traits = font.fontDescriptor.symbolicTraits
                    storage.addAttribute(
                        .font,
                        value: SheetDocument.font(kind: kind, bold: traits.contains(.traitBold), italic: traits.contains(.traitItalic), size: size),
                        range: runRange
                    )
                }
            }
            storage.endEditing()
            textView.selectedRange = selected
        }

        /// Ouvre l'éditeur sur une nouvelle formule, là où est le curseur : dans la phrase s'il
        /// y en a une, posée seule sinon.
        func requestFormula() {
            guard let textView else { return }
            let selected = textView.selectedRange
            let string = textView.textStorage.string as NSString
            let paragraph = string.paragraphRange(for: NSRange(location: min(selected.location, string.length), length: 0))
            let inSentence = SheetDocument.contentRange(of: paragraph, in: string).length > 0
                && SheetDocument.kind(at: paragraph, in: textView.textStorage) != .formula
            onFormula?(SheetFormulaTarget(
                range: selected,
                draft: SheetFormulaDraft(latex: "", caption: "", isInline: inSentence),
                isExisting: false
            ))
        }

        /// Écrit la formule : celle qu'on corrige, ou celle qu'on pose.
        func apply(_ draft: SheetFormulaDraft, to target: SheetFormulaTarget) {
            guard let textView else { return }
            let storage = textView.textStorage
            let string = storage.string as NSString
            let range = NSRange(location: min(target.range.location, storage.length), length: min(target.range.length, max(0, storage.length - target.range.location)))

            if draft.isInline {
                let paragraph = string.paragraphRange(for: NSRange(location: range.location, length: 0))
                let kind = SheetDocument.kind(at: paragraph, in: storage)
                let piece = NSMutableAttributedString(attributedString: SheetDocument.inlineMath(draft.latex, kind: kind == .formula ? .paragraph : kind))
                piece.append(NSAttributedString(string: " ", attributes: SheetDocument.baseAttributes(kind: kind == .formula ? .paragraph : kind)))
                edit(range) { storage in storage.replaceCharacters(in: range, with: piece) }
                textView.selectedRange = NSRange(location: range.location + piece.length, length: 0)
            } else {
                let block = SheetDocument.formulaParagraph(latex: draft.latex, caption: draft.caption.nilIfBlank)
                if target.isExisting {
                    let paragraph = string.paragraphRange(for: range)
                    let content = SheetDocument.contentRange(of: paragraph, in: string)
                    edit(content) { storage in storage.replaceCharacters(in: content, with: block) }
                    textView.selectedRange = NSRange(location: content.location + block.length, length: 0)
                } else {
                    // Posée seule, après le paragraphe où était le curseur.
                    let paragraph = string.paragraphRange(for: NSRange(location: range.location, length: 0))
                    let content = SheetDocument.contentRange(of: paragraph, in: string)
                    let insertion = NSMutableAttributedString()
                    if content.length > 0 { insertion.append(NSAttributedString(string: "\n", attributes: SheetDocument.baseAttributes(kind: .formula))) }
                    insertion.append(block)
                    insertion.append(NSAttributedString(string: "\n", attributes: SheetDocument.baseAttributes(kind: .paragraph)))
                    let at = NSRange(location: NSMaxRange(content), length: 0)
                    edit(at) { storage in storage.replaceCharacters(in: at, with: insertion) }
                    textView.selectedRange = NSRange(location: at.location + insertion.length, length: 0)
                    textView.typingAttributes = SheetDocument.baseAttributes(kind: .paragraph)
                }
            }
            textViewDidChange(textView)
        }

        func removeFormula(_ target: SheetFormulaTarget) {
            guard let textView, target.isExisting else { return }
            let storage = textView.textStorage
            let string = storage.string as NSString
            var range = NSRange(location: min(target.range.location, storage.length), length: min(target.range.length, max(0, storage.length - target.range.location)))
            let paragraph = string.paragraphRange(for: range)
            if SheetDocument.kind(at: paragraph, in: storage) == .formula {
                range = paragraph.location > 0 ? NSRange(location: paragraph.location - 1, length: paragraph.length + 1) : paragraph
                if NSMaxRange(range) > storage.length { range.length = storage.length - range.location }
            }
            edit(range) { storage in storage.replaceCharacters(in: range, with: "") }
            textView.selectedRange = NSRange(location: range.location, length: 0)
            textViewDidChange(textView)
        }

        func explainSelection() {
            guard let textView else { return }
            let range = textView.selectedRange
            guard range.length > 1 else { return }
            let selection = (textView.textStorage.string as NSString).substring(with: range)
            guard SheetSelection.isExplainable(selection) else { return }
            Haptics.selection()
            onExplain?(selection)
        }

        func undo() {
            textView?.undoManager?.undo()
            if let textView { textViewDidChange(textView) }
        }

        func redo() {
            textView?.undoManager?.redo()
            if let textView { textViewDidChange(textView) }
        }

        func dismissKeyboard() {
            textView?.resignFirstResponder()
        }

        /// Une modification d'attributs, **annulable** : UIKit n'enregistre que la frappe, et
        /// un gras qu'on ne peut pas défaire n'est pas un gras.
        private func edit(_ range: NSRange, _ change: (NSTextStorage) -> Void) {
            guard let textView else { return }
            let storage = textView.textStorage
            guard NSMaxRange(range) <= storage.length else { return }
            let before = storage.attributedSubstring(from: range)
            let lengthBefore = storage.length
            storage.beginEditing()
            change(storage)
            storage.endEditing()
            let after = NSRange(location: range.location, length: range.length + (storage.length - lengthBefore))
            registerUndo(replacing: after, with: before)
            textViewDidChange(textView)
        }

        /// L'aller et le retour : défaire remet l'ancien fragment, et enregistre de quoi le
        /// refaire.
        private func registerUndo(replacing range: NSRange, with previous: NSAttributedString) {
            textView?.undoManager?.registerUndo(withTarget: self) { coordinator in
                guard let view = coordinator.textView, NSMaxRange(range) <= view.textStorage.length else { return }
                let current = view.textStorage.attributedSubstring(from: range)
                view.textStorage.replaceCharacters(in: range, with: previous)
                coordinator.registerUndo(replacing: NSRange(location: range.location, length: previous.length), with: current)
                view.selectedRange = NSRange(location: range.location, length: previous.length)
                coordinator.textViewDidChange(view)
            }
        }
    }
}

// MARK: - L'état partagé avec la barre

/// Ce que la barre affiche : la nature du bloc courant, les marques du passage choisi, et ce
/// qu'on peut faire. Le coordinateur l'écrit, la barre le lit.
final class SheetEditorState: ObservableObject {
    @Published var kind: SheetParagraphKind = .paragraph
    @Published var isBold = false
    @Published var isItalic = false
    @Published var isStruck = false
    @Published var highlight: SheetHighlight?
    @Published var size: SheetTextSize?
    @Published var canExplain = false
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var isEditing = false
    @Published var isDirty = false

    /// Le coordinateur, pour que la barre lui parle. Faible : c'est lui qui tient l'état.
    weak var actions: SheetEditorView.Coordinator?
}

/// Une formule en cours d'écriture.
struct SheetFormulaDraft: Equatable {
    var latex: String
    var caption: String
    /// Dans le texte, ou posée seule.
    var isInline: Bool
}

/// La formule qu'on rouvre, ou l'endroit où l'on en pose une.
struct SheetFormulaTarget: Identifiable {
    let id = UUID()
    var range: NSRange
    var draft: SheetFormulaDraft
    var isExisting: Bool
}

private extension UIFont {
    func withTrait(_ trait: UIFontDescriptor.SymbolicTraits, enabled: Bool) -> UIFont {
        var traits = fontDescriptor.symbolicTraits
        if enabled { traits.insert(trait) } else { traits.remove(trait) }
        // Le gras d'une fiche est un demi-gras : la fonte système passe par le poids, pas par
        // le trait, donc on reconstruit depuis le poids voulu.
        if trait == .traitBold {
            let weight: UIFont.Weight = enabled ? .semibold : .regular
            let base = UIFont.systemFont(ofSize: pointSize, weight: weight)
            guard traits.contains(.traitItalic), let italic = base.fontDescriptor.withSymbolicTraits(.traitItalic) else { return base }
            return UIFont(descriptor: italic, size: pointSize)
        }
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
