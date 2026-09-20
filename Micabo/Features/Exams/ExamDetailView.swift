import SwiftData
import SwiftUI

/// **La fiche d'une épreuve**, la même que sur le site.
///
/// Elle répond à deux questions que la liste ne peut pas poser sans se charger : **où j'en suis
/// sur cette épreuve**, et **sur quoi je me plante**. Et elle porte l'examen blanc, qui est la
/// seule mesure du produit qui ne soit pas une estimation.
///
/// Avant, toucher un examen ouvrait son formulaire. Le formulaire reste, derrière le crayon :
/// on ne modifie pas une épreuve tous les jours, on regarde où l'on en est tous les jours.
struct ExamDetailView: View {
    let exam: Exam

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(MockExamService.self) private var mocks: MockExamService?
    @Environment(AuthController.self) private var auth: AuthController?
    @Environment(CloudSync.self) private var sync: CloudSync?

    /// Ce que la fiche affiche, **calculé une fois** par ouverture et par synchro.
    ///
    /// La première version le calculait dans des propriétés lues par le corps : chaque rendu
    /// reparcourait `course.cards` sur chaque cours et `card.logs` sur chaque carte, une
    /// requête à chaque fois. Sur un compte de plusieurs cours, la fiche bégayait au moindre
    /// appui.
    private struct Figures {
        var masteryPercent = 0
        var cardCount = 0
        /// **Des projections, pas des cours.** Ce tableau vit dans un `@State` pour toute la
        /// durée de la fiche poussée : y garder des `Course` managés, c'était y garder leurs
        /// trente kilo-octets de texte, et rester abonné à leurs changements. `CourseBadge`
        /// n'en retient que ce que les rangées dessinent.
        var programme: [(course: CourseBadge, cards: Int, percent: Int)] = []
        var weak: [ExamReadiness.WeakCard] = []
        /// Cartes prévues par décalage depuis aujourd'hui. C'est ce que porte chaque case.
        var load: [Int] = []
    }

    @State private var figures = Figures()
    @State private var sessions: [MockSessionRecord] = []
    @State private var editing = false
    /// Les rendez-vous déplacés, tels qu'ils reviennent du serveur.
    @State private var overrides: [AgendaOverride] = []
    /// Le rendez-vous dont on a ouvert la fiche pour le déplacer.
    @State private var moving: AgendaEvent?
    /// Un blanc passé qu'on relit.
    @State private var report: MockSessionRecord?
    @State private var errorMessage: String?

