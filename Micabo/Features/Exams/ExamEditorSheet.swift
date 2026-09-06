import SwiftData
import SwiftUI

/// Déclarer ou modifier un examen.
///
/// **La création tient en deux questions.** D'abord le nom, le jour et les cours : ce
/// qu'on passe. Ensuite la note seule, puis « Planifier l'examen ». Mélanger les quatre
/// champs sur un seul écran faisait lire un formulaire avant d'avoir compris la question.
/// La modification reste sur une page : on y retouche une valeur, pas un parcours.
struct ExamEditorSheet: View {
    /// Nul pour un nouvel examen.
    let exam: Exam?
    /// Jour proposé à l'ouverture, quand on part d'une case du calendrier.
    var suggestedDate: Date = Date()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    private enum CreationStep: Equatable {
        case details
        case grade
    }

    @State private var name = ""
    @State private var date = Date()
    @State private var selection: Set<UUID> = []
    @State private var intensity: ExamIntensity = .standard
    @State private var targetScore: Double = Double(TargetScore.default)
    @State private var creationStep: CreationStep = .details
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var showDeleteConfirmation = false
    @FocusState private var nameFocused: Bool

    private let calendar = MicaboCalendar.shared

    private var isEditing: Bool { exam != nil }

    private var selectedCourses: [Course] {
        courses.filter { selection.contains($0.id) }
    }

    private var selectedCards: [Flashcard] {
        selectedCourses.flatMap(\.cards).filter { !$0.isSuspended }
    }

    private var plan: ExamPlan {
        ExamRepository.plan(cards: selectedCards, date: date, intensity: intensity, calendar: calendar)
    }

    private var canConfirm: Bool {
        !selectedCards.isEmpty && !isPastDate
    }

    private var isPastDate: Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
    }

    /// L'étape des détails : toujours en modification, et d'abord à la création.
    private var showsDetails: Bool {
        isEditing || creationStep == .details
    }

    /// L'étape de la note : toujours en modification, et ensuite à la création.
    private var showsGrade: Bool {
        isEditing || creationStep == .grade
    }

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

                    if showsGrade {
                        intensitySection

                        // La projection reste à la modification, où l'on retouche tout
                        // d'un coup. À la création, la deuxième étape n'est que la note.
                        if isEditing, canConfirm {
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
        return creationStep == .grade
            ? L10n.t("ios.desiredGrade", locale: .resolved())
            : L10n.t("ios.newExam", locale: .resolved())
    }

    private var headerEyebrow: String {
        if isEditing { return L10n.t("ios.examMode", locale: .resolved()) }
        if creationStep == .grade {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? L10n.t("ios.newExam", locale: .resolved()) : trimmed
        }
        return L10n.t("ios.examMode", locale: .resolved())
    }

    private var headerBack: MicaboHeaderBack {
        if !isEditing, creationStep == .grade {
            return .back(goBackToDetails)
        }
        return .close { dismiss() }
    }

    /// Deux pastilles, comme le parcours web : on sait où l'on est sans lire « 1 / 2 ».
    private var stepPips: some View {
        HStack(spacing: 5) {
            pip(isCurrent: creationStep == .details, isDone: creationStep == .grade)
            pip(isCurrent: creationStep == .grade, isDone: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t(
            "ios.stepOf",
            locale: .resolved(),
            vars: ["current": creationStep == .details ? "1" : "2", "total": "2"]
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
        let count = course.cards.filter { !$0.isSuspended }.count

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

    private var intensitySection: some View {
        let scale = DesiredGradeScale.for(OnboardingPreferences.schoolingCountry)
        let score = Int(targetScore.rounded())

        return VStack(alignment: .leading, spacing: 8) {
            // À la création, le titre d'écran dit déjà « Note souhaitée ».
            if isEditing {
                MicaboSectionCaption(text: L10n.t("ios.desiredGrade", locale: .resolved()))
            }

            Text(scale.label(for: score))
                .font(MicaboFont.hanken(28, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .frame(maxWidth: .infinity)

            Text(intensityDetail)
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkSecondary)
                .frame(maxWidth: .infinity)

            HStack {
                Text(scale.min)
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkTertiary)
                Slider(
                    value: $targetScore,
                    in: Double(TargetScore.min)...Double(TargetScore.max),
                    step: 1
                )
                .tint(MicaboColor.ink)
                .accessibilityLabel(L10n.t("ios.desiredGrade", locale: .resolved()))
                .accessibilityValue(scale.label(for: score))
                .onChange(of: targetScore) { _, next in
                    intensity = TargetScore.intensity(from: Int(next.rounded()))
                }
                Text(scale.max)
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
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
        if !isEditing, creationStep == .details {
            return L10n.t("app.common.continue", locale: .resolved())
        }
        return isEditing
            ? L10n.t("ios.replanExam", locale: .resolved())
            : L10n.t("ios.planExam", locale: .resolved())
    }

    private var showsPrimaryIcon: Bool {
        isEditing || creationStep == .grade
    }

    private func primaryAction() {
        if !isEditing, creationStep == .details {
            goToGrade()
            return
        }
        confirm()
    }

    private func goToGrade() {
        guard canConfirm else { return }
        nameFocused = false
        withAnimation(.easeOut(duration: 0.22)) {
            creationStep = .grade
        }
    }

    private func goBackToDetails() {
        nameFocused = false
        withAnimation(.easeOut(duration: 0.22)) {
            creationStep = .details
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        guard let exam else {
            date = calendar.startOfDay(for: max(suggestedDate, Date()))
            return
        }
        name = exam.name
        date = exam.date
        selection = Set(exam.courseIDs)
        intensity = exam.intensity
        targetScore = Double(exam.targetScore)
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
