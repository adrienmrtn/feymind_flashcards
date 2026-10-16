import Foundation

/// La langue de l'interface iPhone. Pas celle des fiches (`ContentLanguage`).
///
/// UserDefaults, pas colonne : c'est le même contrat que le cookie web
/// `micabo.ui_locale`. Les deux clients ne se synchronisent pas encore.
///
/// **L'anglais vient en premier** parce que c'est la langue du plus grand nombre de
/// lecteurs, et parce que c'est déjà la langue de base du site. Viennent ensuite les langues
/// des marchés de Micabo, de l'Europe au Moyen-Orient et à l'Amérique latine. Sur l'iPhone, le repli
/// reste le français : c'est la langue de la quasi-totalité des comptes existants, et un
/// utilisateur qui n'a jamais touché au sélecteur ne doit pas voir son app changer de
/// langue du jour au lendemain.
enum UiLocale: String, CaseIterable, Identifiable, Sendable {
    case en
    case fr
    case de
    case es
    case es419 = "es-419"
    case it
    case pt = "pt-PT"
    case ptBR = "pt-BR"
    case nl
    case pl
    case ro
    case sv
    case da
    case fi
    case et
    case cs
    case sk
    case hu
    case hr
    case sl
    case sr
    case bg
    case el
    case ru
    case tr
    case ar

    var id: String { rawValue }

    static let storageKey = "micabo.ui_locale"
    static let fallback = UiLocale.fr

    var nativeName: String {
        switch self {
        case .en: "English"
        case .fr: "Français"
        case .de: "Deutsch"
        case .es: "Español (España)"
        case .es419: "Español (Latinoamérica)"
        case .it: "Italiano"
        case .pt: "Português (Portugal)"
        case .ptBR: "Português (Brasil)"
        case .nl: "Nederlands"
        case .pl: "Polski"
        case .ro: "Română"
        case .sv: "Svenska"
        case .da: "Dansk"
        case .fi: "Suomi"
        case .et: "Eesti"
        case .cs: "Čeština"
        case .sk: "Slovenčina"
        case .hu: "Magyar"
        case .hr: "Hrvatski"
        case .sl: "Slovenščina"
        case .sr: "Srpski"
        case .bg: "Български"
        case .el: "Ελληνικά"
        case .ru: "Русский"
        case .tr: "Türkçe"
        case .ar: "العربية"
        }
    }

    /// Drapeau du pays de référence de la langue. Une langue n'est pas un pays,
    /// mais des drapeaux se lisent avant des noms — surtout à l'accueil.
    var flag: String {
        switch self {
        case .en: "🇬🇧"
        case .fr: "🇫🇷"
        case .de: "🇩🇪"
        case .es: "🇪🇸"
        case .es419: "🇲🇽"
        case .it: "🇮🇹"
        case .pt: "🇵🇹"
        case .ptBR: "🇧🇷"
        case .nl: "🇳🇱"
        case .pl: "🇵🇱"
        case .ro: "🇷🇴"
        case .sv: "🇸🇪"
        case .da: "🇩🇰"
        case .fi: "🇫🇮"
        case .et: "🇪🇪"
        case .cs: "🇨🇿"
        case .sk: "🇸🇰"
        case .hu: "🇭🇺"
        case .hr: "🇭🇷"
        case .sl: "🇸🇮"
        case .sr: "🇷🇸"
        case .bg: "🇧🇬"
        case .el: "🇬🇷"
        case .ru: "🇷🇺"
        case .tr: "🇹🇷"
        case .ar: "🇦🇪"
        }
    }

    var bcp47: String {
        switch self {
        case .en: "en-US"
        case .fr: "fr-FR"
        case .de: "de-DE"
        case .es: "es-ES"
        case .es419: "es-419"
        case .it: "it-IT"
        case .pt: "pt-PT"
        case .ptBR: "pt-BR"
        case .nl: "nl-NL"
        case .pl: "pl-PL"
        case .ro: "ro-RO"
        case .sv: "sv-SE"
        case .da: "da-DK"
        case .fi: "fi-FI"
        case .et: "et-EE"
        case .cs: "cs-CZ"
        case .sk: "sk-SK"
        case .hu: "hu-HU"
        case .hr: "hr-HR"
        case .sl: "sl-SI"
        case .sr: "sr-Latn-RS"
        case .bg: "bg-BG"
        case .el: "el-GR"
        case .ru: "ru-RU"
        case .tr: "tr-TR"
        case .ar: "ar-AE"
        }
    }

