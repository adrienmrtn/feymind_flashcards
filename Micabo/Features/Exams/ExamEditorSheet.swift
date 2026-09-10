import SwiftData
import SwiftUI

/// Déclarer ou modifier un examen.
///
/// **La création suit le site, question par question.** Le nom, le jour et les cours ; le
/// type d'épreuve ; d'où l'on part sur ce programme ; les jours où l'on ne révisera pas ; la
/// note visée. Cinq écrans, une question chacun : mélanger ces champs sur une page faisait
/// lire un formulaire avant d'avoir compris ce qu'on demandait.
///
/// Les trois questions du milieu manquaient au téléphone, et elles ne sont pas décoratives :
/// le **point de départ** décale l'intensité d'un cran, les **pauses** retirent des jours de
/// la fenêtre, et le **type** décide de l'examen blanc. Sans elles, deux comptes identiques
/// recevaient le même plan sur le site et sur l'iPhone - et un seul des deux était juste.
///
/// La modification reste sur une page : on y retouche une valeur, pas un parcours.
struct ExamEditorSheet: View {
    /// Nul pour un nouvel examen.
    let exam: Exam?
    /// Jour proposé à l'ouverture, quand on part d'une case du calendrier.
    var suggestedDate: Date = Date()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    /// Les étapes, dans l'ordre du site. `pauses` s'efface quand l'épreuve est trop proche
    /// pour qu'on ait des jours à poser : une question sans réponse possible n'est pas une
    /// étape, c'est un écran qu'on traverse en soupirant.
    private enum CreationStep: Int, Equatable, CaseIterable {
        case details
        case kind
        case start
        case pauses
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
    @State private var offDays: Set<String> = []
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

    private var selectedCourses: [Course] {
        courses.filter { selection.contains($0.id) }
    }

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
            offDays: ExamRepository.offDayOffsets(until: date, stamps: offDays, calendar: calendar),
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

    /// Les jours proposés : d'aujourd'hui à la veille, quatre semaines au plus.
    private var pauseWindow: [Date] {
        OffDays.window(from: Date(), daysRemaining: daysRemaining, calendar: calendar)
    }

    /// Les étapes réellement posées. On saute `pauses` quand il n'y a pas un jour à cocher.
    private var steps: [CreationStep] {
        CreationStep.allCases.filter { $0 != .pauses || !pauseWindow.isEmpty }
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

                    if shows(.pauses), !pauseWindow.isEmpty {
                        pausesSection
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
        .task { load() }
        .onChange(of: selection) { _, _ in replan() }
        .onChange(of: date) { _, _ in replan() }
        .onChange(of: intensity) { _, _ in replan() }
        .onChange(of: startingPoint) { _, _ in replan() }
        .onChange(of: offDays) { _, _ in replan() }
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
        case .pauses: return L10n.t("app.newPlan.pausesTitle", locale: .resolved())
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

            if courses.isEmpty {
                MicaboSectionFootnote(text: "Aucun cours importé. Il faut au moins un cours avec des cartes pour planifier un examen.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                        courseRow(course)
                        if index < courses.count - 1 {
                            MicaboHairline(inset: 71)
                        }
                    }
                }
                .micaboGroup()
            }
        }
    }

