import SwiftData
import SwiftUI

/// **Un chapitre ouvert : ce qu'on lit, ce qu'on corrige, ce qu'on révise.**
///
/// C'est l'unité de travail du deck. Le cours entier n'a plus d'écran à lui : il s'est
/// réparti entre ses chapitres, et chacun porte sa part de la fiche (`Chapter.sheetData`).
/// C'est ce qui permet de réviser la guerre froide sans traverser les huit autres parties —
/// le contrôle de jeudi ne porte que sur elle, et faire repasser le reste pour l'atteindre
/// est exactement ce qui fait renoncer.
///
/// **C'est une page de lecture, et sa mise en page le dit.** Le bandeau est plus court que
/// celui du deck — cent trente-quatre points contre cent quarante-huit — pour que le texte
/// commence plus haut. La marge passe à vingt-deux. Le bouton de droite n'ouvre pas un menu
/// mais la taille du texte, qui est la seule chose qu'on règle en lisant. Et quand le
/// bandeau se replie, sa barre porte **la progression de lecture** : c'est la seule
/// information qu'on cherche en levant les yeux au milieu d'une page.
///
/// **La page s'écrit directement**, sans bouton Modifier : `SheetEditorView` est le même
/// composant que celui de l'ancien écran de fiche, et le texte se corrige au doigt là où on
/// le lit. Ce qui est sauvé l'est sur le chapitre, jamais sur le cours — deux endroits qui
/// écriraient la même chose finiraient par ne plus dire la même chose.
///
/// **Le titre se corrige aussi**, et c'est la seule chose du plan qui bouge : on n'ajoute
/// pas un chapitre, on n'en retire pas, on n'en déplace pas. Le plan est celui du cours, il
/// n'appartient pas à qui le révise.
struct ChapterSheetView: View {
    @Bindable var chapter: Chapter

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var blocks: [SheetBlock] = []
    /// La queue cadenassée, pour qui n'est pas abonné. Voir `applyGate`.
    @State private var lockedTail: [SheetBlock] = []
    /// Le titre de partie retiré du texte parce que la page l'écrit déjà. Voir
    /// `takeRedundantTitle`.
    @State private var leadHeading: [SheetBlock] = []
    @State private var studying = false
    @State private var dueCount = 0
    @State private var showRename = false
    @State private var draftTitle = ""
    @State private var showTextSize = false
    @State private var explaining: ExplainedPassage?
    @State private var formulaTarget: SheetFormulaTarget?
    @State private var paywall: PaywallTrigger?

    @StateObject private var editorState = SheetEditorState()

    /// La marge d'une page de lecture : deux points de plus que partout ailleurs. Une ligne
    /// de seize points se lit mieux un peu plus courte.
    private static let margin: CGFloat = 22

    private var tint: Color {
        Color(hexString: chapter.course?.accentHex ?? "")
    }

    private var pastel: Color {
        MicaboColor.pastel(for: chapter.course?.id ?? chapter.id)
    }

    private var isPro: Bool { pro?.isPro ?? true }

    /// Le rang du chapitre dans le plan de son deck, à partir de 1.
    private var number: Int {
        (chapter.course?.orderedChapters.firstIndex { $0.id == chapter.id } ?? 0) + 1
    }

    /// Le temps de lecture du chapitre.
    ///
    /// `CourseSheet` sait déjà le calculer, sur deux cents mots la minute. En recompter un
    /// ici sur les caractères aurait donné deux durées différentes pour le même texte selon
    /// l'écran qui l'affiche.
    private var readingMinutes: Int {
        CourseSheet(blocks: blocks).readingMinutes
    }

    private var safeTop: CGFloat { MicaboScreen.safeTop }

