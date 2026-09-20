import SwiftData
import SwiftUI

/// **L'écran d'un deck : son plan de travail.**
///
/// Ce n'est plus la fiche. L'écran d'un cours montrait le document entier, du premier
/// paragraphe au dernier, et les cartes en bas comme un accessoire. Un deck couvre une
/// matière : sa fiche fait quatre-vingts blocs, on ne la lit pas d'un trait, et ce qu'on
/// vient y chercher n'est pas un texte mais une réponse à « qu'est-ce que je révise
/// maintenant ».
///
/// L'écran répond donc dans cet ordre :
///
/// 1. **Où j'en suis** — le pourcentage du deck, et la date s'il y en a une.
/// 2. **Ce que je fais maintenant** — le bouton de révision, en bas, toujours atteignable.
/// 3. **Le plan** — les chapitres, chacun avec son pourcentage, chacun ouvrable et
///    révisable seul.
///
/// Et rien d'autre. Les cartes et la suppression sont au menu du bandeau, où l'on va quand
/// on cherche à agir *sur* le deck plutôt qu'à le réviser. L'épreuve n'y a plus sa rangée :
/// sa date est déjà sur la carte d'état, et une seconde entrée pour la même date faisait
/// deux endroits à tenir d'accord.
///
/// **La fiche entière n'a pas disparu, elle s'est répartie.** Chaque chapitre porte la
/// sienne (`Chapter.sheetData`) et s'ouvre comme une page à lui. C'est ce qui permet de
/// réviser la guerre froide sans traverser les huit autres parties, et c'est la demande qui
/// a fait exister le chapitre comme entité.
struct DeckView: View {
    @Bindable var course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var studying = false
    @State private var studyMode: StudyMode = .scheduled
    @State private var showDeleteConfirmation = false
    @State private var showRename = false
    @State private var draftTitle = ""
    @State private var cardsRoute: CourseCardsRoute?
    @State private var paywall: PaywallTrigger?
    /// Le cadeau du premier deck. Il se présente ici, sur le plan qu'on vient d'obtenir :
    /// une offre posée avant qu'on ait vu le produit tourner n'a rien à récompenser.
    @State private var giftOffer: DiscountPresentation?

    /// Les faits du deck, relus après chaque session. Ils coûtent un parcours de toutes les
    /// cartes et une lecture des journaux : les recalculer dans le corps de la vue les
    /// referait à chaque image de défilement.
    @State private var facts = DeckFacts.empty
    @State private var studyRuns = 0
    @State private var showMenu = false
    /// L'épreuve du deck, ouverte en correction depuis le menu. C'est le seul endroit d'où
    /// l'on règle encore une date et une note visée : la fiche d'épreuve qui le faisait
    /// n'existe plus, et sa date se lit désormais ici, sur la carte d'état.
    @State private var editingExam: Exam?
    /// Entre 0 (bandeau déplié) et 1 (réduit en barre). Piloté par le défilement.
    @State private var collapse: Double = 0

    private static let scrollSpace = "micabo.deck"

    private var safeTop: CGFloat { MicaboScreen.safeTop }

    private var pastel: Color { MicaboColor.pastel(for: course.id) }

