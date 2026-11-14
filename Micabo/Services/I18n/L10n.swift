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
        case .nb: IosI18nCatalogs.nb
        case .he: IosI18nCatalogs.he
        case .ja: IosI18nCatalogs.ja
        case .lt: IosI18nCatalogs.lt
        case .lv: IosI18nCatalogs.lv
        case .ko: IosI18nCatalogs.ko
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
        case .nb: LessonI18nCatalogs.nb
        case .he: LessonI18nCatalogs.he
        case .ja: LessonI18nCatalogs.ja
        case .lt: LessonI18nCatalogs.lt
        case .lv: LessonI18nCatalogs.lv
        case .ko: LessonI18nCatalogs.ko
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
    /// turc au pluriel. Les pluriels des phrases passent par `pluralCategory`, qui connaît
    /// toutes les formes de chaque langue ; ceci ne sert plus qu'au test de non-régression.
    static func isSingular(_ count: Int, locale: UiLocale) -> Bool {
        locale == .fr ? (count == 0 || count == 1) : count == 1
    }

    /// **La catégorie de pluriel CLDR d'un nombre entier** (lot 13) : `zero`, `one`, `two`,
    /// `few`, `many` ou `other`, selon les règles de la langue.
    ///
    /// Le moteur ne connaissait que `one` et `other`, ce qui suffit à l'anglais mais pas aux
    /// langues à trois formes et plus : « 5 карточек » n'est pas « 2 карточки », le letton met
    /// 10 et 11 dans `zero`, le lituanien 2 à 9 dans `few`, le japonais et le coréen n'ont que
    /// `other`. Une branche absente retombe sur `other` : une phrase écrite `one`/`other` se lit
    /// toujours comme avant, et le français, l'anglais, l'allemand et l'arabe rendent exactement
    /// ce qu'ils rendaient (`PerfGuardTests`).
    static func pluralCategory(_ count: Int, locale: UiLocale) -> String {
        let n = count.magnitude
        let mod10 = n % 10
        let mod100 = n % 100
        let teen = (11...19).contains(mod100)
        let fewEnding = (2...4).contains(mod10) && !(12...14).contains(mod100)
        switch locale {
        case .ja, .ko:
            return "other"
        case .fr:
            return n <= 1 ? "one" : "other"
        case .ru:
            if mod10 == 1 && mod100 != 11 { return "one" }
            return fewEnding ? "few" : "many"
        case .hr, .sr:
            if mod10 == 1 && mod100 != 11 { return "one" }
            return fewEnding ? "few" : "other"
        case .pl:
            if n == 1 { return "one" }
            return fewEnding ? "few" : "many"
        case .cs, .sk:
            if n == 1 { return "one" }
            return (2...4).contains(n) ? "few" : "other"
        case .sl:
            switch mod100 {
            case 1: return "one"
            case 2: return "two"
            case 3, 4: return "few"
            default: return "other"
            }
        case .ro:
            if n == 1 { return "one" }
            return n == 0 || (1...19).contains(mod100) ? "few" : "other"
        case .lt:
            if teen { return "other" }
            if mod10 == 1 { return "one" }
            return mod10 >= 2 ? "few" : "other"
        case .lv:
            if mod10 == 0 || teen { return "zero" }
            return mod10 == 1 ? "one" : "other"
        case .ar:
            if n == 0 { return "zero" }
            if n == 1 { return "one" }
            if n == 2 { return "two" }
            if (3...10).contains(mod100) { return "few" }
            return (11...99).contains(mod100) ? "many" : "other"
        case .he:
            if n == 1 { return "one" }
            return n == 2 ? "two" : "other"
        default:
            return n == 1 ? "one" : "other"
        }
    }

    /// **Les pluriels d'une phrase** : `{count, plural, one {# carte} other {# cartes}}`, avec
    /// toutes les catégories CLDR (`zero`, `one`, `two`, `few`, `many`, `other`) et les valeurs
    /// exactes d'ICU (`=0 {aucune carte}`), qui passent avant la catégorie. `#` devient le
    /// nombre. Une branche peut porter une variable (`{name}`) : les accolades s'y comptent.
    /// Un pluriel mal écrit reste tel quel, comme avant.
    private static func replacePlurals(
        in template: String,
        locale: UiLocale,
        vars: [String: String]
    ) -> String {
        // Le mot est dans le motif : sans lui, rien ne peut correspondre.
        guard template.contains("plural") else { return template }
        let characters = Array(template)
        var result = ""
        var index = 0
        while index < characters.count {
            if characters[index] == "{",
               let plural = readPlural(characters, from: index) {
                let raw = vars[plural.name] ?? "0"
                let count = Int(raw) ?? 0
                let branch = plural.branches["=\(count)"]
                    ?? plural.branches[pluralCategory(count, locale: locale)]
                    ?? plural.branches["other"]
                    ?? plural.branches.values.first
                    ?? ""
                result += branch.replacingOccurrences(of: "#", with: raw)
                index = plural.end
                continue
            }
            result.append(characters[index])
            index += 1
        }
        return result
    }

    private static let pluralSelectors: Set<String> = ["zero", "one", "two", "few", "many", "other"]

    /// Lit `{name, plural, sel {…} sel {…}}` à partir de l'accolade ouvrante ; `nil` si ce n'en
    /// est pas un.
    private static func readPlural(
        _ characters: [Character],
        from start: Int
    ) -> (name: String, branches: [String: String], end: Int)? {
        var index = start + 1
        func skipSpaces() {
            while index < characters.count, characters[index].isWhitespace { index += 1 }
        }
        func word() -> String {
            var text = ""
            while index < characters.count,
                  characters[index].isLetter || characters[index].isNumber || characters[index] == "_" || characters[index] == "=" {
                text.append(characters[index])
                index += 1
            }
            return text
        }
        skipSpaces()
        let name = word()
        guard !name.isEmpty else { return nil }
        skipSpaces()
        guard index < characters.count, characters[index] == "," else { return nil }
        index += 1
        skipSpaces()
        guard word() == "plural" else { return nil }
        skipSpaces()
        guard index < characters.count, characters[index] == "," else { return nil }
        index += 1
        var branches: [String: String] = [:]
        while true {
            skipSpaces()
            guard index < characters.count else { return nil }
            if characters[index] == "}" {
                if branches.isEmpty { return nil }
                return (name: name, branches: branches, end: index + 1)
            }
            let selector = word()
            guard pluralSelectors.contains(selector) || (selector.hasPrefix("=") && Int(selector.dropFirst()) != nil) else { return nil }
            skipSpaces()
            guard index < characters.count, characters[index] == "{" else { return nil }
            index += 1
            var depth = 1
            var body = ""
            while index < characters.count {
                let character = characters[index]
                index += 1
                if character == "{" { depth += 1 }
                if character == "}" {
                    depth -= 1
                    if depth == 0 { break }
                }
                body.append(character)
            }
            guard depth == 0 else { return nil }
            branches[selector] = body
        }
    }
}
