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

    /// Surlignage utilisateur, exprimé en coordonnées de texte brut.
    struct OverlayHighlight: Hashable {
        var start: Int
        var length: Int
        var color: HighlightColor
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

    static func attributed(
        _ source: String,
        options: RenderOptions = .courseBody,
        overlays: [OverlayHighlight] = []
    ) -> NSAttributedString {
        let overlayKey = overlays
            .map { "\($0.start):\($0.length):\($0.color.rawValue)" }
            .joined(separator: "|")
        let key = "\(options.hashValue)|\(overlayKey)|\(source)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = options.lineSpacing
        paragraph.alignment = options.alignment
        paragraph.lineBreakMode = .byWordWrapping

        let metrics = UIFontMetrics(forTextStyle: .body)
        let result = NSMutableAttributedString()
        // Les surlignages utilisateur sont stockés en offsets UTF-16, comme UITextView.
        var plainOffset = 0

        for run in runs(in: source) {
            guard !run.text.isEmpty else { continue }
            let utf16Length = (run.text as NSString).length

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
                // Marqueur fluo : bande opaque un peu chaude, comme un surligneur.
                attributes[.backgroundColor] = options.highlightColor.withAlphaComponent(0.92)
                attributes[.foregroundColor] = UIColor(FeyColor.ink)
            }

            let start = result.length
            result.append(NSAttributedString(string: run.text, attributes: attributes))
            let runRange = NSRange(location: start, length: utf16Length)

            applyOverlays(
                overlays,
                plainStart: plainOffset,
                plainLength: utf16Length,
                into: result,
                utf16Range: runRange
            )

            plainOffset += utf16Length
        }

        cache.setObject(result, forKey: key)
        return result
    }

    /// Applique les surlignages utilisateur qui chevauchent le run courant.
    private static func applyOverlays(
        _ overlays: [OverlayHighlight],
        plainStart: Int,
        plainLength: Int,
        into result: NSMutableAttributedString,
        utf16Range: NSRange
    ) {
        guard plainLength > 0 else { return }
        let plainEnd = plainStart + plainLength

        for overlay in overlays {
            let overlayEnd = overlay.start + overlay.length
            let start = max(plainStart, overlay.start)
            let end = min(plainEnd, overlayEnd)
            guard end > start else { continue }

            let relativeStart = start - plainStart
            let relativeLength = end - start
            let target = NSRange(
                location: utf16Range.location + relativeStart,
                length: relativeLength
            )
            guard NSMaxRange(target) <= result.length else { continue }

            result.addAttribute(
                .backgroundColor,
                value: overlay.color.uiColor.withAlphaComponent(0.88),
                range: target
            )
        }
    }

    /// Version SwiftUI, pour les titres et les libellés courts.
    static func swiftUIText(_ source: String, options: RenderOptions = .courseBody) -> Text {
        Text(AttributedString(attributed(source, options: options)))
    }
}
