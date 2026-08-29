import SwiftData
import SwiftUI

/// Écran d'ouverture de l'app : **Réviser**. Le chiffre du jour, et ce qu'il contient.
///
/// Il ne parle que de la révision du jour : pas de date, pas de liste de cours, pas de
/// bouton d'import — tout ça vit dans l'onglet Cours. Le bouton de session est ancré en bas,
/// donc visible sans faire défiler : entre le lancement de l'app et la première carte, il
/// n'y a qu'un appui.
///
/// **Le haut de l'écran a été refait.** Il portait une salutation en grand
/// (« Bonsoir »), un sur-titre de série, un nombre de 76 points posé à même le fond avec
/// deux lignes de légende à sa droite, une barre segmentée sans légende, puis un bloc
/// « Répartition » qui redonnait en rangées les trois chiffres de la barre. Beaucoup de
/// hauteur, trois niveaux de gris, et deux fois la même information.
///
/// Il ne reste qu'un titre d'écran, la série en pastille à sa droite, et **une seule carte**
/// qui porte le chiffre, la durée, la barre et sa légende. La barre devient lisible parce
/// qu'elle est légendée juste dessous, et le bloc « Répartition » disparaît puisque c'est
/// exactement ce que la légende dit.
struct TodayView: View {
    @Query private var allCards: [Flashcard]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]
    @Query private var reviewLogs: [ReviewLog]
    @Query(sort: \Exam.date, order: .forward) private var exams: [Exam]

    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(TabRouter.self) private var router: TabRouter?

    @State private var showStudy = false
    @State private var path = NavigationPath()
    @State private var showImportChoice = false
    @State private var pendingImport: ImportKind?
    @State private var activeImport: ImportKind?
    /// Un paquet de cartes ne passe pas par l'écran d'import : il n'y a rien à lire.
    @State private var isCreatingDeck = false
    @State private var paywall: PaywallTrigger?

    /// Les échéances d'examen en cours. Elles ordonnent les neuves, sans lever le plafond.
    private var deadlines: ExamDeadlines {
        ExamDeadlines.active(exams: exams, courses: courses)
    }

    /// Ce qui a déjà été introduit aujourd'hui, y compris depuis un cours.
    private var introducedToday: Int {
        DailyNewQuota.introducedToday(from: reviewLogs)
    }

    private var newRemaining: Int {
        DailyNewQuota.remaining(introduced: introducedToday)
    }

    /// La file telle que la session va la servir : le plafond de cartes neuves du **jour**,
    /// pas d'un écran. Une session depuis un cours a déjà consommé ce budget.
    private var dueCards: [Flashcard] {
        StudyQueueBuilder.build(
            from: allCards,
            limits: .daily(newRemaining: newRemaining),
            deadlines: deadlines
        )
    }

    private var nextExam: Exam? {
        upcomingExams.first
    }

    private var upcomingExams: [Exam] {
        Array(exams.filter { !$0.isPast() }.prefix(5))
    }

    /// Cartes neuves dues mais gardées pour les jours suivants, à cause du plafond.
    private var heldBackNewCards: Int {
        let dueNew = allCards.filter { $0.isDue() && $0.state == .new }.count
        return max(0, dueNew - newCount)
    }

    private var newCount: Int {
        dueCards.filter { $0.state == .new }.count
    }

    private var learningCount: Int {
        dueCards.filter { $0.state == .learning || $0.state == .relearning }.count
    }

    private var reviewCount: Int {
        dueCards.filter { $0.state == .review }.count
    }

    private var coursesWithDue: Int {
        Set(dueCards.compactMap { $0.course?.id }).count
    }

    private var estimatedMinutes: Int {
        max(1, Int((Double(dueCards.count) * 30 / 60).rounded(.up)))
    }

    private var streak: Int {
        StudyStats.streak(reviewDates: reviewLogs.map(\.reviewedAt))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    header

                    if dueCards.isEmpty && heldBackNewCards == 0 {
                        restState
                    } else if dueCards.isEmpty {
                        rhythmReachedCard
                        dueCoursesSection
                    } else {
                        dueCard
                        dueCoursesSection
                    }

                    examSection
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.md)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            // Le bouton de session se pose au-dessus de la barre d'onglets, et la page
            // réserve la hauteur des deux. C'est la page qui doit le faire : l'inset de la
            // racine ne franchit pas la frontière du `NavigationStack`, et le premier appui
            // de l'app passait sous la barre dès qu'il apparaissait — voir
            // `tabBarClearance`.
            .tabBarClearance {
                if hasSessionButton {
                    MicaboBottomBar {
                        Button(action: startSession) {
                            HStack(spacing: MicaboSpacing.xs) {
                                Text(sessionButtonTitle)

                                if dueCards.isEmpty, !canPractice {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11, weight: .bold))
                                }
                            }
                        }
                        .buttonStyle(MicaboPrimaryButtonStyle())
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .reportsNavigationDepth(for: .today, depth: path.count)
            .returnsHome(path: $path)
            .navigationDestination(for: Course.self) { course in
                CourseSheetView(course: course)
            }
            .navigationDestination(for: CourseCardsRoute.self) { route in
                FlashcardsView(course: route.course)
            }
        }
        .sheet(isPresented: $showImportChoice, onDismiss: launchPendingImport) {
            ImportChoiceSheet(
                onSelect: { kind in
                    pendingImport = kind
                    showImportChoice = false
                }
            )
            .presentationDetents([.height(604)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
        .fullScreenCover(item: $activeImport) { kind in
            ImportView(kind: kind) { course in
                activeImport = nil
                path = NavigationPath([course])
            }
        }
        .fullScreenCover(isPresented: $isCreatingDeck) {
            CreateDeckView { course in
                isCreatingDeck = false
                path = NavigationPath([CourseCardsRoute(course: course)])
            }
        }
        .fullScreenCover(isPresented: $showStudy) {
            // Le rythme du jour est atteint mais il reste des neuves : on ouvre quand
            // même une session réglable, pas un entraînement libre.
            StudyView(
                source: .allDue,
                mode: dueCards.isEmpty && heldBackNewCards == 0 ? .practice : .scheduled
            )
        }
        .micaboPaywall($paywall)
    }

    // MARK: - En-tête

    /// Le titre de l'écran, et la série à sa droite. Pas de salutation : c'est le seul
    /// endroit de l'app où l'on ouvre, et ce qu'on vient y chercher est le chiffre juste
    /// dessous.
    private var header: some View {
        MicaboScreenHeader(title: "Réviser") {
            if streak > 0 {
                streakPill
            }
        }
        .padding(.top, MicaboSpacing.xs)
    }

    /// La série est la seule chose que l'utilisateur risque de perdre : elle mérite d'être
    /// visible, pas d'être un sur-titre gris au-dessus du titre.
    private var streakPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .semibold))

            Text("\(streak) j")
                .font(MicaboFont.number(14, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(MicaboColor.caution)
        .padding(.vertical, 8)
        .padding(.horizontal, 13)
        .background(MicaboColor.cautionSoft, in: Capsule())
        .accessibilityLabel("Série de \(streak) jour\(streak > 1 ? "s" : "")")
    }

    // MARK: - Le chiffre du jour

    /// **Une seule carte pour tout ce qui décrit la file du jour** : le chiffre, ce qu'il
    /// coûte en temps, et de quoi il est fait. Les quatre blocs qui se succédaient à même le
    /// fond donnaient trois gris à lire de haut en bas ; là, il y a un objet à regarder.
    private var dueCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Text("\(dueCards.count)")
                    .font(MicaboFont.number(58))
                    .tracking(-1.5)
                    .foregroundStyle(MicaboColor.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(dueCards.count)))
                    .animation(.easeOut(duration: 0.3), value: dueCards.count)

                VStack(alignment: .leading, spacing: 3) {
                    Text(dueCards.count > 1 ? "cartes à réviser" : "carte à réviser")
                        .font(MicaboFont.hanken(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("≈ \(estimatedMinutes) min · \(coursesWithDue > 1 ? "\(coursesWithDue) cours" : "1 cours")")
                        .font(MicaboFont.hanken(13, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 11) {
                progressSegments
                legend
            }

            if heldBackNewCards > 0 {
                heldBackNote
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    /// Ce que la barre veut dire. Sans elle, trois couleurs empilées ne sont qu'un
    /// dégradé — et c'est pour la remplacer qu'un bloc « Répartition » existait plus bas.
    private var legend: some View {
        MicaboFlowLayout(spacing: 14, lineSpacing: 7) {
            ForEach(visibleSegments) { segment in
                HStack(spacing: 6) {
                    Circle()
                        .fill(segment.color)
                        .frame(width: 7, height: 7)

                    Text("\(segment.count) \(segment.label)")
                        .font(MicaboFont.hanken(12.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
    }

    /// Dit pourquoi le chiffre du haut est plus petit que le nombre de cartes réellement
    /// dues : sans cette ligne, le plafond de rythme passerait pour un bug.
    private var heldBackNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)

            Text("\(MicaboCopy.cards(heldBackNewCards)) neuves hors rythme.")
                .font(MicaboFont.hanken(12, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var dueCoursesSection: some View {
        let entries = dueByCourse
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: "Au programme")

                MicaboRowGroup(
                    rows: entries.map { entry in
                        MicaboRow.courseDue(entry.course, dueCount: entry.count) {
                            path.append(entry.course)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Examens

    /// L'entrée vers l'onglet Examens, et le compte à rebours du prochain.
    ///
    /// Elle reste ici parce qu'un examen oriente la file du jour. Un appui ouvre l'onglet,
    /// plus un écran poussé : le calendrier a sa propre place dans la barre.
    /// **La rangée des examens est toujours là**, même sans un seul cours.
    private var examSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Prochains examens")

            if upcomingExams.isEmpty {
                Button {
                    openExams()
                } label: {
                    MicaboRow(
                        tile: MicaboTile(
                            glyph: .symbol("calendar"),
                            background: MicaboColor.surfaceMuted,
                            tint: MicaboColor.inkSecondary
                        ),
                        title: "Planifier un examen",
                        subtitle: examEmptySubtitle,
                        accessory: .chevron
                    )
                }
                .buttonStyle(MicaboRowButtonStyle())
                .micaboGroup()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcomingExams.enumerated()), id: \.element.id) { index, exam in
                        Button {
                            openExams()
                        } label: {
                            MicaboRow(
                                tile: MicaboTile(
                                    glyph: .symbol("calendar"),
                                    background: MicaboColor.cautionSoft,
                                    tint: MicaboColor.caution
                                ),
                                title: exam.name,
                                subtitle: examLine(exam),
                                accessory: .badge(exam.countdownLabel(), .warm)
                            )
                        }
                        .buttonStyle(MicaboRowButtonStyle())

                        if index < upcomingExams.count - 1 {
                            MicaboHairline(inset: 71)
                        }
                    }
                }
                .micaboGroup()
            }
        }
    }

    private func openExams() {
        withAnimation(.easeOut(duration: 0.28)) {
            router?.selection = .exams
        }
    }

    private var examEmptySubtitle: String {
        allCards.isEmpty ? "Quand tu auras des cartes" : "Ajouter une date"
    }

    private func examLine(_ exam: Exam) -> String {
        let grade = DesiredGradeScale.for(OnboardingPreferences.schoolingCountry).label(for: exam.targetScore)
        return "\(grade) souhaitée · \(examProgress(exam)) % d'avancée"
    }

    /// Cartes déjà introduites parmi celles des cours de l'examen.
    private func examProgress(_ exam: Exam) -> Int {
        let relevant = courses
            .filter { exam.courseIDs.contains($0.id) }
            .flatMap(\.cards)
            .filter { !$0.isSuspended }
        guard !relevant.isEmpty else { return 0 }
        let started = relevant.filter { $0.state != .new }.count
        return Int((Double(started) / Double(relevant.count) * 100).rounded())
    }

    /// Compté sur la file du jour, plafond compris : « au programme » doit dire la vérité.
    private var dueByCourse: [(course: Course, count: Int)] {
        var counts: [UUID: Int] = [:]
        for card in dueCards {
            guard let id = card.course?.id else { continue }
            counts[id, default: 0] += 1
        }

        let entries: [(course: Course, count: Int)] = courses.compactMap { course in
            guard let count = counts[course.id], count > 0 else { return nil }
            return (course: course, count: count)
        }
        return entries.sorted { $0.count > $1.count }
    }

    // MARK: - La barre et sa légende

    /// Les trois natures de cartes de la file, dans l'ordre où elles se lisent. Une seule
    /// source pour la barre et pour sa légende : deux listes séparées finiraient par ne plus
    /// dire la même chose.
    private struct Segment: Identifiable {
        let label: String
        let color: Color
        let count: Int

        var id: String { label }
    }

    /// Une part de la barre, une fois sa largeur arrêtée.
    private struct SizedSegment: Identifiable {
        let id: String
        let color: Color
        let width: CGFloat
    }

    private var visibleSegments: [Segment] {
        [
            Segment(label: "en révision", color: MicaboColor.caution, count: reviewCount),
            Segment(label: "en apprentissage", color: MicaboColor.accent, count: learningCount),
            Segment(label: "nouvelles", color: MicaboColor.inkTertiary, count: newCount)
        ]
        .filter { $0.count > 0 }
    }

    private var progressSegments: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 3

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MicaboColor.surfaceMuted)

                HStack(spacing: spacing) {
                    ForEach(segmentWidths(in: proxy.size.width, spacing: spacing)) { entry in
                        Capsule()
                            .fill(entry.color)
                            .frame(width: entry.width)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.3), value: dueCards.count)
    }

    /// Les largeurs sont calculées puis **renormalisées**. Chaque part reçoit un plancher de
    /// six points, sans quoi une seule carte neuve dans une file de cinquante ne se voit
    /// pas ; ces planchers mis bout à bout peuvent dépasser la largeur disponible, et une
    /// rangée qui dépasse déborde de la carte.
    private func segmentWidths(in width: CGFloat, spacing: CGFloat) -> [SizedSegment] {
        let segments = visibleSegments
        let usable = width - spacing * CGFloat(max(0, segments.count - 1))
        guard !segments.isEmpty, usable > 0 else { return [] }

        let total = CGFloat(max(1, dueCards.count))
        var widths = segments.map { max(6, usable * CGFloat($0.count) / total) }

        let sum = widths.reduce(0, +)
        if sum > usable {
            widths = widths.map { $0 * usable / sum }
        }

        return zip(segments, widths).map { SizedSegment(id: $0.label, color: $0.color, width: $1) }
    }

    // MARK: - Rien à réviser

    @ViewBuilder
    private var restState: some View {
        if allCards.isEmpty {
            MicaboEmptyState(
                systemImage: "rectangle.on.rectangle.angled",
                title: "Pas encore de cartes",
                message: "Importe un cours pour commencer.",
                actionTitle: "Importer"
            ) {
                requestImport()
            }
        } else {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                doneState

                if !nextDueSummary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        MicaboSectionCaption(text: "Prochaines échéances")

                        MicaboRowGroup(
                            rows: nextDueSummary.map { entry in
                                MicaboRow(
                                    tile: MicaboTile.course(entry.course),
                                    title: entry.course.title,
                                    subtitle: entry.label,
                                    accessory: .none
                                )
                            }
                        )
                    }
                }
            }
        }
    }

    /// Le rythme est tenu, mais des cartes neuves attendent encore. On le dit,
    /// plutôt que d'afficher « Tout est à jour » alors qu'il reste à apprendre.
    private var rhythmReachedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("C'est fait")
                .font(MicaboFont.hanken(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)

            Text("\(MicaboCopy.cards(heldBackNewCards)) neuves hors rythme.")
                .font(MicaboFont.hanken(13.5, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    private var doneState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("C'est fait")
                .font(MicaboFont.hanken(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)

            Text("Reviens demain.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .micaboGroup()
    }

    private var nextDueSummary: [(course: Course, label: String)] {
        courses.compactMap { course in
            guard let next = course.cards.filter({ !$0.isSuspended }).map(\.dueDate).min() else { return nil }
            let delay = next.timeIntervalSinceNow
            guard delay > 0 else { return nil }
            return (course, "Dans " + SM2Scheduler.format(delay: delay))
        }
        .prefix(4)
        .map { $0 }
    }

    // MARK: - Session

    /// Un seul bouton de session dans l'app, et il garde son nom d'un écran à l'autre.
    private var hasSessionButton: Bool {
        !allCards.isEmpty
    }

    private var sessionButtonTitle: String {
        if !dueCards.isEmpty { return MicaboCopy.reviewButton(count: dueCards.count) }
        if heldBackNewCards > 0 { return "Réviser" }
        return "Entraînement libre"
    }

    private var canPractice: Bool { pro?.canPractice ?? true }

    /// Réviser ce qui est dû reste gratuit. Prendre de l'avance sur tout un paquet, non :
    /// c'est ce qu'on fait la veille d'un partiel, et c'est ce que Pro ouvre.
    private func startSession() {
        guard !dueCards.isEmpty || heldBackNewCards > 0 || canPractice else {
            paywall = .practice
            return
        }
        showStudy = true
    }

    // MARK: - Import

    /// Le premier cours est offert, le deuxième s'achète.
    ///
    /// Le contrôle est ici plutôt que dans l'écran d'import : on refuse **avant** d'avoir
    /// fait choisir un PDF, sélectionner des photos et attendre une analyse. Un paywall qui
    /// tombe après le travail est un paywall qui fait désinstaller.
    private func requestImport() {
        guard pro?.canImportCourse(existingCourses: courses) ?? true else {
            paywall = .secondCourse
            return
        }
        showImportChoice = true
    }

    private func launchPendingImport() {
        guard let kind = pendingImport else { return }
        pendingImport = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if kind.producesSheet {
                activeImport = kind
            } else {
                isCreatingDeck = true
            }
        }
    }
}
