import Foundation

/// La langue de l'interface iPhone. Pas celle des fiches (`ContentLanguage`).
///
/// UserDefaults, pas colonne : c'est le même contrat que le cookie web
/// `micabo.ui_locale`. Les deux clients ne se synchronisent pas encore.
enum UiLocale: String, CaseIterable, Identifiable, Sendable {
    case fr
    case de
    case es
    case tr

    var id: String { rawValue }

    static let storageKey = "micabo.ui_locale"
    static let fallback = UiLocale.fr

    var nativeName: String {
        switch self {
        case .fr: "Français"
        case .de: "Deutsch"
        case .es: "Español"
        case .tr: "Türkçe"
        }
    }

    var bcp47: String {
        switch self {
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
