import SwiftUI

/// Les destinations de la barre d'onglets, dans l'ordre où elles s'y présentent.
///
/// **Réviser** reste l'écran d'ouverture : c'est le quotidien, donc celui qui doit être
/// sous le pouce. **Cours** regroupe tout ce qui est importé. **Examens** ouvre le
/// calendrier directement, sans passer par Réviser. Les cours des amis se voient encore
/// sur leur profil, si leur visibilité le permet.
enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case courses
    case today
    case exams
    case profile

    var id: Int { rawValue }

    func label(t: (String) -> String) -> String {
        switch self {
        case .courses: t("nav.courses")
        case .today: t("nav.review")
        case .exams: t("nav.exams")
        case .profile: t("nav.profile")
        }
    }

    var label: String {
        label(t: { L10n.t($0, locale: .resolved()) })
    }

    var systemImage: String {
        switch self {
        case .courses: "books.vertical"
        case .today: "arrow.triangle.2.circlepath"
        case .exams: "calendar"
        case .profile: "person"
        }
    }

    /// Variante pleine, affichée quand l'onglet est actif.
    ///
    /// **Examens garde `calendar`.** `calendar.fill` disparaît sur la barre : le glyphe
    /// plein n'a plus de traits assez denses, à vingt points et en semibold, pour se
    /// dessiner. L'onglet actif se lit déjà par la couleur.
    var selectedSystemImage: String {
        switch self {
        case .courses: "books.vertical.fill"
        case .today: "arrow.triangle.2.circlepath"
        case .exams: "calendar"
        case .profile: "person.fill"
        }
    }
}

/// Onglet actif, partagé pour permettre un basculement programmatique.
@Observable
final class TabRouter {
    var selection: RootTab = .today
    /// Profondeur de navigation par onglet.
    private var navigationDepth: [RootTab: Int] = [:]

    /// Vrai quand la page affichée est sur sa racine. C'est là, et seulement là, que la
    /// barre du bas a un sens : sur un écran poussé, elle disparaît, parce que changer
    /// d'onglet depuis le fond d'une pile ne veut rien dire.
    var isAtRoot: Bool {
        navigationDepth[selection, default: 0] == 0
    }

    func setDepth(_ depth: Int, for tab: RootTab) {
        navigationDepth[tab] = depth
    }

    /// Compteur de demandes de retour à l'accueil. Chaque onglet l'observe et vide sa pile.
    ///
    /// Un compteur, et pas un booléen : deux retours de suite doivent se distinguer, et un
    /// drapeau qu'il faut remettre à faux se fait forcément oublier une fois.
    private(set) var homeRequests = 0

    /// Compteur de demandes d'import depuis un autre onglet. Cours l'observe et ouvre sa
    /// feuille : l'état vide des examens a besoin de cette porte, et la feuille d'import
    /// vit déjà là.
    private(set) var courseImportRequests = 0

    /// **Ramène l'app à son écran d'accueil**, quelle que soit la profondeur d'où l'on part.
    ///
    /// Une session lancée depuis la fiche d'un cours est deux écrans plus loin que
    /// « Réviser » : changer d'onglet sans vider les piles laisserait l'utilisateur devant
    /// le cours qu'il vient de quitter dès qu'il retourne dans Cours.
    func goHome() {
        homeRequests += 1
        selection = .today
    }

    /// Ouvre Cours et demande l'import. L'état vide des examens n'a pas sa propre feuille :
    /// dupliquer l'import ici ferait deux chemins pour le même geste.
    func requestCourseImport() {
        courseImportRequests += 1
        selection = .courses
    }

}
