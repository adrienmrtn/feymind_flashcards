import SwiftData
import SwiftUI

/// Déclarer ou modifier un examen.
///
/// **La création suit le site, question par question.** Le nom, le jour et les cours ; le
/// type d'épreuve ; d'où l'on part sur ce programme ; les jours où l'on ne révisera pas ; la
/// note visée. Quatre écrans, une question chacun : mélanger ces champs sur une page faisait
/// lire un formulaire avant d'avoir compris ce qu'on demandait.
///
/// Les deux questions du milieu ne sont pas décoratives : le **point de départ** décale
/// l'intensité d'un cran, et le **type** décide de l'examen blanc.
///
/// La modification reste sur une page : on y retouche une valeur, pas un parcours.
struct ExamEditorSheet: View {
    /// Nul pour un nouvel examen.
    let exam: Exam?
    /// Jour proposé à l'ouverture, quand on part d'une case du calendrier.
    var suggestedDate: Date = Date()
    /// Appelé quand le formulaire vient de **créer** une épreuve, jamais quand il en modifie
    /// une. La feuille se referme ensuite, et c'est l'écran appelant qui ouvre la fiche.
    var onCreated: ((Exam) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CloudSync.self) private var sync: CloudSync?

    /// **La liste de sélection, lue une fois à l'ouverture.**
    ///
    /// C'est une liste de cases à cocher : elle ne veut d'un cours que son identifiant, son
    /// titre et sa tuile. Un `@Query` tenait ici la table entière — trente kilo-octets de
    /// texte par ligne, rematérialisés à chaque écriture SwiftData tant que la feuille est
    /// présentée — pour dessiner ça.
    ///
    /// Aucune clé de rechargement n'est nécessaire : on ne crée pas de cours depuis ce
    /// formulaire, et une feuille est reconstruite à chaque présentation, donc `load()` la
    /// remplit à chaque ouverture.
    @State private var courses: [CourseBadge] = []

    /// Les étapes, dans l'ordre du site.
    ///
    /// **`pauses` a disparu.** Elle faisait cocher les jours où l'on ne réviserait pas, et
    /// le plan les retirait de sa fenêtre — c'est-à-dire qu'il reportait leur travail sur
    /// les autres jours. Un étudiant qui déclarait se reposer le dimanche obtenait des
    /// lundis plus lourds : exactement l'inverse de ce qu'il demandait.
    private enum CreationStep: Int, Equatable, CaseIterable {
        case details
        case kind
        case start
        case grade
    }

    @State private var name = ""
    @State private var date = Date()
    @State private var selection: Set<UUID> = []
    @State private var intensity: ExamIntensity = .standard
    @State private var targetScore: Double = Double(TargetScore.default)
    @State private var kind: ExamKind = .exam
    @State private var startingPoint: ExamStartingPoint = .seen
    /// Les journées fermées, en `yyyy-MM-dd`. Globales : un samedi pris n'est pas pris « pour
    /// la biologie ». On les lit à l'ouverture et on les réécrit au moment de confirmer.
    @State private var creationStep: CreationStep = .details
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var showDeleteConfirmation = false
    @FocusState private var nameFocused: Bool
    /// Les cartes actives, rangées par cours, lues **une fois** à l'ouverture. Avant, chaque
    /// rendu faultait `course.cards` sur chaque cours et replanifiait tout : taper le nom de
    /// l'examen recalculait un planning à chaque lettre.
    @State private var cardsByCourse: [UUID: [Flashcard]] = [:]
    @State private var plan: ExamPlan?

    private let calendar = MicaboCalendar.shared

    private var isEditing: Bool { exam != nil }

    private var selectedCards: [Flashcard] {
        selection.flatMap { cardsByCourse[$0] ?? [] }
    }

    /// Le planning se refait quand un choix change, jamais parce que l'écran se redessine.
    private func replan() {
        guard isEditing, canConfirm else {
            plan = nil
            return
        }
        plan = ExamRepository.plan(
            cards: selectedCards,
            date: date,
            intensity: startingPoint.intensity(from: intensity),
            calendar: calendar
        )
    }

    // MARK: - Les étapes

