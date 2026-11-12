import SwiftData
import SwiftUI
import UIKit

/// Une ligne de l'historique, figée : ce que la liste montre d'un exercice.
struct SolverHistoryItem: Identifiable, Equatable {
    var id: UUID
    var statement: String
    var subject: SolverSubject
    var date: Date
    var thumbnail: Data?
    var steps: Int
    var solved: Bool

    init(id: UUID = UUID(), statement: String, subject: SolverSubject, date: Date, thumbnail: Data? = nil, steps: Int, solved: Bool) {
        self.id = id
        self.statement = statement
        self.subject = subject
        self.date = date
        self.thumbnail = thumbnail
        self.steps = steps
        self.solved = solved
    }

    init(_ exercise: SolvedExercise) {
        let solution = exercise.solution
        self.init(
            id: exercise.id,
            statement: exercise.statement,
            subject: exercise.subject,
            date: exercise.createdAt,
            thumbnail: exercise.thumbnail,
            steps: solution?.steps.count ?? 0,
            solved: exercise.solutionRaw != nil
        )
    }
}

/// **Mes exercices** : ceux qu'on a déjà scannés, du plus récent au plus ancien, avec leur
/// vignette, leur matière et leur date, et un filtre par matière. Un appui rouvre la solution.
struct SolverHistoryContent: View {
    let items: [SolverHistoryItem]
    @Binding var filter: SolverSubject?
    var onOpen: (UUID) -> Void = { _ in }
    var onDelete: (UUID) -> Void = { _ in }
    var onScan: () -> Void = {}

    private var shown: [SolverHistoryItem] {
        guard let filter else { return items }
        return items.filter { $0.subject == filter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if items.isEmpty {
                empty
            } else {
                filters
                if shown.isEmpty {
                    Text(solveText("history.emptyFilter"))
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 10) {
                        ForEach(shown) { item in
                            Button { onOpen(item.id) } label: { row(item) }
                                .buttonStyle(MicaboPressableButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) { onDelete(item.id) } label: {
                                        Label(solveText("history.delete"), systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    private var filters: some View {
        MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
            chip(nil)
            ForEach(SolverSubject.allCases) { subject in
                if items.contains(where: { $0.subject == subject }) {
                    chip(subject)
                }
            }
        }
    }

    private func chip(_ subject: SolverSubject?) -> some View {
        let selected = filter == subject
        return Button {
            withAnimation(LearnMotion.quick) { filter = subject }
        } label: {
            HStack(spacing: 6) {
                if let subject { MicaboIconView(icon: subject.icon, size: 16) }
                Text(subject?.label ?? solveText("history.all"))
                    .font(MicaboFont.ui(14, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? MicaboColor.onInk : MicaboColor.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(selected ? MicaboColor.ink : MicaboColor.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Color.clear : MicaboColor.stroke, lineWidth: 1))
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func row(_ item: SolverHistoryItem) -> some View {
        HStack(spacing: 14) {
            Group {
                if let data = item.thumbnail, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            MicaboIconView(icon: item.subject.icon, size: 20)
                                .padding(3)
                                .background(MicaboColor.surface, in: Circle())
                                .offset(x: 5, y: 5)
                        }
                } else {
                    SolverSubjectTile(subject: item.subject, size: 58)
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(KeywordText.plain(item.statement.replacingOccurrences(of: "\n", with: " ")))
                    .font(MicaboFont.ui(16, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    Text(item.subject.label)
                        .foregroundStyle(item.subject == .physics ? MicaboColor.inkSecondary : item.subject.tint)
                    Text("·").foregroundStyle(MicaboColor.inkTertiary)
                    Text(SolverDates.short(item.date))
                        .foregroundStyle(MicaboColor.inkSecondary)
                    if !item.solved {
                        Text("·").foregroundStyle(MicaboColor.inkTertiary)
                        Text(solveText("history.unsolved"))
                            .foregroundStyle(MicaboColor.accentInk)
                    }
                }
                .font(MicaboFont.ui(13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.forward")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(12)
        .solverCard(radius: 20)
    }

    private var empty: some View {
        SolverMikaCard(mood: .idle) {
            VStack(alignment: .leading, spacing: 12) {
                Text(solveText("history.empty"))
                    .font(MicaboFont.ui(17, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onScan) {
                    Label(solveText("history.scan"), systemImage: "viewfinder")
                        .font(MicaboFont.ui(15, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(MicaboBrand.blue, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
            }
        }
    }
}

struct SolverHistoryView: View {
    var onBack: () -> Void
    var onOpen: (UUID) -> Void
    @Query(sort: \SolvedExercise.createdAt, order: .reverse) private var exercises: [SolvedExercise]
    @Environment(\.modelContext) private var context
    @State private var filter: SolverSubject?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MicaboScreenHeader(
                    title: solveText("history.title"),
                    eyebrow: exercises.isEmpty ? nil : solveText("history.count", ["count": "\(exercises.count)"]),
                    back: .back(onBack)
                )
                SolverHistoryContent(
                    items: exercises.map { SolverHistoryItem($0) },
                    filter: $filter,
                    onOpen: onOpen,
                    onDelete: delete,
                    onScan: onBack
                )
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enablesSwipeBack()
    }

    private func delete(_ id: UUID) {
        guard let exercise = exercises.first(where: { $0.id == id }) else { return }
        let target: UUID? = id
        let linked = (try? context.fetch(FetchDescriptor<TutorMessage>(predicate: #Predicate { $0.exerciseID == target }))) ?? []
        for message in linked {
            context.delete(message)
        }
        context.delete(exercise)
        try? context.save()
    }
}
