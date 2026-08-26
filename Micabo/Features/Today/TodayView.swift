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
    @Environment(AuthController.self) private var auth
    @Environment(TabRouter.self) private var router: TabRouter?

    @State private var showStudy = false
    @State private var path = NavigationPath()
    @State private var showImportChoice = false
    @State private var pendingImport: ImportKind?
    @State private var activeImport: ImportKind?
    /// Un paquet de cartes ne passe pas par l'écran d'import : il n'y a rien à lire.
    @State private var isCreatingDeck = false
    @State private var paywall: PaywallTrigger?

    /// Les échéances d'examen en cours. L'écran doit les connaître : ce sont elles qui
    /// lèvent le plafond de cartes neuves, donc qui décident du chiffre annoncé.
    private var deadlines: ExamDeadlines {
        ExamDeadlines.active(exams: exams, courses: courses)
    }

    /// La file telle que la session va la servir : le plafond de cartes neuves du jour,
    /// hérité du rythme choisi à l'inscription, est déjà appliqué, exception faite des
    /// cartes sous échéance d'examen. Le chiffre affiché est donc exactement celui qu'on va
    /// réviser.
    private var dueCards: [Flashcard] {
        StudyQueueBuilder.build(from: allCards, limits: .daily(), deadlines: deadlines)
    }

    private var nextExam: Exam? {
        exams.first { !$0.isPast() }
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

                    if dueCards.isEmpty {
                        restState
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
            .navigationDestination(for: ExamsRoute.self) { _ in
                // L'état vide des examens renvoie à l'import, et c'est cet écran-ci qui sait
                // l'ouvrir : la feuille d'import vit ici. Elle attend la fin du retour —
                // une feuille présentée pendant une transition de pile ne s'ouvre pas.
                ExamsView {
                    path.removeLast()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        requestImport()
                    }
                }
            }
        }
        .sheet(isPresented: $showImportChoice, onDismiss: launchPendingImport) {
            ImportChoiceSheet(
                onSelect: { kind in
                    pendingImport = kind
                    showImportChoice = false
                },
                onLibrary: libraryAction
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
            // Rien à réviser : on ouvre franchement un entraînement libre plutôt que de
            // faire passer des cartes en avance pour une vraie session.
            StudyView(source: .allDue, mode: dueCards.isEmpty ? .practice : .scheduled)
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

            Text("\(MicaboCopy.cards(heldBackNewCards)) neuves gardées pour les jours suivants, pour tenir ton rythme de \(DailyLoad.label(forMinutes: OnboardingPreferences.dailyMinutes)) par jour.")
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

    /// L'entrée vers la page Examens, et le compte à rebours du prochain.
    ///
    /// Elle vit ici parce qu'un examen est une affaire de planning, et que le planning est
    /// le sujet de cet onglet. Elle reste visible même sans examen déclaré : c'est une
    /// fonctionnalité qu'on ne cherche pas si on ne sait pas qu'elle existe.
    /// **La rangée des examens est toujours là**, même sans un seul cours.
    ///
    /// Elle n'apparaissait qu'une fois qu'il y avait des cartes, au motif que planifier ne
    /// mène à rien sans elles. C'était confondre deux choses : une fonctionnalité qui ne
    /// s'applique pas encore n'est pas une fonctionnalité qui n'existe pas. Un écran d'accueil
    /// dont une entrée entière n'apparaît qu'après un import ne s'apprend pas — on ne
    /// découvre pas ce qu'on n'a jamais vu — et la page qu'elle ouvre sait maintenant se
    /// présenter à vide.
    private var examSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Examens")

            Button {
                path.append(ExamsRoute())
            } label: {
                MicaboRow(
                    tile: MicaboTile(
                        glyph: .symbol("calendar"),
                        background: nextExam == nil ? MicaboColor.surfaceMuted : MicaboColor.cautionSoft,
                        tint: nextExam == nil ? MicaboColor.inkSecondary : MicaboColor.caution
                    ),
                    title: nextExam?.name ?? "Planifier un examen",
                    subtitle: examSubtitle,
                    accessory: examAccessory
                )
            }
            .buttonStyle(MicaboRowButtonStyle())
            .micaboGroup()
        }
    }

    private var examAccessory: MicaboRowAccessory {
        guard let nextExam else { return .chevron }
        return .badge(nextExam.countdownLabel(), .warm)
    }

    private var examSubtitle: String {
        if let nextExam {
            return MicaboCalendar.dayLabel(nextExam.date)
                + (nextExam.isPlanned ? " · révisions replanifiées" : " · planning normal")
        }
        // La rangée dit ce qu'il manque plutôt que de promettre ce qu'elle ne peut pas
        // encore faire : un examen agit sur des cartes.
        guard !allCards.isEmpty else {
            return "Dès que tu auras des cartes à replanifier"
        }
        return "Micabo replanifie tes révisions pour le jour J"
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
                message: "Importe un cours : Micabo en tire tes premières cartes et te les repose au bon moment.",
                actionTitle: "Importer un cours"
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

    private var doneState: some View {
        VStack(spacing: MicaboSpacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(MicaboColor.positive)
                .frame(width: 76, height: 76)
                .background(MicaboColor.positiveSoft, in: Circle())

            Text("Tout est à jour")
                .font(MicaboFont.hanken(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.3)
                .padding(.top, MicaboSpacing.xxs)

            Text("Aucune carte à réviser aujourd'hui. Reviens demain, ou prends de l'avance.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MicaboSpacing.lg)
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
        dueCards.isEmpty ? "Entraînement libre" : MicaboCopy.reviewButton(count: dueCards.count)
    }

    private var canPractice: Bool { pro?.canPractice ?? true }

    /// Réviser ce qui est dû reste gratuit. Prendre de l'avance sur tout un paquet, non :
    /// c'est ce qu'on fait la veille d'un partiel, et c'est ce que Pro ouvre.
    private func startSession() {
        guard !dueCards.isEmpty || canPractice else {
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

    private var libraryAction: (() -> Void)? {
        LibraryAccess.isAvailable(signedIn: auth.isSignedIn) ? openLibrary : nil
    }

    private func openLibrary() {
        showImportChoice = false
        router?.showLibrary()
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
