import Foundation

/// Lexique de l'app. Trois règles, valables de l'onboarding aux réglages.
///
/// 1. **Un seul mot par concept.** Un contenu importé est un *cours*, et ce que Micabo en
///    écrit est sa *fiche* : ni « résumé », ni « synthèse », ni « note ». Une
///    question-réponse est une *carte* — « flashcard » n'apparaît jamais dans l'interface,
///    seulement dans le code. Un passage de révision est une *session*. L'action est
///    *réviser* : ni « entraînement », ni « exercice », ni « travailler ».
/// 2. **Tutoiement systématique.** Jamais de « vous », jamais de « vos cours ».
/// 3. **Un bouton garde son nom du début à la fin d'un parcours.** Le bouton qui ouvre une
///    session s'appelle « Réviser N cartes », qu'on parte de l'onglet Réviser ou d'un cours.
enum MicaboCopy {
    /// « 1 carte » / « 12 cartes ».
    static func cards(_ count: Int) -> String {
        "\(count) carte\(count > 1 ? "s" : "")"
    }

    /// « 1 cours » / « 4 cours » — invariable au pluriel.
    static func courses(_ count: Int) -> String {
        "\(count) cours"
    }

    /// Le libellé du bouton qui ouvre une session, où qu'il se trouve.
    static func reviewButton(count: Int) -> String {
        count > 0 ? "Réviser \(cards(count))" : "Réviser"
    }

    /// Le libellé du bouton qui lance l'écriture d'une fiche : à l'import comme depuis un
    /// cours qui n'en a pas encore.
    static let sheetButton = "Ficher le cours"

    /// Le libellé du bouton qui lance l'écriture des cartes, où qu'il se trouve.
    static let cardsButton = "Générer les cartes"

    /// « 12 vues · 3 ajouts » — les deux compteurs publics d'un cours.
    static func audience(views: Int, adopts: Int) -> String {
        let viewLabel = views <= 1 ? "\(views) vue" : "\(views) vues"
        let adoptLabel = adopts <= 1 ? "\(adopts) ajout" : "\(adopts) ajouts"
        return "\(viewLabel) · \(adoptLabel)"
    }

    static func audience(of course: SharedCourseRecord) -> String {
        audience(views: course.view_count ?? 0, adopts: course.adopt_count ?? 0)
    }

    static func audience(of course: Course) -> String {
        audience(views: course.viewCount, adopts: course.adoptCount)
    }

    /// Réviser un cours hors file du jour, sans toucher aux échéances.
    static let practiceReview = "Réviser sans compter"

    static let practiceReviewHint = "Réviser sans compter · tes échéances ne bougent pas"

    /// Cartes neuves reportées parce que le rythme du jour est atteint.
    static func heldBackNew(_ count: Int) -> String {
        let noun = count > 1 ? "nouvelles cartes" : "nouvelle carte"
        return "\(count) \(noun) pour plus tard — ton rythme du jour est atteint."
    }
}
