import SwiftUI

/// Les mouvements de Micabo : une seule famille de courbes pour toute l'app,
/// pour que chaque ouverture, sélection et apparition ait le même caractère.
///
/// - `standard` : sélection, apparition d'un élément, changement d'état (0,35 s).
/// - `quick` : retour d'un appui, petit basculement (0,22 s).
/// - `gentle` : entrée d'un écran ou d'un bloc entier (0,45 s).
/// - `celebrate` : seule courbe avec rebond, réservée aux réussites.
///
/// Avec « Réduire les animations », passe par `MicaboMotion.resolved(_:reduceMotion:)` :
/// le mouvement devient un fondu bref.
enum MicaboMotion {
    static let standard: Animation = .spring(duration: 0.35, bounce: 0.0)
    static let quick: Animation = .spring(duration: 0.22, bounce: 0.0)
    static let gentle: Animation = .spring(duration: 0.45, bounce: 0.0)
    static let celebrate: Animation = .spring(duration: 0.5, bounce: 0.3)

    /// Fondu bref qui remplace tout mouvement quand l'élève a réduit les animations.
    static let reduced: Animation = .easeOut(duration: 0.15)

    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }
}
