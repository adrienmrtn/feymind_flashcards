import SwiftData
import SwiftUI

/// Valeur du filtre par matière qui n'exclut rien.
private let allSubjectsFilter = "Tout"

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TabRouter.self) private var router: TabRouter?

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
        guard subjectFilter != allSubjectsFilter, subjects.contains(subjectFilter) else { return courses }
        return courses.filter { $0.subject?.nilIfBlank == subjectFilter }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                            .padding(.horizontal, FeySpacing.screen)

                        if courses.isEmpty {
                            emptyState
                                .padding(.horizontal, FeySpacing.screen)
                        } else {
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
                        }
                    }
                    .padding(.top, FeySpacing.xs)
                    .padding(.bottom, FeyLayout.fabClearance)
                }
                .feyScreenBackground()

                FeyFloatingAddButton {
                    showImportChoice = true
                }
                .padding(.trailing, 18)
                .padding(.bottom, 18)
            }
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
            .presentationDetents([.height(320)])
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
        VStack(alignment: .leading, spacing: 7) {
            Text(StudyStats.formattedDate())
                .font(FeyFont.hanken(13, weight: .medium))
                .foregroundStyle(FeyColor.inkTertiary)

            Text(StudyStats.greeting())
                .font(FeyFont.hanken(26, weight: .bold))
                .foregroundStyle(FeyColor.ink)
                .tracking(-0.4)
        }
        .padding(.top, FeySpacing.xs)
    }

    private var emptyState: some View {
        FeyEmptyState(
            systemImage: "doc.text",
            title: "Aucun cours pour l'instant",
            message: "Importez un PDF ou collez du texte pour générer vos premières flashcards.",
            actionTitle: "Importer un cours"
        ) {
            showImportChoice = true
        }
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeySectionHeader(
                title: "Vos cours",
                actionTitle: "Tout voir"
            ) {
                router?.selection = .courses
            }

            VStack(spacing: 12) {
                ForEach(visibleCourses.prefix(6)) { course in
                    Button {
                        path.append(course)
                    } label: {
                        CourseRow(course: course)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Import

    private func launchPendingImport() {
        guard let kind = pendingImport else { return }
        pendingImport = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            activeImport = kind
        }
    }
}