    private func courseRow(_ course: Course) -> some View {
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
                MicaboTile.course(course)

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.title)
                        .font(MicaboFont.rowTitle)
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(count > 0 ? MicaboCopy.cards(count) : "aucune carte")
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
                            .font(MicaboFont.hanken(14, weight: .medium))
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
                        MicaboHairline(inset: 71)
                    }
                }
            }
            .micaboGroup()
        }
    }

    // MARK: - Les jours de pause

    /// **Toucher les jours où l'on ne révisera pas.**
    ///
    /// Sans eux, le plan pose du travail le dimanche où l'on ne touchera pas au téléphone :
    /// on prend un jour de retard dès la première semaine, et le plan qui devait rassurer
    /// devient une dette. Les jours fermés ne disparaissent pas, ils se reportent sur les
    /// autres - c'est le prix, et la projection l'annonce.
    private var pausesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isEditing {
                MicaboSectionCaption(text: L10n.t("app.newPlan.pausesTitle", locale: .resolved()))
            }

            Text(L10n.t("app.newPlan.pausesLead", locale: .resolved()))
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            MicaboFlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(pauseWindow, id: \.self) { day in
                    pauseCell(day)
                }
            }

            if !offDays.isEmpty {
                Text(L10n.t("app.newPlan.pausesCount", locale: .resolved(), vars: ["count": "\(offDays.count)"]))
                    .font(MicaboFont.micro)
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
    }

    private func pauseCell(_ day: Date) -> some View {
        let stamp = OffDays.stamp(day, in: calendar)
        let picked = offDays.contains(stamp)
        let weekday = calendar.component(.weekday, from: day)
        // `weekdayInitials` commence au lundi, `Calendar` au dimanche : d'où le décalage.
        let initials = MicaboCalendar.weekdayInitials
        let initial = initials.indices.contains((weekday + 5) % 7) ? initials[(weekday + 5) % 7] : ""

        return Button {
            Haptics.selection()
            if picked { offDays.remove(stamp) } else { offDays.insert(stamp) }
        } label: {
            VStack(spacing: 2) {
                Text(initial)
                    .font(MicaboFont.hanken(10.5, weight: .medium))
                    .foregroundStyle(picked ? MicaboColor.onInk.opacity(0.8) : MicaboColor.inkTertiary)
                Text("\(calendar.component(.day, from: day))")
                    .font(MicaboFont.number(15, weight: .semibold))
                    .foregroundStyle(picked ? MicaboColor.onInk : MicaboColor.ink)
                    .monospacedDigit()
            }
            .frame(width: 44, height: 46)
            .background(
                picked ? MicaboColor.ink : MicaboColor.surface,
                in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
            )
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .accessibilityLabel(MicaboCalendar.dayLabel(day))
        .accessibilityAddTraits(picked ? .isSelected : [])
    }

    /// **La note qu'on vise, choisie au doigt.**
    ///
    /// C'était un curseur système : gris, sans retour, et sans rapport avec le reste de
    /// l'app. On vise une note une fois par épreuve, et ce geste-là décide de toute
    /// l'intensité du plan - il mérite mieux qu'un rail de réglages.
    ///
    /// Les crans sont donc **des pastilles qu'on touche**, prises dans `scale.choices` : le
    /// barème du pays, sans doublon, donc onze notes en France et neuf lettres ailleurs. La
    /// pastille choisie grossit, la note s'écrit en grand au-dessus et **se transforme
    /// chiffre par chiffre**, et chaque cran franchi rend un petit coup. On sait ce qu'on
    /// vient de choisir sans lire.
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

            gradeDial(scale, score: score)
        }
        .accessibilityElement(children: .contain)
    }

    /// Le cadran : une pastille par note, la choisie en accent.
    ///
    /// Il défile à l'horizontale et **se recentre tout seul** sur la note retenue : ouvrir la
    /// fiche d'une épreuve déjà réglée sur 18 doit montrer 18, pas le début du barème.
    private func gradeDial(_ scale: DesiredGradeScale, score: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(scale.choices) { tick in
                        gradeTick(tick, isPicked: tick.score == score)
                            .id(tick.score)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                proxy.scrollTo(score, anchor: .center)
            }
            .onChange(of: score) { _, next in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(next, anchor: .center) }
            }
        }
        .accessibilityLabel(L10n.t("ios.desiredGrade", locale: .resolved()))
        .accessibilityValue(scale.label(for: score))
    }

    private func gradeTick(_ tick: GradeTick, isPicked: Bool) -> some View {
        Button {
            guard Int(targetScore.rounded()) != tick.score else { return }
            // Le coup part **avant** l'animation : un retour qui suit la peinture se sent en
            // retard, et c'est ce décalage qui rend un réglage mou.
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                targetScore = Double(tick.score)
                intensity = TargetScore.intensity(from: tick.score)
            }
        } label: {
            Text(tick.label)
                .font(MicaboFont.hanken(isPicked ? 17 : 15, weight: isPicked ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(isPicked ? MicaboColor.onInk : MicaboColor.ink)
                .frame(minWidth: 46)
                .frame(height: isPicked ? 46 : 40)
                .background(
                    isPicked ? MicaboColor.accent : MicaboColor.surfaceMuted,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(isPicked ? Color.clear : MicaboColor.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .accessibilityLabel(tick.label)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
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

                    MicaboHairline(inset: 71)
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

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        // Une lecture de la table des cartes, puis un rangement par cours.
        var byCourse: [UUID: [Flashcard]] = [:]
        for card in CourseRepository.allCards(in: modelContext) where !card.isSuspended {
            guard let courseID = card.course?.id else { continue }
            byCourse[courseID, default: []].append(card)
        }
        cardsByCourse = byCourse
        // Les journées fermées sont globales : on part de celles du compte, pas d'une page
        // blanche, et ce qu'on coche ici vaut pour les autres épreuves aussi.
        offDays = OffDays.stamps(in: modelContext)

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

    /// Écrit les journées cochées dans la base. Elles ne suivent pas l'examen : elles sont à
    /// l'étudiant, et la synchro les remonte avec le reste.
    private func saveOffDays() {
        let known = OffDays.stamps(in: modelContext)
        for stamp in offDays.subtracting(known) {
            OffDays.insert(stamp, in: modelContext)
        }
        for stale in known.subtracting(offDays) {
            OffDays.remove(stale, in: modelContext)
        }
        try? modelContext.save()
    }

    private func confirm() {
        guard canConfirm else { return }

        // **Les pauses s'écrivent avant le plan**, parce que c'est le plan qui les lit. Les
        // enregistrer après aurait posé un planning sur des jours qu'on venait de fermer.
        saveOffDays()

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
