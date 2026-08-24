import SwiftData
import SwiftUI

/// **La page Examens.**
///
/// Elle n'est pas un quatrième onglet, et ce n'est pas un compromis : Micabo tient à trois
/// onglets avec Réviser au milieu, et un quatrième ferait disparaître ce milieu. Un examen
/// est de toute façon une affaire de planning, donc sa place est derrière Réviser, qui est
/// l'écran du planning.
///
/// L'écran fait deux choses. Le **calendrier** montre les échéances et sert de cible pour
/// les déplacer. La **liste** en dessous montre ce qu'un calendrier ne peut pas dire : le
/// nom, les cours, le volume de cartes, et si la replanification est active.
struct ExamsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Exam.date, order: .forward) private var exams: [Exam]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var month = Date()
    @State private var selectedDay: Date?
    @State private var editing: ExamEdition?
    @State private var pendingDeletion: Exam?
    @State private var errorMessage: String?

    private let calendar = MicaboCalendar.shared
    private let today = Date()

    /// Ce qu'on ouvre dans la feuille : un examen existant, ou un nouveau sur un jour donné.
    private struct ExamEdition: Identifiable {
        let id = UUID()
        var exam: Exam?
        var date: Date
    }

    private var upcoming: [Exam] {
        exams.filter { !$0.isPast(from: today, calendar: calendar) }
    }

    /// Du plus récent au plus ancien : un examen passé qu'on relit est celui qu'on vient de
    /// passer, pas celui de l'an dernier.
    private var past: [Exam] {
        Array(exams.filter { $0.isPast(from: today, calendar: calendar) }.reversed())
    }

    private var examsByDay: [Date: [Exam]] {
        Dictionary(grouping: exams) { calendar.startOfDay(for: $0.date) }
    }

    /// Les examens du jour sélectionné. Vide quand aucun jour ne l'est, ou quand le jour
    /// choisi est libre : la section propose alors d'y placer un examen.
    private var selectedExams: [Exam] {
        guard let selectedDay else { return [] }
        return examsByDay[calendar.startOfDay(for: selectedDay)] ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                header

                ExamCalendarView(
                    month: month,
                    selectedDay: selectedDay,
                    examsByDay: examsByDay,
                    onSelect: select,
                    onStep: step,
                    onDrop: drop
                )

                if selectedDay != nil {
                    selectedDaySection
                }

                if !upcoming.isEmpty {
                    section(title: "À venir", exams: upcoming)
                }

                if !past.isEmpty {
                    section(title: "Passés", exams: past)
                }

                if exams.isEmpty {
                    emptyState
                }
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
        .overlay(alignment: .bottom) {
            MicaboBottomBar {
                Button {
                    Haptics.medium()
                    editing = ExamEdition(exam: nil, date: selectedDay ?? today)
                } label: {
                    HStack(spacing: MicaboSpacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Ajouter un examen")
                    }
                }
                .buttonStyle(MicaboPrimaryButtonStyle())
            }
        }
        .sheet(item: $editing) { edition in
            ExamEditorSheet(exam: edition.exam, suggestedDate: edition.date)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(MicaboRadius.sheet)
        }
        .alert("Oups", isPresented: .constant(errorMessage != nil)) {
            Button("Fermer", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Supprimer cet examen ?",
            isPresented: .constant(pendingDeletion != nil),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { exam in
            Button("Supprimer", role: .destructive) { delete(exam) }
            Button("Annuler", role: .cancel) { pendingDeletion = nil }
        } message: { exam in
            Text(deletionWarning(for: exam))
        }
    }

    // MARK: - En-tête

    private var header: some View {
        MicaboScreenHeader(
            title: "Examens",
            eyebrow: headerEyebrow,
            back: MicaboHeaderBack.back { dismiss() }
        )
        .padding(.top, MicaboSpacing.xs)
    }

    private var headerEyebrow: String {
        guard let next = upcoming.first else {
            return exams.isEmpty ? "Aucun examen" : "Rien à venir"
        }
        return "\(next.name) · \(next.countdownLabel(from: today, calendar: calendar))"
    }

    // MARK: - Sections

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                MicaboSectionCaption(text: MicaboCalendar.dayLabel(selectedDay ?? today))
                Spacer(minLength: MicaboSpacing.xs)
                Button("Fermer") {
                    withAnimation(.easeOut(duration: 0.2)) { selectedDay = nil }
                }
                .font(MicaboFont.hanken(13, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
            }

            if selectedExams.isEmpty {
                Button {
                    Haptics.medium()
                    editing = ExamEdition(exam: nil, date: selectedDay ?? today)
                } label: {
                    HStack(spacing: MicaboSpacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Placer un examen ce jour-là")
                    }
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
            } else {
                rows(selectedExams)
            }
        }
    }

    private func section(title: String, exams: [Exam]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: title)
            rows(exams)
        }
    }

    private func rows(_ exams: [Exam]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(exams.enumerated()), id: \.element.id) { index, exam in
                row(exam)
                if index < exams.count - 1 {
                    MicaboHairline(inset: 71)
                }
            }
        }
        .micaboGroup()
    }

    /// La rangée d'un examen. C'est elle qu'on **prend au doigt** pour la poser sur un jour
    /// du calendrier, et son menu contextuel porte les actions qui ne se devinent pas.
    private func row(_ exam: Exam) -> some View {
        let isPast = exam.isPast(from: today, calendar: calendar)

        return Button {
            editing = ExamEdition(exam: exam, date: exam.date)
        } label: {
            HStack(spacing: 13) {
                MicaboTile(
                    glyph: .symbol("calendar"),
                    background: isPast ? MicaboColor.surfaceMuted : MicaboColor.cautionSoft,
                    tint: isPast ? MicaboColor.inkTertiary : MicaboColor.caution
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(exam.name)
                        .font(MicaboFont.rowTitle)
                        .foregroundStyle(isPast ? MicaboColor.inkSecondary : MicaboColor.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(subtitle(for: exam))
                        .font(MicaboFont.rowSubtitle)
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: MicaboSpacing.xs)

                if !isPast {
                    MicaboBadge(
                        text: exam.countdownLabel(from: today, calendar: calendar),
                        tone: exam.isPlanned ? .warm : .neutral
                    )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary.opacity(0.8))
            }
            .padding(.vertical, 11)
            .padding(.horizontal, MicaboSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboRowButtonStyle())
        .draggable(ExamTransfer(id: exam.id)) {
            // Ce qui suit le doigt : le nom suffit, et une vignette large masquerait le jour
            // qu'on vise.
            Text(exam.name)
                .font(MicaboFont.captionEmphasis)
                .foregroundStyle(MicaboColor.ink)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(MicaboColor.cautionSoft, in: Capsule())
        }
        .contextMenu {
            Button {
                editing = ExamEdition(exam: exam, date: exam.date)
            } label: {
                Label("Modifier", systemImage: "pencil")
            }
            if exam.isPlanned {
                Button { unplan(exam) } label: {
                    Label("Rendre le planning normal", systemImage: "arrow.uturn.backward")
                }
            } else if !isPast {
                Button { replan(exam) } label: {
                    Label("Replanifier les révisions", systemImage: "calendar.badge.clock")
                }
            }
            Divider()
            Button(role: .destructive) { pendingDeletion = exam } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    private func subtitle(for exam: Exam) -> String {
        var parts = [MicaboCalendar.dayLabel(exam.date, from: today)]

        // Les cours sont comptés depuis la liste déjà chargée : une requête par rangée à
        // chaque rendu coûterait cher pour une information de sous-titre.
        let count = courseCount(of: exam)
        if count > 0 {
            parts.append(MicaboCopy.courses(count))
        }
        if !exam.isPlanned, !exam.isPast(from: today, calendar: calendar) {
            parts.append("planning normal")
        }
        return parts.joined(separator: " · ")
    }

    private func courseCount(of exam: Exam) -> Int {
        let wanted = Set(exam.courseIDs)
        return courses.filter { wanted.contains($0.id) }.count
    }

    private var emptyState: some View {
        MicaboEmptyState(
            systemImage: "calendar",
            title: "Aucun examen prévu",
            message: "Déclare une date et les cours au programme : Micabo replanifie tes révisions pour que chaque carte soit au sommet de sa rétention le jour J, et pas trois semaines après.",
            actionTitle: "Ajouter un examen"
        ) {
            editing = ExamEdition(exam: nil, date: today)
        }
    }

    // MARK: - Actions

    /// Un second appui sur le jour déjà sélectionné le déselectionne : c'est la façon la
    /// plus simple de refermer la section du jour sans chercher un bouton.
    private func select(_ day: Date) {
        let start = calendar.startOfDay(for: day)
        let wasSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: start) } ?? false

        withAnimation(.easeOut(duration: 0.2)) {
            selectedDay = wasSelected ? nil : start
            // Toucher un débord du mois voisin fait suivre le calendrier.
            if !calendar.isDate(start, equalTo: month, toGranularity: .month) {
                month = start
            }
        }
    }

    private func step(_ months: Int) {
        withAnimation(.easeOut(duration: 0.2)) {
            month = calendar.date(byAdding: .month, value: months, to: month) ?? month
        }
    }

    /// Un examen posé sur un jour du calendrier. Le déplacement **replanifie** : garder les
    /// échéances calculées pour l'ancienne date donnerait un planning qui ne mène plus nulle
    /// part.
    private func drop(_ id: UUID, on day: Date) -> Bool {
        guard let exam = exams.first(where: { $0.id == id }) else { return false }
        let target = calendar.startOfDay(for: day)
        guard target >= calendar.startOfDay(for: today) else { return false }
        guard !calendar.isDate(exam.date, inSameDayAs: target) else { return true }

        do {
            try ExamRepository.move(exam, to: target, in: modelContext)
            Haptics.success()
            withAnimation(.easeOut(duration: 0.2)) { selectedDay = target }
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    private func replan(_ exam: Exam) {
        do {
            try ExamRepository.plan(exam, in: modelContext)
            Haptics.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func unplan(_ exam: Exam) {
        do {
            try ExamRepository.unplan(exam, in: modelContext)
            Haptics.light()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func delete(_ exam: Exam) {
        pendingDeletion = nil
        do {
            try ExamRepository.delete(exam, in: modelContext)
            Haptics.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func deletionWarning(for exam: Exam) -> String {
        exam.isPlanned
            ? "Les révisions replanifiées pour « \(exam.name) » retrouveront leurs échéances d'avant."
            : "« \(exam.name) » sera retiré du calendrier."
    }
}

/// Destination de navigation de la page Examens.
struct ExamsRoute: Hashable {}
