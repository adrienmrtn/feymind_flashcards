import SwiftUI

/// **Scanner un exo** : l'ancien écran (une photo, puis une conversation qui s'oubliait) a laissé
/// la place au scanner d'exercices, `SolverFlowView` (`Micabo/Features/Solver`) — capture avec
/// cadre, solution pas à pas, historique, et « Demande à Mika » par matière. Le nom reste pour
/// les écrans qui l'ouvrent.
struct ScanExerciseView: View {
    var body: some View {
        SolverFlowView()
    }
}
