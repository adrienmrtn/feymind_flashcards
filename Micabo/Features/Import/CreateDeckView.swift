import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Créer un **paquet de cartes**, sans document et sans fiche.
///
/// Deux départs : un fichier Anki, ou rien. Les deux mènent à l'écran des cartes,
/// où l'on ajoute, corrige et génère à volonté, carte par carte.
struct CreateDeckView: View {
    var onCreated: (Course) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subject = ""
    @AppStorage(CourseVisibility.importKey) private var visibility = CourseVisibility.standard
    @State private var isWorking = false
    @State private var isReading = false
    @State private var errorMessage: String?
    @State private var showFileImporter = false
    @State private var imported: AnkiImportedPackage?
    @State private var fileName: String?
    @State private var excluded = Set<String>()
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case title
        case subject
    }

    private var chosen: [AnkiImportedCard] {
        imported?.cards.filter { !excluded.contains($0.deck) } ?? []
    }

    private var canCreate: Bool {
        title.nilIfBlank != nil && (imported == nil || !chosen.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                        MicaboScreenHeader(
                            title: L10n.t("ios.deckOfCards", locale: .resolved()),
                            eyebrow: L10n.t("ios.withoutCourse", locale: .resolved()),
                            back: MicaboHeaderBack.close { dismiss() }
                        )
                        .padding(.top, MicaboSpacing.xs)

                        nameSection
                        ankiSection
                        visibilitySection
                    }
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.top, MicaboSpacing.xs)
                    .padding(.bottom, MicaboLayout.bottomBarClearance)
                }
                .scrollIndicators(.hidden)
                .micaboScreenBackground()
                .scrollDismissesKeyboard(.interactively)

                MicaboBottomBar {
                    Button {
                        Task { await create() }
                    } label: {
                        HStack(spacing: MicaboSpacing.xs) {
                            Image(systemName: imported == nil ? "plus" : "square.and.arrow.down")
                                .font(.system(size: 13, weight: .semibold))
                            Text(
                                imported == nil
                                    ? L10n.t("app.deck.createEmpty", locale: .resolved())
                                    : L10n.t("app.deck.importCards", locale: .resolved())
                            )
                        }
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle(tint: canCreate ? MicaboColor.accent : MicaboColor.strokeStrong))
                    .disabled(!canCreate || isWorking || isReading)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: UTType.ankiImports,
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .overlay {
                if isWorking || isReading {
                    GenerationOverlay(
                        title: isReading
                            ? L10n.t("app.deck.reading", locale: .resolved())
                            : L10n.t("app.deck.pouring", locale: .resolved()),
                        steps: [
                            L10n.t("app.deck.reading", locale: .resolved()),
                            L10n.t("app.deck.pouring", locale: .resolved()),
                        ]
                    )
                }
            }
            .alert(L10n.t("app.common.oops", locale: .resolved()), isPresented: .constant(errorMessage != nil)) {
                Button(L10n.t("app.a11y.close", locale: .resolved()), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(isWorking || isReading)
        .onAppear { focus = .title }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: L10n.t("ios.deckName", locale: .resolved()))

            VStack(spacing: 0) {
                field(
                    emoji: "🃏",
                    background: MicaboColor.tilePastels[1],
                    placeholder: L10n.t("ios.deckNameHint", locale: .resolved()),
                    text: $title,
                    field: .title
                )

                MicaboHairline(inset: 71)

                field(
                    emoji: "🏷️",
                    background: MicaboColor.tilePastels[4],
                    placeholder: L10n.t("ios.subjectOptional", locale: .resolved()),
                    text: $subject,
                    field: .subject
                )
            }
            .micaboGroup()
        }
    }

    @ViewBuilder
    private var ankiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: L10n.t("app.deck.ankiDrop", locale: .resolved()))

            if let imported {
                preview(imported)
            } else {
                Button {
                    showFileImporter = true
                } label: {
                    VStack(spacing: 10) {
                        Text("🃏")
                            .font(.system(size: 28))
                        Text(L10n.t("app.deck.chooseAnki", locale: .resolved()))
                            .font(MicaboFont.rowTitle)
                            .foregroundStyle(MicaboColor.ink)
                        Text(L10n.t("app.deck.ankiHint", locale: .resolved()))
                            .font(MicaboFont.rowSubtitle)
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, MicaboSpacing.md)
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: true))
                .micaboGroup()
            }
        }
    }

    private func preview(_ parsed: AnkiImportedPackage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileName ?? L10n.t("app.deck.ankiFile", locale: .resolved()))
                        .font(MicaboFont.rowTitle)
                        .foregroundStyle(MicaboColor.ink)
                    Text(
                        L10n.t(
                            "app.deck.cardsFound",
                            locale: .resolved(),
                            vars: ["count": "\(parsed.cards.count)"]
                        )
                    )
                    .font(MicaboFont.rowSubtitle)
                    .foregroundStyle(MicaboColor.inkTertiary)
                }
                Spacer(minLength: 0)
                Button(L10n.t("app.common.change", locale: .resolved())) {
                    imported = nil
                    fileName = nil
                    excluded = []
                }
                .buttonStyle(MicaboQuietButtonStyle())
            }

            if parsed.decks.count > 1 {
                FlowDeckChips(decks: parsed.decks, excluded: $excluded)
            }
        }
        .padding(MicaboSpacing.md)
        .micaboGroup()
    }

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MicaboSectionCaption(text: L10n.t("ios.whoCanFindDeck", locale: .resolved()))

            HStack(spacing: MicaboSpacing.xs) {
                ForEach(CourseVisibility.choosable) { value in
                    MicaboSelectChip(title: value.title, isSelected: value == visibility.asChoice) {
                        withAnimation(.easeOut(duration: 0.2)) { visibility = value }
                    }
                }
            }
        }
    }

    private func field(
        emoji: String,
        background: Color,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        HStack(spacing: 13) {
            MicaboTile(glyph: .emoji(emoji), background: background)

            TextField(placeholder, text: text)
                .font(MicaboFont.rowTitle)
                .foregroundStyle(MicaboColor.ink)
                .tint(MicaboColor.accent)
                .submitLabel(.done)
                .focused($focus, equals: field)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, MicaboSpacing.md)
    }

    // MARK: - Fichier

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            errorMessage = L10n.t("app.deck.errors.unreadable", locale: .resolved())
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await readFile(url) }
        }
    }

    @MainActor
    private func readFile(_ url: URL) async {
        isReading = true
        errorMessage = nil
        defer { isReading = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let parsed = try AnkiPackageReader.read(data: data, fileName: url.lastPathComponent)
            imported = parsed
            fileName = url.lastPathComponent
            excluded = []
            if title.nilIfBlank == nil, !parsed.title.isEmpty {
                title = parsed.title
            }
        } catch let error as AnkiImportError {
            imported = nil
            fileName = nil
            errorMessage = ankiMessage(error)
        } catch {
            imported = nil
            fileName = nil
            errorMessage = L10n.t("app.deck.errors.unreadable", locale: .resolved())
        }
    }

    private func ankiMessage(_ error: AnkiImportError) -> String {
        switch error {
        case .notPackage: L10n.t("app.deck.errors.notPackage", locale: .resolved())
        case .noCollection: L10n.t("app.deck.errors.noCollection", locale: .resolved())
        case .empty: L10n.t("app.deck.errors.empty", locale: .resolved())
        case .noZstd: L10n.t("app.deck.errors.noZstd", locale: .resolved())
        case .unreadableCollection: L10n.t("app.deck.errors.unreadable", locale: .resolved())
        }
    }

    // MARK: - Création

    @MainActor
    private func create() async {
        guard !isWorking, let name = title.nilIfBlank else { return }
        if imported != nil, chosen.isEmpty { return }
        isWorking = true
        defer { isWorking = false }

        let course: Course
        do {
            course = try CourseRepository.makeDeck(
                title: name,
                subject: subject.nilIfBlank,
                visibility: visibility.asChoice,
                in: modelContext
            )
        } catch {
            errorMessage = L10n.t("app.common.errorGeneric", locale: .resolved())
            return
        }

        if !chosen.isEmpty {
            do {
                _ = try CourseRepository.addFlashcards(
                    chosen.map {
                        GeneratedFlashcard(front: $0.front, back: $0.back, hint: $0.hint, kind: $0.kind)
                    },
                    to: course,
                    in: modelContext
                )
            } catch {
                onCreated(course)
                return
            }
        }

        onCreated(course)
    }
}

