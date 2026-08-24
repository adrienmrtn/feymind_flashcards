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
