import Foundation

enum InstitutionKind: String, Codable, Hashable {
    case university
    case grandeEcole = "grande_ecole"
    case lycee
    case other

    var label: String {
        label(locale: .resolved())
    }

    func label(locale: UiLocale) -> String {
        switch self {
        case .university: L10n.t("app.institution.university", locale: locale)
        case .grandeEcole: L10n.t("app.institution.grandeEcole", locale: locale)
        case .lycee: L10n.t("app.institution.lycee", locale: locale)
        case .other: L10n.t("app.institution.other", locale: locale)
        }
    }
}

struct Institution: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let countryCode: String
    let kind: InstitutionKind
    var aliases: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, name, aliases
        case countryCode
        case kind
        case country_code
        case score
    }

    init(id: String, name: String, countryCode: String, kind: InstitutionKind, aliases: [String] = []) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.kind = kind
        self.aliases = aliases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        countryCode = try container.decodeIfPresent(String.self, forKey: .countryCode)
            ?? container.decodeIfPresent(String.self, forKey: .country_code)
            ?? ""
        let rawKind = try container.decode(String.self, forKey: .kind)
        kind = InstitutionKind(rawValue: rawKind) ?? .other
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(countryCode, forKey: .countryCode)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encode(aliases, forKey: .aliases)
    }

    var subtitle: String {
        let country = Locale.current.localizedString(forRegionCode: countryCode) ?? countryCode
        if countryCode.isEmpty {
            return kind.label
        }
        return "\(kind.label) · \(country)"
    }
}
