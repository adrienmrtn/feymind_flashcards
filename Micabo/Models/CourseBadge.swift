import Foundation

/// **Ce qu'il faut d'un cours pour le poser dans une liste, et rien de plus.**
///
/// Quatre champs, quelques dizaines d'octets. Une ligne `Course` en porte trente mille :
/// `rawText`, `contextText` et `sheetData` sont stockés en ligne, et SwiftData les charge avec
/// elle — il n'y a pas de matérialisation partielle, un fault rend l'objet entier. Un écran qui
/// garde des `Course` dans son état garde donc tout ce texte, pour afficher un titre.
///
/// L'emoji est **résolu à la construction**, pas à l'affichage. C'est le seul point subtil :
/// `CourseEmoji.resolve(for:)` lit `emoji`, `subject` **et** `title` d'un cours, et un écran qui
/// ne garde que la projection n'a plus `subject` sous la main. Le résoudre trop tard rendrait le
/// livre par défaut là où l'ancien code trouvait une fiole ou une carte.
///
/// Ce n'est pas un cache et ça ne se met pas à jour : c'est une copie, prise à un instant. Un
/// écran qui affiche des projections doit donc les relire quand ce qu'elles montrent a pu
/// changer — exactement comme il relisait sa table avant.
///
/// **Quand, précisément.** Deux choses seulement peuvent périmer un badge, et les deux ont
/// déjà leur signal. La liste des cours change : `CourseLedger.shared.stamp`. Le titre,
/// l'emoji ou la teinte d'un cours changent : `CloudSync.epoch` — parce que la
/// synchronisation est le **seul** endroit du dépôt qui les réécrive (`CloudSync.swift:725`,
/// `:728`, `:729`). Il n'existe pas de renommage de cours dans l'app ; le seul que
/// l'interface propose porte sur les dossiers. Une clé de rechargement qui porte ces deux
/// valeurs est donc complète, et cesse de l'être le jour où l'app apprend à renommer un cours.
struct CourseBadge: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    /// Déjà résolu : voir plus haut.
    let emoji: String
    let accentHex: String

    init(_ course: Course) {
        id = course.id
        title = course.title
        emoji = CourseEmoji.resolve(for: course)
        accentHex = course.accentHex
    }
}