    var body: some View {
        ScrollView {
            // **Le bandeau défile avec le contenu ; la barre repliée apparaît par-dessus.**
            //
            // C'est le `ScrollView` qui emporte le bandeau, pas un calcul : il s'en va parce
            // qu'il est dans le contenu, exactement comme la première rangée de chapitres.
            // La sonde de défilement ne décide plus que d'une chose, le fondu de la barre —
            // et si elle se trompait, le bandeau partirait quand même.
            VStack(alignment: .leading, spacing: 0) {
                MicaboDeckBanner(
                    emoji: course.emoji,
                    pastel: pastel,
                    safeTop: safeTop,
                    onBack: { dismiss() },
                    onMenu: { showMenu = true }
                )

                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    identity
                    statusCard
                    DeckChaptersView(course: course)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 22)
                .padding(.bottom, MicaboLayout.bottomBarClearance)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboScrollProbe(space: Self.scrollSpace)
        }
        .coordinateSpace(name: Self.scrollSpace)
        .scrollIndicators(.hidden)
        .onPreferenceChange(MicaboScrollOffsetKey.self) { top in
            collapse = min(1, max(0, -top / MicaboDeckBanner.travel))
        }
        .overlay(alignment: .top) {
            MicaboDeckBar(
                emoji: course.emoji,
                pastel: pastel,
                title: course.title,
                safeTop: safeTop,
                visible: collapse,
                onBack: { dismiss() },
                onMenu: { showMenu = true }
            )
        }
        // **Après la superposition, pas avant.** Posé avant, il n'étend que le défilement :
        // le bandeau reste aligné sur le haut de la zone sûre, une bande blanche subsiste
        // au-dessus de lui, et le contenu qui défile passe dedans par-dessus l'heure. Posé
        // ici, il étend l'ensemble — défilement **et** bandeau — jusqu'au bord de l'écran.
        .ignoresSafeArea(edges: .top)
        .micaboScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .enablesSwipeBack()
        .overlay(alignment: .bottom) { bottomBar }
        .navigationDestination(item: $cardsRoute) { route in
            FlashcardsView(course: route.course)
        }
        .fullScreenCover(isPresented: $studying, onDismiss: { studyRuns += 1 }) {
            StudyView(source: .course(course), mode: studyMode)
        }
        .task(id: studyRuns) {
            // **Le plan se matérialise à la première ouverture.** Un deck importé avant la
            // refonte n'a pas de chapitres : ses parties n'étaient qu'une lecture des titres
            // de sa fiche, refaite à chaque affichage. On la transforme ici en table, deck
            // par deck, plutôt que de passer toute la base en revue au démarrage.
            ChapterBuilder.migrate(course, in: modelContext)
            // Et le rattrapage des decks restés plats, quand leur fiche avait ses parties en
            // titres de niveau deux. Voir `resplitIfFlat`.
            ChapterBuilder.resplitIfFlat(course, in: modelContext)
            reload()
            Analytics.track(.sheetOpened, [
                "written": .flag(course.hasSheet),
                "source": .text(course.source.rawValue),
                "chapters": .number(Double(course.orderedChapters.count)),
            ])
            await presentGiftIfEarned()
        }
        .sheet(item: $editingExam) { exam in
            ExamEditorSheet(exam: exam, suggestedDate: exam.date) { _ in reload() }
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(MicaboRadius.sheet)
        }
        .micaboPaywall($paywall)
        .micaboDiscountOffer($giftOffer)
        .confirmationDialog(course.title, isPresented: $showMenu, titleVisibility: .visible) {
            Button(i18n.t("ios.deck.rename")) {
                draftTitle = course.title
                showRename = true
            }
            Button(MicaboCopy.cards(course.cards.count)) {
                cardsRoute = CourseCardsRoute(course: course)
            }
            if let exam = facts.exam {
                Button(i18n.t("ios.editExam")) { editingExam = exam }
            }
            Button(i18n.t("app.common.delete"), role: .destructive) {
                showDeleteConfirmation = true
            }
            Button(i18n.t("app.common.cancel"), role: .cancel) {}
        }
        .alert(i18n.t("ios.deck.rename"), isPresented: $showRename) {
            TextField(i18n.t("ios.deckSetup.name.placeholder"), text: $draftTitle)
            Button(i18n.t("app.common.save")) { applyRename() }
            Button(i18n.t("app.common.cancel"), role: .cancel) {}
        }
        .confirmationDialog(
            i18n.t("app.courses.deleteQ"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(i18n.t("app.common.delete"), role: .destructive) {
                try? CourseRepository.delete(course, in: modelContext)
                dismiss()
            }
            Button(i18n.t("app.common.cancel"), role: .cancel) {}
        } message: {
            Text(i18n.t("ios.deck.deleteWarning", ["count": "\(course.cards.count)"]))
        }
    }

    // MARK: - En-tête

    /// Le titre et sa ligne de faits, sous le bandeau.
    ///
    /// Les séparateurs sont des points de trois points, pas des barres verticales : trois
    /// faits séparés par des barres se lisent comme un tableau, et ce n'en est pas un.
    private var identity: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(course.title)
                .font(MicaboFont.ui(25, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 9) {
                if let subject = course.subject?.nilIfBlank {
                    Text(subject.uppercased())
                        .font(MicaboFont.ui(11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(MicaboColor.inkSecondary)
                    dot
                }

                Text(i18n.t("ios.deck.chapterCount", ["count": "\(course.orderedChapters.count)"]))
                    .font(MicaboFont.ui(13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)

                dot

                Text(MicaboCopy.cards(course.cards.count))
                    .font(MicaboFont.ui(13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)

                Spacer(minLength: 0)
            }
        }
    }

    private var dot: some View {
        Circle()
            .fill(MicaboColor.inkTertiary)
            .frame(width: 3, height: 3)
    }

    // MARK: - Où j'en suis

    /// **Le pourcentage du deck et sa date, dans le même bloc.**
    ///
    /// Les deux répondent à la même question — « où j'en suis par rapport à ce qui
    /// m'attend » — et les séparer obligeait à les rapprocher de tête. Le compte à rebours
    /// n'est pas une décoration : c'est lui qui explique pourquoi le nombre de cartes neuves
    /// du jour est ce qu'il est.
    /// **L'encadré ouvre les cartes.**
    ///
    /// Il annonce un pourcentage de cartes apprises et un nombre de cartes neuves : c'est du
    /// stock, et il n'y avait aucun moyen d'aller le voir depuis la page qui le chiffre. Le
    /// menu du bandeau y menait, ce qui est l'endroit où l'on va pour renommer ou supprimer —
    /// pas pour regarder ce qu'on apprend.
    private var statusCard: some View {
        Button {
            cardsRoute = CourseCardsRoute(course: course)
        } label: {
            statusCardBody
                .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
        .accessibilityHint(MicaboCopy.cards(course.cards.count))
    }

    private var statusCardBody: some View {
        MicaboOutlineCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center, spacing: 10) {
                    Text("\(facts.percent) %")
                        .font(MicaboFont.ui(26, weight: .heavy))
                        .tracking(-0.8)
                        .foregroundStyle(MicaboColor.accent)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .fixedSize()

                    Text(i18n.t("ios.deck.globalMastery"))
                        .font(MicaboFont.ui(13, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let deadline = facts.deadline {
                        MicaboCountdownPill(days: DeckPace.daysUntil(deadline))
                    }
                }

                MicaboSlimProgress(percent: facts.percent, showsLabel: false, height: 7)

                paceRow
            }
        }
    }

    /// **Le rythme, et d'où il vient.**
    ///
    /// C'est la seule chose que la date change, et c'est donc la seule chose qu'on annonce à
    /// côté d'elle. Un étudiant qui trouve sa session trop lourde doit pouvoir remonter en
    /// une lecture jusqu'à la cause, qui est sa propre réponse à « c'est quand ? ».
    private var paceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: facts.deadline == nil ? "bolt.fill" : "calendar")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)

            Group {
                if facts.newRemaining > 0 {
                    Text(i18n.t("ios.deck.newToday", ["count": "\(facts.newRemaining)"]))
                } else {
                    Text(i18n.t("ios.deck.newDone"))
                }
            }
            .font(MicaboFont.ui(13, weight: .regular))
            .foregroundStyle(MicaboColor.inkSecondary)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Le bouton

    @ViewBuilder
    private var bottomBar: some View {
        MicaboBottomBar(fade: 44) {
            if course.cards.isEmpty {
                Button {
                    cardsRoute = CourseCardsRoute(course: course)
                } label: {
                    HStack(spacing: MicaboSpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                        Text(MicaboCopy.cardsButton())
                    }
                }
                .buttonStyle(MicaboActionButtonStyle())
            } else {
                Button(action: startSession) {
                    Text(sessionButtonTitle)
                }
                .buttonStyle(MicaboActionButtonStyle())
            }
        }
    }

    private var sessionButtonTitle: String {
        facts.dueCount > 0
            ? i18n.t("app.today.startCards", ["count": "\(facts.dueCount)"])
            : i18n.t("ios.deck.practiceDeck")
    }

    private func startSession() {
        if facts.dueCount == 0 {
            guard pro?.canPractice ?? true else {
                paywall = .practice
                return
            }
            studyMode = .practice
        } else {
            studyMode = .scheduled
        }
        studying = true
    }

    private func applyRename() {
        guard let clean = draftTitle.nilIfBlank else { return }
        course.title = clean
        course.updatedAt = Date()
        try? modelContext.save()
    }

    // MARK: - Le cadeau du premier deck

    /// Pose le cadeau, une fois, sur le plan du premier deck.
    ///
    /// L'attente n'est pas décorative : on arrive ici par une poussée de navigation, et un
    /// pop-up ouvert pendant que la page glisse encore donne deux animations concurrentes.
    /// Le temps que l'écran se pose, on a aussi eu le temps de voir son deck.
    @MainActor
    private func presentGiftIfEarned() async {
        guard
            DiscountOffer.shouldPresentGift(
                isPro: pro?.isPro ?? true,
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

    // MARK: - Les faits

    private func reload() {
        facts = DeckFacts.read(course, in: modelContext)
    }
}

/// Ce que l'écran du deck affiche, lu d'un coup plutôt que reconstruit par morceaux.
///
/// Une seule lecture des journaux, une seule des examens, un seul parcours des cartes. Les
/// trois écrans qui affichaient ces chiffres les lisaient chacun de leur côté, et un deck de
/// deux cents cartes payait trois fois le même travail à chaque ouverture.
struct DeckFacts: Equatable {
    var percent: Int
    var dueCount: Int
    /// Cartes jamais découvertes.
    var undiscovered: Int
    /// Cartes neuves que le plafond du jour autorise encore.
    var newRemaining: Int
    /// L'épreuve la plus proche qui porte sur ce deck. Elle porte la date **et** l'examen
    /// blanc : les séparer obligerait à relire les examens une seconde fois pour retrouver
    /// celui dont on vient d'afficher la date.
    var exam: Exam?

    var deadline: Date? { exam?.date }

    static let empty = DeckFacts(percent: 0, dueCount: 0, undiscovered: 0, newRemaining: 0, exam: nil)

    static func read(_ course: Course, in context: ModelContext, now: Date = Date()) -> DeckFacts {
        let cards = course.cards
        let exams = (try? context.fetch(FetchDescriptor<Exam>())) ?? []
        let logs = ExamReadiness.recentLogsByCard(in: context)

        var due = 0
        var undiscovered = 0
        for card in cards where !card.isSuspended {
            if card.isDue(at: now) { due += 1 }
            if card.state == .new { undiscovered += 1 }
        }

        return DeckFacts(
            percent: ExamReadiness.masteryPercent(of: cards, logs: logs, now: now),
            dueCount: due,
            undiscovered: undiscovered,
            newRemaining: DeckPace.remainingToday(
                for: course,
                exams: exams,
                logs: logs.values.flatMap { $0 },
                now: now
            ),
            exam: nextExam(for: course, exams: exams, now: now)
        )
    }

    /// L'épreuve à venir la plus proche qui porte sur ce deck.
    private static func nextExam(
        for course: Course,
        exams: [Exam],
        now: Date,
        calendar: Calendar = MicaboCalendar.shared
    ) -> Exam? {
        let today = calendar.startOfDay(for: now)
        return exams
            .filter { $0.courseIDs.contains(course.id) && calendar.startOfDay(for: $0.date) >= today }
            .min { $0.date < $1.date }
    }
}
