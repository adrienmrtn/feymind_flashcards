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

    static func t(_ key: String, locale: UiLocale, vars: [String: String] = [:]) -> String {
        let table = table(for: locale)
        let fallback = SharedI18nCatalogs.fr
        let ios = IosI18nCatalogs.table(for: locale.rawValue)
        let iosFallback = IosI18nCatalogs.fr
        let template = ios[key] ?? table[key] ?? iosFallback[key] ?? fallback[key] ?? key
        return format(template, locale: locale, vars: vars)
    }

    static func table(for locale: UiLocale) -> [String: String] {
        SharedI18nCatalogs.table(for: locale.rawValue)
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
            let branch = count == 1 ? one : other
            let formatted = raw
            let replacement = branch.replacingOccurrences(of: "#", with: formatted)
            result.replaceSubrange(allRange, with: replacement)
        }
        return result
    }
}
