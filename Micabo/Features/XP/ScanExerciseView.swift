import SwiftUI

/// **Scanner un exo** : l'ancien écran (une photo, puis une conversation qui s'oubliait) a laissé
/// la place au scanner d'exercices, `SolverFlowView` (`Micabo/Features/Solver`) — capture avec
/// cadre, solution pas à pas, historique, et « Demande à Mika » par matière. Le nom reste pour
/// les écrans qui l'ouvrent.
struct ScanExerciseView: View {
    /// Lot 12 — le mode d'ouverture de la caméra (la feuille Outils) ; sinon le dernier choisi.
    var initialMode: ScanMode?
    var onMakeLesson: ((ChatLessonSeed) -> Void)?

    var body: some View {
        SolverFlowView(initialMode: initialMode, onMakeLesson: onMakeLesson)
    }
}
