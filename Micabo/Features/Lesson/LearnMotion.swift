import SwiftUI
import UIKit

/// **Les mouvements d'« Apprendre et réviser »** : les courbes de `MicaboMotion`, déjà
/// résolues pour « Réduire les animations ».
///
/// Les écrans d'une leçon, des flashcards, du quiz, de l'examen blanc, du tuteur et du scanner
/// animent beaucoup de petites choses — une carte qui se retourne, la question suivante, une
/// barre qui se remplit — souvent dans des sous-vues qui n'ont pas l'environnement sous la
/// main. Plutôt que de faire descendre `accessibilityReduceMotion` partout, chaque appel lit
/// le réglage du système au moment où il anime : avec « Réduire les animations », le
/// mouvement devient le fondu bref de `MicaboMotion.reduced`.
///
/// Aucune autre courbe dans ce périmètre : `LearnMotionTests` relit les sources.
enum LearnMotion {
    static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    /// Sélection, apparition, changement d'état, question suivante (0,35 s).
    static var standard: Animation { MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion) }
    /// Retour d'un appui, petit basculement (0,22 s).
    static var quick: Animation { MicaboMotion.resolved(MicaboMotion.quick, reduceMotion: reduceMotion) }
    /// Entrée d'un bloc entier, barre qui se remplit, carte qui se retourne (0,45 s).
    static var gentle: Animation { MicaboMotion.resolved(MicaboMotion.gentle, reduceMotion: reduceMotion) }
    /// Une réussite : le cercle coché, le score atteint.
    static var celebrate: Animation { MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: reduceMotion) }

    /// Une entrée décalée, pour une liste qui apparaît rangée par rangée. Sans délai quand
    /// l'élève a réduit les animations : rien ne doit attendre pour se montrer.
    static func gentle(delay: Double) -> Animation {
        reduceMotion ? MicaboMotion.reduced : MicaboMotion.gentle.delay(delay)
    }

    static func standard(delay: Double) -> Animation {
        reduceMotion ? MicaboMotion.reduced : MicaboMotion.standard.delay(delay)
    }
}
