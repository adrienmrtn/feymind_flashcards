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
    @Environment(CloudSync.self) private var sync
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// La fiche se décode hors de l'acteur principal. La décoder dans `init` retenait la
    /// poussée de navigation jusqu'à la fin du JSON et du surlignage ; l'en-tête n'avait
    /// donc même pas le droit d'apparaître.
    @State private var sheet: CourseSheet?
    @State private var isLoadingSheet: Bool
    @State private var explaining: ExplainedPassage?
    @State private var showCardOptions = false
    @State private var isWorking: Work?
    @State private var showStudy = false
    @State private var studyMode: StudyMode = .scheduled
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    /// Les cartes à ouvrir dès qu'elles existent. C'est ce qui fait de la génération un
    /// parcours qui aboutit, plutôt qu'une opération dont il faut aller chercher le résultat.
    @State private var generatedCards: CourseCardsRoute?
    @State private var paywall: PaywallTrigger?
    /// L'état de l'éditeur de fiche, partagé avec sa barre d'outils.
    @StateObject private var editorState = SheetEditorState()
    /// La formule ouverte dans son éditeur, ou l'endroit où l'on en pose une.
    @State private var formulaTarget: SheetFormulaTarget?
    /// Le cadeau du premier cours. Il se présente ici, sur la fiche qu'on vient d'obtenir :
    /// une offre posée avant qu'on ait vu le produit tourner n'a rien à récompenser.
    @State private var giftOffer: DiscountPresentation?
    /// Compteurs de session : instantanés au premier cadre, affinés ensuite.
    @State private var duePreview: CourseDuePreview
    /// Les cartes ne sont lues qu'après le premier cadre. Les faulter dans `init`
    /// retenait la poussée de navigation le temps de charger tout le paquet.
    @State private var loadedCards: [Flashcard]?

    // MARK: Les chapitres

    /// La fiche découpée à chaque titre de partie. Tenue en état plutôt que recalculée dans
    /// `body` : le défilement rend la page à chaque image, et redécouper quatre-vingt-dix
    /// blocs soixante fois par seconde pour obtenir le même résultat n'est pas gratuit.
    @State private var chapters: [SheetChapter] = []
    /// La queue que le mur d'abonnement cache. Elle n'appartient à aucun chapitre : elle est
    /// floutée d'un bloc, et recollée telle quelle à l'enregistrement.
    @State private var lockedTail: [SheetBlock] = []
    /// Les chapitres repliés. Rien n'est replié à l'ouverture : une fiche qu'on ouvre fermée
    /// demanderait un geste avant de pouvoir lire, et on vient lire.
    @State private var collapsed: Set<Int> = []
    /// Le chapitre qu'on lit, celui que le sommaire marque et que l'en-tête collant nomme.
    @State private var currentChapter = 0
    @State private var showOutline = false
    /// L'en-tête collant est-il posé ? Il apparaît dès qu'on a quitté le haut de la fiche.
    @State private var showSticky = false
    /// La barre d'action est-elle visible ? Voir `readScroll`.
    @State private var showBar = true
    /// Le défilement de l'image précédente, pour savoir dans quel sens on va.
    @State private var lastOffset: CGFloat = 0

    /// Le repère de défilement de cet écran.
    private static let scrollSpace = "micabo.sheet"

    /// Ce à quoi le sommaire et le retour en haut font sauter.
    ///
    /// Le haut de la fiche n'est **pas** le premier chapitre : le titre du cours, son chapeau
    /// et l'invitation à sélectionner un passage sont au-dessus de lui. Sans cette ancre-là,
    /// « revenir en haut » se posait sur la première partie et laissait croire que l'écran
    /// s'était arrêté trop tôt.
    private enum SheetAnchor: Hashable {
        case top
        case chapter(Int)
    }

    /// L'invitation à sélectionner un passage disparaît une fois le geste découvert : une
    /// consigne qu'on a suivie n'a plus rien à dire.
    @AppStorage("micabo.sheet.didExplainOnce") private var didExplainOnce = false

    init(course: Course) {
        self.course = course
        _sheet = State(initialValue: nil)
        _isLoadingSheet = State(initialValue: course.hasSheet)
        _duePreview = State(initialValue: .empty)
        _loadedCards = State(initialValue: nil)
    }

    private enum Work: Equatable {
        case sheet
        case cards
    }

    private var cards: [Flashcard] { loadedCards ?? [] }
    private var didLoadCards: Bool { loadedCards != nil }
    private var dueCount: Int { duePreview.dueCount }
    private var heldBackNewCards: Int { duePreview.heldBackNewCards }
    private var tint: Color { Color(hexString: course.accentHex) }
    private var isPro: Bool { pro?.isPro ?? true }

    var body: some View {
        GeometryReader { page in
            ScrollViewReader { scroller in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        header
                            .id(SheetAnchor.top)
                        lead
                        chaptersSection
                        content
                        cardsSection
                    }
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.top, MicaboSpacing.xs)
                    .padding(.bottom, MicaboLayout.bottomBarClearance)
                    .background(scrollProbe)
                }
                .coordinateSpace(name: Self.scrollSpace)
                .scrollIndicators(.hidden)
                .onPreferenceChange(SheetScrollKey.self) { metrics in
                    readScroll(metrics, viewport: page.size.height)
                }
                .onPreferenceChange(SheetChapterTopsKey.self) { tops in
                    readCurrentChapter(tops)
                }
                .overlay(alignment: .top) { stickyBar }
                .overlay(alignment: .bottomTrailing) { cluster(scroller) }
                .overlay(alignment: .bottom) { bottomBar }
                .overlay { workOverlay }
                .sheet(isPresented: $showOutline) {
                    SheetOutlineSheet(
                        chapters: chapters,
                        current: currentChapter,
                        tint: tint
                    ) { index in
                        jump(to: index, using: scroller)
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(MicaboRadius.sheet)
                }
            }
        }
        .micaboScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .enablesSwipeBack()
        .task(id: course.updatedAt) {
            await loadSheet()
        }
        .onChange(of: isPro) { _, _ in applyGate() }
        .task(id: course.id) {
            let ordered = course.orderedCards
            loadedCards = ordered
            duePreview = CourseDuePreview.immediate(from: ordered)
            duePreview = CourseDuePreview.scheduled(
                from: ordered,
                courseID: course.id,
                in: modelContext
            )
            await presentGiftIfEarned()
        }
        .sheet(item: $explaining) { passage in
            ExplainSelectionSheet(course: course, selection: passage.text)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(MicaboRadius.sheet)
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
        .sheet(isPresented: $showCardOptions) {
            GenerateCardsSheet(course: course) { options in
                Task { await generateCards(options) }
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        // Les cartes fraîchement écrites s'ouvrent d'elles-mêmes. Le chemin est celui de la
        // rangée « Cartes » plus bas, donc le chevron de retour ramène bien à la fiche.
        .navigationDestination(item: $generatedCards) { route in
            FlashcardsView(course: route.course)
        }
        // Un chapitre s'ouvre comme une page à lui, et non comme une ancre dans la fiche :
        // c'est ce qui permet de le réviser seul depuis son propre écran.
        .navigationDestination(for: Chapter.self) { chapter in
            ChapterSheetView(chapter: chapter)
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .course(course), mode: studyMode)
        }
        // La fiche ouverte, avec ou sans fiche écrite : l'écart entre les deux dit
        // combien de cours importés restent sans fiche.
        .onAppear {
            // **Le plan se matérialise à la première ouverture, pas au lancement.**
            //
            // Un deck importé avant la refonte n'a pas de chapitres : ses parties n'étaient
            // qu'une lecture des titres de sa fiche, refaite à chaque affichage. On la
            // transforme ici en table, deck par deck. Passer toute la base en revue au
            // démarrage aurait ouvert cent quarante cours d'un bloc sur l'acteur principal,
            // ce qui est exactement ce qui fait ramer une app au lancement.
            ChapterBuilder.migrate(course, in: modelContext)

            Analytics.track(.sheetOpened, [
                "written": .flag(CourseSheet.decode(from: course.sheetData) != nil),
                "source": .text(course.source.rawValue),
            ])
        }
        .micaboPaywall($paywall)
        .micaboDiscountOffer($giftOffer)
        .alert(i18n.t("app.common.oops"), isPresented: .constant(errorMessage != nil)) {
            Button(i18n.t("app.a11y.close"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(i18n.t("app.courses.deleteQ"), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(i18n.t("app.common.delete"), role: .destructive) {
                try? CourseRepository.delete(course, in: modelContext)
                dismiss()
            }
            Button(i18n.t("app.common.cancel"), role: .cancel) {}
        } message: {
            Text(deleteWarning)
        }
    }

    // MARK: - Le cadeau du premier cours

    /// Pose le cadeau, une fois, sur la fiche du premier cours.
    ///
    /// L'attente n'est pas décorative : on arrive ici par une poussée de navigation, et un
    /// pop-up ouvert pendant que la fiche glisse encore donne deux animations concurrentes.
    /// Le temps que la page se pose, on a aussi eu le temps de voir son cours.
    @MainActor
    private func presentGiftIfEarned() async {
        guard
            DiscountOffer.shouldPresentGift(
                isPro: isPro,
                courseCount: (try? modelContext.fetchCount(FetchDescriptor<Course>(
                    predicate: #Predicate { !$0.isFromLibrary }
                ))) ?? 0,
                seen: DiscountOffer.isSeen(),
                startedAt: DiscountOffer.start()
            )
        else { return }

        try? await Task.sleep(for: .milliseconds(900))
        guard !Task.isCancelled, giftOffer == nil, paywall == nil else { return }
        giftOffer = .gift
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
                MicaboBadge(
                    text: i18n.t("app.courses.dueBadge", ["count": "\(dueCount)"]),
                    tone: .accent
                )
            }
        }
        .padding(.top, MicaboSpacing.xs)
    }

    /// Matière et durée de lecture : c'est ce qu'on veut savoir avant d'ouvrir une fiche.
    /// Le volume de cartes n'y figure pas, il est annoncé par leur propre rangée.
    private var headerEyebrow: String {
        var parts: [String] = []
        if let subject = course.subject?.nilIfBlank { parts.append(subject) }
        if let sheet {
            parts.append(
                i18n.t("ios.readingMin", ["minutes": "\(sheet.readingMinutes)"])
            )
        }
        parts.append(MicaboCopy.audience(of: course))
        return parts.isEmpty ? MicaboCopy.cards(cards.count) : parts.joined(separator: " · ")
    }

    private var courseMenu: some View {
        Menu {
            Button { showCardOptions = true } label: {
                Label(cards.isEmpty ? MicaboCopy.cardsButton() : i18n.t("ios.newCardsTitle"), systemImage: "sparkles")
            }
            // Refaire la fiche est l'endroit où la longueur se choisit vraiment : on a la
            // fiche sous les yeux, et c'est en la lisant qu'on la trouve trop courte.
            Menu {
                ForEach(SheetLength.allCases) { length in
                    Button { Task { await writeSheet(length: length) } } label: {
                        Text("\(length.title) · \(SheetPreferences.readingHint(forBlocks: length.defaultBlocks))")
                    }
                }
            } label: {
                Label(sheet == nil ? i18n.t("ios.makeSheet") : i18n.t("ios.rewriteSheet"), systemImage: "text.book.closed")
            }
            .disabled(course.rawText.nilIfBlank == nil || !course.source.expectsSheet)

            // Le partage se règle là où le cours se lit, et pas dans les réglages : c'est en
            // ayant sa fiche sous les yeux qu'on sait si on veut la laisser voir.
            Menu {
                ForEach(CourseVisibility.choosable) { value in
                    Button {
                        setVisibility(value)
                    } label: {
                        Label(value.title, systemImage: value.systemImage)
                    }
                }
            } label: {
                Label(course.visibility.title, systemImage: course.visibility.systemImage)
            }

            Divider()
            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                Label(i18n.t("app.courses.deleteCourse"), systemImage: "trash")
            }
        } label: {
            MicaboCircleIcon(systemImage: "ellipsis", size: 38)
        }
        .accessibilityLabel(i18n.t("ios.courseActions"))
    }

    /// Change qui peut retrouver ce cours dans la bibliothèque.
    ///
    /// L'écriture est locale, et la synchro la remonte à son prochain passage : refermer un
    /// cours doit être immédiat à l'écran, même dans un train sans réseau. C'est le bon sens
    /// pour ce réglage-là — le cours reste visible en ligne quelques minutes de plus, mais
    /// l'app ne fait jamais attendre quelqu'un qui vient de décider de se refermer.
    private func setVisibility(_ value: CourseVisibility) {
        guard value != course.visibility else { return }
        Haptics.selection()
        course.visibility = value
        course.updatedAt = Date()
        try? modelContext.save()
        Task { await sync.sync(context: modelContext) }
    }

    private var deleteWarning: String {
        cards.isEmpty
            ? i18n.t("ios.deleteSheetOnly")
            : i18n.t("ios.deleteSheetAndCards", ["cards": MicaboCopy.cards(cards.count)])
    }

    // MARK: - Chapeau

    /// Le résumé, composé plus grand que le corps du texte : c'est l'entrée en matière,
    /// pas un paragraphe de plus.
    @ViewBuilder
    private var lead: some View {
        if let summary = SheetText.lead(course.summary).nilIfBlank {
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
            Text(i18n.t("ios.selectToExplain"))
                .font(MicaboFont.micro)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(MicaboColor.inkTertiary)
        .padding(.top, MicaboSpacing.md)
    }

    // MARK: - La fiche

    private func loadSheet() async {
        guard let data = course.sheetData, !data.isEmpty else {
            sheet = nil
            applyGate()
            isLoadingSheet = false
            return
        }

        isLoadingSheet = true
        let decoded = await Task.detached(priority: .userInitiated) {
            CourseSheet.decode(from: data)
        }.value
        guard !Task.isCancelled, course.sheetData == data else { return }
        sheet = decoded
        applyGate()
        isLoadingSheet = false
    }

    /// Recoupe la fiche : le mur d'abonnement d'abord, les chapitres ensuite.
    ///
    /// L'ordre n'est pas indifférent. Découper en chapitres puis verrouiller aurait demandé
    /// de décider ce qu'est un chapitre à moitié lisible ; verrouiller d'abord laisse la
    /// queue floutée hors des chapitres, telle qu'elle était avant eux.
    private func applyGate() {
        guard let sheet else {
            chapters = []
            lockedTail = []
            return
        }
        let parts = SheetGate.split(sheet.blocks, isPro: isPro)
        chapters = SheetChapters.split(parts.readable)
        lockedTail = parts.locked
    }

    /// La fiche, coupée tant qu'on n'est pas abonné.
    ///
    /// La partie lisible est **un document qu'on écrit** : on touche le texte, le clavier
    /// monte, la barre d'outils se pose au-dessus, et la fiche s'enregistre toute seule. La
    /// coupure se compte en blocs (`SheetGate`) et non en caractères : couper un paragraphe
    /// en plein milieu d'un mot ressemble à un bug d'affichage, pas à une limite assumée.
    @ViewBuilder
    private var content: some View {
        if !chapters.isEmpty {
            LazyVStack(alignment: .leading, spacing: 0) {
                // **Pas de filet entre les chapitres.**
                //
                // Il y en avait un, sur toute la largeur, et la capsule teintée d'un titre de
                // partie arrive vingt points plus bas : deux barres horizontales coup sur
                // coup, dont une qui ne dit rien que l'air ne disait déjà. L'air et la
                // capsule séparent les parties ; un filet en plus les encadre, et une fiche
                // encadrée redevient une brochure.
                ForEach(chapters) { chapter in
                    SheetChapterView(
                        chapter: chapter,
                        number: partNumber(of: chapter),
                        revision: course.updatedAt,
                        tint: tint,
                        isCollapsed: collapsed.contains(chapter.index),
                        state: editorState,
                        onToggle: { toggle(chapter.index) },
                        onSave: { blocks in saveChapter(chapter.index, blocks: blocks) },
                        onExplain: explain,
                        onFormula: { target in formulaTarget = target }
                    )
                    .id(SheetAnchor.chapter(chapter.index))
                    .background(chapterProbe(chapter.index))
                }
            }
            .padding(.top, MicaboSpacing.md)

            if !lockedTail.isEmpty {
                LockedSheetTail(blocks: lockedTail, tint: tint) {
                    paywall = .lockedSheet
                }
            }
        } else if isLoadingSheet {
            HStack(spacing: MicaboSpacing.sm) {
                ProgressView()
                    .tint(MicaboColor.accent)
                Text(i18n.t("ios.openingSheet"))
                    .font(MicaboFont.ui(13.5, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, MicaboSpacing.lg)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(i18n.t("ios.openingSheet"))
        } else {
            missingSheet
        }
    }

    /// Écrit la partie lisible et enregistre la fiche.
    ///
    /// **Les blocs verrouillés sont recollés derrière.** Ils ne sont pas affichés, donc pas
    /// modifiables, donc ils ne doivent pas disparaître à l'enregistrement : c'est la même
    /// règle que sur le site, et sans elle un compte gratuit effacerait la moitié de sa fiche
    /// en corrigeant une faute de frappe. Le texte de référence des cartes est refait à partir
    /// de la fiche entière, comme le fait le serveur.
    private func saveChapter(_ index: Int, blocks: [SheetBlock]) {
        guard let current = sheet else { return }
        let readable = SheetChapters.replacing(chapters, at: index, with: blocks)
        let next = CourseSheet(blocks: readable + lockedTail)
        guard next != current else { return }
        course.apply(next)
        course.contextText = next.plainText()
        course.updatedAt = Date()
        try? modelContext.save()
        sheet = next
        // On redécoupe à partir de ce qu'on vient d'écrire, et pas en attendant le
        // rechargement : effacer un titre de partie fond deux chapitres en un, et l'écran
        // doit le montrer à la frappe suivante, pas au prochain passage sur la fiche.
        chapters = SheetChapters.split(readable)
        Task { await sync.sync(context: modelContext) }
    }

    /// Le rang affiché d'une partie, compté parmi les chapitres titrés.
    private func partNumber(of chapter: SheetChapter) -> Int {
        chapters.prefix(chapter.index + 1).reduce(0) { $0 + ($1.title == nil ? 0 : 1) }
    }

    /// Replie ou déplie un chapitre.
    ///
    /// Sans animation, et c'est délibéré : ce qui se déplie est un `UITextView`, dont la
    /// hauteur est mesurée par UIKit. Animer son apparition fait courir deux systèmes de
    /// mise en page l'un après l'autre, et le texte sautille pendant que la hauteur se
    /// stabilise. Le repli est instantané, le retour haptique dit qu'il a eu lieu.
    private func toggle(_ index: Int) {
        if collapsed.contains(index) {
            collapsed.remove(index)
        } else {
            collapsed.insert(index)
        }
    }

    /// Un cours sans fiche : un paquet de cartes, un import fait avant que la fiche n'existe,
    /// ou une analyse tombée pendant une panne. On ne montre pas un écran vide.
    ///
    /// Un paquet, lui, n'attend pas de fiche : il n'a pas de document, et lui en promettre
    /// une serait une impasse. Son écran renvoie donc à ses cartes, qui sont tout son contenu.
    @ViewBuilder
    private var missingSheet: some View {
        if course.source.expectsSheet {
            MicaboEmptyState(
                systemImage: "text.book.closed",
                title: i18n.t("ios.noSheetYet"),
                message: course.rawText.nilIfBlank == nil
                    ? i18n.t("ios.reimportDoc")
                    : i18n.t("ios.canWriteSheet"),
                actionTitle: course.rawText.nilIfBlank == nil ? nil : i18n.t("ios.makeSheet")
            ) {
                Task { await writeSheet() }
            }
            .padding(.top, MicaboSpacing.md)
        } else {
            MicaboEmptyState(
                systemImage: "rectangle.on.rectangle.angled",
                title: i18n.t("ios.deckOnlyTitle"),
                message: i18n.t("ios.deckOnlyBody"),
                actionTitle: i18n.t("ios.seeCards")
            ) {
                generatedCards = CourseCardsRoute(course: course)
            }
            .padding(.top, MicaboSpacing.md)
        }
    }

    // MARK: - Le plan du deck

    /// **Le plan, avec ce qu'on en sait, avant la fiche elle-même.**
    ///
    /// Le sommaire du bouton flottant et cette liste ne font pas le même travail : le
    /// premier déplace le regard à l'intérieur d'une lecture en cours, celle-ci dit où en
    /// est chaque partie et permet de n'en réviser qu'une. C'est la seule des deux qui
    /// répond à « je n'ai que la guerre froide à revoir pour jeudi ».
    ///
    /// Elle ne s'affiche que si le deck a des chapitres. Un cours sans fiche écrite n'en a
    /// pas encore, et lui annoncer qu'il n'a pas de plan à l'endroit même où on lui propose
    /// d'en écrire une serait lui dire deux fois la même chose.
    @ViewBuilder
    private var chaptersSection: some View {
        if !course.orderedChapters.isEmpty {
            DeckChaptersView(course: course)
                .padding(.top, MicaboSpacing.xl)
        }
    }

    // MARK: - Les cartes

    /// Les cartes ne sont plus le sujet de l'écran, mais elles ne se cachent pas : une
    /// rangée en fin de fiche, comme tout ce qui se liste dans l'app.
    @ViewBuilder
    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: i18n.t("ios.cardsCaption"))

            if !didLoadCards {
                EmptyView()
            } else if cards.isEmpty {
                // Un bouton, et rien au-dessus de lui. La phrase qui l'introduisait disait
                // que la fiche se lit très bien sans cartes, ce dont personne n'a besoin
                // d'être convaincu à l'endroit exact où l'on vient d'en lire une.
                Button {
                    showCardOptions = true
                } label: {
                    HStack(spacing: MicaboSpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                        Text(MicaboCopy.cardsButton())
                    }
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
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
        if dueCount > 0 {
            return i18n.t("ios.dueToday", ["count": "\(dueCount)"])
        }
        let newCount = cards.filter { $0.state == .new }.count
        return newCount > 0
            ? i18n.t("ios.neverSeen", ["count": "\(newCount)"])
            : i18n.t("ios.upToDateCap")
    }

    // MARK: - Le plan de la fiche

    /// Ce que la page rapporte du défilement : où en est le haut du contenu, et sa hauteur.
    private var scrollProbe: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: SheetScrollKey.self,
                value: SheetScrollMetrics(
                    top: proxy.frame(in: .named(Self.scrollSpace)).minY,
                    height: proxy.size.height
                )
            )
        }
    }

    /// Où commence un chapitre, dans le même repère. C'est ce qui dit lequel on lit.
    private func chapterProbe(_ index: Int) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: SheetChapterTopsKey.self,
                value: [index: proxy.frame(in: .named(Self.scrollSpace)).minY]
            )
        }
    }

    /// **Ce que le défilement décide : l'en-tête collant, et la barre d'action.**
    ///
    /// L'en-tête apparaît dès qu'on a quitté le haut de la fiche, et il sert deux fois : il
    /// rend le retour et le titre du chapitre courant, qui s'en allaient tous les deux avec
    /// le premier écran, et il pose une matière sous la barre d'état, où le texte passait
    /// jusque-là par-dessus l'heure.
    ///
    /// La barre d'action, elle, se comporte comme celle de Safari : elle s'efface quand on
    /// descend dans le texte, revient dès qu'on remonte, et reste posée aux deux bouts de la
    /// fiche. Elle occupait un sixième de l'écran en permanence, dégradé compris, et coupait
    /// systématiquement en deux la dernière ligne lisible. Au milieu d'un chapitre, l'écran
    /// est à la lecture.
    private func readScroll(_ metrics: SheetScrollMetrics, viewport: CGFloat) {
        let offset = metrics.top
        // **Dix points, et pas quatre-vingt-dix.**
        //
        // Le seuil décidait de deux choses à la fois, et il n'était bon que pour l'une : il
        // fallait beaucoup de défilement avant que l'en-tête collant ne vienne, et pendant
        // ces quatre-vingt-dix points le texte passait sous la barre d'état, par-dessus
        // l'heure et le réseau, sans rien derrière lui. La matière arrive maintenant dès que
        // la page a bougé.
        let atTop = offset > -10
        let atBottom = viewport > 0 && metrics.height + offset <= viewport + 60

        if showSticky == atTop {
            withAnimation(.easeOut(duration: 0.18)) { showSticky = !atTop }
        }

        // La barre d'action, elle, garde sa marge : elle ne doit pas réapparaître au moindre
        // frémissement du pouce en haut de la fiche.
        let nearTop = offset > -90

        var bar = showBar
        let delta = offset - lastOffset
        // Le seuil évite que la barre clignote sur les quelques points de rebond d'un
        // défilement qui s'arrête.
        if abs(delta) > 26 {
            bar = delta > 0
            lastOffset = offset
        }
        if nearTop || atBottom { bar = true }
        if bar != showBar {
            withAnimation(.easeOut(duration: 0.2)) { showBar = bar }
        }
    }

    /// Le chapitre courant : le dernier dont l'en-tête est passé sous la ligne de flottaison.
    private func readCurrentChapter(_ tops: [Int: CGFloat]) {
        guard !tops.isEmpty else { return }
        let line = CGFloat(140)
        let passed = tops.filter { $0.value <= line }.max { $0.value < $1.value }
        let fallback = tops.min { $0.value < $1.value }
        let next = passed?.key ?? fallback?.key ?? 0
        if next != currentChapter { currentChapter = next }
    }

    /// Y a-t-il un plan à montrer ? Une fiche d'une seule partie n'a pas de sommaire : la
    /// liste répéterait le titre qu'on a déjà sous les yeux.
    private var hasOutline: Bool {
        chapters.filter { $0.title != nil }.count >= 2
    }

    /// Le titre porté par l'en-tête collant : la partie qu'on lit, ou le cours lui-même tant
    /// qu'on est dans l'entrée en matière.
    private var stickyTitle: String {
        chapters.first { $0.index == currentChapter }?.title ?? course.title
    }

    @ViewBuilder
    private var stickyBar: some View {
        if showSticky, !editorState.isEditing {
            HStack(spacing: MicaboSpacing.sm) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(i18n.t("app.common.back"))

                Text(stickyTitle)
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.leading, MicaboSpacing.sm)
            .padding(.trailing, MicaboSpacing.screen)
            .padding(.vertical, 6)
            .background {
                // La matière déborde **sous la barre d'état**, que le contenu traversait
                // jusqu'ici en passant par-dessus l'heure.
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(MicaboColor.hairlineOnCanvas)
                            .frame(height: 1)
                    }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Le sommaire et le retour en haut, posés là où le pouce arrive.
    @ViewBuilder
    private func cluster(_ scroller: ScrollViewProxy) -> some View {
        if (hasOutline || showSticky), !editorState.isEditing {
            VStack(spacing: 10) {
                // Le retour en haut vaut pour **toute** fiche qu'on a fait défiler, plan ou
                // pas : c'est le geste qu'on cherche après avoir lu, et il n'existait nulle
                // part. Le sommaire, lui, n'a de sens qu'avec plusieurs parties.
                if showSticky {
                    MicaboCircleButton(
                        systemImage: "arrow.up",
                        size: 40,
                        accessibilityTitle: i18n.t("ios.backToTop")
                    ) {
                        goToTop(using: scroller)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                if hasOutline {
                    MicaboCircleButton(
                        systemImage: "list.bullet",
                        size: 46,
                        accessibilityTitle: i18n.t("ios.sheetOutline")
                    ) {
                        showOutline = true
                    }
                }
            }
            .padding(.trailing, MicaboSpacing.screen)
            .padding(.bottom, showBar ? MicaboLayout.bottomBarClearance : MicaboSpacing.xl)
        }
    }

    /// Ouvre un chapitre et s'y rend.
    ///
    /// Le déplier **avant** de sauter, et attendre une image : viser un en-tête replié
    /// reviendrait à viser une hauteur qui va changer juste après, et l'écran se poserait
    /// quelque part au milieu du chapitre précédent. L'attente couvre aussi le retour de la
    /// feuille du sommaire, dont l'animation se disputerait le défilement.
    private func jump(to index: Int, using scroller: ScrollViewProxy) {
        collapsed.remove(index)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.easeInOut(duration: 0.3)) {
                scroller.scrollTo(SheetAnchor.chapter(index), anchor: .top)
            }
        }
    }

    /// Le haut de la fiche : son titre, pas sa première partie.
    private func goToTop(using scroller: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.3)) {
            scroller.scrollTo(SheetAnchor.top, anchor: .top)
        }
    }

    // MARK: - Bas d'écran

    /// Un seul bouton ancré, et il dit ce qui manque : sans carte, l'action est d'en
    /// générer ; avec des cartes, c'est de réviser, sous le nom qu'il porte partout.
    @ViewBuilder
    private var bottomBar: some View {
        if showBar, !editorState.isEditing, didLoadCards {
            MicaboBottomBar(fade: 44) {
                if cards.isEmpty {
                    Button {
                        showCardOptions = true
                    } label: {
                        HStack(spacing: MicaboSpacing.xs) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                            Text(MicaboCopy.cardsButton())
                        }
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle())
                } else {
                    Button(action: startSession) {
                        HStack(spacing: MicaboSpacing.xs) {
                            Text(sessionButtonTitle)

                            if dueCount == 0, heldBackNewCards == 0, !(pro?.canPractice ?? true) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle())
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Réviser ce qui est dû reste gratuit. **L'entraînement libre, non** : c'est ce qu'on
    /// fait la veille d'un partiel, et le cadenas sur le bouton le dit avant l'appui plutôt
    /// que de faire surgir un paywall à la place d'une session.
    private var sessionButtonTitle: String {
        if dueCount > 0 { return MicaboCopy.reviewButton(count: dueCount) }
        if heldBackNewCards > 0 { return i18n.t("nav.review") }
        return MicaboCopy.practiceReview()
    }

    private func startSession() {
        let canSchedule = dueCount > 0 || heldBackNewCards > 0
        guard canSchedule || (pro?.canPractice ?? true) else {
            paywall = .practice
            return
        }
        studyMode = canSchedule ? .scheduled : .practice
        showStudy = true
    }

    @ViewBuilder
    private var workOverlay: some View {
        switch isWorking {
        case .sheet:
            GenerationOverlay(title: i18n.t("ios.writingSheet"), steps: SheetGenerationSteps.all())
        case .cards:
            GenerationOverlay(
                title: i18n.t("ios.writingCards"),
                steps: [
                    i18n.t("ios.genStepRead"),
                    i18n.t("ios.genStepPick"),
                    i18n.t("ios.genStepWrite"),
                    i18n.t("ios.genStepCheckAnswers")
                ]
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

    /// Écrit ou réécrit la fiche. La longueur retenue est celle choisie, et elle devient le
    /// réglage courant : on ne redemande pas à chaque fois ce qu'on vient de trancher.
    @MainActor
    private func writeSheet(length: SheetLength = SheetPreferences.length) async {
        guard isWorking == nil, let rawText = course.rawText.nilIfBlank else { return }
        SheetPreferences.length = length
        isWorking = .sheet
        defer { isWorking = nil }

        // « Refaire » compte à part : c'est le geste qui dit qu'une fiche n'a pas plu, et
        // c'est celui qu'on veut voir baisser.
        let again = CourseSheet.decode(from: course.sheetData) != nil
        Analytics.track(.sheetWriteStarted, [
            "length": .text(length.rawValue),
            "again": .flag(again),
            "source": .text(course.source.rawValue),
        ])

        let request = CourseGenerationRequest(
            rawText: rawText,
            pageImages: [],
            hintTitle: course.title,
            sourceName: course.sourceFileName,
            studyLevel: OnboardingPreferences.studyLevel,
            country: OnboardingPreferences.schoolingCountry,
            language: OnboardingPreferences.contentLanguage,
            sheetLength: length,
            sheetBlocks: SheetPreferences.blocks,
            // Ici la matière est connue, trouvée au premier passage ou corrigée à la main :
            // elle vaut mieux que des mots comptés sur le texte.
            subject: course.subject,
            sourceKind: course.source
        )

        do {
            let generated = try await aiService.generateCourse(request)
            try CourseRepository.updateSheet(of: course, with: generated, in: modelContext)
            Analytics.track(.sheetWritten, [
                "length": .text(length.rawValue),
                "again": .flag(again),
                "blocks": .number(Double(generated.sheet?.blocks.count ?? 0)),
            ])
            Haptics.success()
        } catch {
            Analytics.track(.sheetWriteFailed, ["length": .text(length.rawValue)])
            errorMessage = describe(error)
        }
    }

    /// Génère les cartes, **puis ouvre l'écran des cartes**.
    ///
    /// Avant, on retombait sur la fiche : il fallait la faire défiler jusqu'en bas pour
    /// trouver la rangée « Cartes » et découvrir ce qui venait d'être écrit. Une action qui
    /// produit quelque chose doit mener à ce qu'elle a produit.
    @MainActor
    private func generateCards(_ options: CardGeneration.Options) async {
        guard isWorking == nil else { return }
        isWorking = .cards
        Analytics.track(.cardsGenerationStarted)

        do {
            try await CardGeneration.run(for: course, options: options, using: aiService, in: modelContext)
            Analytics.track(.cardsGenerated, ["cards": .number(Double(course.flashcards?.count ?? 0))])
            Haptics.success()
            // Le voile tombe avant la poussée : pousser un écran par-dessus un plein écran
            // opaque montrerait la transition à travers lui.
            isWorking = nil
            generatedCards = CourseCardsRoute(course: course)
        } catch {
            Analytics.track(.cardsGenerationFailed)
            isWorking = nil
            errorMessage = describe(error)
        }
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

/// **Où en est le défilement de la fiche.**
///
/// Deux nombres, et ils décident de trois choses : l'apparition de l'en-tête collant, le sens
/// dans lequel on va — donc la barre d'action — et le fait d'être arrivé au bas du texte.
private struct SheetScrollMetrics: Equatable {
    /// Le haut du contenu dans le repère de la page : zéro en haut, négatif dès qu'on descend.
    var top: CGFloat = 0
    /// La hauteur de tout le contenu, pour savoir quand on en touche le bas.
    var height: CGFloat = 0
}

private struct SheetScrollKey: PreferenceKey {
    static var defaultValue = SheetScrollMetrics()
    static func reduce(value: inout SheetScrollMetrics, nextValue: () -> SheetScrollMetrics) {
        value = nextValue()
    }
}

/// Où commence chaque chapitre, par rang. Les valeurs se **fusionnent** au lieu de s'écraser :
/// chaque chapitre n'en rapporte qu'une, et c'est l'ensemble qui dit lequel on lit.
private struct SheetChapterTopsKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, next in next }
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
    static func all(reading: String? = nil) -> [String] {
        let locale = UiLocale.resolved()
        return [
            reading ?? L10n.t("ios.genStepDoc", locale: locale),
            L10n.t("ios.genStepPlan", locale: locale),
            L10n.t("ios.writingSheet", locale: locale),
            L10n.t("ios.genStepLayout", locale: locale)
        ]
    }
}
