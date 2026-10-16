import Foundation

extension SharedI18nCatalogs {
    /// **Les cinq langues que le site parle.** La table partagée est engendrée depuis le site
    /// (`scripts/export-i18n-catalogs.ts`) et ne connaît qu'elles ; les autres langues de l'app
    /// portent leurs phrases dans `IosI18nCatalogs`, et lisent l'anglais pour le reste.
    static let sharedLocales: Set<String> = ["fr", "en", "de", "es", "tr"]
}
