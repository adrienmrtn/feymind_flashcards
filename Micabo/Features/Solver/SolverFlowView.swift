import SwiftData
import SwiftUI

enum SolverFlow {
    /// En dessous, la photo n'a rien donné de lisible.
    static let minimumCharacters = 12
}

/// Les écrans qu'on pousse depuis la capture.
enum SolverRoute: Hashable {
    case solution(UUID)
    case history
    case tutor
    case thread(SolverSubject)
}

/// **Le scanner d'exercices** (`docs/refonte-knowunity.md` § 4), ouvert depuis la tuile
/// « Scanner un exo » de Home : la capture, puis la solution pas à pas ; l'historique des
/// exercices ; et « Demande à Mika », un fil par matière où les exercices scannés arrivent.
struct SolverFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SolvedExercise.createdAt, order: .reverse) private var exercises: [SolvedExercise]
    @State private var path: [SolverRoute] = []
    /// Les séances ouvertes : une par exercice, gardée tant que l'écran du scanner vit.
    @State private var sessions: [UUID: SolverSession] = [:]

    var body: some View {
        NavigationStack(path: $path) {
            SolverCaptureView(
                historyCount: exercises.count,
                onClose: { dismiss() },
                onHistory: { path.append(.history) },
                onTutor: { path.append(.tutor) },
                onRead: read
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SolverRoute.self) { route in
                destination(route)
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: SolverRoute) -> some View {
        switch route {
        case .solution(let id):
            if let session = session(for: id) {
                SolverSolutionView(
                    session: session,
                    onBack: { pop() },
                    onAskMika: { subject in path.append(.thread(subject)) }
                )
                .enablesSwipeBack()
            }
        case .history:
            SolverHistoryView(onBack: { pop() }, onOpen: open)
        case .tutor:
            TutorHomeView(onBack: { pop() }, onOpen: { subject in path.append(.thread(subject)) })
        case .thread(let subject):
            TutorThreadView(subject: subject, onBack: { pop() }, onOpenExercise: open)
        }
    }

    private func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// La séance d'un exercice : celle qui est ouverte, sinon une nouvelle sur l'exercice gardé.
    private func session(for id: UUID) -> SolverSession? {
        if let open = sessions[id] { return open }
        return exercises.first(where: { $0.id == id }).map { SolverSession(exercise: $0) }
    }

    /// Rouvre un exercice de l'historique ou d'un fil.
    private func open(_ id: UUID) {
        if sessions[id] == nil, let exercise = exercises.first(where: { $0.id == id }) {
            sessions[id] = SolverSession(exercise: exercise)
        }
        guard sessions[id] != nil else { return }
        path.append(.solution(id))
    }

    /// Un énoncé lu : la matière devinée, et la solution s'ouvre sur l'énoncé à vérifier.
    /// L'exercice n'entre dans l'historique qu'à la demande de solution.
    private func read(_ statement: String, _ source: SolverSource, _ thumbnail: Data?) {
        let exercise = SolvedExercise(
            statement: String(statement.prefix(MikaLimits.attachmentCharacters)),
            subject: SolverSubjectGuess.guess(statement),
            source: source,
            thumbnail: thumbnail
        )
        let session = SolverSession(exercise: exercise)
        sessions[exercise.id] = session
        path.append(.solution(exercise.id))
    }
}
