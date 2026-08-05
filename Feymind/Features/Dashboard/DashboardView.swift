import SwiftData
import SwiftUI

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

    private var dueCards: [Flashcard] {
        allCards.filter { $0.isDue() }
    }

    private var reviewDates: [Date] {
        reviewLogs.map(\.reviewedAt)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: FeySpacing.lg) {
                        greeting

                        TodayCTACard(
                            dueCount: dueCards.count,
                            reviewedToday: StudyStats.reviewsToday(reviewDates: reviewDates),
                            streak: StudyStats.streak(reviewDates: reviewDates)
                        ) {
                            showStudy = true
                        }

                        statsRow
                        recentCourses
                    }
                    .padding(.horizontal, FeySpacing.screen)
                    .padding(.top, FeySpacing.xs)
                    .padding(.bottom, 96)
                }
                .feyScreenBackground()

                FeyFloatingButton {
                    showImportChoice = true
                }
                .padding(.trailing, FeySpacing.screen)
                .padding(.bottom, FeySpacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Course.self) { course in
                CourseView(course: course)
            }
        }
        .sheet(isPresented: $showImportChoice, onDismiss: launchPendingImport) {
            ImportChoiceSheet { kind in
                pendingImport = kind
                showImportChoice = false
            }
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
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

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(StudyStats.formattedDate())
                .font(FeyFont.caption)
                .foregroundStyle(FeyColor.inkTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(StudyStats.greeting())
                    .font(FeyFont.screenTitle)
                    .foregroundStyle(FeyColor.ink)
                Text("Feymind")
                    .font(FeyFont.display(20))
                    .foregroundStyle(FeyColor.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, FeySpacing.xs)
    }

    private var statsRow: some View {
        HStack(spacing: FeySpacing.sm) {
            statTile(
                value: "\(courses.count)",
                label: courses.count > 1 ? "cours" : "cours",
                systemImage: "book.fill",
                tint: FeyColor.accent
            )
            statTile(
                value: "\(allCards.count)",
                label: "cartes",
                systemImage: "rectangle.on.rectangle",
                tint: FeyColor.mint
            )
            statTile(
                value: "\(StudyStats.reviewsToday(reviewDates: reviewDates))",
                label: "aujourd'hui",
                systemImage: "checkmark.circle.fill",
                tint: FeyColor.amber
            )
        }
    }

    private func statTile(value: String, label: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)

            Text(value)
                .font(FeyFont.display(21))
                .foregroundStyle(FeyColor.ink)

            Text(label)
                .font(FeyFont.micro)
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .feyCard(padding: FeySpacing.sm + 2, radius: FeyRadius.lg, elevated: false)
    }

    @ViewBuilder
    private var recentCourses: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            FeySectionHeader(
                title: "Cours récents",
                subtitle: courses.isEmpty ? nil : "\(courses.count) au total"
            )

            if courses.isEmpty {
                FeyEmptyState(
                    systemImage: "square.and.arrow.down",
                    title: "Aucun cours pour l'instant",
                    message: "Importez un PDF ou collez vos notes : Feymind en fait un cours illustré, puis des flashcards.",
                    actionTitle: "Importer un cours"
                ) {
                    showImportChoice = true
                }
                .feyCard(padding: FeySpacing.xs, radius: FeyRadius.xl, elevated: false)
            } else {
                ForEach(courses.prefix(5)) { course in
                    Button {
                        path.append(course)
                    } label: {
                        CourseCard(course: course)
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
        // Laisse la feuille se refermer avant d'ouvrir l'écran d'import.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            activeImport = kind
        }
    }
}
