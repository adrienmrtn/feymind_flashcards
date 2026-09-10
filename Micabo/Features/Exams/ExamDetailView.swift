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

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    /// Ce que la fiche affiche, **calculé une fois** par ouverture et par synchro.
    ///
    /// La première version le calculait dans des propriétés lues par le corps : chaque rendu
    /// reparcourait `course.cards` sur chaque cours et `card.logs` sur chaque carte, une
    /// requête à chaque fois. Sur un compte de plusieurs cours, la fiche bégayait au moindre
    /// appui.
    private struct Figures {
        var masteryPercent = 0
        var cardCount = 0
        var programme: [(course: Course, cards: Int, percent: Int)] = []
        var weak: [ExamReadiness.WeakCard] = []
        var canRunMock = false
    }

    @State private var figures = Figures()
    @State private var sessions: [MockSessionRecord] = []
    @State private var sessionsLoaded = false
    @State private var editing = false
    @State private var askingMicrophone = false
    @State private var writing = false
    /// La copie ouverte en plein écran.
    @State private var paper: MockSessionRecord?
    /// Un blanc passé qu'on relit.
    @State private var report: MockSessionRecord?
    @State private var errorMessage: String?

    private let calendar = MicaboCalendar.shared
    private let today = Date()

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        i18n?.t(key, vars) ?? L10n.t(key, locale: .resolved(), vars: vars)
    }

    // MARK: - Ce qu'on lit

    private var masteryPercent: Int { figures.masteryPercent }
    private var weak: [ExamReadiness.WeakCard] { figures.weak }
    private var canRunMock: Bool { figures.canRunMock }

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
    private var open: MockSessionRecord? {
        sessions.first { !$0.isFinished && !$0.questions.isEmpty }
    }

    /// Ce qui fait recalculer les chiffres : l'épreuve, ses cours, une synchro.
    private var figuresKey: String {
        "\(exam.id)-\(exam.updatedAt.timeIntervalSince1970)-\(courses.count)-\(sync?.epoch ?? 0)"
    }

    /// Deux lectures de table - les cartes, le journal - puis tout se range en mémoire.
    private func loadFigures() {
        let wanted = Set(exam.courseIDs)
        let programme = courses.filter { wanted.contains($0.id) }
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
                return (course: course, cards: own.count, percent: ExamReadiness.masteryPercent(of: own, logs: logs, now: today))
            },
            weak: ExamReadiness.weakCards(in: cards, logs: logs, now: today),
            canRunMock: MockExamService.canRun(exam: exam, in: programme)
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
                mockSection
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
        .task(id: exam.id) { await loadSessions() }
        .overlay {
            if writing {
                writingOverlay
            }
        }
        .sheet(isPresented: $editing, onDismiss: {
            // L'épreuve supprimée depuis le formulaire n'a plus de fiche à montrer.
            if exam.isDeleted { dismiss() }
        }) {
            ExamEditorSheet(exam: exam, suggestedDate: exam.date)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(MicaboRadius.sheet)
        }
        .sheet(isPresented: $askingMicrophone) {
            StartMockSheet { withAudio in
                startMock(withAudio: withAudio)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .fullScreenCover(item: $paper) { session in
            MockPaperView(session: session, examName: exam.name) { closed in
                paper = nil
                if let closed {
                    sessions = [closed] + sessions.filter { $0.id != closed.id }
                }
            }
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

                MicaboHairline(inset: MicaboSpacing.md)

                Text(progressNote)
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(MicaboSpacing.md)
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
                    .font(MicaboFont.hanken(15, weight: .semibold))
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

    private var progressNote: String {
        let mastery = t("app.plan.sheet.lead", ["percent": "\(masteryPercent)", "cards": "\(figures.cardCount)"])
        if finished.isEmpty {
            return "\(mastery) \(t("app.exam.progress.noMock"))"
        }
        if finished.count == 1, let only = finished.first {
            return "\(mastery) \(t("app.exam.progress.single", ["score": "\(only.score)", "day": MicaboCalendar.shortDayLabel(only.finished_at ?? only.started_at)]))"
        }
        return mastery
    }

    // MARK: - L'examen blanc

    private var mockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: t("app.mock.panelTitle"))

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
                    Text(t("app.mock.panelLead"))
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let open {
                        Button {
                            paper = open
                        } label: {
                            HStack(spacing: MicaboSpacing.xs) {
                                Image(systemName: "arrow.forward.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(t("ios.mock.resume"))
                            }
                        }
                        .buttonStyle(MicaboPrimaryButtonStyle())
                    } else {
                        Button {
                            askingMicrophone = true
                        } label: {
                            HStack(spacing: MicaboSpacing.xs) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(t("app.mock.start"))
                            }
                        }
                        .buttonStyle(MicaboPrimaryButtonStyle(tint: canRunMock && isSignedIn ? MicaboColor.accent : MicaboColor.strokeStrong))
                        .disabled(!canRunMock || !isSignedIn || writing)
                    }

                    if !isSignedIn {
                        Text(t("app.errors.signIn"))
                            .font(MicaboFont.micro)
                            .foregroundStyle(MicaboColor.inkTertiary)
                    } else if !canRunMock {
                        Text(t("app.mock.tooFew"))
                            .font(MicaboFont.micro)
                            .foregroundStyle(MicaboColor.inkTertiary)
                    }
                }
                .padding(MicaboSpacing.md)

                MicaboHairline(inset: MicaboSpacing.md)

                if finished.isEmpty {
                    Text(sessionsLoaded ? t("app.mock.none") : t("app.exams.wait"))
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .padding(MicaboSpacing.md)
                } else {
                    ForEach(Array(finished.enumerated()), id: \.element.id) { index, session in
                        mockRow(session)
                        if index < finished.count - 1 {
                            MicaboHairline(inset: 71)
                        }
                    }
                }
            }
            .micaboGroup()
        }
    }

    /// Un blanc passé : la note, le jour, et le détail derrière.
    private func mockRow(_ session: MockSessionRecord) -> some View {
        Button {
            report = session
        } label: {
            HStack(spacing: 13) {
                MicaboTile(
                    glyph: .symbol("doc.text"),
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
                            MicaboHairline(inset: 71)
                        }
                    }
                }
                .micaboGroup()
            }
        }
    }

    private func courseRow(_ course: Course, cards: Int, percent: Int) -> some View {
        HStack(spacing: 13) {
            MicaboTile.course(course)

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
                Text(t("app.plan.sheet.weakLead"))
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(MicaboSpacing.md)

                MicaboHairline(inset: MicaboSpacing.md)

                ForEach(Array(weak.enumerated()), id: \.element.id) { index, card in
                    weakRow(card)
                    if index < weak.count - 1 {
                        MicaboHairline(inset: MicaboSpacing.md)
                    }
                }

                MicaboHairline(inset: MicaboSpacing.md)

                Text(t("app.plan.sheet.weakHint"))
                    .font(MicaboFont.micro)
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(MicaboSpacing.md)
            }
            .micaboGroup()
        }
    }

    private func weakRow(_ card: ExamReadiness.WeakCard) -> some View {
        HStack(alignment: .top, spacing: MicaboSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(card.front)
                    .font(MicaboFont.hanken(14, weight: .medium))
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

    // MARK: - Le temps d'écrire la copie

    /// La copie s'écrit sur le serveur, et ça prend le temps d'une génération. On le dit, et
    /// on couvre l'écran : un bouton qu'on pourrait toucher deux fois ouvrirait deux copies.
    private var writingOverlay: some View {
        ZStack {
            MicaboColor.ink.opacity(0.18).ignoresSafeArea()
            VStack(spacing: MicaboSpacing.sm) {
                ProgressView()
                    .tint(MicaboColor.accent)
                Text(t("ios.mock.writing"))
                    .font(MicaboFont.captionEmphasis)
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
            }
            .padding(MicaboSpacing.lg)
            .frame(maxWidth: 260)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private func loadSessions() async {
        guard let mocks, isSignedIn else {
            sessionsLoaded = true
            return
        }
        do {
            sessions = try await mocks.sessions(for: exam.id)
        } catch {
            // Une liste qu'on ne peut pas lire n'est pas une panne à annoncer : la fiche
            // reste utile sans elle, et la prochaine ouverture réessaiera.
        }
        sessionsLoaded = true
    }

    private func startMock(withAudio: Bool) {
        guard let mocks, !writing else { return }
        withAnimation(.easeOut(duration: 0.2)) { writing = true }
        Task {
            do {
                let session = try await mocks.start(exam: exam, courses: courses, withAudio: withAudio)
                sessions = [session] + sessions
                withAnimation(.easeOut(duration: 0.2)) { writing = false }
                paper = session
            } catch {
                withAnimation(.easeOut(duration: 0.2)) { writing = false }
                Haptics.warning()
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func tone(for score: Int) -> Color {
        score >= 75 ? MicaboColor.positive : score >= 50 ? MicaboColor.caution : MicaboColor.negative
    }

    private func soft(for score: Int) -> Color {
        score >= 75 ? MicaboColor.positiveSoft : score >= 50 ? MicaboColor.cautionSoft : MicaboColor.negativeSoft
    }
}

// MARK: - As-tu un micro ?

/// **La seule question qui change la copie.** Répondre oui ajoute des questions Feynman,
/// répondues à l'oral. Elle est posée avant l'ouverture, et pas au milieu : une autorisation
/// demandée pendant l'épreuve arrête le chronomètre dans la tête de l'étudiant.
struct StartMockSheet: View {
    var onChoose: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var asking = false
    @State private var failed: String?

    private func t(_ key: String) -> String {
        i18n?.t(key) ?? L10n.t(key, locale: .resolved())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                    Text(t("app.mock.micLead"))
                        .font(MicaboFont.body)
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        askMicrophone()
                    } label: {
                        HStack(spacing: MicaboSpacing.xs) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(asking ? t("app.exams.wait") : t("app.mock.micYes"))
                        }
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle())
                    .disabled(asking)

                    Button {
                        choose(false)
                    } label: {
                        Text(t("app.mock.micNo"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MicaboSecondaryButtonStyle())
                    .disabled(asking)

                    Text(t("app.mock.micHint"))
                        .font(MicaboFont.micro)
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let failed {
                        Text(failed)
                            .font(MicaboFont.caption)
                            .foregroundStyle(MicaboColor.negative)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.md)
                .padding(.bottom, MicaboSpacing.xxl)
            }
            .micaboScreenBackground()
            .navigationTitle(t("app.mock.micTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("app.common.cancel")) { dismiss() }
                }
            }
        }
    }

    /// Demander le micro **et** la reconnaissance pour de vrai, avant de composer la copie.
    /// Sans ça, on écrirait trois questions orales à quelqu'un qui a refusé l'accès, et il le
    /// découvrirait une fois le chronomètre lancé.
    private func askMicrophone() {
        asking = true
        failed = nil
        Task {
            let dictation = Dictation()
            let ready = await dictation.prepare()
            asking = false
            if ready {
                choose(true)
            } else {
                Haptics.warning()
                failed = dictation.availability == .denied ? t("app.mock.micDenied") : t("app.mock.micBroken")
            }
        }
    }

    private func choose(_ withAudio: Bool) {
        Haptics.selection()
        dismiss()
        onChoose(withAudio)
    }
}
