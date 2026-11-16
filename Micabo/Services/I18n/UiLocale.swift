import Foundation

/// La langue de l'interface iPhone. Pas celle des fiches (`ContentLanguage`).
///
/// UserDefaults, pas colonne : c'est le même contrat que le cookie web
/// `micabo.ui_locale`. Les deux clients ne se synchronisent pas encore.
///
/// **L'anglais vient en premier, et c'est la langue de base** : l'app s'ouvre dans la langue
/// du téléphone quand Micabo la parle, et en anglais sinon. Viennent ensuite les langues des
/// marchés de Micabo, de l'Europe au Moyen-Orient et à l'Amérique latine.
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
    case nb
    case fi
    case et
    case lv
    case lt
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
    case he
    case ja
    case ko

    var id: String { rawValue }

    static let storageKey = "micabo.ui_locale"
    /// **L'anglais, quand le téléphone ne parle aucune des langues de Micabo** : c'est la
    /// langue que le plus de monde lit.
    static let fallback = UiLocale.en

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
        case .nb: "Norsk bokmål"
        case .fi: "Suomi"
        case .et: "Eesti"
        case .lv: "Latviešu"
        case .lt: "Lietuvių"
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
        case .he: "עברית"
        case .ja: "日本語"
        case .ko: "한국어"
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
        case .nb: "🇳🇴"
        case .fi: "🇫🇮"
        case .et: "🇪🇪"
        case .lv: "🇱🇻"
        case .lt: "🇱🇹"
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
        case .he: "🇮🇱"
        case .ja: "🇯🇵"
        case .ko: "🇰🇷"
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
        case .nb: "nb-NO"
        case .fi: "fi-FI"
        case .et: "et-EE"
        case .lv: "lv-LV"
        case .lt: "lt-LT"
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
        case .he: "he-IL"
        case .ja: "ja-JP"
        case .ko: "ko-KR"
        }
    }

    var foundation: Locale { Locale(identifier: bcp47) }

    /// **Une langue dont les catalogues sont encore la copie anglaise** (lot 13).
    ///
    /// Les six langues ajoutées au lot 13 sont nées branchées, avec l'anglais pour contenu, puis
    /// traduites : chaque fichier `Locales/I18n+xx.swift` porte son drapeau, que le traducteur
    /// baisse en finissant. Tant qu'il est levé, `I18nTests.testNoLanguageIsLeftInEnglish` ne
    /// compte pas les phrases restées en anglais ; une fois baissé, il les compte.
    var catalogIsProvisional: Bool {
        switch self {
        case .nb: IosI18nCatalogs.nbIsProvisional
        case .he: IosI18nCatalogs.heIsProvisional
        case .ja: IosI18nCatalogs.jaIsProvisional
        case .lt: IosI18nCatalogs.ltIsProvisional
        case .lv: IosI18nCatalogs.lvIsProvisional
        case .ko: IosI18nCatalogs.koIsProvisional
        default: false
        }
    }

    /// **L'arabe et l'hébreu se lisent de droite à gauche** : toute l'interface se retourne avec
    /// eux. C'est la seule question qu'un écran pose sur le sens de lecture : tout ce qui a été
    /// fait pour l'arabe (tiroir, flèches, barres de progression, export) vaut pour l'hébreu.
    var isRightToLeft: Bool { self == .ar || self == .he }

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
        case .nb: "NO"
        case .fi: "FI"
        case .et: "EE"
        case .lv: "LV"
        case .lt: "LT"
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
        case .he: "IL"
        case .ja: "JP"
        case .ko: "KR"
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
        case .nb: .nb
        case .fi: .fi
        case .et: .et
        case .lv: .lv
        case .lt: .lt
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
        case .he: .he
        case .ja: .ja
        case .ko: .ko
        }
    }

    static func isKnown(_ value: String?) -> Bool {
        guard let value else { return false }
        return UiLocale(rawValue: value) != nil
    }

    /// **La langue du téléphone, région comprise.** Le portugais du Brésil n'est pas celui du
    /// Portugal, ni l'espagnol du Mexique celui de l'Espagne : la région décide, puis la
    /// langue seule. Une langue qu'on ne parle pas retombe sur l'anglais.
    static func fromPreferredLanguages(_ languages: [String] = Locale.preferredLanguages) -> UiLocale {
        for tag in languages {
            let parts = tag.replacingOccurrences(of: "_", with: "-").split(separator: "-").map { String($0).lowercased() }
            guard let primary = parts.first else { continue }
            let region = parts.dropFirst().first { $0.count == 2 || $0 == "419" }
            switch primary {
            case "pt": return region == "pt" || region == "ao" || region == "mz" ? .pt : .ptBR
            case "es": return region == nil || region == "es" ? .es : .es419
            case "bs", "sh", "cnr": return .hr
            // Le norvégien arrive en `nb`, en `no` (la macrolangue) ou en `nn` (le nynorsk, servi
            // en bokmål, la norme écrite de neuf élèves sur dix) ; l'hébreu aussi en `iw`, son
            // code d'avant 1989 que de vieux systèmes envoient encore.
            case "nb", "no", "nn": return .nb
            case "he", "iw": return .he
            default:
                if let locale = UiLocale(rawValue: primary) { return locale }
            }
        }
        return fallback
    }

    /// **La langue du téléphone, lue une fois par lancement.** `resolved()` est appelée à chaque
    /// phrase affichée (`loc`, `L10n.t(…, locale: .resolved())`) : relire et redécouper les
    /// langues préférées du système à chaque fois coûtait plus que la phrase elle-même. Elles
    /// ne changent pas pendant que l'app tourne : iOS la relance quand on change de langue,
    /// celle du téléphone comme celle de l'app dans Réglages.
    private static let system = fromPreferredLanguages()

    static func resolved(defaults: UserDefaults = .standard) -> UiLocale {
        if let stored = defaults.string(forKey: storageKey), let locale = UiLocale(rawValue: stored) {
            return locale
        }
        return system
    }
}
