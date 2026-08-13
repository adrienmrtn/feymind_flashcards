import Foundation
import SwiftUI

/// Couverture d'un cours : un emoji posé sur un aplat pastel dérivé de la teinte du cours.
/// La première page du document n'est jamais reprise : illisible en petit, et deux PDF
/// se ressemblent toujours.
struct CourseCover: View {
    let course: Course
    var emojiSize: CGFloat = 34

    private var tint: Color { Color(hexString: course.accentHex) }

    var body: some View {
        ZStack {
            tint.lightened(by: 0.82)
            Text(CourseEmoji.resolve(for: course))
                .font(.system(size: emojiSize))
        }
        .clipped()
    }
}

/// Voile sombre appliqué au bas d'une couverture pour garder le texte lisible.
struct MicaboCoverScrim: View {
    var strength: Double = 0.6

    var body: some View {
        LinearGradient(
            colors: [Color.clear, Color.black.opacity(strength * 0.5), Color.black.opacity(strength)],
            startPoint: .center,
            endPoint: .bottom
        )
    }
}

/// Choix de l'emoji d'un cours. L'analyse en propose un ; quand il manque ou qu'il
/// reste le générique, on le déduit de la matière puis du titre.
enum CourseEmoji {
    static let fallback = "📘"

    static func resolve(for course: Course) -> String {
        resolve(proposed: course.emoji, subject: course.subject, title: course.title)
    }

    static func resolve(proposed: String?, subject: String?, title: String) -> String {
        if let proposed = proposed?.nilIfBlank, proposed != fallback, proposed != "📝" {
            return proposed
        }
        return derive(subject: subject, title: title)
    }

    static func derive(subject: String?, title: String) -> String {
        let haystack = [subject ?? "", title]
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        for (emoji, keywords) in table {
            if keywords.contains(where: { haystack.contains($0) }) {
                return emoji
            }
        }
        return fallback
    }

    /// Ordonné : la première correspondance gagne, du plus spécifique au plus large.
    private static let table: [(String, [String])] = [
        ("🧪", ["chimie", "molecul", "reaction"]),
        ("🧬", ["biolog", "genet", "cellul", "svt", "adn"]),
        ("🌿", ["botan", "ecolog", "plante", "photosynth", "environnement"]),
        ("⚛️", ["physique", "mecanique", "quantique", "electricite", "optique"]),
        ("📐", ["math", "geometr", "algebr", "analyse", "statistique", "probabilit"]),
        ("💻", ["informat", "programm", "algorithm", "code", "reseau", "donnees"]),
        ("🏛️", ["histoire", "antiquite", "revolution", "guerre", "civilisation"]),
        ("🗺️", ["geograph", "territoire", "climat", "urbanis"]),
        ("⚖️", ["droit", "juridique", "constitution", "penal", "civil"]),
        ("💰", ["economie", "gestion", "comptab", "finance", "marketing", "commerce"]),
        ("🧠", ["psycho", "philo", "cognit", "neuro", "sociolog"]),
        ("🩺", ["medecine", "anatomie", "physiolog", "pharmac", "sante", "infirm"]),
        ("🗣️", ["anglais", "espagnol", "allemand", "italien", "langue", "vocabulaire", "grammaire"]),
        ("📖", ["litterature", "francais", "poesie", "roman", "theatre"]),
        ("🎨", ["arts", "dessin", "design", "architecture", "peinture"]),
        ("🎵", ["musique", "solfege", "harmonie"]),
        ("🏗️", ["ingenier", "genie", "materiaux", "construction"]),
        ("🌍", ["geopolit", "international", "europe"])
    ]
}
