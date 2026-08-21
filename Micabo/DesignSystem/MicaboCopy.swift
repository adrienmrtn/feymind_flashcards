import Foundation

/// Lexique de l'app. Trois règles, valables de l'onboarding aux réglages.
///
/// 1. **Un seul mot par concept.** Un contenu importé est un *cours*. Une question-réponse
///    est une *carte* — « flashcard » n'apparaît jamais dans l'interface, seulement dans le
///    code. Un passage de révision est une *session*. L'action est *réviser* : ni
///    « entraînement », ni « exercice », ni « travailler ».
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
}