private struct FlowDeckChips: View {
    let decks: [AnkiDeckSummary]
    @Binding var excluded: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("app.deck.whichDecks", locale: .resolved()))
                .font(MicaboFont.eyebrow)
                .foregroundStyle(MicaboColor.inkTertiary)

            FlexibleChips(decks: decks, excluded: $excluded)
        }
    }
}

/// Puces de paquets Anki, en ligne, à cocher.
private struct FlexibleChips: View {
    let decks: [AnkiDeckSummary]
    @Binding var excluded: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(decks, id: \.name) { deck in
                let on = !excluded.contains(deck.name)
                Button {
                    if excluded.contains(deck.name) {
                        excluded.remove(deck.name)
                    } else {
                        excluded.insert(deck.name)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(deck.name.isEmpty ? L10n.t("app.deck.unnamedDeck", locale: .resolved()) : deck.name)
                        Text("\(deck.cards)")
                            .opacity(0.7)
                    }
                    .font(MicaboFont.hanken(13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(on ? MicaboColor.onInk : MicaboColor.inkTertiary)
                    .background(on ? MicaboColor.accent : MicaboColor.surfaceMuted, in: Capsule())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false))
            }
        }
    }
}

private extension UTType {
    static var ankiImports: [UTType] {
        let extras = ["apkg", "colpkg", "anki2", "anki21", "anki21b", "txt", "csv", "tsv"]
            .compactMap { UTType(filenameExtension: $0) }
        return extras + [.plainText, .commaSeparatedText, .data]
    }
}
