import SwiftData
import SwiftUI

/// **Un chapitre ouvert : ce qu'on lit, ce qu'on corrige, ce qu'on révise.**
///
/// C'est l'unité de travail du deck. Le cours entier n'a plus d'écran à lui : il s'est
/// réparti entre ses chapitres, et chacun porte sa part de la fiche
/// (`Chapter.sheetData`). C'est ce qui permet de réviser la guerre froide sans traverser
/// les huit autres parties — le contrôle de jeudi ne porte que sur elle, et faire repasser
/// le reste pour l'atteindre est exactement ce qui fait renoncer.
///
/// **La page s'écrit directement**, sans bouton Modifier : `SheetEditorView` est le même
/// composant que celui de l'ancien écran de fiche, et le texte se corrige au doigt là où on
/// le lit. Ce qui est sauvé l'est sur le chapitre, pas sur le cours : le cours garde sa
/// fiche d'origine comme trace de l'import, et deux endroits qui écriraient la même chose
/// finiraient par ne plus dire la même chose — c'est précisément ce qui arrivait quand la
/// fiche du cours restait modifiable après avoir été découpée.
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
    @State private var studying = false
    @State private var dueCount = 0
    @State private var showRename = false
    @State private var draftTitle = ""
    @State private var explaining: ExplainedPassage?
    @State private var formulaTarget: SheetFormulaTarget?
    @State private var paywall: PaywallTrigger?

    @StateObject private var editorState = SheetEditorState()

    private var tint: Color {
        Color(hexString: chapter.course?.accentHex ?? "")
    }

    private var isPro: Bool { pro?.isPro ?? true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
                header

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
                }

                if !lockedTail.isEmpty {
                    LockedSheetTail(blocks: lockedTail, tint: tint) {
                        paywall = .lockedSheet
                    }
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)
            .padding(.bottom, MicaboLayout.bottomBarClearance)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
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
        .alert(i18n.t("ios.deck.renameChapter"), isPresented: $showRename) {
            TextField(chapter.title, text: $draftTitle)
            Button(i18n.t("app.common.save")) { applyRename() }
            Button(i18n.t("app.common.cancel"), role: .cancel) {}
        }
        .micaboPaywall($paywall)
    }

    // MARK: - En-tête

    private var header: some View {
        MicaboScreenHeader(
            title: chapter.title,
            eyebrow: chapter.course?.title,
            back: MicaboHeaderBack.back { dismiss() }
        ) {
            Button {
                draftTitle = chapter.title
                showRename = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .frame(width: 34, height: 34)
                    .background(MicaboColor.surfaceMuted, in: Circle())
            }
            .accessibilityLabel(i18n.t("ios.deck.renameChapter"))
        }
        .padding(.top, MicaboSpacing.xs)
    }

    // MARK: - Le bouton

    /// **Le bouton garde son nom.** « Réviser N cartes » est le même libellé que depuis
    /// l'onglet Réviser et depuis un deck : un bouton qui change de nom au milieu d'un
    /// parcours se lit comme une autre action.
    ///
    /// Il disparaît pendant qu'on écrit : une barre posée au-dessus du clavier, sur un
    /// écran où l'on corrige une phrase, n'est plus un bouton, c'est un obstacle.
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
                .buttonStyle(MicaboPrimaryButtonStyle())
            }
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
    /// s'applique désormais par chapitre. C'est plus généreux qu'une coupure unique en
    /// milieu de cours, et c'est le bon compromis : un chapitre entièrement cadenassé
    /// laisserait croire que le deck n'a pas été écrit, alors qu'il l'a été.
    private func applyGate() {
        let all = chapter.decodedSheet()?.blocks ?? []
        let parts = SheetGate.split(all, isPro: isPro)
        blocks = parts.readable
        lockedTail = parts.locked
    }

    /// Enregistre le texte corrigé **sur le chapitre**.
    ///
    /// La queue cadenassée est recollée telle quelle : elle n'a pas été montrée, donc elle
    /// n'a pas pu être modifiée, et l'oublier ferait disparaître la moitié d'un chapitre au
    /// premier mot corrigé par quelqu'un qui n'est pas abonné.
    private func save(_ edited: [SheetBlock]) {
        chapter.apply(CourseSheet(blocks: edited + lockedTail))
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
