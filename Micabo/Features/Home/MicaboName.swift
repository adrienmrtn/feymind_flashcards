import Foundation

/// **Un nom par chose** (lot 10, HOME.md § 3).
///
/// Une leçon s'ouvre sur ses Notes, son Quiz, ses Cartes, Mika, Écouter, À voix haute, sa Carte
/// mentale et sa Fiche PDF ; la Home propose Scanner un exo, Quiz éclair, Corriger un texte et
/// Examen blanc ; la barre du bas dit Focus. Chaque chose a **un** nom, et chaque écran qui la
/// nomme — une tuile, une puce, un titre, un libellé d'accessibilité — le lit ici. Un synonyme
/// écrit à part (« Flashcards », « Aide aux devoirs », « Entraînement », « Concentration ») est
/// ce qui faisait dire « j'comprends rien aux fonctionnalités ».
///
/// Les noms qui existaient déjà sous leur bon mot gardent leur clé (vingt-six langues écrites) ;
/// seuls ceux qui changent en ont une neuve.
enum MicaboName: String, CaseIterable {
    case notes
    case quiz
    case cards
    case mika
    case listen
    case voice
    case mindMap
    case sheet
    case mock
    case scan
    case writing
    case quickQuiz
    case focus

    /// La clé de la phrase. Mika est un nom propre : il ne se traduit pas.
    var key: String? {
        switch self {
        case .notes: "lesson.nav.notes"
        case .quiz: "lesson.nav.quiz"
        case .cards: "ios.home10.name.cards"
        case .mika: nil
        case .listen: "ios.sup.modes.listen"
        case .voice: "ios.sup.modes.voice"
        case .mindMap: "ios.sup.modes.mindMap"
        case .sheet: "ios.sup.modes.export"
        case .mock: "ios.cal.mock"
        case .scan: "ios.home10.name.scan"
        case .writing: "ios.ku7.tools.writing"
        case .quickQuiz: "ios.kx.tools.quiz.title"
        case .focus: "ios.pol.sys.tab.focus"
        }
    }

    /// Le nom, dans la langue de l'app.
    func text(locale: UiLocale = .resolved()) -> String {
        guard let key else { return "Mika" }
        return L10n.t(key, locale: locale)
    }
}