    var foundation: Locale { Locale(identifier: bcp47) }

    /// **L'arabe se lit de droite à gauche** : toute l'interface se retourne avec lui.
    var isRightToLeft: Bool { self == .ar }

    /// Le pays de l'annuaire d'établissements que cette langue désigne, faute de mieux.
    ///
    /// **Une langue n'est pas un pays** : l'anglais renvoie aux États-Unis, l'espagnol
    /// d'Amérique latine au Mexique, l'arabe aux Émirats — le pays le plus probable, la
    /// question du pays de scolarisation ayant été posée juste avant.
    var institutionCountryIso: String {
        switch self {
        case .en: "US"
        case .fr: "FR"
        case .de: "DE"
        case .es: "ES"
        case .es419: "MX"
        case .it: "IT"
        case .pt: "PT"
        case .ptBR: "BR"
        case .nl: "NL"
        case .pl: "PL"
        case .ro: "RO"
        case .sv: "SE"
        case .da: "DK"
        case .fi: "FI"
        case .et: "EE"
        case .cs: "CZ"
        case .sk: "SK"
        case .hu: "HU"
        case .hr: "HR"
        case .sl: "SI"
        case .sr: "RS"
        case .bg: "BG"
        case .el: "GR"
        case .ru: "RU"
        case .tr: "TR"
        case .ar: "AE"
        }
    }

    /// La langue des fiches qui va avec cette langue d'interface.
    var contentLanguage: ContentLanguage {
        switch self {
        case .en: .en
        case .fr: .fr
        case .de: .de
        case .es: .es
        case .es419: .es419
        case .it: .it
        case .pt: .pt
        case .ptBR: .ptBR
        case .nl: .nl
        case .pl: .pl
        case .ro: .ro
        case .sv: .sv
        case .da: .da
        case .fi: .fi
        case .et: .et
        case .cs: .cs
        case .sk: .sk
        case .hu: .hu
        case .hr: .hr
        case .sl: .sl
        case .sr: .sr
        case .bg: .bg
        case .el: .el
        case .ru: .ru
        case .tr: .tr
        case .ar: .ar
        }
    }

    static func isKnown(_ value: String?) -> Bool {
        guard let value else { return false }
        return UiLocale(rawValue: value) != nil
    }

    /// **La langue du téléphone, région comprise.** Le portugais du Brésil n'est pas celui du
    /// Portugal, ni l'espagnol du Mexique celui de l'Espagne : la région décide, puis la
    /// langue seule. Une langue qu'on ne parle pas retombe sur l'anglais, lu partout ; un
    /// appareil sans préférence aucune, sur le français.
    static func fromPreferredLanguages(_ languages: [String] = Locale.preferredLanguages) -> UiLocale {
        for tag in languages {
            let parts = tag.replacingOccurrences(of: "_", with: "-").split(separator: "-").map { String($0).lowercased() }
            guard let primary = parts.first else { continue }
            let region = parts.dropFirst().first { $0.count == 2 || $0 == "419" }
            switch primary {
            case "pt": return region == "pt" || region == "ao" || region == "mz" ? .pt : .ptBR
            case "es": return region == nil || region == "es" ? .es : .es419
            case "bs", "sh", "cnr": return .hr
            default:
                if let locale = UiLocale(rawValue: primary) { return locale }
            }
        }
        return languages.isEmpty ? fallback : .en
    }

    static func resolved(defaults: UserDefaults = .standard) -> UiLocale {
        if let stored = defaults.string(forKey: storageKey), let locale = UiLocale(rawValue: stored) {
            return locale
        }
        return fromPreferredLanguages()
    }
}
