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
/// 4. **Le reste** — les cartes, l'examen blanc, les réglages du deck.
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

    private var tint: Color { Color(hexString: course.accentHex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                header
                statusCard
                DeckChaptersView(course: course)
                extras
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
        .navigationDestination(for: Chapter.self) { chapter in
            ChapterSheetView(chapter: chapter)
        }
        .navigationDestination(item: $cardsRoute) { route in
            FlashcardsView(course: route.course)
        }
        .navigationDestination(for: Exam.self) { exam in
            ExamDetailView(exam: exam)
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
            reload()
            Analytics.track(.sheetOpened, [
                "written": .flag(course.hasSheet),
                "source": .text(course.source.rawValue),
                "chapters": .number(Double(course.orderedChapters.count)),
            ])
            await presentGiftIfEarned()
        }
        .micaboPaywall($paywall)
        .micaboDiscountOffer($giftOffer)
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

    private var header: some View {
        MicaboScreenHeader(
            title: course.title,
            eyebrow: course.subject?.nilIfBlank ?? course.source.label,
            tile: MicaboTile.course(course, size: 52),
            back: MicaboHeaderBack.back { dismiss() }
        ) {
            deckMenu
        }
        .padding(.top, MicaboSpacing.xs)
    }

    private var deckMenu: some View {
        Menu {
            Button {
                draftTitle = course.title
                showRename = true
            } label: {
                Label(i18n.t("ios.deck.rename"), systemImage: "pencil")
            }

            Button {
                cardsRoute = CourseCardsRoute(course: course)
            } label: {
                Label(MicaboCopy.cards(course.cards.count), systemImage: "rectangle.on.rectangle.angled")
            }

            Divider()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(i18n.t("app.common.delete"), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .frame(width: 34, height: 34)
                .background(MicaboColor.surfaceMuted, in: Circle())
        }
    }

    // MARK: - Où j'en suis

    /// **Le pourcentage du deck et sa date, dans le même bloc.**
    ///
    /// Les deux répondent à la même question — « où j'en suis par rapport à ce qui
    /// m'attend » — et les séparer obligeait à les rapprocher de tête. Le compte à rebours
    /// n'est pas une décoration : c'est lui qui explique pourquoi le nombre de cartes neuves
    /// du jour est ce qu'il est.
    private var statusCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: MicaboSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(facts.percent) %")
                        .font(MicaboFont.number(34, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    Text(i18n.t("ios.deck.globalMastery"))
                        .font(MicaboFont.ui(12.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Spacer(minLength: MicaboSpacing.xs)

                if let deadline = facts.deadline {
                    deadlineBadge(deadline)
                }
            }
            .padding(MicaboSpacing.md)

            MicaboHairline()

            paceRow
                .padding(.horizontal, MicaboSpacing.md)
                .padding(.vertical, 12)
        }
        .micaboGroup()
    }

    private func deadlineBadge(_ deadline: Date) -> some View {
        let days = DeckPace.daysUntil(deadline)
        return VStack(alignment: .trailing, spacing: 2) {
            Text(days <= 0
                ? i18n.t("app.exams.countdown.today")
                : i18n.t("ios.examDaysLeft", ["n": "\(days)"]))
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(days < DeckPace.crunchDays ? MicaboColor.ratingAgain : MicaboColor.ink)

            Text(deadline.formatted(date: .abbreviated, time: .omitted))
                .font(MicaboFont.ui(12, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
    }

    /// **Le rythme, et d'où il vient.**
    ///
    /// C'est la seule chose que la date change, et c'est donc la seule chose qu'on annonce à
    /// côté d'elle. Un étudiant qui trouve sa session trop lourde doit pouvoir remonter en
    /// une lecture jusqu'à la cause, qui est sa propre réponse à « c'est quand ? ».
    private var paceRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)

            Text(
                facts.newRemaining > 0
                    ? i18n.t("ios.deck.newToday", ["count": "\(facts.newRemaining)"])
                    : i18n.t("ios.deck.newDone")
            )
            .font(MicaboFont.ui(13, weight: .medium))
            .foregroundStyle(MicaboColor.inkSecondary)

            Spacer(minLength: 0)

            if facts.undiscovered > 0 {
                Text(i18n.t("ios.deck.leftToDiscover", ["count": "\(facts.undiscovered)"]))
                    .font(MicaboFont.ui(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
    }

    // MARK: - Le reste

    private var extras: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: i18n.t("ios.deck.more"))

            VStack(spacing: 0) {
                Button {
                    cardsRoute = CourseCardsRoute(course: course)
                } label: {
                    MicaboRow(
                        tile: MicaboTile(
                            glyph: .symbol("rectangle.on.rectangle.angled"),
                            background: tint.lightened(by: 0.84),
                            tint: tint.darkened(by: 0.25)
                        ),
                        title: MicaboCopy.cards(course.cards.count),
                        subtitle: i18n.t("ios.deck.cardsHint"),
                        accessory: .chevron
                    )
                }
                .buttonStyle(MicaboRowButtonStyle())

                // **L'examen blanc a quitté son onglet pour venir ici.** Il ne porte que sur
                // ce deck ; le chercher dans un écran qui listait toutes les épreuves du
                // compte n'avait de sens que tant que cet écran existait. La rangée n'existe
                // que s'il y a une épreuve : proposer un examen blanc à quelqu'un qui révise
                // sans date, c'est lui proposer de s'entraîner à rien.
                if let exam = facts.exam {
                    MicaboHairline(inset: 72)

                    NavigationLink(value: exam) {
                        MicaboRow(
                            tile: MicaboTile.exam(exam.date),
                            title: i18n.t("ios.deck.exam"),
                            subtitle: exam.countdownLabel(),
                            accessory: .chevron
                        )
                    }
                    .buttonStyle(MicaboRowButtonStyle())
                }
            }
            .micaboGroup()
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
                .buttonStyle(MicaboPrimaryButtonStyle())
            } else {
                Button(action: startSession) {
                    Text(sessionButtonTitle)
                }
                .buttonStyle(MicaboPrimaryButtonStyle())
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