    private let calendar = MicaboCalendar.shared
    private let today = Date()

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        i18n.t(key, vars)
    }

    // MARK: - Ce qu'on lit

    private var masteryPercent: Int { figures.masteryPercent }
    private var weak: [ExamReadiness.WeakCard] { figures.weak }

    private var targetPercent: Int {
        TargetScore.percent(from: exam.targetScore)
    }

    /// Ce que la jauge montre : la maîtrise des cartes, **poussée** par le dernier blanc et
    /// non remplacée par lui. Les deux chiffres du haut restent entiers à côté.
    private var readingPercent: Int {
        ExamReadiness.blend(
            mastery: figures.masteryPercent,
            score: finished.first?.score,
            finishedAt: finished.first?.finished_at,
            now: today
        )
    }

    private var finished: [MockSessionRecord] {
        sessions.filter(\.isFinished)
    }

    /// Une copie ouverte et jamais remise : on la reprend, on n'en ouvre pas une deuxième.
    private var figuresKey: String {
        // `CourseLedger.stamp` remplace le `courses.count` qui vivait ici : il dit la même
        // chose — la liste des cours a bougé — sans tenir la table pour le dire.
        "\(exam.id)-\(exam.updatedAt.timeIntervalSince1970)-\(CourseLedger.shared.stamp)-\(sync?.epoch ?? 0)"
    }

    /// Deux lectures de table - les cartes, le journal - puis tout se range en mémoire.
    private func loadFigures() {
        let wanted = Set(exam.courseIDs)
        // Les cours de l'épreuve, lus ici plutôt que tenus par un `@Query`. Les objets ne
        // sortent pas de cette fonction : seules leurs projections entrent dans `figures`.
        let programme = ExamRepository.courses(of: exam, in: modelContext)
        let all = CourseRepository.allCards(in: modelContext)
        var byCourse: [UUID: [Flashcard]] = [:]
        for card in all where !card.isSuspended {
            guard let courseID = card.course?.id, wanted.contains(courseID) else { continue }
            byCourse[courseID, default: []].append(card)
        }
        let cards = programme.flatMap { byCourse[$0.id] ?? [] }
        let logs = ExamReadiness.recentLogsByCard(in: modelContext, now: today)

        figures = Figures(
            masteryPercent: ExamReadiness.masteryPercent(of: cards, logs: logs, now: today),
            cardCount: cards.count,
            programme: programme.map { course in
                let own = byCourse[course.id] ?? []
                return (
                    course: CourseBadge(course),
                    cards: own.count,
                    percent: ExamReadiness.masteryPercent(of: own, logs: logs, now: today)
                )
            },
            weak: ExamReadiness.weakCards(in: cards, logs: logs, now: today),
            // La même projection que la page de plan : le calendrier ne recalcule pas sa
            // charge de son côté, sinon deux écrans annonceraient deux journées différentes.
            load: ExamRepository.plan(
                cards: cards,
                date: exam.date,
                intensity: exam.intensity,
                offDays: ExamRepository.offDayOffsets(until: exam.date, stamps: OffDays.stamps(in: modelContext), now: today),
                now: today
            ).projection.load
        )
    }

    private var isSignedIn: Bool {
        auth?.user != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                header
                progressSection
                agendaSection
                programmeSection
                if !weak.isEmpty {
                    weakSection
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)
            .padding(.bottom, MicaboLayout.bottomBarClearance)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .task(id: figuresKey) { loadFigures() }
        .task(id: exam.id) { await loadAgenda() }
        .sheet(isPresented: $editing, onDismiss: {
            // L'épreuve supprimée depuis le formulaire n'a plus de fiche à montrer.
            if exam.isDeleted { dismiss() }
        }) {
            ExamEditorSheet(exam: exam, suggestedDate: exam.date)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(MicaboRadius.sheet)
        }
        .sheet(item: $moving) { event in
            AgendaEventSheet(
                event: event,
                examDay: calendar.startOfDay(for: exam.date),
                plannedDate: plannedDate(of: event)
            ) { date in
                move(event, to: date)
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .sheet(item: $report) { session in
            NavigationStack {
                MockReportView(session: session, examName: exam.name) {
                    report = nil
                }
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .alert(t("app.common.oops"), isPresented: .constant(errorMessage != nil)) {
            Button(t("app.a11y.close"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - En-tête

    private var header: some View {
        MicaboScreenHeader(
            title: exam.name,
            eyebrow: "\(MicaboCalendar.dayLabel(exam.date, from: today)) · \(exam.countdownLabel(from: today, calendar: calendar))",
            back: .back { dismiss() }
        ) {
            Button {
                editing = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 38, height: 38)
                    .background(MicaboColor.surface, in: Circle())
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(t("ios.edit"))
        }
        .padding(.top, MicaboSpacing.xs)
    }

    // MARK: - Où tu en es

    /// Deux chiffres côte à côte : ce que les cartes disent, et ce que le dernier blanc a mesuré.
    /// Le second manque souvent, et la phrase du bas dit alors pourquoi il vaut le quart d'heure.
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: t("app.exam.progress.title"))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: MicaboSpacing.md) {
                    figure(label: t("app.exam.progress.now"), value: masteryPercent, tint: MicaboColor.accent)
                    if let last = finished.first {
                        figure(label: t("app.exam.progress.measured"), value: last.score, tint: tone(for: last.score))
                    }
                }
                .padding(.horizontal, MicaboSpacing.md)
                .padding(.top, MicaboSpacing.md)

                gauge
                    .padding(.horizontal, MicaboSpacing.md)
                    .padding(.top, MicaboSpacing.sm)
                    .padding(.bottom, MicaboSpacing.md)

                // Le mot n'apparaît que tant qu'aucun blanc n'a été passé : c'est alors une
                // invitation. Une fois le second chiffre là, il ne dirait plus que ce que les
                // deux chiffres disent déjà.
                if finished.isEmpty {
                    MicaboHairline(inset: MicaboSpacing.md)

                    Text(t("app.exam.progress.noMock"))
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(MicaboSpacing.md)
                }
            }
            .micaboGroup()
        }
    }

    private func figure(label: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(MicaboFont.micro)
                .foregroundStyle(MicaboColor.inkTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(MicaboFont.number(30, weight: .bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("%")
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// La barre de maîtrise, avec l'objectif posé dessus : on voit l'écart sans lire deux chiffres.
    private var gauge: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MicaboColor.surfaceMuted)
                    Capsule()
                        .fill(MicaboColor.accent)
                        .frame(width: proxy.size.width * CGFloat(max(2, readingPercent)) / 100)
                    Rectangle()
                        .fill(MicaboColor.ink)
                        .frame(width: 2, height: 12)
                        .offset(x: proxy.size.width * CGFloat(targetPercent) / 100 - 1)
                }
            }
            .frame(height: 8)

            Text(t("app.chart.mock.target", ["percent": "\(targetPercent)"]))
                .font(MicaboFont.micro)
                .foregroundStyle(MicaboColor.inkTertiary)
        }
    }


    // MARK: - L'agenda

    /// **Le calendrier de l'épreuve, et les mesures déjà passées.**
    ///
    /// La page portait un bouton « passer un examen blanc ». Il n'y est plus, et c'est
    /// délibéré : cette page dit **ce qui est prévu**, le travail se lance depuis « Au
    /// programme » le jour venu, avec le reste de la journée. Deux écrans qui proposent la même
    /// chose obligent l'étudiant à se demander lequel est le bon, et celui qui la propose hors
    /// de son jour casse la cadence que le plan vient de poser.
    ///
    /// L'historique reste : c'est par lui qu'on relit un débriefing, et le calendrier ne dit
    /// que l'état d'un rendez-vous, pas ce qu'on y a répondu.
    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: t("app.exam.schedule.title"))

            ExamAgendaCalendar(
                exam: exam,
                events: agenda,
                load: figures.load,
                onPick: { moving = $0 },
                now: today
            )

            if !finished.isEmpty {
                MicaboSectionCaption(text: t("app.exam.progress.mocks"))
                    .padding(.top, MicaboSpacing.xs)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(finished.enumerated()), id: \.element.id) { index, session in
                        mockRow(session)
                        if index < finished.count - 1 {
                            MicaboHairline(inset: 72)
                        }
                    }
                }
                .micaboGroup()
            }
        }
    }

    /// Les rendez-vous de l'épreuve, dérivés à chaque rendu.
    ///
    /// Le calcul est court - deux blancs et huit parcours au plus - et le dériver ici plutôt
    /// que de le garder en état évite qu'il vieillisse : une session qui se ferme ou une date
    /// qu'on déplace doit changer la grille tout de suite.
    private var agenda: [AgendaEvent] {
        ExamAgenda.events(
            for: exam,
            cardCount: figures.cardCount,
            done: MockExamService.done(from: sessions),
            overrides: overrides,
            now: today,
            calendar: calendar
        )
    }

    /// La date que la dérivation donnerait à un rendez-vous, sans les déplacements.
    ///
    /// C'est ce que la fiche affiche à côté de « déplacé » : sans elle, le mot ne dit pas de
    /// combien ni depuis quand.
    private func plannedDate(of event: AgendaEvent) -> Date? {
        guard event.moved else { return nil }
        return ExamAgenda.events(
            for: exam,
            cardCount: figures.cardCount,
            done: [],
            overrides: [],
            now: today,
            calendar: calendar
        )
        .first { $0.kind == event.kind && $0.slot == event.slot }?
        .date
    }

    /// **Ce que l'agenda ne peut pas dériver : ce qui a été fait, et ce qui a été déplacé.**
    ///
    /// Le reste - quels rendez-vous existent et quand ils tombent - se recalcule depuis la
    /// date de l'épreuve à chaque rendu. Ces deux lectures-là ne se devinent pas.
    ///
    /// Les deux partent ensemble : en file, la grille se dessinerait une première fois sans
    /// les déplacements, et les rendez-vous sauteraient d'un jour sous les yeux de l'étudiant.
    ///
    /// Une lecture qui échoue laisse la grille sur ses rendez-vous dérivés plutôt que sur une
    /// page vide : c'est encore le bon calendrier, moins l'état de ce qui est passé.
    private func loadAgenda() async {
        guard let mocks else { return }
        do {
            async let passed = mocks.sessions(for: exam.id)
            async let moved = mocks.overrides(for: exam.id)
            (sessions, overrides) = try await (passed, moved)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func move(_ event: AgendaEvent, to date: Date?) {
        guard let mocks else { return }
        Task {
            do {
                try await mocks.move(event, to: date)
                overrides = try await mocks.overrides(for: exam.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Un blanc passé : la note, le jour, et le détail derrière.
    private func mockRow(_ session: MockSessionRecord) -> some View {
        Button {
            report = session
        } label: {
            HStack(spacing: 13) {
                MicaboTile(
                    glyph: .symbol(session.kind == AgendaKind.parcours.rawValue ? "target" : "doc.text"),
                    background: soft(for: session.score),
                    tint: tone(for: session.score)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(session.score) %")
                        .font(MicaboFont.rowTitle)
                        .foregroundStyle(MicaboColor.ink)
                        .monospacedDigit()

                    Text("\(MicaboCalendar.shortDayLabel(session.finished_at ?? session.started_at)) · \(t("app.mock.outOf", ["correct": "\(session.correct_count)", "total": "\(session.question_count)"]))")
                        .font(MicaboFont.rowSubtitle)
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: MicaboSpacing.xs)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary.opacity(0.8))
            }
            .padding(.vertical, 11)
            .padding(.horizontal, MicaboSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboRowButtonStyle())
    }

    // MARK: - Le programme

    private var programmeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: t("app.plan.sheet.programTitle"))

            if figures.programme.isEmpty {
                MicaboSectionFootnote(text: t("app.errors.pickACourse"))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(figures.programme.enumerated()), id: \.element.course.id) { index, entry in
                        courseRow(entry.course, cards: entry.cards, percent: entry.percent)
                        if index < figures.programme.count - 1 {
                            MicaboHairline(inset: 72)
                        }
                    }
                }
                .micaboGroup()
            }
        }
    }

    private func courseRow(_ course: CourseBadge, cards: Int, percent: Int) -> some View {
        HStack(spacing: 13) {
            MicaboTile.course(badge: course)

            VStack(alignment: .leading, spacing: 3) {
                Text(course.title)
                    .font(MicaboFont.rowTitle)
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(2)

                Text(t("app.plan.sheet.courseLine", ["cards": "\(cards)", "percent": "\(percent)"]))
                    .font(MicaboFont.rowSubtitle)
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: MicaboSpacing.xs)

            ZStack(alignment: .leading) {
                Capsule().fill(MicaboColor.surfaceMuted)
                Capsule()
                    .fill(MicaboColor.accent)
                    .frame(width: 64 * CGFloat(max(2, percent)) / 100)
            }
            .frame(width: 64, height: 6)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, MicaboSpacing.md)
    }

    // MARK: - Ce qui résiste

    private var weakSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: t("app.plan.sheet.weakTitle"))

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(weak.enumerated()), id: \.element.id) { index, card in
                    weakRow(card)
                    if index < weak.count - 1 {
                        MicaboHairline(inset: MicaboSpacing.md)
                    }
                }
            }
            .micaboGroup()
        }
    }

    private func weakRow(_ card: ExamReadiness.WeakCard) -> some View {
        HStack(alignment: .top, spacing: MicaboSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.front)
                    .font(MicaboFont.ui(14, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(2)
                Text(t("app.plan.sheet.weakLine", ["again": "\(card.againCount)", "reviews": "\(card.reviews)"]))
                    .font(MicaboFont.rowSubtitle)
                    .foregroundStyle(MicaboColor.inkTertiary)
            }

            Spacer(minLength: MicaboSpacing.xs)

            if card.isStubborn {
                MicaboBadge(text: t("app.plan.sheet.stubborn"), tone: .warm)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, MicaboSpacing.md)
    }

    private func tone(for score: Int) -> Color {
        score >= 75 ? MicaboColor.positive : score >= 50 ? MicaboColor.caution : MicaboColor.negative
    }

    private func soft(for score: Int) -> Color {
        score >= 75 ? MicaboColor.positiveSoft : score >= 50 ? MicaboColor.cautionSoft : MicaboColor.negativeSoft
    }
}
