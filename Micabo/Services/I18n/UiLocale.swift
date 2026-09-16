import Foundation

/// La langue de l'interface iPhone. Pas celle des fiches (`ContentLanguage`).
///
/// UserDefaults, pas colonne : c'est le même contrat que le cookie web
/// `micabo.ui_locale`. Les deux clients ne se synchronisent pas encore.
///
/// **L'anglais vient en premier** parce que c'est la langue du plus grand nombre de
/// lecteurs, et parce que c'est déjà la langue de base du site. Sur l'iPhone, le repli
/// reste le français : c'est la langue de la quasi-totalité des comptes existants, et un
/// utilisateur qui n'a jamais touché au sélecteur ne doit pas voir son app changer de
/// langue du jour au lendemain.
enum UiLocale: String, CaseIterable, Identifiable, Sendable {
    case en
    case fr
    case de
    case es
    case tr

    var id: String { rawValue }

    static let storageKey = "micabo.ui_locale"
    static let fallback = UiLocale.fr

    var nativeName: String {
        switch self {
        case .en: "English"
        case .fr: "Français"
        case .de: "Deutsch"
        case .es: "Español"
        case .tr: "Türkçe"
        }
    }

    /// Drapeau du pays de référence de la langue. Une langue n'est pas un pays,
    /// mais cinq drapeaux se lisent avant cinq noms — surtout à l'accueil.
    var flag: String {
        switch self {
        case .en: "🇬🇧"
        case .fr: "🇫🇷"
        case .de: "🇩🇪"
        case .es: "🇪🇸"
        case .tr: "🇹🇷"
        }
    }

    var bcp47: String {
        switch self {
        case .en: "en-US"
        case .fr: "fr-FR"
        case .de: "de-DE"
        case .es: "es-ES"
        case .tr: "tr-TR"
        }
    }

    var foundation: Locale { Locale(identifier: bcp47) }

    static func isKnown(_ value: String?) -> Bool {
        guard let value else { return false }
        return UiLocale(rawValue: value) != nil
    }

    /// Préférences système, sinon le français.
    static func fromPreferredLanguages(_ languages: [String] = Locale.preferredLanguages) -> UiLocale {
        for tag in languages {
            let primary = tag.split(separator: "-").first.map(String.init)?.lowercased()
            if let primary, let locale = UiLocale(rawValue: primary) { return locale }
        }
        return fallback
    }

    static func resolved(defaults: UserDefaults = .standard) -> UiLocale {
        if let stored = defaults.string(forKey: storageKey), let locale = UiLocale(rawValue: stored) {
            return locale
        }
        return fromPreferredLanguages()
    }
}
