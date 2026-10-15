import SwiftUI

/// Les destinations de la barre d'onglets.
///
/// **Trois : Home, Leçons, Profil** (`docs/refonte-parcours.md` § 2). Home crée une leçon et
/// montre les stats, Leçons les range, Profil garde le compte et les réglages. On ne balaye pas
/// d'un onglet à l'autre : la barre est le seul moyen de changer de page.
///
/// Les noms de cas datent de l'ancienne barre (`today` porte Home, `decks` les Leçons) : ils
/// sont la clé de la profondeur de navigation de chaque page, et `mika` reste le temps que
/// l'ancien écran de Mika parte avec le nettoyage.
enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case decks
    case today
    case mika
    case profile

    var id: Int { rawValue }

    /// **Les trois onglets de la refonte**, dans l'ordre de la barre : Home, Leçons, Profil
    /// (`docs/refonte-parcours.md` § 2). `today` porte Home, `decks` les Leçons ; Mika vit
    /// désormais dans chaque leçon, son onglet ne s'affiche plus.
    static let tabs: [RootTab] = [.today, .decks, .profile]

    func label(t: (String) -> String) -> String {
        switch self {
        case .decks: t("lesson.tab.lessons")
        case .today: t("lesson.tab.home")
        case .mika: t("ios.nav.mika")
        case .profile: t("lesson.tab.profile")
        }
    }

    var label: String {
        label(t: { L10n.t($0, locale: .resolved()) })
    }

    var systemImage: String {
        switch self {
        case .decks: "books.vertical"
        case .today: "house"
        case .mika: "sparkles"
        case .profile: "person"
        }
    }

    /// Variante pleine, affichée quand l'onglet est actif.
    ///
    /// **Réviser garde son glyphe creux.** Les deux flèches circulaires n'ont pas de
    /// variante pleine qui se dessine à vingt points ; l'onglet actif se lit déjà par la
    /// couleur. Les étincelles de Mika non plus : elles sont déjà pleines.
    var selectedSystemImage: String {
        switch self {
        case .decks: "books.vertical.fill"
        case .today: "house.fill"
        case .mika: "sparkles"
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

    /// Compteur de demandes du cadeau. La liste des decks le demande au retour du premier
    /// cours ; c'est la racine (`DiscountBadgeHost`) qui le présente, par-dessus la barre
    /// du bas et les onglets. Présenté depuis la page, le pop-up assombrissait tout sauf
    /// la barre.
    private(set) var giftRequests = 0

    /// Demande à la racine de poser le cadeau par-dessus l'app.
    func requestGift() {
        giftRequests += 1
    }

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
