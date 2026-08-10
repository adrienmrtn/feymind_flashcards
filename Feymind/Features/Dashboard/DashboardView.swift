import SwiftData
import SwiftUI

/// Valeur du filtre par matière qui n'exclut rien.
private let allSubjectsFilter = "Tous"

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Course.createdAt, order: .reverse) private var courses: [Course]
    @Query private var allCards: [Flashcard]
    @Query private var reviewLogs: [ReviewLog]

    @State private var path: [Course] = []
    @State private var showImportChoice = false
    @State private var pendingImport: ImportKind?
    @State private var activeImport: ImportKind?
    @State private var showStudy = false
    @State private var subjectFilter = allSubjectsFilter

    private var dueCards: [Flashcard] {
        allCards.filter { $0.isDue() }
    }

    private var reviewDates: [Date] {
        reviewLogs.map(\.reviewedAt)
    }

    private var subjects: [String] {
        let names = Set(courses.compactMap { $0.subject?.nilIfBlank })
        return [allSubjectsFilter] + names.sorted()
    }

    private var visibleCourses: [Course] {
        // Le filtre retombe sur « Tous » si la matière sélectionnée n'existe plus.
        guard subjectFilter != allSubjectsFilter, subjects.contains(subjectFilter) else { return courses }
        return courses.filter { $0.subject?.nilIfBlank == subjectFilter }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: FeySpacing.lg) {
                    header
                        .padding(.horizontal, FeySpacing.screen)

                    TodayCTACard(
                        dueCount: dueCards.count,
                        reviewedToday: StudyStats.reviewsToday(reviewDates: reviewDates),
                        streak: StudyStats.streak(reviewDates: reviewDates)
                    ) {
                        showStudy = true
                    }
                    .padding(.horizontal, FeySpacing.screen)

                    if subjects.count > 2 {
                        FeySelectChipRow(titles: subjects, selection: $subjectFilter)
                    }

                    coursesSection
                        .padding(.horizontal, FeySpacing.screen)

                    if !courses.isEmpty {
                        statsRow
                            .padding(.horizontal, FeySpacing.screen)
                    }
                }
                .padding(.top, FeySpacing.xs)
                .padding(.bottom, FeySpacing.xl)
            }
            .feyScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Course.self) { course in
                FlashcardsView(course: course)
            }
        }
        .sheet(isPresented: $showImportChoice, onDismiss: launchPendingImport) {
            ImportChoiceSheet { kind in
                pendingImport = kind
                showImportChoice = false
            }
            .presentationDetents([.height(330)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(FeyRadius.xxl)
        }
        .fullScreenCover(item: $activeImport) { kind in
            ImportView(kind: kind) { course in
                activeImport = nil
                path = [course]
            }
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudyView(source: .allDue)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(StudyStats.formattedDate())
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)

                Text(StudyStats.greeting())
                    .font(FeyFont.screenTitle)
                    .foregroundStyle(FeyColor.ink)
                    .tracking(FeyTracking.tight)
            }

            Spacer(minLength: FeySpacing.sm)

            FeyCircleButton(
                systemImage: "plus",
                style: .dark,
                size: 48,
                accessibilityTitle: "Importer un cours"
            ) {
                showImportChoice = true
            }
        }
        .padding(.top, FeySpacing.xs)
    }

    @ViewBuilder
    private var coursesSection: some View {
        if courses.isEmpty {
            FeyEmptyState(
                systemImage: "square.and.arrow.down",
                title: "Aucun cours",
                message: "Importez un PDF ou collez vos notes : Feymind en fait des flashcards prêtes à réviser.",
                actionTitle: "Importer un cours"
            ) {
                showImportChoice = true
            }
        } else {
            VStack(alignment: .leading, spacing: FeySpacing.sm) {
                FeySectionHeader(
                    title: "Vos cours",
                    subtitle: visibleCourses.count > 1 ? "\(visibleCourses.count) au total" : nil
                )

                ForEach(visibleCourses.prefix(6)) { course in
                    Button {
                        path.append(course)
                    } label: {
                        CourseCoverCard(course: course)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: FeySpacing.sm) {
            statTile(value: "\(courses.count)", label: "cours")
            statTile(value: "\(allCards.count)", label: "cartes")
            statTile(
                value: "\(StudyStats.reviewsToday(reviewDates: reviewDates))",
                label: "aujourd'hui"
            )
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(FeyFont.display(22))
                .foregroundStyle(FeyColor.ink)

            Text(label)
                .font(FeyFont.micro)
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .feyCard(padding: FeySpacing.sm + 2, radius: FeyRadius.lg, elevated: false)
    }

    // MARK: - Import

    private func launchPendingImport() {
        guard let kind = pendingImport else { return }
        pendingImport = nil
        // Laisse la feuille se refermer avant d'ouvrir l'écran d'import.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            activeImport = kind
        }
    }
}
