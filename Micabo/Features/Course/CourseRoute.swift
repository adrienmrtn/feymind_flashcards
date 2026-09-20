import Foundation

/// Les cartes d'un cours, comme destination de navigation.
///
/// Un cours a maintenant deux écrans : sa **fiche**, qui est l'écran du cours, et ses
/// **cartes**, qui n'existent que si on les a demandées. `Course` seul mène donc à la
/// fiche, et ce type mène aux cartes : sans lui, la même valeur devrait pousser deux
/// destinations différentes.
struct CourseCardsRoute: Hashable {
    let course: Course
}

/// **L'épreuve d'un deck, comme destination de navigation.**
///
/// Pousser `Exam` directement marcherait — et c'est bien le problème. L'accueil déclare déjà
/// une destination pour `Exam` à la racine de sa pile, et l'écran du deck s'y empile : deux
/// destinations pour le même type dans la même pile, dont SwiftUI signale le conflit et dont
/// il ne garde que la plus profonde. Ça fonctionne aujourd'hui par accident d'ordre, et ça
/// casserait le jour où l'une des deux change.
///
/// Un type à soi supprime la question : l'accueil garde `Exam`, le deck a le sien, et les
/// deux peuvent cohabiter sur la même pile sans se marcher dessus.
struct DeckExamRoute: Hashable {
    let exam: Exam
}
