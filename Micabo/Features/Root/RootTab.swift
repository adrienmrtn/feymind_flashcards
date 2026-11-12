import SwiftUI

/// Les destinations de la barre d'onglets.
///
/// **Cinq : Home, Leçons, Calendrier, Concentration, Profil.** Home crée une leçon et montre
/// la journée, Leçons les range, Calendrier tient la vie d'étude en un seul endroit (les
/// cours, les examens et leur compte à rebours, les révisions que Mika planifie), Concentration
/// lance une séance chronométrée et garde les tâches, Profil garde le compte et les réglages.
/// On ne balaye pas d'un onglet à l'autre : la barre est le seul moyen de changer de page.
///
/// **Les rangs ne bougent jamais** : ils sont la clé de la profondeur de navigation de chaque
/// page. Les noms de cas datent de l'ancienne barre (`today` porte Home, `decks` les Leçons) ;
/// `calendar` a repris le rang 3 de l'ancien onglet Examen, qu'il remplace : tout ce qui
/// ouvrait Examen ouvre le Calendrier, où les examens ont déménagé.
enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case decks
    case today
    case profile
    /// Le Calendrier, au rang de l'ancien onglet Examen.
    case calendar
    /// Ajouté après les autres : les rangs déjà donnés ne bougent pas.
    case focus

    var id: Int { rawValue }

    /// **Les cinq onglets**, dans l'ordre de la barre : Home, Leçons, Calendrier,
    /// Concentration, Profil. `today` porte Home, `decks` les Leçons ; Mika vit dans chaque
    /// leçon.
    static let tabs: [RootTab] = [.today, .decks, .calendar, .focus, .profile]

    func label(t: (String) -> String) -> String {
        switch self {
        case .decks: t("lesson.tab.lessons")
        case .today: t("lesson.tab.home")
        case .calendar: t("ios.cal.tab")
        case .focus: t("ios.focus.tab")
        case .profile: t("lesson.tab.profile")
        }
    }

    var label: String {
        label(t: { L10n.t($0, locale: .resolved()) })
    }

    /// **Le nom écrit dans la barre**, plus court quand le titre de la page ne tient pas dans
    /// un cinquième d'écran : « Concentration », « Keskittyminen », « Concentración » y
    /// tombaient à 62 % de leur taille. La page garde son titre entier ; la barre dit
    /// « Focus », « Keskity », « Enfoque ».
    ///
    /// Home s'y appelle « Accueil ». Depuis la V3.3 la barre ne montre que des icônes : ces noms
    /// sont ceux que VoiceOver lit, et que la visionneuse en très grand texte affiche.
    func barLabel(t: (String) -> String) -> String {
        switch self {
        case .focus: t("ios.pol.sys.tab.focus")
        case .today: t("ios.look10.tab.home")
        default: label(t: t)
        }
    }

    var systemImage: String {
        switch self {
        case .decks: "books.vertical"
        case .today: "house"
        case .calendar: "calendar"
        case .focus: "timer"
        case .profile: "person"
        }
    }

    /// Variante pleine, affichée quand l'onglet est actif : sans libellé, c'est le plein et la
    /// clarté de l'icône qui disent où l'on est.
    var selectedSystemImage: String {
        switch self {
        case .decks: "books.vertical.fill"
        case .today: "house.fill"
        case .calendar: "calendar"
        case .focus: "timer"
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

    /// Compteur de demandes de séance depuis un autre onglet : Concentration l'observe et
    /// ouvre « Préparer ma session ».
    private(set) var focusRequests = 0

    /// Le jour que le Calendrier doit montrer en arrivant, s'il y en a un.
    private(set) var calendarDay: Date?
    private(set) var calendarRequests = 0

    /// **Ouvre le Calendrier**, sur un jour si on en donne un. C'est la porte de tout ce qui
    /// ouvrait l'ancien onglet Examen.
    func showCalendar(day: Date? = nil) {
        calendarDay = day
        calendarRequests += 1
        selection = .calendar
    }

    /// Ouvre Concentration et sa feuille « Préparer ma session ».
    func requestFocusSession() {
        focusRequests += 1
        selection = .focus
    }
}
