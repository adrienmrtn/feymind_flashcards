import SwiftUI
import UIKit

/// Mini balisage utilisé dans les textes de cours produits par l'IA.
///
/// `**gras**`, `*italique*`, `==surligné==`, `` `code` ``.
enum InlineMarkup {
    struct Style: Hashable {
        var bold = false
        var italic = false
        var highlighted = false
        var code = false
    }

    struct Run: Hashable {
        var text: String
        var style: Style
    }

    // MARK: - Analyse

    static func runs(in source: String) -> [Run] {
        var runs: [Run] = []
        var style = Style()
        var buffer = ""
        let characters = Array(source)
        var index = 0

        func flush() {
            guard !buffer.isEmpty else { return }
            runs.append(Run(text: buffer, style: style))
            buffer = ""
        }

        while index < characters.count {
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil

            if character == "*" && next == "*" {
                flush()
                style.bold.toggle()
                index += 2
                continue
            }
            if character == "=" && next == "=" {
                flush()
                style.highlighted.toggle()
                index += 2
                continue
            }
            if character == "*" {
                flush()
                style.italic.toggle()
                index += 1
                continue
            }
            if character == "`" {
                flush()
                style.code.toggle()
                index += 1
                continue
            }

            buffer.append(character)
            index += 1
        }

        flush()
        return runs
    }

    /// Retire le balisage pour obtenir le texte lisible brut.
    static func plainText(_ source: String) -> String {
        runs(in: source).map(\.text).joined()
    }

    // MARK: - Rendu

    struct RenderOptions: Hashable {
        var fontSize: CGFloat = 17
        var weight: UIFont.Weight = .regular
        var textColor: UIColor = UIColor(FeyColor.ink)
        var lineSpacing: CGFloat = 6
        var alignment: NSTextAlignment = .natural
        var highlightColor: UIColor = UIColor(FeyColor.highlightYellow)

        static let courseBody = RenderOptions()
    }

    private static let cache = NSCache<NSString, NSAttributedString>()

    static func attributed(_ source: String, options: RenderOptions = .courseBody) -> NSAttributedString {
        let key = "\(options.hashValue)|\(source)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = options.lineSpacing
        paragraph.alignment = options.alignment
        paragraph.lineBreakMode = .byWordWrapping

        let metrics = UIFontMetrics(forTextStyle: .body)
        let result = NSMutableAttributedString()

        for run in runs(in: source) {
            guard !run.text.isEmpty else { continue }

            var attributes: [NSAttributedString.Key: Any] = [
                .paragraphStyle: paragraph,
                .foregroundColor: options.textColor
            ]

            let baseFont: UIFont
            if run.style.code {
                baseFont = UIFont.monospacedSystemFont(ofSize: options.fontSize - 1, weight: .medium)
                attributes[.backgroundColor] = UIColor(FeyColor.surfaceSunken)
                attributes[.foregroundColor] = UIColor(FeyColor.accentDeep)
            } else {
                var weight = options.weight
                if run.style.bold {
                    weight = options.weight == .regular ? .semibold : .heavy
                }
                var font = UIFont.systemFont(ofSize: options.fontSize, weight: weight)
                if run.style.italic, let descriptor = font.fontDescriptor.withSymbolicTraits(.traitItalic) {
                    font = UIFont(descriptor: descriptor, size: options.fontSize)
                }
                baseFont = font
            }

            attributes[.font] = metrics.scaledFont(for: baseFont)

            if run.style.highlighted {
                attributes[.backgroundColor] = options.highlightColor
                attributes[.foregroundColor] = UIColor(FeyColor.ink)
            }

            result.append(NSAttributedString(string: run.text, attributes: attributes))
        }

        cache.setObject(result, forKey: key)
        return result
    }

    /// Version SwiftUI, pour les titres et les libellés courts.
    static func swiftUIText(_ source: String, options: RenderOptions = .courseBody) -> Text {
        Text(AttributedString(attributed(source, options: options)))
    }
}
