import SwiftUI

/// Les destinations de la barre d'onglets, dans l'ordre où elles s'y présentent.
///
/// **Trois, et Réviser au milieu.** Il y en avait cinq — Cours, Paquets, Réviser, Examens,
/// Profil — ce qui posait deux problèmes. Une barre à cinq n'a plus de milieu, donc plus de
/// place sous le pouce pour le geste quotidien. Et deux de ces cinq onglets montraient la
/// même table sous deux angles : *Cours* listait ce qui était importé, *Paquets* listait
/// les cartes de ces mêmes cours. Un utilisateur devait savoir laquelle des deux portes
/// ouvrir pour un objet unique.
///
/// **Decks remplace Cours**, et c'est le même écran : `CoursesListView`. Le renommage suit
/// le modèle — on n'importe plus un document mais tout le matériel d'une matière — et
/// l'ancien onglet *Paquets* disparaît avec sa vue.
///
/// **Examens disparaît de la barre, pas de l'app.** Les épreuves se lisent sur Réviser, qui
/// les affiche déjà, et la fiche d'une épreuve s'ouvre de là. Le calendrier plein écran,
/// lui, ne revient pas : une date d'examen se pose sur un deck, et c'est tout ce qu'elle
/// fait — elle règle le nombre de cartes neuves par jour.
enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case decks
    case today
    case profile

    var id: Int { rawValue }

    func label(t: (String) -> String) -> String {
        switch self {
        case .decks: t("nav.decks")
        case .today: t("nav.review")
        case .profile: t("nav.profile")
        }
    }

    var label: String {
        label(t: { L10n.t($0, locale: .resolved()) })
    }

    var systemImage: String {
        switch self {
        case .decks: "rectangle.on.rectangle.angled"
        case .today: "arrow.triangle.2.circlepath"
        case .profile: "person"
        }
    }

    /// Variante pleine, affichée quand l'onglet est actif.
    ///
    /// **Réviser garde son glyphe creux.** Les deux flèches circulaires n'ont pas de
    /// variante pleine qui se dessine à vingt points ; l'onglet actif se lit déjà par la
    /// couleur.
    var selectedSystemImage: String {
        switch self {
        case .decks: "rectangle.on.rectangle.angled.fill"
        case .today: "arrow.triangle.2.circlepath"
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

    /// Compteur de demandes d'import depuis un autre onglet. Decks l'observe et ouvre sa
    /// feuille : la feuille d'import vit là, et dupliquer cette porte ferait deux chemins
    /// pour le même geste.
    private(set) var courseImportRequests = 0

    /// **Ramène l'app à son écran d'accueil**, quelle que soit la profondeur d'où l'on part.
    ///
    /// Une session lancée depuis la fiche d'un deck est deux écrans plus loin que
    /// « Réviser » : changer d'onglet sans vider les piles laisserait l'utilisateur devant
    /// le deck qu'il vient de quitter dès qu'il y retourne.
    func goHome() {
        homeRequests += 1
        selection = .today
    }

    /// Ouvre Decks et demande l'import.
    func requestCourseImport() {
        courseImportRequests += 1
        selection = .decks
    }
}
