import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// **Reprendre ses flashcards** (`docs/supports.md`) : un paquet Anki (`.apkg`), un export
/// texte ou tableur, ou un copier-coller Quizlet. Les cartes sont lues sur l'appareil, l'élève
/// voit ce qui a été lu et nomme son deck, et le deck naît tout de suite, en leçon complète
/// (notes, quiz, flashcards), sans passer par la génération (`DeckLessonBuilder`).
struct FlashcardImportSheet: View {
    enum Step: Equatable {
        case choose
        case paste
        case preview(title: String, cards: [DeckLessonBuilder.Card], skipped: Int)
    }

    let onCreated: (Course) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step
    @State private var pasted: String
    @State private var title = ""
    @State private var showsFiles = false
    @State private var reading = false
    @State private var failure: String?
    @FocusState private var editing: Bool

    init(step: Step = .choose, pasted: String = "", onCreated: @escaping (Course) -> Void) {
        _step = State(initialValue: step)
        _pasted = State(initialValue: pasted)
        if case .preview(let title, _, _) = step {
            _title = State(initialValue: title)
        }
        self.onCreated = onCreated
    }

    static var fileTypes: [UTType] {
        [
            UTType(filenameExtension: "apkg"),
            UTType(filenameExtension: "colpkg"),
            .commaSeparatedText,
            .tabSeparatedText,
            .plainText,
            .zip,
        ].compactMap { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            Group {
                switch step {
                case .choose: choose
                case .paste: paste
                case .preview(_, let cards, let skipped): preview(cards: cards, skipped: skipped)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .fileImporter(isPresented: $showsFiles, allowedContentTypes: Self.fileTypes, allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            readFile(url)
        }
        .animation(LearnMotion.standard, value: step)
    }

    private var topBar: some View {
        HStack {
            if step != .choose {
                Button {
                    failure = nil
                    step = step == .paste ? .choose : (pasted.isEmpty ? .choose : .paste)
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .frame(width: 40, height: 40)
                        .flipsForRightToLeftLayoutDirection(true)
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(L10n.t("ios.sup.cards.back", locale: .resolved())))
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    // MARK: Choisir

    private var choose: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                SourceIcon(kind: .flashcards, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("ios.sup.cards.title", locale: .resolved()))
                        .font(MicaboFont.ui(24, weight: .black))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t("ios.sup.cards.sub", locale: .resolved()))
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            option(
                symbol: "square.and.arrow.down.fill",
                tone: .blue,
                title: L10n.t("ios.sup.cards.file", locale: .resolved()),
                detail: L10n.t("ios.sup.cards.fileSub", locale: .resolved())
            ) {
                failure = nil
                showsFiles = true
            }
            option(
                symbol: "doc.on.clipboard.fill",
                tone: .mint,
                title: L10n.t("ios.sup.cards.paste", locale: .resolved()),
                detail: L10n.t("ios.sup.cards.pasteSub", locale: .resolved())
            ) {
                failure = nil
                step = .paste
            }
            if reading {
                HStack(spacing: 10) {
                    ProgressView().tint(MicaboColor.accent)
                    Text(L10n.t("ios.sup.cards.reading", locale: .resolved()))
                        .font(MicaboFont.ui(15, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
            }
            failureLine
            freeNote
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 6)
        // Les boutons du bas collaient à la barre d'accueil (au bord, sur un iPhone SE).
        .padding(.bottom, 12)
    }

    private func option(symbol: String, tone: LessonTone, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(tone.ink)
                    .frame(width: 48, height: 48)
                    .background(tone.pale, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MicaboFont.ui(17, weight: .black))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: MicaboSurface.border))
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .disabled(reading)
    }

    /// Ce qui rassure : rien ne part, rien ne se paie.
    private var freeNote: some View {
        Label {
            Text(L10n.t("ios.sup.cards.free", locale: .resolved()))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "checkmark.seal.fill")
        }
        .font(MicaboFont.ui(13, weight: .semibold))
        .foregroundStyle(MicaboColor.correctInk)
    }

    @ViewBuilder
    private var failureLine: some View {
        if let failure {
            Text(failure)
                .font(MicaboFont.ui(14, weight: .bold))
                .foregroundStyle(MicaboColor.wrongInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Coller

    private var paste: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("ios.sup.cards.pasteTitle", locale: .resolved()))
                .font(MicaboFont.ui(22, weight: .black))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("ios.sup.cards.pasteHelp", locale: .resolved()))
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $pasted)
                .font(MicaboFont.ui(16))
                .scrollContentBackground(.hidden)
                .focused($editing)
                .frame(minHeight: 180)
                .padding(12)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
                .overlay(alignment: .topLeading) {
                    if pasted.isEmpty {
                        Text(L10n.t("ios.sup.cards.pastePlaceholder", locale: .resolved()))
                            .font(MicaboFont.ui(16))
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
            failureLine
            HStack(spacing: 10) {
                Button(L10n.t("lesson.import.paste", locale: .resolved())) {
                    if let text = UIPasteboard.general.string { pasted = text }
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
                Button(L10n.t("ios.sup.cards.read", locale: .resolved())) { readPasted() }
                    .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent, enabled: pasted.nilIfBlank != nil))
                    .disabled(pasted.nilIfBlank == nil)
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 6)
        // Les boutons du bas collaient à la barre d'accueil (au bord, sur un iPhone SE).
        .padding(.bottom, 12)
    }

    // MARK: Ce qui a été lu

    private func preview(cards: [DeckLessonBuilder.Card], skipped: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: String(cards.count))
                    .font(MicaboFont.number(40))
                    .foregroundStyle(MicaboColor.accentInk)
                Text(L10n.t("ios.sup.cards.found", locale: .resolved(), vars: ["count": String(cards.count)]))
                    .font(MicaboFont.ui(18, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("ios.sup.cards.name", locale: .resolved()))
                    .font(MicaboFont.ui(13, weight: .heavy))
                    .foregroundStyle(MicaboColor.inkSecondary)
                TextField(L10n.t("ios.sup.cards.namePlaceholder", locale: .resolved()), text: $title)
                    .font(MicaboFont.ui(17, weight: .bold))
                    .padding(14)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
            }
            VStack(spacing: 0) {
                ForEach(Array(cards.prefix(4).enumerated()), id: \.offset) { index, card in
                    if index > 0 { Rectangle().fill(MicaboColor.hairline).frame(height: 1) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.front)
                            .font(MicaboFont.ui(16, weight: .heavy))
                            .foregroundStyle(MicaboColor.ink)
                            .lineLimit(2)
                        Text(card.back)
                            .font(MicaboFont.ui(14, weight: .medium))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                }
                if cards.count > 4 {
                    Text(L10n.t("ios.sup.cards.more", locale: .resolved(), vars: ["count": String(cards.count - 4)]))
                        .font(MicaboFont.ui(13, weight: .bold))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: MicaboSurface.border))

            if skipped > 0 {
                Text(L10n.t("ios.sup.cards.skipped", locale: .resolved(), vars: ["count": String(skipped)]))
                    .font(MicaboFont.ui(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label {
                Text(L10n.t("ios.sup.cards.becomes", locale: .resolved()))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "sparkles")
            }
            .font(MicaboFont.ui(14, weight: .semibold))
            .foregroundStyle(MicaboColor.inkSecondary)
            failureLine
            Button {
                create(cards)
            } label: {
                Text(L10n.t("ios.sup.cards.create", locale: .resolved()))
            }
            .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 6)
        // Les boutons du bas collaient à la barre d'accueil (au bord, sur un iPhone SE).
        .padding(.bottom, 12)
    }

    // MARK: Lire et créer

    private func readPasted() {
        editing = false
        let result = FlashcardPaste.parse(pasted)
        guard !result.cards.isEmpty else {
            Haptics.warning()
            failure = L10n.t("ios.sup.cards.noneFound", locale: .resolved())
            return
        }
        failure = nil
        title = L10n.t("ios.sup.cards.defaultName", locale: .resolved())
        step = .preview(
            title: title,
            cards: result.cards.map { DeckLessonBuilder.Card(front: $0.front, back: $0.back) },
            skipped: result.skipped
        )
    }

    private func readFile(_ url: URL) {
        let name = url.lastPathComponent
        let scoped = url.startAccessingSecurityScopedResource()
        let data = try? Data(contentsOf: url)
        if scoped { url.stopAccessingSecurityScopedResource() }
        guard let data else {
            failure = L10n.t("ios.sup.cards.unreadable", locale: .resolved())
            return
        }
        reading = true
        failure = nil
        Task {
            let package = await Task.detached(priority: .userInitiated) {
                try? AnkiPackageReader.read(data: data, fileName: name)
            }.value
            reading = false
            guard let package, !package.cards.isEmpty else {
                Haptics.warning()
                failure = L10n.t("ios.sup.cards.unreadable", locale: .resolved())
                return
            }
            let cards = package.cards.map { card in
                DeckLessonBuilder.Card(front: card.front, back: [card.back, card.hint].compactMap { $0?.nilIfBlank }.joined(separator: "\n"))
            }
            title = package.title.nilIfBlank ?? L10n.t("ios.sup.cards.defaultName", locale: .resolved())
            step = .preview(title: title, cards: cards, skipped: package.skipped)
        }
    }

    private func create(_ cards: [DeckLessonBuilder.Card]) {
        let name = title.nilIfBlank ?? L10n.t("ios.sup.cards.defaultName", locale: .resolved())
        do {
            let course = try DeckLessonBuilder.make(title: name, cards: cards, in: modelContext)
            Haptics.success()
            onCreated(course)
        } catch {
            Haptics.warning()
            failure = L10n.t("ios.sup.cards.failed", locale: .resolved())
        }
    }
}
