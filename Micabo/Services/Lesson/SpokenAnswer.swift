import Foundation

/// **Une réponse dite à voix haute, comparée à celle de la carte** (`docs/supports.md`).
///
/// La reconnaissance vocale n'écrit jamais exactement la réponse : « la photosynthèse » devient
/// « photo synthèse », un pluriel tombe, un accent manque. La comparaison est donc tolérante :
/// les deux textes sont ramenés à leurs mots (sans casse, accents ni ponctuation), la réponse
/// attendue à ses mots-clés (les mots vides retirés), et chaque mot-clé est cherché dans ce
/// qui a été dit, à une faute ou une terminaison près. La part des mots-clés retrouvés donne
/// le verdict ; l'élève garde le dernier mot avec « Je savais » ou « Pas encore ».
enum SpokenAnswer {
    enum Verdict: String, Equatable {
        /// L'essentiel y est.
        case right
        /// Une partie y est.
        case close
        /// Rien de la réponse.
        case missed
    }

    struct Judgement: Equatable {
        var verdict: Verdict
        /// La part des mots-clés retrouvés, de 0 à 1.
        var score: Double
        var matched: [String]
        var missing: [String]
    }

    static func judge(heard: String, expected: String) -> Judgement {
        let said = words(heard)
        let keys = keywords(expected)
        guard !keys.isEmpty else {
            return Judgement(verdict: said.isEmpty ? .missed : .close, score: 0, matched: [], missing: [])
        }
        guard !said.isEmpty else {
            return Judgement(verdict: .missed, score: 0, matched: [], missing: keys)
        }
        // Dit d'un seul tenant, collé (« photo synthèse » pour « photosynthèse ») : c'est juste.
        let joinedSaid = said.joined()
        let joinedExpected = words(expected).joined()
        if !joinedExpected.isEmpty, joinedSaid.contains(joinedExpected) {
            return Judgement(verdict: .right, score: 1, matched: keys, missing: [])
        }

        var matched: [String] = []
        var missing: [String] = []
        for key in keys {
            if said.contains(where: { close($0, key) }) || (key.count >= 6 && joinedSaid.contains(key)) {
                matched.append(key)
            } else {
                missing.append(key)
            }
        }
        let score = Double(matched.count) / Double(keys.count)
        let rightThreshold = keys.count >= 5 ? 0.6 : 0.7
        let verdict: Verdict = score >= rightThreshold ? .right : (score >= 0.34 ? .close : .missed)
        return Judgement(verdict: verdict, score: score, matched: matched, missing: missing)
    }

    // MARK: Les mots

    /// Les mots d'un texte : en minuscules, sans accents ni ponctuation, les chiffres gardés.
    static func words(_ text: String) -> [String] {
        let folded = text
            .replacingOccurrences(of: ClozeGap.marker, with: " ")
            .replacingOccurrences(of: "**", with: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
        var cleaned = ""
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                cleaned.unicodeScalars.append(scalar)
            } else {
                cleaned.append(" ")
            }
        }
        return cleaned.split(separator: " ").map(String.init)
    }

    /// Les mots qui portent le sens : sans les mots vides, et au moins trois lettres (ou un
    /// nombre). Une réponse faite seulement de petits mots les garde tous.
    static func keywords(_ text: String) -> [String] {
        let all = words(text)
        var seen: Set<String> = []
        let meaningful = all.filter { word in
            let keep = (word.count >= 3 || word.allSatisfy(\.isNumber)) && !stopWords.contains(word)
            guard keep, !seen.contains(word) else { return false }
            seen.insert(word)
            return true
        }
        if !meaningful.isEmpty { return meaningful }
        var unique: [String] = []
        for word in all where !unique.contains(word) { unique.append(word) }
        return unique
    }

    /// Deux mots qui se valent à l'oral : égaux, l'un début de l'autre (un pluriel, une
    /// terminaison), ou à une faute près (deux au-delà de huit lettres).
    static func close(_ said: String, _ key: String) -> Bool {
        if said == key { return true }
        if key.allSatisfy(\.isNumber) || said.allSatisfy(\.isNumber) { return false }
        let shorter = min(said.count, key.count)
        if shorter >= 4, said.hasPrefix(key) || key.hasPrefix(said), abs(said.count - key.count) <= 3 {
            return true
        }
        guard shorter >= 4 else { return false }
        let allowed = max(said.count, key.count) >= 8 ? 2 : 1
        return distance(said, key, limit: allowed) <= allowed
    }

    /// La distance d'édition, arrêtée dès qu'elle dépasse `limit`.
    static func distance(_ a: String, _ b: String, limit: Int) -> Int {
        let left = Array(a)
        let right = Array(b)
        if abs(left.count - right.count) > limit { return limit + 1 }
        var previous = Array(0...right.count)
        for i in 1...max(1, left.count) where !left.isEmpty {
            var current = [i] + Array(repeating: 0, count: right.count)
            var best = current[0]
            for j in 1...max(1, right.count) where !right.isEmpty {
                let cost = left[i - 1] == right[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                best = min(best, current[j])
            }
            if best > limit { return limit + 1 }
            previous = current
        }
        return previous[right.count]
    }

    /// Les mots vides des langues les plus parlées de l'app, déjà sans accents.
    static let stopWords: Set<String> = [
        // français
        "les", "des", "une", "est", "sont", "dans", "par", "pour", "avec", "sur", "que", "qui", "aux", "son", "ses", "leur", "leurs", "pas", "plus", "cette", "ces", "elle", "ils", "elles", "entre",
        // anglais
        "the", "and", "for", "are", "with", "that", "this", "from", "its", "was", "were", "which", "into", "than",
        // allemand
        "der", "die", "das", "und", "ist", "sind", "ein", "eine", "einen", "dem", "den", "mit", "von", "fur", "auf", "aus", "bei", "nicht", "sich",
        // espagnol, italien, portugais
        "los", "las", "del", "una", "uno", "con", "por", "para", "como", "gli", "della", "delle", "degli", "nel", "nella", "sono", "dos", "uma", "com", "pelo", "pela",
    ]
}
