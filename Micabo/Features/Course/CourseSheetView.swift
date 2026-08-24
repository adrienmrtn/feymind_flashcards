import SwiftData
import SwiftUI

/// **L'écran d'un cours : sa fiche.**
///
/// C'est ce qu'on obtient en important un document, et c'est ce qu'on relit. Les cartes,
/// elles, sont devenues une possibilité : elles vivent un écran plus loin, et se demandent.
///
/// Trois choix de composition portent cet écran :
///
/// - **le texte est posé sur le papier**, les objets sont dans des surfaces. Un paragraphe
///   n'est pas une carte, et une fiche entièrement encartée ne se lirait pas.
/// - **l'en-tête est celui de toute l'app**, `MicaboScreenHeader` : la couleur du cours
///   reste dans sa tuile et dans les filets de la fiche, pas dans un bandeau.
/// - **on sélectionne pour comprendre.** N'importe quel passage se prend au doigt et se
///   fait expliquer. C'est le geste central de l'écran, et il n'a donc pas de bouton :
///   c'est le menu du système qui le porte, là où l'utilisateur cherche déjà « Copier ».
struct CourseSheetView: View {
    @Bindable var course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(\.dismiss) private var dismiss

    /// La fiche décodée une fois, pas à chaque passage dans le corps de la vue.
    @State private var sheet: CourseSheet?
    @State private var explaining: ExplainedPassage?
    @State private var showCardOptions = false
    @State private var isWorking: Work?
    @State private var showStudy = false
    @State private var studyMode: StudyMode = .scheduled
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    /// L'invitation à sélectionner un passage disparaît une fois le geste découvert : une
    /// consigne qu'on a suivie n'a plus rien à dire.
    @AppStorage("micabo.sheet.didExplainOnce") private var didExplainOnce = false

    private enum Work: Equatable {
        case sheet
        case cards
    }

    private var cards: [Flashcard] { course.orderedCards }
    private var dueCount: Int { course.dueCards.count }
    private var tint: Color { Color(hexString: course.accentHex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                lead
                content
                cardsSection
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)
            .padding(.bottom, MicaboLayout.bottomBarClearance)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .enablesSwipeBack()
        .overlay(alignment: .bottom) { bottomBar }
        .overlay { workOverlay }
        .task { sheet = course.decodedSheet() }
        .onChange(of: course.sheetData) { _, _ in
            sheet = course.decodedSheet()
        }
        .sheet(item: $explaining) { passage in
            ExplainSelectionSheet(course: course, selection: passage.text)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(MicaboRadius.sheet)
        }
        .sheet(isPresented: $showCardOptions) {
            GenerateCardsSheet(course: course) { options in
                Task { await generateCards(options) }
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .course(course), mode: studyMode)
        }
        .alert("Oups", isPresented: .constant(errorMessage != nil)) {
            Button("Fermer", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Supprimer ce cours ?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                try? CourseRepository.delete(course, in: modelContext)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(deleteWarning)
        }
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            MicaboScreenHeader(
                title: course.title,
                eyebrow: headerEyebrow,
                tile: MicaboTile.course(course, size: 52),
                back: MicaboHeaderBack.back { dismiss() }
            ) {
                courseMenu
            }

            if dueCount > 0 {
                MicaboBadge(text: "\(dueCount) à réviser", tone: .accent)
            }
        }
        .padding(.top, MicaboSpacing.xs)
    }

    /// Matière et durée de lecture : c'est ce qu'on veut savoir avant d'ouvrir une fiche.
    /// Le volume de cartes n'y figure pas, il est annoncé par leur propre rangée.
    private var headerEyebrow: String {
        var parts: [String] = []
        if let subject = course.subject?.nilIfBlank { parts.append(subject) }
        if let sheet { parts.append("\(sheet.readingMinutes) min de lecture") }
        return parts.isEmpty ? MicaboCopy.cards(cards.count) : parts.joined(separator: " · ")
    }