    private var daysRemaining: Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
    }

    private var steps: [CreationStep] {
        CreationStep.allCases
    }

    private var stepIndex: Int {
        steps.firstIndex(of: creationStep) ?? 0
    }

    private var isLastStep: Bool {
        creationStep == steps.last
    }

    private var canConfirm: Bool {
        !selectedCards.isEmpty && !isPastDate
    }

    private var isPastDate: Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
    }

    /// En modification, tout est sur une page : on y retouche une valeur. À la création,
    /// une étape montre sa question et rien d'autre.
    private func shows(_ step: CreationStep) -> Bool {
        isEditing || creationStep == step
    }

    private var showsDetails: Bool { shows(.details) }
    private var showsGrade: Bool { shows(.grade) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    header

                    if showsDetails {
                        nameField
                        dateField
                        coursesSection
                    }

                    if shows(.kind) {
                        kindSection
                    }

                    if shows(.start) {
                        startSection
                    }

                    if showsGrade {
                        intensitySection

                        // La projection reste à la modification, où l'on retouche tout
                        // d'un coup. À la création, la dernière étape n'est que la note.
                        if isEditing, canConfirm, let plan {
                            ExamProjectionView(plan: plan)
                        }
                    }

                    if isEditing {
                        dangerZone
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboLayout.bottomBarClearance)
                .animation(.easeOut(duration: 0.22), value: creationStep)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .micaboScreenBackground()

            MicaboBottomBar {
                Button(action: primaryAction) {
                    HStack(spacing: MicaboSpacing.xs) {
                        if showsPrimaryIcon {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(primaryTitle)
                    }
                }
                .buttonStyle(MicaboPrimaryButtonStyle(tint: canConfirm ? MicaboColor.accent : MicaboColor.strokeStrong))
                .disabled(!canConfirm)
            }
        }
        // **`onAppear`, pas `task` — et ce n'est pas un détail de style.** `load()` est
        // entièrement synchrone : un `.task` ne lui apporterait aucune asynchronie, il ne
        // ferait que la repousser après la première image. La section « Cours au programme »
        // ne pèserait alors que son intitulé le temps d'une passe, et tout ce qui la suit en
        // modification — type d'épreuve, point de départ, note visée — serait posé
        // trop haut puis redescendrait d'un coup. `onAppear` pose l'état avant que l'image ne
        // soit présentée.
        .onAppear { load() }
        // Et la bibliothèque suit ensuite : une synchro peut faire descendre un cours pendant
        // que le formulaire est ouvert.
        .onChange(of: libraryKey) { _, _ in load() }
        .onChange(of: selection) { _, _ in replan() }
        .onChange(of: date) { _, _ in replan() }
        .onChange(of: intensity) { _, _ in replan() }
        .onChange(of: startingPoint) { _, _ in replan() }
        .alert(L10n.t("app.common.oops", locale: .resolved()), isPresented: .constant(errorMessage != nil)) {
            Button(L10n.t("app.a11y.close", locale: .resolved()), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Champs

    private var header: some View {
        MicaboScreenHeader(
            title: headerTitle,
            eyebrow: headerEyebrow,
            back: headerBack
        ) {
            if !isEditing {
                stepPips
            }
        }
        .padding(.top, MicaboSpacing.xs)
    }

    private var headerTitle: String {
        if isEditing { return L10n.t("ios.editExam", locale: .resolved()) }
        switch creationStep {
        case .details: return L10n.t("ios.newExam", locale: .resolved())
        case .kind: return L10n.t("app.newPlan.kindTitle", locale: .resolved())
        case .start: return L10n.t("app.newPlan.startTitle", locale: .resolved())
        case .grade: return L10n.t("ios.desiredGrade", locale: .resolved())
        }
    }

    /// Passé la première étape, le sur-titre porte le nom de l'épreuve : on sait à quoi on
    /// répond, sans le relire dans le titre.
    private var headerEyebrow: String {
        if isEditing { return L10n.t("ios.examMode", locale: .resolved()) }
        if creationStep != .details {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? L10n.t("ios.newExam", locale: .resolved()) : trimmed
        }
        return L10n.t("ios.examMode", locale: .resolved())
    }

    private var headerBack: MicaboHeaderBack {
        if !isEditing, creationStep != .details {
            return .back(goBack)
        }
        return .close { dismiss() }
    }

    /// Une pastille par étape, comme le parcours web : on sait où l'on est sans lire « 2 / 5 ».
    private var stepPips: some View {
        HStack(spacing: 5) {
            ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                pip(isCurrent: step == creationStep, isDone: index < stepIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t(
            "ios.stepOf",
            locale: .resolved(),
            vars: ["current": "\(stepIndex + 1)", "total": "\(steps.count)"]
        ))
    }

    private func pip(isCurrent: Bool, isDone: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(isCurrent || isDone ? MicaboColor.ink : MicaboColor.strokeStrong)
            .frame(width: isCurrent ? 18 : 6, height: 6)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L10n.t("ios.fieldName", locale: .resolved()))
                .font(MicaboFont.captionEmphasis)
                .foregroundStyle(MicaboColor.ink)

            TextField(L10n.t("ios.examNameHint", locale: .resolved()), text: $name)
                .font(MicaboFont.body)
                .focused($nameFocused)
                .padding(MicaboSpacing.sm)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L10n.t("ios.fieldDate", locale: .resolved()))
                .font(MicaboFont.captionEmphasis)
                .foregroundStyle(MicaboColor.ink)

            DatePicker("", selection: $date, in: Date().addingTimeInterval(-86_400)..., displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, UiLocale.resolved().foundation)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(MicaboSpacing.sm)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))

            if isPastDate {
                Text(L10n.t("ios.examPastHint", locale: .resolved()))
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.negative)
            }
        }
    }

    /// Les cours au programme. Une rangée par cours, avec son volume de cartes : c'est ce
    /// volume qui fait la charge, donc c'est lui qu'on doit voir en cochant.
    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: L10n.t("ios.coursesOnProgram", locale: .resolved()))

            if !didLoad {
                // **Rien tant qu'on n'a pas lu.** `load()` part maintenant d'un `onAppear`,
                // donc avant la première image : en pratique on ne passe plus ici. La garde
                // reste parce qu'une liste vide ne veut pas dire « aucun cours » tant que la
                // lecture n'a pas eu lieu, et que déplacer `load()` ailleurs un jour ferait
                // sinon afficher « il te faut un cours » à quelqu'un qui en a vingt.
                EmptyView()
            } else if courses.isEmpty {
                MicaboSectionFootnote(text: L10n.t("ios.examNeedCourse", locale: .resolved()))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                        courseRow(course)
                        if index < courses.count - 1 {
                            MicaboHairline(inset: 72)
                        }
                    }
                }
                .micaboGroup()
            }
        }
    }

    private func courseRow(_ course: CourseBadge) -> some View {
        let isSelected = selection.contains(course.id)
        let count = cardsByCourse[course.id]?.count ?? 0

        return Button {
            if isSelected {
                selection.remove(course.id)
            } else {
                selection.insert(course.id)
            }
        } label: {
            HStack(spacing: 13) {
                MicaboTile.course(badge: course)

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.title)
                        .font(MicaboFont.rowTitle)
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(count > 0 ? MicaboCopy.cards(count) : L10n.t("ios.noCardsShort", locale: .resolved()))
                        .font(MicaboFont.rowSubtitle)
                        .foregroundStyle(count > 0 ? MicaboColor.inkTertiary : MicaboColor.caution)
                }

                Spacer(minLength: MicaboSpacing.xs)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(isSelected ? MicaboColor.accent : MicaboColor.strokeStrong)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, MicaboSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboRowButtonStyle(feedback: .selection))
    }

    // MARK: - Le type d'épreuve

    /// **Il ne change pas la replanification.** Il décide de l'examen blanc - on ne s'entraîne
    /// pas à un oral avec un QCM - et des formats proposés.
    private var kindSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                MicaboSectionCaption(text: L10n.t("app.plan.sheet.kindTitle", locale: .resolved()))
            }

            MicaboFlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(ExamKind.allCases) { option in
                    let picked = kind == option
                    Button {
                        Haptics.selection()
                        kind = option
                    } label: {
                        Text(option.title())
                            .font(MicaboFont.ui(14, weight: .medium))
                            .foregroundStyle(picked ? MicaboColor.onInk : MicaboColor.ink)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 14)
                            .background(picked ? MicaboColor.ink : MicaboColor.surface, in: Capsule())
                    }
                    .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                    .accessibilityAddTraits(picked ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Le point de départ

    /// **Ce que l'app ne peut pas deviner.** Micabo ne voit que ce qui a été travaillé chez
    /// lui ; il ne sait rien d'un cours suivi en amphi toute l'année. La réponse décale
    /// l'intensité d'un cran, dans un sens ou dans l'autre.
    private var startSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                MicaboSectionCaption(text: L10n.t("app.newPlan.startTitle", locale: .resolved()))
            }

            VStack(spacing: 0) {
                ForEach(Array(ExamStartingPoint.allCases.enumerated()), id: \.element) { index, option in
                    let picked = startingPoint == option
                    Button {
                        Haptics.selection()
                        startingPoint = option
                    } label: {
                        HStack(spacing: 13) {
                            MicaboTile(
                                glyph: .emoji(option.emoji),
                                background: picked ? MicaboColor.accentSoft : MicaboColor.surfaceMuted
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.title())
                                    .font(MicaboFont.rowTitle)
                                    .foregroundStyle(MicaboColor.ink)
                                Text(option.detail())
                                    .font(MicaboFont.rowSubtitle)
                                    .foregroundStyle(MicaboColor.inkTertiary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: MicaboSpacing.xs)

                            Image(systemName: picked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 19, weight: .regular))
                                .foregroundStyle(picked ? MicaboColor.accent : MicaboColor.strokeStrong)
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, MicaboSpacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MicaboRowButtonStyle(feedback: .selection))

                    if index < ExamStartingPoint.allCases.count - 1 {
                        MicaboHairline(inset: 72)
                    }
                }
            }
            .micaboGroup()
        }
    }

    // MARK: - Les jours de pause

    /// **Toucher les jours où l'on ne révisera pas.**
    ///

    /// **La note qu'on vise, glissée au pouce.**
    ///
    /// Un rail, et non une rangée de pastilles : on ne compare pas onze notes entre elles,
    /// on pousse un curseur vers le haut jusqu'à ce que le chiffre affiché soit celui qu'on
    /// veut. Le geste est continu, la note se lit en grand au-dessus, et c'est tout.
    ///
    /// Ce n'est pas le curseur du système pour autant : celui-là est gris, ne rend rien sous
    /// le doigt, et glisse entre les notes. Le nôtre s'arrête sur chaque **note proposable**
    /// - `scale.choices`, donc le barème du pays sans ses doublons - et rend un coup à chaque
    /// cran franchi. On sait ce qu'on vient de choisir sans lire.
    private var intensitySection: some View {
        let scale = DesiredGradeScale.for(OnboardingPreferences.schoolingCountry)
        let score = Int(targetScore.rounded())

        return VStack(alignment: .leading, spacing: 10) {
            // À la création, le titre d'écran dit déjà « Note souhaitée ».
            if isEditing {
                MicaboSectionCaption(text: L10n.t("ios.desiredGrade", locale: .resolved()))
            }

            Text(scale.label(for: score))
                .font(MicaboFont.number(40))
                .foregroundStyle(MicaboColor.ink)
                .tracking(MicaboTracking.tight)
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .animation(.snappy(duration: 0.22), value: score)

            Text(intensityDetail)
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkSecondary)
                .frame(maxWidth: .infinity)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: intensity)

            VStack(spacing: 6) {
                GradeSlider(
                    choices: scale.choices,
                    score: Binding(
                        get: { Int(targetScore.rounded()) },
                        set: { next in
                            targetScore = Double(next)
                            intensity = TargetScore.intensity(from: next)
                        }
                    )
                )

                // Les deux bouts du barème, et son milieu : sans eux, un rail nu ne dit pas
                // dans quel sens on monte.
                HStack {
                    Text(scale.min)
                    Spacer()
                    Text(scale.mid)
                    Spacer()
                    Text(scale.max)
                }
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(.top, 2)
        }
        .accessibilityElement(children: .contain)
    }

    private var intensityDetail: String {
        switch intensity {
        case .light: L10n.t("ios.exam.light", locale: .resolved())
        case .standard: L10n.t("ios.exam.standard", locale: .resolved())
        case .intense: L10n.t("ios.exam.intense", locale: .resolved())
        }
    }

    /// Les deux actions qui défont quelque chose.
    ///
    /// Elles vivent aussi dans le menu contextuel de la liste, mais elles ne peuvent pas y
    /// vivre **seulement** : ce menu partage l'appui long avec le glisser-déposer du
    /// calendrier, et une action qu'un geste peut voler n'est pas une action accessible.
    @ViewBuilder
    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: L10n.t("ios.cancel", locale: .resolved()))

            VStack(spacing: 0) {
                if exam?.isPlanned == true {
                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("arrow.uturn.backward"), background: MicaboColor.surfaceMuted),
                        title: L10n.t("ios.restoreSchedule", locale: .resolved()),
                        subtitle: L10n.t("ios.restoreScheduleHelp", locale: .resolved()),
                        accessory: .none,
                        action: unplan
                    )

                    MicaboHairline(inset: 72)
                }

                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("trash"), background: MicaboColor.negativeSoft, tint: MicaboColor.negative),
                    title: L10n.t("ios.deleteExam", locale: .resolved()),
                    subtitle: exam?.isPlanned == true ? L10n.t("ios.unplanHelp", locale: .resolved()) : nil,
                    accessory: .none,
                    titleColor: MicaboColor.negative,
                    action: { showDeleteConfirmation = true }
                )
            }
            .micaboGroup()
        }
        .confirmationDialog(L10n.t("ios.deleteExamQ", locale: .resolved()), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(L10n.t("app.common.delete", locale: .resolved()), role: .destructive, action: delete)
            Button(L10n.t("app.common.cancel", locale: .resolved()), role: .cancel) {}
        } message: {
            Text(
                exam?.isPlanned == true
                    ? L10n.t("ios.deleteExamPlannedMsg", locale: .resolved())
                    : L10n.t("ios.deleteExamMsg", locale: .resolved())
            )
        }
    }

    // MARK: - Actions

    private var primaryTitle: String {
        if !isEditing, !isLastStep {
            return L10n.t("app.common.continue", locale: .resolved())
        }
        return isEditing
            ? L10n.t("ios.replanExam", locale: .resolved())
            : L10n.t("ios.planExam", locale: .resolved())
    }

    private var showsPrimaryIcon: Bool {
        isEditing || isLastStep
    }

    private func primaryAction() {
        if !isEditing, !isLastStep {
            goForward()
            return
        }
        confirm()
    }

    private func goForward() {
        // Seule la première étape a de quoi être invalide : les trois suivantes ont toutes
        // une réponse par défaut, et la note aussi.
        guard canConfirm else { return }
        move(to: stepIndex + 1)
    }

    private func goBack() {
        move(to: stepIndex - 1)
    }

    private func move(to index: Int) {
        guard steps.indices.contains(index) else { return }
        nameFocused = false
        Haptics.selection()
        withAnimation(.easeOut(duration: 0.22)) {
            creationStep = steps[index]
        }
    }

    /// **La bibliothèque, relue ; l'état éditable, non.**
    ///
    /// Les deux parties de cette feuille n'ont pas le même cycle. Ce qui vient de la base —
    /// les cours, leurs cartes — doit suivre : une synchro peut en faire descendre un pendant
    /// que le formulaire est ouvert, et le `@Query` retiré le montrait tout seul. Ce que
    /// l'utilisateur est en train de saisir, lui, ne doit **jamais** être réécrit : recharger
    /// `name` ou `selection` effacerait ce qu'il vient de taper. D'où la garde `didLoad`, qui
    /// ne protège plus que la seconde moitié.
    private func loadLibrary() {
        // Une lecture de la table des cartes, puis un rangement par cours.
        var byCourse: [UUID: [Flashcard]] = [:]
        for card in CourseRepository.allCards(in: modelContext) where !card.isSuspended {
            guard let courseID = card.course?.id else { continue }
            byCourse[courseID, default: []].append(card)
        }
        cardsByCourse = byCourse
        // Les cours, dans le même ordre que le `@Query` qu'ils remplacent (`updatedAt`
        // décroissant, cf. `CourseRepository.allCourses`). Les objets ne sortent pas de cette
        // ligne : seules leurs projections entrent dans l'état de la feuille.
        courses = CourseRepository.allCourses(in: modelContext).map(CourseBadge.init)
    }

    /// Ce qui fait relire la bibliothèque : un cours créé ou supprimé (`CourseLedger`), une
    /// passe de synchro descendue (`CloudSync.epoch`). La synchro est le seul endroit du
    /// dépôt qui réécrive le titre, l'emoji ou la teinte d'un cours — donc la seule qui
    /// puisse périmer une projection déjà lue.
    private var libraryKey: String {
        "\(CourseLedger.shared.stamp)-\(sync?.epoch ?? 0)"
    }

    private func load() {
        loadLibrary()

        guard !didLoad else {
            // Rechargement : les cartes ont pu changer, donc le plan aussi.
            replan()
            return
        }
        didLoad = true

        guard let exam else {
            date = calendar.startOfDay(for: max(suggestedDate, Date()))
            return
        }
        name = exam.name
        date = exam.date
        selection = Set(exam.courseIDs)
        intensity = exam.intensity
        kind = exam.kind
        startingPoint = exam.startingPoint
        targetScore = Double(exam.targetScore)
        replan()
    }


    private func confirm() {
        guard canConfirm else { return }

        do {
            if let exam {
                try ExamRepository.update(
                    exam,
                    name: name,
                    date: date,
                    courseIDs: Array(selection),
                    intensity: intensity,
                    targetScore: Int(targetScore.rounded()),
                    kind: kind,
                    startingPoint: startingPoint,
                    in: modelContext
                )
                if !exam.isPlanned {
                    try ExamRepository.plan(exam, in: modelContext)
                }
            } else {
                let created = try ExamRepository.create(
                    name: name,
                    date: date,
                    courseIDs: Array(selection),
                    intensity: intensity,
                    targetScore: Int(targetScore.rounded()),
                    kind: kind,
                    startingPoint: startingPoint,
                    in: modelContext
                )
                try ExamRepository.plan(created, in: modelContext)
                // On sort du formulaire **sur la fiche de l'épreuve**, et pas sur la liste.
                // Quelqu'un qui vient de planifier veut voir ce qu'il a planifié : le
                // calendrier, les jours chargés, les rendez-vous. La liste, elle, ne lui
                // apprend que le nom qu'il vient d'écrire.
                onCreated?(created)
            }
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = describe(error)
        }
    }

    private func unplan() {
        guard let exam else { return }
        do {
            try ExamRepository.unplan(exam, in: modelContext)
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = describe(error)
        }
    }

    private func delete() {
        guard let exam else { return }
        do {
            try ExamRepository.delete(exam, in: modelContext)
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = describe(error)
        }
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

/// **Le rail des notes.**
///
/// Un curseur à crans, dessiné plutôt qu'emprunté. `Slider` glisse entre les valeurs, se
/// peint en gris système et ne rend rien sous le pouce ; ici chaque cran est une note
/// proposable, le pouce s'y pose franchement, et le coup part **avant** l'animation - un
/// retour qui suit la peinture se sent en retard, et c'est ce décalage qui rend un réglage
/// mou.
///
/// `choices` porte le barème du pays sans ses doublons : onze crans en France, neuf ailleurs.
/// La note enregistrée peut tomber sur un cran fusionné - deux « C- » de suite, dont un seul
/// survit -, auquel cas le pouce se pose sur le cran proposable immédiatement en dessous
/// plutôt que de sauter au début du barème.
private struct GradeSlider: View {
    let choices: [GradeTick]
    @Binding var score: Int

    @State private var isDragging = false

    private static let knob: CGFloat = 28
    private static let track: CGFloat = 8

    private var index: Int {
        choices.lastIndex { $0.score <= score } ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            let travel = max(geo.size.width - Self.knob, 1)
            let step = choices.count > 1 ? travel / CGFloat(choices.count - 1) : travel
            let x = step * CGFloat(index)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MicaboColor.surfaceMuted)
                    .frame(height: Self.track)

                Capsule()
                    .fill(MicaboColor.accent)
                    .frame(width: x + Self.knob / 2, height: Self.track)

                Circle()
                    .fill(MicaboColor.surface)
                    .overlay {
                        Circle().strokeBorder(MicaboColor.hairline, lineWidth: 1)
                    }
                    .shadow(color: MicaboColor.ink.opacity(0.16), radius: 5, y: 2)
                    .frame(width: Self.knob, height: Self.knob)
                    .scaleEffect(isDragging ? 1.14 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
                    .offset(x: x)
            }
            .frame(height: Self.knob)
            // Le rail entier prend le geste, pas seulement le pouce : viser un disque de
            // vingt-huit points pour régler une note est un jeu d'adresse, pas un réglage.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        pick(at: value.location.x - Self.knob / 2, step: step)
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .frame(height: Self.knob)
        .accessibilityElement()
        .accessibilityLabel(L10n.t("ios.desiredGrade", locale: .resolved()))
        .accessibilityValue(choices.indices.contains(index) ? choices[index].label : "")
        .accessibilityAdjustableAction { direction in
            let next = index + (direction == .increment ? 1 : -1)
            guard choices.indices.contains(next) else { return }
            score = choices[next].score
        }
    }

    private func pick(at x: CGFloat, step: CGFloat) {
        guard step > 0, !choices.isEmpty else { return }
        let raw = Int((x / step).rounded())
        let next = choices[min(max(raw, 0), choices.count - 1)].score
        guard next != score else { return }
        Haptics.selection()
        withAnimation(.snappy(duration: 0.18)) { score = next }
    }
}
