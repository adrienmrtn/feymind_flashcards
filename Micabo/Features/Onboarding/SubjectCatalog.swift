import Foundation

/// **Les matières proposées à l'inscription**, par familles.
///
/// Elles vivaient dans la vue qui les affiche. Les sortir n'est pas un rangement : c'est ce
/// qui permet de vérifier la seule règle qui compte ici, à savoir qu'**aucune matière d'une
/// même famille ne porte l'emoji d'une autre**. Sept familles de six matières côte à côte,
/// c'est trente-huit pastilles sur un écran ; deux pastilles identiques dans la même famille
/// obligent à lire les libellés un par un, et un emoji qui ne distingue plus rien ne vaut
/// pas la place qu'il prend.
///
/// L'emoji n'est pas écrit ici : il vient de `CourseEmoji`, la même table que les cours
/// importés. Une deuxième liste tenue en parallèle finirait par ne plus dire la même chose
/// que la première, et l'écran des matières donnerait à une matière un emoji que ses cours
/// n'ont pas.
enum SubjectCatalog {
    struct Family: Identifiable {
        let name: String
        let subjects: [String]

        var id: String { name }
    }

    static let families: [Family] = [
        Family(name: "Sciences", subjects: [
            "Mathématiques", "Physique", "Chimie", "SVT", "Statistiques", "Astronomie", "Géologie"
        ]),
        Family(name: "Santé", subjects: [
            "Médecine", "Pharmacie", "Soins infirmiers", "Kinésithérapie", "Anatomie", "Nutrition"
        ]),
        Family(name: "Sciences humaines", subjects: [
            "Histoire", "Géographie", "Philosophie", "Sociologie", "Psychologie", "Sciences politiques"
        ]),
        Family(name: "Langues", subjects: [
            "Anglais", "Espagnol", "Allemand", "Italien", "Portugais", "Japonais",
            "Chinois", "Arabe", "Russe", "Latin & grec", "Français"
        ]),
        Family(name: "Droit & économie", subjects: [
            "Droit", "Économie", "Comptabilité", "Finance", "Management", "Marketing"
        ]),
        Family(name: "Technique", subjects: [
            "Informatique", "Algorithmique", "Réseaux", "Électronique", "Mécanique",
            "Génie civil", "Architecture"
        ]),
        Family(name: "Et aussi", subjects: [
            "Arts", "Musique", "Cinéma", "Sport & STAPS", "Code de la route", "Culture générale"
        ])
    ]

    static var allSubjects: [String] {
        families.flatMap(\.subjects)
    }

    /// L'emoji d'une matière du catalogue, déduit comme celui d'un cours qui porterait ce
    /// nom-là.
    static func emoji(for subject: String) -> String {
        CourseEmoji.derive(subject: subject, title: subject)
    }
}
