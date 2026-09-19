import Foundation
import Observation

/// **Le tampon qui dit « la liste des cours a bougé », sans tenir la liste.**
///
/// Six écrans voulaient savoir quand un cours apparaît ou disparaît, et six écrans posaient
/// pour ça un `@Query` sur `Course` — la seule façon, avec SwiftData, d'être prévenu d'un
/// changement de table. Mais un `@Query` ne prévient pas : il **rend la table**. Et une ligne
/// `Course` porte trente kilo-octets de texte en ligne (`rawText`, `contextText`, `sheetData`),
/// que SwiftData matérialise en entier sur l'acteur principal, une fois par requête vivante,
/// à chaque écriture. Six requêtes vivantes, c'est six fois la table pour apprendre un
/// changement qui tient dans un entier.
///
/// Ce compteur est cet entier. Il monte quand un cours est créé, repris ou supprimé, et rien
/// d'autre ne le fait bouger. Les écrans le mettent dans leur clé de rechargement à la place
/// de `courses.count`, et relisent alors ce dont ils ont besoin — un compte par
/// `fetchCount`, les cours par `CourseRepository.allCourses(in:)` — au moment où ça change,
/// au lieu de le tenir en permanence.
///
/// **Ce n'est pas un cache.** Il ne connaît ni les cours ni leur nombre : il ne sait que dire
/// « ce n'est plus la même liste qu'avant ». C'est volontaire — un cache aurait deux vérités
/// à tenir d'accord, celui-ci n'en a aucune.
///
/// ## Pourquoi pas `ModelContext.didSave`
///
/// SwiftData sait signaler chaque enregistrement, et ç'aurait été plus complet : la
/// synchronisation écrit des cours sans passer par `CourseRepository`. Mais `didSave` part à
/// **chaque** écriture, carte notée comprise — donc plusieurs fois par seconde pendant une
/// session — et il aurait fallu filtrer, puis recompter, pour retomber sur ce que ce compteur
/// donne directement. La descente de synchro, elle, est déjà couverte : `CloudSync.epoch`
/// monte à chaque passe et vit déjà dans les mêmes clés de rechargement.
@Observable
final class CourseLedger {
    /// Un seul tampon pour toute l'app, comme `AppearanceStore` : deux écrans qui compteraient
    /// chacun de leur côté finiraient par ne pas être d'accord sur le même instant.
    static let shared = CourseLedger()

    /// Monte d'une unité à chaque changement de la liste. Sa valeur ne veut rien dire ; seul
    /// le fait qu'elle ait changé en veut une.
    private(set) var stamp = 0

    private init() {}

    /// À appeler **après** l'enregistrement, pas avant : un écran réveillé par un tampon qui
    /// précède le `save()` relirait l'état d'avant et n'aurait aucune raison d'y revenir.
    ///
    /// Le saut vers l'acteur principal n'est pas de la précaution : `CourseRepository` est
    /// appelé depuis des tâches d'import qui ne sont pas toutes sur le fil principal, et une
    /// mutation observée depuis un autre fil réveille SwiftUI hors de chez lui.
    static func noteChange() {
        Task { @MainActor in shared.stamp &+= 1 }
    }
}
