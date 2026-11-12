import Foundation

/// ICU réduit, le même que le web : `{name}` et `{count, plural, one {} other {}}`.
///
/// **Lire une phrase ne coûte presque rien, et c'est voulu** (lot 10). Les écrans lisent leurs
/// phrases au moment de se dessiner : une page en lit cinquante à deux cents à chaque passe.
/// Jusqu'au lot 10, chaque lecture compilait une expression régulière (celle du pluriel) et la
/// faisait tourner sur la phrase, même sans accolade : trente fois le prix de la lecture
/// elle-même. Désormais une phrase sans accolade ressort telle quelle, l'expression n'est
/// compilée qu'une fois, et la table d'une langue se lit sans construire celles des vingt
/// autres (`iosTable`, `lessonTable`).
enum L10n {
    static func format(_ template: String, locale: UiLocale, vars: [String: String] = [:]) -> String {
        // Sans accolade, il n'y a ni variable ni pluriel : presque toutes les phrases sont là.
        guard template.utf8.contains(UInt8(ascii: "{")) else { return template }
        var result = replacePlurals(in: template, locale: locale, vars: vars)
        for (key, value) in vars {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }

    /// **Ce qui manque se lit en anglais**, la langue de base : une phrase oubliée dans une
    /// langue tombe sur la langue que le plus de monde lit. Le français, langue d'écriture du
    /// projet, ne reste que le dernier recours.
    static func t(_ key: String, locale: UiLocale, vars: [String: String] = [:]) -> String {
        PerfProbe.hit("l10n")
        // Les phrases de la refonte d'abord : leurs clés commencent toutes par `lesson.`.
        if key.hasPrefix("lesson.") {
            let lesson = lessonTable(locale)[key]
                ?? (locale == .fr ? nil : LessonI18nCatalogs.en[key])
                ?? LessonI18nCatalogs.fr[key] ?? key
            return format(lesson, locale: locale, vars: vars)
        }
        let template = iosTable(locale)[key] ?? table(for: locale)[key]
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

    /// **Les phrases de l'iPhone dans une langue, et dans celle-là seulement.**
    ///
    /// `IosI18nCatalogs.table(for:)` passe par `regional`, un dictionnaire des vingt et une
    /// langues régionales : y lire l'italien construisait d'abord les vingt autres tables
    /// (quarante mille phrases), au premier écran. Ici chaque langue nomme sa table, et Swift
    /// ne construit que celle qu'on lit. `I18nTests` vérifie que les deux chemins rendent la
    /// même table ; une langue ajoutée à `UiLocale` ne compile pas tant qu'elle manque ici.
    static func iosTable(_ locale: UiLocale) -> [String: String] {
        switch locale {
        case .en: IosI18nCatalogs.en
        case .fr: IosI18nCatalogs.fr
        case .de: IosI18nCatalogs.de
        case .es: IosI18nCatalogs.es
        case .tr: IosI18nCatalogs.tr
        case .es419: IosI18nCatalogs.es419
        case .it: IosI18nCatalogs.it
        case .pt: IosI18nCatalogs.pt
        case .ptBR: IosI18nCatalogs.ptBR
        case .nl: IosI18nCatalogs.nl
        case .pl: IosI18nCatalogs.pl
        case .ro: IosI18nCatalogs.ro
        case .sv: IosI18nCatalogs.sv
        case .da: IosI18nCatalogs.da
        case .fi: IosI18nCatalogs.fi
        case .et: IosI18nCatalogs.et
        case .cs: IosI18nCatalogs.cs
        case .sk: IosI18nCatalogs.sk
        case .hu: IosI18nCatalogs.hu
        case .hr: IosI18nCatalogs.hr
        case .sl: IosI18nCatalogs.sl
        case .sr: IosI18nCatalogs.sr
        case .bg: IosI18nCatalogs.bg
        case .el: IosI18nCatalogs.el
        case .ru: IosI18nCatalogs.ru
        case .ar: IosI18nCatalogs.ar
        }
    }

    /// Les phrases de la refonte (`lesson.…`) dans une langue, lues de la même façon.
    static func lessonTable(_ locale: UiLocale) -> [String: String] {
        switch locale {
        case .en: LessonI18nCatalogs.en
        case .fr: LessonI18nCatalogs.fr
        case .de: LessonI18nCatalogs.de
        case .es: LessonI18nCatalogs.es
        case .tr: LessonI18nCatalogs.tr
        case .es419: LessonI18nCatalogs.es419
        case .it: LessonI18nCatalogs.it
        case .pt: LessonI18nCatalogs.pt
        case .ptBR: LessonI18nCatalogs.ptBR
        case .nl: LessonI18nCatalogs.nl
        case .pl: LessonI18nCatalogs.pl
        case .ro: LessonI18nCatalogs.ro
        case .sv: LessonI18nCatalogs.sv
        case .da: LessonI18nCatalogs.da
        case .fi: LessonI18nCatalogs.fi
        case .et: LessonI18nCatalogs.et
        case .cs: LessonI18nCatalogs.cs
        case .sk: LessonI18nCatalogs.sk
        case .hu: LessonI18nCatalogs.hu
        case .hr: LessonI18nCatalogs.hr
        case .sl: LessonI18nCatalogs.sl
        case .sr: LessonI18nCatalogs.sr
        case .bg: LessonI18nCatalogs.bg
        case .el: LessonI18nCatalogs.el
        case .ru: LessonI18nCatalogs.ru
        case .ar: LessonI18nCatalogs.ar
        }
    }

    /// **Un pourcentage, écrit comme la langue l'écrit** : « 42 % » en français et en
    /// allemand, « 42% » en anglais, « %42 » en turc. Un `"\(n) %"` écrit à la main posait
    /// l'espace française dans toutes les langues, et le signe du mauvais côté en turc.
    static func percent(_ value: Int, locale: UiLocale) -> String {
        (Double(value) / 100).formatted(
            .percent.precision(.fractionLength(0)).locale(locale.foundation)
        )
    }

    /// Le français met zéro au singulier (« 0 vue »), l'anglais, l'allemand, l'espagnol et le
    /// turc au pluriel.
    static func isSingular(_ count: Int, locale: UiLocale) -> Bool {
        locale == .fr ? (count == 0 || count == 1) : count == 1
    }

    /// L'expression du pluriel, compilée une fois pour toute l'app. Elle se lit depuis
    /// n'importe quel fil : `NSRegularExpression` ne change plus une fois construite.
    private static let pluralRegex = try? NSRegularExpression(
        pattern: #"\{(\w+),\s*plural,\s*one\s*\{([\s\S]*?)\}\s*other\s*\{([\s\S]*?)\}\}"#
    )

    private static func replacePlurals(
        in template: String,
        locale: UiLocale,
        vars: [String: String]
    ) -> String {
        // Le mot est dans le motif : sans lui, rien ne peut correspondre.
        guard template.contains("plural"), let regex = pluralRegex else { return template }
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
