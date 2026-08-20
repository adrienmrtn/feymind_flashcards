import SwiftUI

/// Les trois destinations de la barre d'onglets.
///
/// L'app ouvre sur **Réviser**, qui porte aussi ce que faisait l'accueil : entre le
/// lancement et la première carte, il ne doit y avoir aucun appui parasite. **Cours**
/// regroupe tout ce qui est importé, et accueillera la bibliothèque en sous-onglet
/// « Découvrir » quand elle sera réellement active.
enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case today
    case courses
    case profile

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .today: "Réviser"
        case .courses: "Cours"
        case .profile: "Profil"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "arrow.triangle.2.circlepath"
        case .courses: "books.vertical"
        case .profile: "person"
        }
    }

    /// Variante pleine, affichée quand l'onglet est actif.
    var selectedSystemImage: String {
        switch self {
        case .today: "arrow.triangle.2.circlepath"
        case .courses: "books.vertical.fill"
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

    var allowsPaging: Bool {
        navigationDepth[selection, default: 0] == 0
    }

    func setDepth(_ depth: Int, for tab: RootTab) {
        navigationDepth[tab] = depth
    }
}
