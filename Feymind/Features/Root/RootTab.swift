import SwiftUI

/// Les cinq destinations de la barre d'onglets.
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
}

/// Onglet actif et profondeur de navigation, partagés par les cinq pages.
@Observable
final class TabRouter {
    var selection: RootTab = .dashboard

    /// Profondeur de pile par onglet : le balayage horizontal ne reste actif
    /// que sur la racine de l'onglet courant.
    private var navigationDepth: [RootTab: Int] = [:]

    var allowsPaging: Bool {
        navigationDepth[selection, default: 0] == 0
    }

    func setNavigationDepth(_ depth: Int, for tab: RootTab) {
        navigationDepth[tab] = max(0, depth)
    }
}
