import SwiftData
import SwiftUI

/// Déclarer ou modifier un examen : un nom, un jour, des cours, une intensité.
///
/// Les quatre champs se remplissent dans cet ordre, et **la projection apparaît dès que la
/// date et un cours sont là**. Elle n'est pas au bout d'un bouton « Calculer » : c'est en
/// voyant la charge bouger qu'on comprend ce que l'intensité veut dire, et qu'on recule d'un
/// cran si le jour le plus chargé fait peur.
struct ExamEditorSheet: View {
    /// Nul pour un nouvel examen.
    let exam: Exam?
    /// Jour proposé à l'ouverture, quand on part d'une case du calendrier.
    var suggestedDate: Date = Date()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var name = ""
    @State private var date = Date()
    @State private var selection: Set<UUID> = []
    @State private var intensity: ExamIntensity = .standard
    @State private var errorMessage: String?
    @State private var didLoad = false

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

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    header
                    nameField
                    dateField
                    coursesSection
                    intensitySection

                    if canConfirm {
                        ExamProjectionView(plan: plan)
                    } else {
                        emptyProjection
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboLayout.bottomBarClearance)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .micaboScreenBackground()

            MicaboBottomBar {
                Button(action: confirm) {
                    HStack(spacing: MicaboSpacing.xs) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 13, weight: .semibold))
                        Text(isEditing ? "Replanifier" : "Planifier l'examen")
                    }
                }
                .buttonStyle(MicaboPrimaryButtonStyle(tint: canConfirm ? MicaboColor.ink : MicaboColor.strokeStrong))
                .disabled(!canConfirm)
            }
        }
        .task { load() }
        .alert("Oups", isPresented: .constant(errorMessage != nil)) {
            Button("Fermer", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Champs

    private var header: some View {
        MicaboScreenHeader(
            title: isEditing ? "Modifier l'examen" : "Nouvel examen",
            eyebrow: "Mode examen",
            back: MicaboHeaderBack.close { dismiss() }
        )
        .padding(.top, MicaboSpacing.xs)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Nom")
                .font(MicaboFont.captionEmphasis)
                .foregroundStyle(MicaboColor.ink)

            TextField("Bac blanc, partiel de SVT…", text: $name)
                .font(MicaboFont.body)
                .padding(MicaboSpacing.sm)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Date")
                .font(MicaboFont.captionEmphasis)
                .foregroundStyle(MicaboColor.ink)

            DatePicker("", selection: $date, in: Date().addingTimeInterval(-86_400)..., displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(MicaboSpacing.sm)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))

            if isPastDate {
                Text("Un examen passé ne se planifie pas.")
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.negative)
            }
        }
    }

    /// Les cours au programme. Une rangée par cours, avec son volume de cartes : c'est ce
    /// volume qui fait la charge, donc c'est lui qu'on doit voir en cochant.
    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Cours au programme")

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
            Haptics.selection()
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
        .buttonStyle(MicaboRowButtonStyle())
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Intensité")

            HStack(spacing: MicaboSpacing.xs) {
                ForEach(ExamIntensity.allCases) { value in
                    MicaboSelectChip(title: value.label, isSelected: value == intensity) {
                        Haptics.selection()
                        withAnimation(.easeOut(duration: 0.2)) { intensity = value }
                    }
                }
            }

            MicaboSectionFootnote(text: intensity.detail)
        }
    }

    private var emptyProjection: some View {
        MicaboSectionFootnote(
            text: selectedCourses.isEmpty
                ? "Choisis les cours au programme : Micabo te dira ce que ça représente par jour avant de replanifier quoi que ce soit."
                : "Les cours choisis n'ont aucune carte. Génère-les depuis leur fiche, puis reviens ici."
        )
    }

    // MARK: - Actions

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
                    in: modelContext
                )
                try ExamRepository.plan(created, in: modelContext)
            }
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
