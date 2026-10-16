import Foundation

/// ICU réduit, le même que le web : `{name}` et `{count, plural, one {} other {}}`.
enum L10n {
    static func format(_ template: String, locale: UiLocale, vars: [String: String] = [:]) -> String {
        var result = replacePlurals(in: template, locale: locale, vars: vars)
        for (key, value) in vars {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }

    /// **Ce qui manque se lit en anglais, pas en français** : une phrase oubliée dans une langue
    /// tombe sur la langue que le plus de monde lit. Le français ne reste le repli que du
    /// français lui-même, puis le dernier recours de tous.
    static func t(_ key: String, locale: UiLocale, vars: [String: String] = [:]) -> String {
        // Les phrases de la refonte d'abord : leurs clés commencent toutes par `lesson.`.
        if key.hasPrefix("lesson.") {
            let lesson = LessonI18nCatalogs.table(for: locale.rawValue)[key]
                ?? (locale == .fr ? nil : LessonI18nCatalogs.en[key])
                ?? LessonI18nCatalogs.fr[key] ?? key
            return format(lesson, locale: locale, vars: vars)
        }
        let ios = IosI18nCatalogs.table(for: locale.rawValue)
        let shared = table(for: locale)
        let template = ios[key] ?? shared[key]
            ?? (locale == .fr ? nil : IosI18nCatalogs.en[key] ?? SharedI18nCatalogs.en[key])
            ?? IosI18nCatalogs.fr[key] ?? SharedI18nCatalogs.fr[key] ?? key
        return format(template, locale: locale, vars: vars)
    }

    /// La table partagée avec le site, qui ne parle que cinq langues : les autres lisent
    /// l'anglais, et leurs phrases propres vivent dans `IosI18nCatalogs`.
    static func table(for locale: UiLocale) -> [String: String] {
        SharedI18nCatalogs.sharedLocales.contains(locale.rawValue)
            ? SharedI18nCatalogs.table(for: locale.rawValue)
            : SharedI18nCatalogs.en
    }

    /// Le français met zéro au singulier (« 0 vue »), l'anglais, l'allemand, l'espagnol et le
    /// turc au pluriel.
    static func isSingular(_ count: Int, locale: UiLocale) -> Bool {
        locale == .fr ? (count == 0 || count == 1) : count == 1
    }

    private static func replacePlurals(
        in template: String,
        locale: UiLocale,
        vars: [String: String]
    ) -> String {
        let pattern = #"\{(\w+),\s*plural,\s*one\s*\{([\s\S]*?)\}\s*other\s*\{([\s\S]*?)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return template }
        let range = NSRange(template.startIndex..., in: template)
        var result = template
        let matches = regex.matches(in: template, range: range).reversed()
        for match in matches {
            guard match.numberOfRanges == 4,
                  let keyRange = Range(match.range(at: 1), in: template),
                  let oneRange = Range(match.range(at: 2), in: template),
                  let otherRange = Range(match.range(at: 3), in: template),
                  let allRange = Range(match.range(at: 0), in: result)
            else { continue }
            let key = String(template[keyRange])
            let raw = vars[key] ?? "0"
            let count = Int(raw) ?? 0
            let one = String(template[oneRange])
            let other = String(template[otherRange])
            let branch = isSingular(count, locale: locale) ? one : other
            let formatted = raw
            let replacement = branch.replacingOccurrences(of: "#", with: formatted)
            result.replaceSubrange(allRange, with: replacement)
        }
        return result
    }
}
