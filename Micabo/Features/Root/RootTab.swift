import SwiftUI

/// Les trois destinations de la barre d'onglets, dans l'ordre où elles se balayent.
///
/// **Réviser** est au milieu, et c'est là que l'app ouvre : c'est l'écran du quotidien,
/// donc celui qu'on rejoint d'un seul balayage depuis n'importe où. **Cours** regroupe
/// tout ce qui est importé, et accueillera la bibliothèque en sous-onglet « Découvrir »
/// quand elle sera réellement active.
enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case courses
    case today
    case profile

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .courses: "Cours"
        case .today: "Réviser"
        case .profile: "Profil"
        }
    }

    var systemImage: String {
        switch self {
        case .courses: "books.vertical"
        case .today: "arrow.triangle.2.circlepath"
        case .profile: "person"
        }
    }

    /// Variante pleine, affichée quand l'onglet est actif.
    var selectedSystemImage: String {
        switch self {
        case .courses: "books.vertical.fill"
        case .today: "arrow.triangle.2.circlepath"
        case .profile: "person.fill"
        }
    }
}

/// Onglet actif, partagé pour permettre un basculement programmatique.
@Observable
final class TabRouter {
    var selection: RootTab = .today
    /// Profondeur de navigation par onglet : le balayage n'est actif que sur une racine.
    private var navigationDepth: [RootTab: Int] = [:]

    /// Vrai quand la page affichée est sur sa racine. C'est là, et seulement là, que le
    /// balayage entre onglets et la barre du bas ont un sens : sur un écran poussé, les
    /// deux disparaissent.
    var isAtRoot: Bool {
        navigationDepth[selection, default: 0] == 0
    }

    func setDepth(_ depth: Int, for tab: RootTab) {
        navigationDepth[tab] = depth
    }
}
