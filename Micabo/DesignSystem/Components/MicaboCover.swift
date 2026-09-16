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
    ///
    /// **Une matière, un emoji.** La table en servait un pour six matières voisines : quatre
    /// matières de santé partageaient le stéthoscope, quatre matières d'économie le billet,
    /// et les dix langues vivantes se partageaient une bouche qui parle. Sur l'écran des
    /// matières, où trente-huit pastilles s'enroulent en sept familles, un emoji répété
    /// n'accroche plus rien : il fait relire les libellés un par un, ce qui est exactement
    /// le travail qu'il devait éviter. Chaque langue porte donc son drapeau, et chaque
    /// matière ce qu'elle a en propre — la fiole pour la chimie, l'os pour la kiné, l'urne
    /// pour les sciences politiques.
    ///
    /// **Une entrée large ne doit jamais passer avant une entrée précise**, et c'est tout
    /// l'intérêt de l'ordre : « code de la route » contenait « code », donc il sortait un
    /// ordinateur portable. Les mots les plus généraux — « langue », « genie », « arts » —
    /// ferment donc la liste, derrière les matières qu'ils englobent.
    ///
    /// **Chaque entrée porte aussi son radical anglais.** Les titres de cours sont écrits
    /// dans la langue de l'étudiant, et une table qui ne connaissait que le français rendait
    /// le livre générique à tout un catalogue anglophone : « Chemistry », « Nursing » et
    /// « Driving theory » n'ont pas une lettre commune avec « chimie », « soins » et « code
    /// de la route ». Les radicaux ajoutés ne changent aucune sortie française — c'est ce
    /// que vérifient les tests d'ordre juste à côté.
    private static let table: [(String, [String])] = [
        // Langues vivantes : un drapeau se reconnaît sans lire, et c'est justement à ça que
        // sert un emoji sur une pastille de quarante points.
        ("🇬🇧", ["anglais", "english"]),
        ("🇪🇸", ["espagnol", "spanish"]),
        ("🇩🇪", ["allemand", "german"]),
        ("🇮🇹", ["italien", "italian"]),
        ("🇵🇹", ["portugais", "portuguese"]),
        ("🇯🇵", ["japonais", "japanese"]),
        ("🇨🇳", ["chinois", "chinese", "mandarin"]),
        ("🇷🇺", ["russe", "russian"]),
        ("🇸🇦", ["arabe", "arabic"]),
        // Les langues anciennes n'ont pas de drapeau : l'amphore dit l'antiquité mieux que
        // le drapeau d'un pays qui n'existait pas.
        ("🏺", ["latin", "grec", "greek"]),

        // Sciences
        ("🧪", ["chimie", "chemistr", "molecul", "reaction"]),
        ("🧬", ["biolog", "genet", "cellul", "svt", "adn", "dna"]),
        ("🌿", ["botan", "ecolog", "plante", "photosynth", "environnement", "environment"]),
        ("🔭", ["astronom", "astrophys", "cosmolog"]),
        ("🪨", ["geolog", "mineral", "tectoniq", "tectonic"]),
        ("📊", ["statistique", "statistic", "probabilit", "econometr"]),
        ("📐", ["math", "geometr", "algebr", "analyse", "calculus", "trigonom"]),
        ("⚛️", ["physique", "physics", "quantique", "quantum", "thermodynam", "optique", "optics"]),

        // Santé
        ("🫀", ["anatomie", "anatomy", "physiolog", "cardio"]),
        ("💊", ["pharmac", "posolog", "dosage"]),
        ("🥗", ["nutrition", "dietet", "dietar"]),
        ("🦴", ["kinesi", "osteo", "orthoped", "physiother", "rhumatolog", "rheumatolog"]),
        ("🏥", ["infirm", "soins", "hospital", "nursing"]),
        ("🩺", ["medecine", "medicine", "sante", "clinique", "clinical", "semiolog"]),

        // Technique
        ("🧩", ["algorithm", "complexite", "complexity", "structures de donnees", "data structures"]),
        ("🌐", ["reseau", "network", "internet", "protocole", "protocol"]),
        ("🔌", ["electron", "electricite", "electricity", "circuit"]),
        ("⚙️", ["mecanique", "mechanic", "cinematique", "kinematic", "statique"]),
        ("💻", ["informat", "comput", "programm", "logiciel", "software", "donnees", "python", "java"]),
        ("🏢", ["architecture", "urbanis", "urban plan"]),
        ("🏗️", ["genie civil", "civil engineering", "materiaux", "construction", "beton", "concrete", "ingenier", "engineering", "genie"]),

        // Sciences humaines
        ("🏛️", ["histoire", "history", "antiquite", "antiquity", "revolution", "guerre", "civilisation", "civilization"]),
        ("🗳️", ["sciences politiques", "science politique", "political science", "politics", "institution", "electoral"]),
        ("👥", ["sociolog", "anthropolog", "demograph"]),
        ("🤔", ["philo", "epistemolog", "metaphysi", "ethique", "ethics"]),
        ("🧠", ["psycho", "cognit", "neuro"]),
        ("🗺️", ["geograph", "territoire", "territor", "climat"]),
        ("🌍", ["geopolit", "international", "europe"]),

        // Droit et économie
        ("⚖️", ["droit", "juridique", "legal", "law", "constitution", "penal", "criminal", "civil"]),
        ("🧾", ["comptab", "accounting", "bilan", "fiscal"]),
        ("📈", ["finance", "boursier", "investissement", "investment"]),
        ("📣", ["marketing", "communication", "publicite", "advertis"]),
        ("🧑‍💼", ["management", "gestion", "ressources humaines", "human resources", "entrepreneur"]),
        ("💰", ["economie", "economic", "monetaire", "monetar", "commerce"]),

        // Et le reste
        ("🚗", ["code de la route", "driving theory", "highway code", "permis", "conduite"]),
        ("🏃", ["sport", "staps", "athletisme", "athletic", "entrainement physique"]),
        ("🎬", ["cinema", "film", "audiovisuel", "montage"]),
        ("🎵", ["musique", "music", "solfege", "harmonie", "harmony"]),
        ("🎭", ["theatre", "theater", "drama"]),
        ("💃", ["danse", "dance"]),
        ("📷", ["photographie", "photo"]),
        ("📰", ["journalisme", "journalism"]),
        ("🎒", ["pedagogie", "pedagog", "education", "teaching"]),
        ("🌾", ["agronomie", "agronom", "agriculture"]),
        ("✈️", ["aeronautique", "aeronautic", "aviation"]),
        ("🎨", ["arts", "dessin", "drawing", "design", "peinture", "painting"]),
        ("📖", ["litterature", "literature", "francais", "french", "poesie", "poetry", "roman"]),
        ("💡", ["culture generale", "general knowledge", "actualite", "current affairs"]),
        // Le filet de sécurité des langues : il attrape « LV2 », « vocabulaire », « thème
        // grammatical » — tout ce qui parle de langue sans nommer laquelle.
        //
        // Le radical est **`grammat`** et non `grammaire`, et c'est ce qui manquait : « thème
        // grammatical » ne contient pas « grammaire », donc l'exemple que ce commentaire donne
        // depuis le début retombait sur le livre générique — et le test qui le vérifie
        // (`testEachLivingLanguageCarriesItsFlag`) échouait. Un mot-clé écrit en entier ne
        // rattrape pas ses dérivés ; c'est pour ça que le reste de la table est en radicaux.
        ("🗣️", ["langue", "language", "vocabulaire", "vocabular", "grammat", "conjugaison", "conjugation"])
    ]
}
