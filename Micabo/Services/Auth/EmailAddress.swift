import Foundation

/**
 Ce qu'on vérifie **avant** de demander un lien par courriel.

 Le pendant iOS de `web/lib/auth/email.ts`, et la même raison d'être : un lien envoyé à une
 boîte qui n'existe pas revient, et ce rebond est compté contre l'envoyeur mutualisé que
 Micabo partage avec tous les projets Supabase. Sur un projet qui envoie dix courriels par
 semaine, deux adresses ratées font un taux à deux chiffres et une lettre d'avertissement.

 Les listes de référence sont générées depuis le site (`EmailReference`), pas retapées ici.
 C'est délibéré : la dérive entre les deux plateformes est précisément ce qui a coûté le
 premier rebond.
 */
enum EmailAddress {
    enum Verdict: Equatable {
        /// Elle peut partir.
        case ok(String)
        /// GoTrue la refuserait aussi ; autant l'annoncer sans faire l'aller-retour.
        case malformed
        /// Domaine réservé par l'IETF : pas de DNS, pas de boîte, rebond garanti.
        case undeliverable
        /// Un domaine qui existe, et qui ressemble beaucoup à un autre.
        case suspicious(address: String, suggestion: String)
    }

    /// L'adresse telle que GoTrue la rangera : il met tout en minuscules avant de l'écrire.
    static func normalize(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Le verdict, avant tout appel réseau.
    static func inspect(_ raw: String?) -> Verdict {
        let address = normalize(raw)
        guard isWellFormed(address) else { return .malformed }

        let domain = String(address[address.index(after: address.lastIndex(of: "@")!)...])

        if EmailReference.undeliverableDomains.contains(domain) { return .undeliverable }
        if let dot = domain.lastIndex(of: "."),
           EmailReference.undeliverableTLDs.contains(String(domain[domain.index(after: dot)...])) {
            return .undeliverable
        }

        if let corrected = suggestDomain(domain) {
            let local = String(address[..<address.lastIndex(of: "@")!])
            return .suspicious(address: address, suggestion: "\(local)@\(corrected)")
        }

        return .ok(address)
    }

    /// Assez bien formée pour qu'on laisse appuyer.
    ///
    /// C'est ce que le bouton regarde, et **pas** le verdict complet : une adresse douteuse
    /// doit pouvoir être soumise, sinon la question « tu voulais dire … ? » ne s'afficherait
    /// jamais et l'élève resterait devant un bouton gris sans savoir pourquoi.
    static func isPlausible(_ raw: String) -> Bool {
        isWellFormed(normalize(raw))
    }

    /// Vrai quand l'adresse part sans question.
    static func isSendable(_ raw: String?) -> Bool {
        if case .ok = inspect(raw) { return true }
        return false
    }

    // MARK: - Rouages

    // Construites une fois : `isPlausible` décide de l'état du bouton, donc elle repasse à
    // chaque frappe.
    private static let localAllowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789!#$%&'*+/=?^_`{|}~.-"
    )
    private static let domainAllowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-"
    )

    /// La forme, et rien d'autre. Plus strict que la RFC 5321, qui accepte `eleve@lycee` -
    /// une adresse légale dans la norme, et qui rebondit dans la vraie vie.
    private static func isWellFormed(_ address: String) -> Bool {
        guard !address.isEmpty, address.count <= 254 else { return false }
        guard address.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }
        guard address.filter({ $0 == "@" }).count == 1 else { return false }
        guard let at = address.firstIndex(of: "@") else { return false }

        let local = String(address[..<at])
        let domain = String(address[address.index(after: at)...])

        guard !local.isEmpty, local.count <= 64 else { return false }
        guard !local.hasPrefix("."), !local.hasSuffix("."), !local.contains("..") else {
            return false
        }
        guard local.unicodeScalars.allSatisfy({ localAllowed.contains($0) }) else { return false }

        guard !domain.isEmpty, domain.count <= 253 else { return false }
        guard domain.unicodeScalars.allSatisfy({ domainAllowed.contains($0) }) else { return false }
        guard !domain.contains("..") else { return false }

        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        for label in labels {
            guard !label.isEmpty, !label.hasPrefix("-"), !label.hasSuffix("-") else { return false }
        }

        let tld = labels[labels.count - 1]
        return tld.count >= 2 && tld.allSatisfy { $0.isLetter && $0.isASCII }
    }

    /// Le domaine qu'on aurait voulu taper, ou rien.
    ///
    /// La fin d'abord - une faute sur l'extension se corrige seule -, le domaine entier
    /// ensuite. Le seuil se resserre sur les domaines courts, où deux caractères d'écart ne
    /// sont plus une faute de frappe mais un autre nom.
    private static func suggestDomain(_ domain: String) -> String? {
        if EmailReference.knownDomainSet.contains(domain) { return nil }

        if let dot = domain.lastIndex(of: ".") {
            let tld = String(domain[domain.index(after: dot)...])
            if let fixed = EmailReference.tldTypos[tld], fixed != tld {
                let repaired = "\(domain[..<dot]).\(fixed)"
                if EmailReference.knownDomainSet.contains(repaired) { return repaired }
            }
        }

        var best: String?
        var bestDistance = Int.max

        for candidate in EmailReference.knownDomains {
            let limit = candidate.count <= 8 ? 1 : 2
            let distance = editDistance(domain, candidate, limit: limit)
            if distance <= limit, distance < bestDistance {
                best = candidate
                bestDistance = distance
            }
        }

        return best
    }

    /// Distance de Damerau-Levenshtein, version « alignement optimal ».
    ///
    /// L'inversion compte pour une opération et non deux, ce qui compte ici : `gmial` est
    /// `gmail` avec deux lettres échangées, la faute la plus courante qui soit.
    private static func editDistance(_ a: String, _ b: String, limit: Int) -> Int {
        let source = Array(a)
        let target = Array(b)
        if abs(source.count - target.count) > limit { return limit + 1 }
        if source.isEmpty { return target.count }
        if target.isEmpty { return source.count }

        var previousPrevious: [Int] = []
        var previous = Array(0...target.count)
        var current: [Int] = []

        for i in 1...source.count {
            current = Array(repeating: 0, count: target.count + 1)
            current[0] = i
            var rowBest = i

            for j in 1...target.count {
                let substitution = source[i - 1] == target[j - 1] ? 0 : 1
                var value = min(
                    current[j - 1] + 1,
                    previous[j] + 1,
                    previous[j - 1] + substitution
                )

                if i > 1, j > 1,
                   source[i - 1] == target[j - 2],
                   source[i - 2] == target[j - 1] {
                    value = min(value, previousPrevious[j - 2] + 1)
                }

                current[j] = value
                rowBest = min(rowBest, value)
            }

            if rowBest > limit { return limit + 1 }

            previousPrevious = previous
            previous = current
        }

        return previous[target.count]
    }
}
