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
}
