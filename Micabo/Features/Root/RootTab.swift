import SwiftUI

/// Les cinq destinations de la barre d'onglets native.
enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case today
    case courses
    case dashboard
    case library
    case profile

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .today: "Réviser"
        case .courses: "Mes cours"
        case .dashboard: "Accueil"
        case .library: "Bibliothèque"
        case .profile: "Profil"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "arrow.triangle.2.circlepath"
        case .courses: "books.vertical"
        case .dashboard: "house"
        case .library: "book"
        case .profile: "person"
        }
    }

    /// Variante pleine, affichée quand l'onglet est actif.
    var selectedSystemImage: String {
        switch self {
        case .today: "arrow.triangle.2.circlepath"
        case .courses: "books.vertical.fill"
        case .dashboard: "house.fill"
        case .library: "book.fill"
        case .profile: "person.fill"
        }
    }
}

/// Onglet actif, partagé pour permettre un basculement programmatique.
@Observable
final class TabRouter {
    var selection: RootTab = .dashboard
    /// Profondeur de navigation par onglet : le balayage n'est actif que sur une racine.
    private var navigationDepth: [RootTab: Int] = [:]

    var allowsPaging: Bool {
        navigationDepth[selection, default: 0] == 0
    }

    func setDepth(_ depth: Int, for tab: RootTab) {
        navigationDepth[tab] = depth
    }
}
