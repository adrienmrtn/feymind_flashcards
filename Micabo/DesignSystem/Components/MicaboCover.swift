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
    private static let table: [(String, [String])] = [
        // Langues vivantes : un drapeau se reconnaît sans lire, et c'est justement à ça que
        // sert un emoji sur une pastille de quarante points.
        ("🇬🇧", ["anglais", "english"]),
        ("🇪🇸", ["espagnol"]),
        ("🇩🇪", ["allemand"]),
        ("🇮🇹", ["italien"]),
        ("🇵🇹", ["portugais"]),
        ("🇯🇵", ["japonais"]),
        ("🇨🇳", ["chinois", "mandarin"]),
        ("🇷🇺", ["russe"]),
        ("🇸🇦", ["arabe"]),
        // Les langues anciennes n'ont pas de drapeau : l'amphore dit l'antiquité mieux que
        // le drapeau d'un pays qui n'existait pas.
        ("🏺", ["latin", "grec"]),

        // Sciences
        ("🧪", ["chimie", "molecul", "reaction"]),
        ("🧬", ["biolog", "genet", "cellul", "svt", "adn"]),
        ("🌿", ["botan", "ecolog", "plante", "photosynth", "environnement"]),
        ("🔭", ["astronom", "astrophys", "cosmolog"]),
        ("🪨", ["geolog", "mineral", "tectoniq"]),
        ("📊", ["statistique", "probabilit", "econometr"]),
        ("📐", ["math", "geometr", "algebr", "analyse", "trigonom"]),
        ("⚛️", ["physique", "quantique", "thermodynam", "optique"]),

        // Santé
        ("🫀", ["anatomie", "physiolog", "cardio"]),
        ("💊", ["pharmac", "posolog"]),
        ("🥗", ["nutrition", "dietet"]),
        ("🦴", ["kinesi", "osteo", "orthoped", "rhumatolog"]),
        ("🏥", ["infirm", "soins", "hospital"]),
        ("🩺", ["medecine", "sante", "clinique", "semiolog"]),

        // Technique
        ("🧩", ["algorithm", "complexite", "structures de donnees"]),
        ("🌐", ["reseau", "internet", "protocole"]),
        ("🔌", ["electron", "electricite", "circuit"]),
        ("⚙️", ["mecanique", "cinematique", "statique"]),
        ("💻", ["informat", "programm", "logiciel", "donnees", "python", "java"]),
        ("🏢", ["architecture", "urbanis"]),
        ("🏗️", ["genie civil", "materiaux", "construction", "beton", "ingenier", "genie"]),

        // Sciences humaines
        ("🏛️", ["histoire", "antiquite", "revolution", "guerre", "civilisation"]),
        ("🗳️", ["sciences politiques", "science politique", "institution", "electoral"]),
        ("👥", ["sociolog", "anthropolog", "demograph"]),
        ("🤔", ["philo", "epistemolog", "metaphysiq", "ethique"]),
        ("🧠", ["psycho", "cognit", "neuro"]),
        ("🗺️", ["geograph", "territoire", "climat"]),
        ("🌍", ["geopolit", "international", "europe"]),

        // Droit et économie
        ("⚖️", ["droit", "juridique", "constitution", "penal", "civil"]),
        ("🧾", ["comptab", "bilan", "fiscal"]),
        ("📈", ["finance", "boursier", "investissement"]),
        ("📣", ["marketing", "communication", "publicite"]),
        ("🧑‍💼", ["management", "gestion", "ressources humaines", "entrepreneur"]),
        ("💰", ["economie", "monetaire", "commerce"]),

        // Et le reste
        ("🚗", ["code de la route", "permis", "conduite"]),
        ("🏃", ["sport", "staps", "athletisme", "entrainement physique"]),
        ("🎬", ["cinema", "audiovisuel", "montage"]),
        ("🎵", ["musique", "solfege", "harmonie"]),
        ("🎨", ["arts", "dessin", "design", "peinture"]),
        ("📖", ["litterature", "francais", "poesie", "roman", "theatre"]),
        ("💡", ["culture generale", "actualite"]),
        // Le filet de sécurité des langues : il attrape « LV2 », « vocabulaire », « thème
        // grammatical » — tout ce qui parle de langue sans nommer laquelle.
        //
        // Le radical est **`grammat`** et non `grammaire`, et c'est ce qui manquait : « thème
        // grammatical » ne contient pas « grammaire », donc l'exemple que ce commentaire donne
        // depuis le début retombait sur le livre générique — et le test qui le vérifie
        // (`testEachLivingLanguageCarriesItsFlag`) échouait. Un mot-clé écrit en entier ne
        // rattrape pas ses dérivés ; c'est pour ça que le reste de la table est en radicaux.
        ("🗣️", ["langue", "vocabulaire", "grammat", "conjugaison"])
    ]
}