    var body: some View {
        // **Le bandeau se replie en place** et, replié, porte la progression de lecture.
        // Le texte lui laisse sa hauteur dépliée puis remonte dessous, coupé par la barre,
        // comme sur `ChapitreScroll`. Voir `MicaboCollapsingScreen`.
        MicaboCollapsingScreen(expandedHeight: safeTop + MicaboHeaderBand.chapter) { scroll in
            MicaboCollapsingHeader(
                emoji: chapter.course?.emoji ?? "📘",
                pastel: pastel,
                title: chapter.title,
                band: MicaboHeaderBand.chapter,
                safeTop: safeTop,
                offset: scroll.offset,
                readingProgress: scroll.progress,
                onBack: { dismiss() },
                onTrailing: { showTextSize = true }
            ) {
                Text("Aa")
                    .font(MicaboFont.ui(15, weight: .bold))
            }
        } content: {
            reading
                .padding(.horizontal, Self.margin)
                .padding(.top, 20)
                .padding(.bottom, MicaboLayout.bottomBarClearance)
        }
        .micaboScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .enablesSwipeBack()
        .overlay(alignment: .bottom) { reviewBar }
        .onAppear(perform: reload)
        .onChange(of: isPro) { _, _ in applyGate() }
        .fullScreenCover(isPresented: $studying) {
            StudyView(source: .chapter(chapter), mode: .scheduled)
                .onDisappear(perform: reload)
        }
        .sheet(item: $explaining) { passage in
            if let course = chapter.course {
                ExplainSelectionSheet(course: course, selection: passage.text)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(MicaboRadius.sheet)
            }
        }
        .sheet(item: $formulaTarget) { target in
            FormulaEditorSheet(
                initial: target.draft,
                onDelete: target.isExisting ? { editorState.actions?.removeFormula(target) } : nil,
                onApply: { draft in editorState.actions?.apply(draft, to: target) }
            )
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .confirmationDialog(
            i18n.t("ios.sheet.textSize"),
            isPresented: $showTextSize,
            titleVisibility: .visible
        ) {
            ForEach(SheetReadingSize.allCases) { size in
                Button(size.title()) { SheetPreferences.readingSize = size }
            }
            Button(i18n.t("ios.deck.renameChapter")) {
                draftTitle = chapter.title
                showRename = true
            }
            Button(i18n.t("app.common.cancel"), role: .cancel) {}
        }
        .alert(i18n.t("ios.deck.renameChapter"), isPresented: $showRename) {
            TextField(chapter.title, text: $draftTitle)
            Button(i18n.t("app.common.save")) { applyRename() }
            Button(i18n.t("app.common.cancel"), role: .cancel) {}
        }
        .micaboPaywall($paywall)
    }

    // MARK: - La lecture

    private var reading: some View {
        VStack(alignment: .leading, spacing: 0) {
            MicaboFactLine(facts: facts)

            Text(chapter.title)
                .font(MicaboFont.ui(25, weight: .bold))
                .tracking(-0.5)
                .lineSpacing(2)
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)

            if blocks.isEmpty, lockedTail.isEmpty {
                Text(i18n.t("ios.deck.emptyChapter"))
                    .font(MicaboFont.ui(14, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .padding(.top, MicaboSpacing.md)
            } else {
                SheetEditorView(
                    blocks: blocks,
                    revision: chapter.updatedAt,
                    tint: tint,
                    state: editorState,
                    onSave: save,
                    onExplain: explain,
                    onFormula: { formulaTarget = $0 }
                )
                .padding(.top, 14)
            }

            if !lockedTail.isEmpty {
                LockedSheetTail(blocks: lockedTail, tint: tint) {
                    paywall = .lockedSheet
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Le rang, le nombre de cartes, le temps de lecture. Le rang porte le violet parce que
    /// c'est une position dans un plan, pas une quantité.
    private var facts: [MicaboFactLine.Fact] {
        var out: [MicaboFactLine.Fact] = [
            .init(text: i18n.t("ios.chapterShort", ["number": "\(number)"]), isLead: true)
        ]
        if chapter.cardCount > 0 {
            out.append(.init(text: MicaboCopy.cards(chapter.cardCount)))
        }
        if !blocks.isEmpty {
            out.append(.init(text: i18n.t("ios.chapter.readingTime", ["minutes": "\(readingMinutes)"])))
        }
        return out
    }

    // MARK: - Le bouton

    /// **Le bouton garde son nom.** « Réviser N cartes » est le même libellé que depuis
    /// l'onglet Réviser et depuis un deck : un bouton qui change de nom au milieu d'un
    /// parcours se lit comme une autre action.
    ///
    /// Il disparaît pendant qu'on écrit : une barre posée au-dessus du clavier, sur un écran
    /// où l'on corrige une phrase, n'est plus un bouton, c'est un obstacle.
    @ViewBuilder
    private var reviewBar: some View {
        if chapter.cardCount > 0, !editorState.isEditing {
            MicaboBottomBar(fade: 44) {
                Button {
                    studying = true
                } label: {
                    Text(
                        dueCount > 0
                            ? i18n.t("app.today.startCards", ["count": "\(dueCount)"])
                            : i18n.t("ios.deck.practiceChapter")
                    )
                }
                .buttonStyle(MicaboActionButtonStyle())
            }
            .padding(.horizontal, Self.margin - MicaboSpacing.screen)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Lire, écrire

    private func reload() {
        applyGate()
        let now = Date()
        dueCount = chapter.orderedCards.reduce(0) { $0 + ($1.isDue(at: now) ? 1 : 0) }
    }

    /// **Le cadenas suit le chapitre, pas la fiche entière.**
    ///
    /// La règle est la même qu'avant — une part lisible, le reste flouté — mais elle
    /// s'applique désormais par chapitre. C'est plus généreux qu'une coupure unique en milieu
    /// de cours, et c'est le bon compromis : un chapitre entièrement cadenassé laisserait
    /// croire que le deck n'a pas été écrit, alors qu'il l'a été.
    private func applyGate() {
        var all = chapter.decodedSheet()?.blocks ?? []
        leadHeading = Self.takeRedundantTitle(from: &all, title: chapter.title)
        let parts = SheetGate.split(all, isPro: isPro)
        blocks = parts.readable
        lockedTail = parts.locked
    }

    /// **Retire le titre que la page affiche déjà.**
    ///
    /// Un chapitre garde son titre de partie dans ses blocs — c'est ce qui permet à
    /// `SheetChapters.join` de reconstituer la fiche du deck au bloc près. Mais la page
    /// écrit ce même titre en tête, en vingt-cinq points : le laisser dans le texte le fait
    /// lire deux fois de suite, une fois en noir et une fois en violet.
    ///
    /// Il est mis de côté plutôt que supprimé, et recollé à l'enregistrement. Le sortir pour
    /// de bon aurait effacé un bloc de la fiche à la première correction de frappe, et le
    /// découpage du deck n'aurait plus retrouvé ses parties.
    private static func takeRedundantTitle(from blocks: inout [SheetBlock], title: String) -> [SheetBlock] {
        guard case .heading(_, let text)? = blocks.first else { return [] }
        let heading = SheetMarkup.plain(text).trimmingCharacters(in: .whitespacesAndNewlines)
        let chapter = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heading.isEmpty, heading.caseInsensitiveCompare(chapter) == .orderedSame else { return [] }
        return [blocks.removeFirst()]
    }

    /// Enregistre le texte corrigé **sur le chapitre**.
    ///
    /// La queue cadenassée est recollée telle quelle : elle n'a pas été montrée, donc elle
    /// n'a pas pu être modifiée, et l'oublier ferait disparaître la moitié d'un chapitre au
    /// premier mot corrigé par quelqu'un qui n'est pas abonné.
    private func save(_ edited: [SheetBlock]) {
        chapter.apply(CourseSheet(blocks: leadHeading + edited + lockedTail))
        chapter.updatedAt = Date()
        chapter.course?.updatedAt = Date()
        try? modelContext.save()
    }

    private func applyRename() {
        guard let clean = draftTitle.nilIfBlank else { return }
        chapter.title = clean
        chapter.updatedAt = Date()
        chapter.course?.updatedAt = Date()
        try? modelContext.save()
    }

    private func explain(_ text: String) {
        guard let clean = text.nilIfBlank else { return }
        explaining = ExplainedPassage(text: clean)
    }
}

/// Un passage sélectionné dans une fiche, en attente d'explication.
///
/// L'identité est tirée du texte : sélectionner deux fois le même passage rouvre la même
/// feuille plutôt que d'en empiler une seconde.
struct ExplainedPassage: Identifiable {
    let text: String

    var id: String { text }
}
