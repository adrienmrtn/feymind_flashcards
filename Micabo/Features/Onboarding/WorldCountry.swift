import Foundation

/// **Un pays du monde, pour ceux que la liste courte ne couvre pas.**
///
/// La liste de pastilles de l'écran d'accueil ne peut pas tenir deux cents pays, et elle ne
/// doit pas essayer : elle porte les systèmes scolaires que Micabo connaît réellement. Ce
/// catalogue-ci sert la sortie de secours — on tape son pays, on le choisit, et il est
/// conservé tel quel.
///
/// Il n'est **pas écrit à la main** : il est construit depuis les régions ISO du système, et
/// les noms sont ceux de la langue du téléphone. Une liste de deux cents pays recopiée dans
/// un fichier Swift serait fausse dans l'année et intraduisible.
struct WorldCountry: Identifiable, Hashable {
    /// Code ISO 3166-1 alpha-2, en majuscules.
    let code: String
    let name: String

    var id: String { code }

    /// Le drapeau, déduit du code : deux lettres devenues indicateurs régionaux. Les émojis
    /// de drapeaux n'ont pas de nom propre en Unicode, c'est la seule façon de les obtenir
    /// sans écrire deux cents caractères à la main.
    var flag: String {
        let base: UInt32 = 0x1F1E6
        let scalars = code.uppercased().unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
            guard scalar.value >= 65, scalar.value <= 90 else { return nil }
            return Unicode.Scalar(base + scalar.value - 65)
        }
        guard scalars.count == 2 else { return "🌍" }
        return String(String.UnicodeScalarView(scalars))
    }
}

enum WorldCountries {
    /// Tous les pays, triés par nom dans la langue de l'appareil.
    ///
    /// Calculé une fois : la construction fait deux cents recherches de nom localisé, et la
    /// refaire à chaque frappe dans le champ de recherche se sentirait.
    static let all: [WorldCountry] = {
        let locale = Locale.current
        return Locale.Region.isoRegions
            .filter { $0.subRegions.isEmpty && $0.identifier.count == 2 }
            .compactMap { region -> WorldCountry? in
                guard let name = locale.localizedString(forRegionCode: region.identifier)?.nilIfBlank else {
                    return nil
                }
                return WorldCountry(code: region.identifier.uppercased(), name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    /// Les pays qui correspondent à ce qu'on a tapé, les plus proches d'abord.
    ///
    /// Un pays dont le nom **commence** par la recherche passe devant un pays qui la contient
    /// au milieu : « Mali » doit arriver avant « Somalie » quand on tape « mal ». Les accents
    /// et la casse sont ignorés — personne ne tape « Émirats » avec son accent.
    static func matches(_ query: String, limit: Int = 6) -> [WorldCountry] {
        let needle = query.folded
        guard !needle.isEmpty else { return [] }

        let scored = all.compactMap { country -> (country: WorldCountry, rank: Int)? in
            let name = country.name.folded
            if name.hasPrefix(needle) { return (country, 0) }
            if name.contains(needle) { return (country, 1) }
            if country.code.lowercased() == needle { return (country, 2) }
            return nil
        }

        return scored
            .sorted { left, right in
                left.rank == right.rank
                    ? left.country.name.localizedCaseInsensitiveCompare(right.country.name) == .orderedAscending
                    : left.rank < right.rank
            }
            .prefix(limit)
            .map(\.country)
    }

    static func country(code: String?) -> WorldCountry? {
        guard let code = code?.nilIfBlank?.uppercased() else { return nil }
        return all.first { $0.code == code }
    }
}

private extension String {
    /// Le texte réduit à ce qui compte pour une comparaison : sans accent, sans casse.
    var folded: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
