import Foundation

enum TextSanitizer {
    /// Micabo bannit les tirets cadratins : le modèle en produit parfois malgré la consigne.
    static func removeEmDashes(_ text: String) -> String {
        var result = text
        let separators: [(String, String)] = [
            (" — ", ", "),
            (" – ", ", "),
            (" ― ", ", "),
            ("— ", ""),
            ("– ", ""),
            (" —", ""),
            (" –", "")
        ]
        for (pattern, replacement) in separators {
            result = result.replacingOccurrences(of: pattern, with: replacement)
        }
        result = result.replacingOccurrences(of: "—", with: "-")
        result = result.replacingOccurrences(of: "–", with: "-")
        result = result.replacingOccurrences(of: "―", with: "-")
        return result
    }

    /// Retire le balisage court que le modèle ajoute parfois : plus rien ne le rend à l'écran.
    static func removeInlineMarkup(_ text: String) -> String {
        var result = text
        for marker in ["**", "==", "`", "*", "_"] {
            result = result.replacingOccurrences(of: marker, with: "")
        }
        return result
    }

    static func clean(_ text: String) -> String {
        removeInlineMarkup(removeEmDashes(text)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// La matière d'un cours, nettoyée **et décapitalisée si elle crie**.
    ///
    /// Le modèle rend parfois « HISTOIRE », « PHYSIQUE-CHIMIE », « DROIT » — la casse du
    /// titre qu'il a lu dans le document. Sur une pastille de filtre ou sous le titre d'un
    /// cours, une matière en capitales hurle au milieu d'un écran qui ne crie jamais, et deux
    /// cours de la même matière écrits différemment font deux matières dans les filtres.
    static func subject(_ text: String) -> String {
        deScreamed(clean(text))
    }

    /// Rend sa casse à un texte écrit **entièrement** en capitales, en laissant les
    /// acronymes tranquilles.
    ///
    /// Un texte qui contient déjà une minuscule n'est pas touché : « Histoire des arts » est
    /// écrit comme quelqu'un l'écrirait, et on n'a rien à y redire.
    ///
    /// La règle, pour les autres, se joue **mot par mot** : un mot de quatre lettres ou plus
    /// qui contient au moins deux voyelles est un mot, et il reprend sa casse ; tout le reste
    /// est probablement un sigle et reste en capitales. C'est ce qui distingue « DROIT »
    /// (deux voyelles, donc « Droit ») de « STAPS », « PASS », « SVT » ou « HGGSP », qui sont
    /// les noms réels de filières et de matières françaises. Baisser la casse d'un sigle est
    /// une faute qu'on lit tout de suite — « Svt » —, tandis que laisser « ARTS » en
    /// capitales n'est qu'un cas non corrigé : entre les deux, on choisit de ne pas se
    /// tromper.
    ///
    /// **Chaque mot reprend sa majuscule**, et non le seul premier. Le français voudrait
    /// « Droit constitutionnel » ; mais la même règle écrirait « Histoire de france », et une
    /// majuscule manquante à un nom propre se lit comme une faute, là où « Droit
    /// Constitutionnel » se lit comme un intitulé. Sur une pastille de matière, c'est le bon
    /// compromis.
    static func deScreamed(_ text: String) -> String {
        guard !text.isEmpty, text.rangeOfCharacter(from: .lowercaseLetters) == nil else {
            return text
        }

        var result = ""
        var word = ""

        func flushWord() {
            guard !word.isEmpty else { return }
            result += deScreamedWord(word)
            word = ""
        }

        for character in text {
            if character.isLetter {
                word.append(character)
            } else {
                flushWord()
                result.append(character)
            }
        }
        flushWord()

        return result
    }

    private static let vowels = Set("AEIOUYÀÂÄÉÈÊËÎÏÔÖÙÛÜ")

    private static func deScreamedWord(_ word: String) -> String {
        let vowelCount = word.filter { vowels.contains($0) }.count
        guard word.count >= 4, vowelCount >= 2 else { return word }
        return word.prefix(1) + word.dropFirst().lowercased()
    }

    /// Compacte les espaces et sauts de ligne d'un texte extrait d'un PDF.
    static func normalizeExtractedText(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\u{00AD}", with: "")
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension GeneratedCourse {
    /// Nettoie tous les textes produits par le modèle avant enregistrement.
    ///
    /// Le titre, la matière, le résumé et le contexte sont ramenés au texte nu : personne
    /// ne les met en forme. La **fiche**, elle, garde son balisage en ligne, qui est
    /// justement ce qui la met en page : elle passe donc par `CourseSheet.sanitized()`,
    /// qui retire les tirets cadratins et les puces sans toucher au gras ni au surlignage.
    func sanitized() -> GeneratedCourse {
        let cleanSheet = sheet?.sanitized()

        return GeneratedCourse(
            title: TextSanitizer.clean(title),
            subject: subject.map(TextSanitizer.subject),
            emoji: emoji,
            summary: TextSanitizer.clean(summary),
            sheet: (cleanSheet?.isEmpty == false) ? cleanSheet : nil,
            contextText: TextSanitizer.clean(contextText)
        )
    }
}