    private var courseMenu: some View {
        Menu {
            Button { showCardOptions = true } label: {
                Label(cards.isEmpty ? MicaboCopy.cardsButton : "Générer de nouvelles cartes", systemImage: "sparkles")
            }
            Button { Task { await writeSheet() } } label: {
                Label(sheet == nil ? "Ficher ce cours" : "Refaire la fiche", systemImage: "text.book.closed")
            }
            .disabled(course.rawText.nilIfBlank == nil)
            Divider()
            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                Label("Supprimer le cours", systemImage: "trash")
            }
        } label: {
            MicaboCircleIcon(systemImage: "ellipsis", size: 38)
        }
        .accessibilityLabel("Actions du cours")
    }

    private var deleteWarning: String {
        cards.isEmpty
            ? "La fiche de ce cours sera définitivement effacée."
            : "La fiche et ses \(MicaboCopy.cards(cards.count)) seront définitivement effacées."
    }

    // MARK: - Chapeau

    /// Le résumé, composé plus grand que le corps du texte : c'est l'entrée en matière,
    /// pas un paragraphe de plus.
    @ViewBuilder
    private var lead: some View {
        if let summary = course.summary.nilIfBlank {
            SheetInlineText(markup: summary, style: .lead)
                .padding(.top, MicaboSpacing.md)
        }

        if sheet != nil, !didExplainOnce {
            selectionHint
        }
    }

    private var selectionHint: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.tap")
                .font(.system(size: 11, weight: .semibold))
            Text("Sélectionne un mot ou une phrase pour demander une explication.")
                .font(MicaboFont.micro)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(MicaboColor.inkTertiary)
        .padding(.top, MicaboSpacing.md)
    }

    // MARK: - La fiche

    @ViewBuilder
    private var content: some View {
        if let sheet {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sheet.blocks.enumerated()), id: \.offset) { index, block in
                    SheetBlockView(block: block, tint: tint, onExplain: explain)
                        .padding(.top, index == 0 ? MicaboSpacing.lg : SheetBlockView.spacing(before: block))
                }
            }
            .padding(.bottom, MicaboSpacing.xs)
        } else {
            missingSheet
        }
    }

    /// Un cours sans fiche : importé avant que la fiche n'existe, ou analysé pendant une
    /// panne. On ne montre pas un écran vide, on propose de l'écrire.
    private var missingSheet: some View {
        MicaboEmptyState(
            systemImage: "text.book.closed",
            title: "Ce cours n'est pas encore fiché",
            message: course.rawText.nilIfBlank == nil
                ? "Le texte d'origine n'a pas été conservé : réimporte le document pour en obtenir une fiche."
                : "Micabo a gardé le document. Il peut en écrire la fiche : le plan, les définitions et ce qu'il faut retenir.",
            actionTitle: course.rawText.nilIfBlank == nil ? nil : "Ficher ce cours"
        ) {
            Task { await writeSheet() }
        }
        .padding(.top, MicaboSpacing.md)
    }

    // MARK: - Les cartes

    /// Les cartes ne sont plus le sujet de l'écran, mais elles ne se cachent pas : une
    /// rangée en fin de fiche, comme tout ce qui se liste dans l'app.
    @ViewBuilder
    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Cartes")

            if cards.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Aucune carte pour ce cours. La fiche se lit très bien sans, mais ce sont les cartes qui font tenir le contenu dans le temps.")
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        showCardOptions = true
                    } label: {
                        HStack(spacing: MicaboSpacing.xs) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                            Text(MicaboCopy.cardsButton)
                        }
                    }
                    .buttonStyle(MicaboSecondaryButtonStyle())
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .micaboGroup(radius: MicaboRadius.lg)
            } else {
                NavigationLink(value: CourseCardsRoute(course: course)) {
                    MicaboRow(
                        tile: MicaboTile(
                            glyph: .symbol("rectangle.on.rectangle.angled"),
                            background: tint.lightened(by: 0.84),
                            tint: tint.darkened(by: 0.25)
                        ),
                        title: MicaboCopy.cards(cards.count),
                        subtitle: cardsSubtitle,
                        accessory: .chevron
                    )
                }
                .buttonStyle(MicaboRowButtonStyle())
                .micaboGroup()
            }
        }
        .padding(.top, MicaboSpacing.xl)
    }

    private var cardsSubtitle: String {
        if dueCount > 0 { return "\(dueCount) à réviser aujourd'hui" }
        let newCount = course.newCards.count
        return newCount > 0 ? "\(newCount) jamais vues" : "À jour"
    }

    // MARK: - Bas d'écran

    /// Un seul bouton ancré, et il dit ce qui manque : sans carte, l'action est d'en
    /// générer ; avec des cartes, c'est de réviser, sous le nom qu'il porte partout.
    @ViewBuilder
    private var bottomBar: some View {
        MicaboBottomBar {
            if cards.isEmpty {
                Button {
                    Haptics.medium()
                    showCardOptions = true
                } label: {
                    HStack(spacing: MicaboSpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                        Text(MicaboCopy.cardsButton)
                    }
                }
                .buttonStyle(MicaboPrimaryButtonStyle())
            } else {
                Button {
                    Haptics.medium()
                    studyMode = dueCount > 0 ? .scheduled : .practice
                    showStudy = true
                } label: {
                    Text(dueCount > 0 ? MicaboCopy.reviewButton(count: dueCount) : "Entraînement libre")
                }
                .buttonStyle(MicaboPrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var workOverlay: some View {
        switch isWorking {
        case .sheet:
            GenerationOverlay(title: "Écriture de la fiche", steps: SheetGenerationSteps.all())
        case .cards:
            GenerationOverlay(
                title: "Écriture des cartes",
                steps: ["Relecture de la fiche", "Choix des notions", "Rédaction", "Vérification des réponses"]
            )
        case nil:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func explain(_ selection: String) {
        guard SheetSelection.isExplainable(selection) else { return }
        didExplainOnce = true
        explaining = ExplainedPassage(text: selection)
    }

    @MainActor
    private func writeSheet() async {
        guard isWorking == nil, let rawText = course.rawText.nilIfBlank else { return }
        isWorking = .sheet
        defer { isWorking = nil }

        let request = CourseGenerationRequest(
            rawText: rawText,
            pageImages: [],
            hintTitle: course.title,
            sourceName: course.sourceFileName
        )

        do {
            let generated = try await aiService.generateCourse(request)
            try CourseRepository.updateSheet(of: course, with: generated, in: modelContext)
            Haptics.success()
        } catch {
            errorMessage = describe(error)
        }
    }

    @MainActor
    private func generateCards(_ options: CardGeneration.Options) async {
        guard isWorking == nil else { return }
        isWorking = .cards
        defer { isWorking = nil }

        do {
            try await CardGeneration.run(for: course, options: options, using: aiService, in: modelContext)
            Haptics.success()
        } catch {
            errorMessage = describe(error)
        }
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

/// Le passage sélectionné, porté jusqu'à la feuille d'explication.
private struct ExplainedPassage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

/// Les étapes annoncées pendant l'écriture d'une fiche. Elles sont au même endroit, que
/// l'import s'en serve ou que le cours refasse sa fiche : deux listes divergeraient.
enum SheetGenerationSteps {
    static func all(reading: String = "Lecture du document") -> [String] {
        [reading, "Repérage du plan", "Rédaction de la fiche", "Mise en page"]
    }
}
