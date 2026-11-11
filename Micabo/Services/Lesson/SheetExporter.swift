import SwiftUI
import UIKit

/// **La fiche d'une leçon, en PDF à partager** (`docs/supports.md`).
///
/// Tout se fait sur l'appareil : les notes de chaque thème (ou ses cartes, pour un paquet)
/// sont mises en page en A4, avec la police de l'app, le titre de la leçon en tête et un pied
/// de page numéroté. Le texte suit la langue de la leçon : de droite à gauche en arabe.
enum SheetExporter {
    /// A4, en points.
    static let pageSize = CGSize(width: 595.2, height: 841.8)
    static let margins = UIEdgeInsets(top: 56, left: 52, bottom: 64, right: 52)

    /// Écrit le PDF dans le dossier temporaire et rend son adresse.
    @MainActor
    static func export(_ digest: LessonDigest, locale: UiLocale = .resolved()) throws -> URL {
        let data = render(digest, locale: locale)
        let name = fileName(for: digest.title)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("micabo-sheets", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name).appendingPathExtension("pdf")
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url)
        return url
    }

    /// Un nom de fichier lisible, sans les caractères que Fichiers refuse.
    static func fileName(for title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title.components(separatedBy: forbidden).joined(separator: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let short = String(cleaned.prefix(80))
        return short.isEmpty ? "Micabo" : short
    }

    /// Les octets du PDF.
    @MainActor
    static func render(_ digest: LessonDigest, locale: UiLocale = .resolved()) -> Data {
        let text = attributedSheet(digest, locale: locale)
        let page = CGRect(origin: .zero, size: pageSize)
        let printable = page.inset(by: margins)

        let formatter = UISimpleTextPrintFormatter(attributedText: text)
        let renderer = FooterRenderer(footer: L10n.t("ios.sup.export.footer", locale: locale), rightToLeft: locale.isRightToLeft)
        renderer.footerHeight = 28
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: page), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, page, [kCGPDFContextTitle as String: digest.title, kCGPDFContextCreator as String: "Micabo"])
        let pages = max(1, renderer.numberOfPages)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: pages))
        for index in 0..<pages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: index, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }

    // MARK: La mise en page

    @MainActor
    static func attributedSheet(_ digest: LessonDigest, locale: UiLocale) -> NSAttributedString {
        let rtl = locale.isRightToLeft
        let output = NSMutableAttributedString()
        let ink = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        let soft = UIColor(red: 0.30, green: 0.31, blue: 0.36, alpha: 1)
        let accent = UIColor(red: 0.22, green: 0.44, blue: 0.996, alpha: 1)

        func paragraph(spacingBefore: CGFloat = 0, after: CGFloat = 6, indent: CGFloat = 0) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.alignment = .natural
            style.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
            style.paragraphSpacingBefore = spacingBefore
            style.paragraphSpacing = after
            style.lineHeightMultiple = 1.15
            style.firstLineHeadIndent = indent
            style.headIndent = indent == 0 ? 0 : indent + 12
            return style
        }
        func add(_ text: String, size: CGFloat, weight: Font.Weight = .regular, color: UIColor? = nil, style: NSParagraphStyle) {
            let clean = LessonDigest.plain(text)
            guard !clean.isEmpty else { return }
            output.append(NSAttributedString(string: clean + "\n", attributes: [
                .font: MicaboFont.uiFont(size, weight: weight),
                .foregroundColor: color ?? ink,
                .paragraphStyle: style,
            ]))
        }
        func addPair(_ term: String, _ text: String, indent: CGFloat = 0) {
            let line = NSMutableAttributedString(string: LessonDigest.plain(term), attributes: [
                .font: MicaboFont.uiFont(12, weight: .bold),
                .foregroundColor: ink,
                .paragraphStyle: paragraph(after: 5, indent: indent),
            ])
            line.append(NSAttributedString(string: " : " + LessonDigest.plain(text) + "\n", attributes: [
                .font: MicaboFont.uiFont(12),
                .foregroundColor: ink,
                .paragraphStyle: paragraph(after: 5, indent: indent),
            ]))
            output.append(line)
        }

        add(digest.title, size: 24, weight: .heavy, style: paragraph(after: 4))
        let subtitle = [digest.subject, L10n.t("ios.sup.export.subtitle", locale: locale)].compactMap { $0 }.joined(separator: " · ")
        add(subtitle, size: 11, weight: .semibold, color: soft, style: paragraph(after: 14))

        for (index, theme) in digest.themes.enumerated() {
            add("\(index + 1). \(theme.title)", size: 16, weight: .heavy, color: accent, style: paragraph(spacingBefore: 14, after: 6))
            if let notes = theme.notes {
                add(notes.oneLiner, size: 12, weight: .semibold, color: soft, style: paragraph(after: 8))
                for block in notes.blocks {
                    switch block {
                    case .subtitle(let text):
                        add(text, size: 13, weight: .bold, style: paragraph(spacingBefore: 6, after: 4))
                    case .paragraph(let text), .example(let text):
                        add(text, size: 12, style: paragraph())
                    case .list(let items):
                        for item in items { add("•  " + item, size: 12, style: paragraph(after: 3, indent: 8)) }
                    case .steps(let items):
                        for (step, item) in items.enumerated() { add("\(step + 1).  " + item, size: 12, style: paragraph(after: 3, indent: 8)) }
                    case .definition(let term, let text):
                        addPair(term, text)
                    case .dates(let items):
                        for item in items { addPair(item.date, item.text, indent: 8) }
                    case .formula(let latex, let caption):
                        add(latex, size: 12, weight: .semibold, style: paragraph(after: 2, indent: 8))
                        if let caption { add(caption, size: 11, color: soft, style: paragraph(indent: 8)) }
                    case .table(let columns, let rows):
                        add(columns.joined(separator: "  |  "), size: 11, weight: .bold, style: paragraph(after: 2, indent: 8))
                        for row in rows { add(row.joined(separator: "  |  "), size: 11, style: paragraph(after: 2, indent: 8)) }
                    case .quote(let text, let author):
                        add("« \(text) »" + (author.map { " · \($0)" } ?? ""), size: 12, color: soft, style: paragraph(indent: 8))
                    case .callout(let kind, let title, let text):
                        let label = title?.nilIfBlank ?? L10n.t(kind.titleKey, locale: locale)
                        addPair(label, text, indent: 8)
                    }
                }
                if !notes.takeaways.isEmpty {
                    add(L10n.t("ios.sup.listen.remember", locale: locale), size: 12, weight: .heavy, color: accent, style: paragraph(spacingBefore: 6, after: 3))
                    for takeaway in notes.takeaways { add("✓  " + takeaway, size: 12, style: paragraph(after: 3, indent: 8)) }
                }
            } else {
                for card in theme.cards { addPair(card.front, card.back) }
            }
        }

        if !digest.takeaways.isEmpty {
            add(L10n.t("ios.sup.listen.takeaways", locale: locale), size: 16, weight: .heavy, color: accent, style: paragraph(spacingBefore: 16, after: 6))
            for takeaway in digest.takeaways { add("✓  " + takeaway, size: 12, style: paragraph(after: 3, indent: 8)) }
        }
        return output
    }

    /// Le pied de page : « Fiche faite avec Micabo · 2 / 5 ».
    private final class FooterRenderer: UIPrintPageRenderer {
        let footer: String
        let rightToLeft: Bool

        init(footer: String, rightToLeft: Bool) {
            self.footer = footer
            self.rightToLeft = rightToLeft
            super.init()
        }

        override func drawFooterForPage(at pageIndex: Int, in footerRect: CGRect) {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let text = "\(footer) · \(pageIndex + 1) / \(numberOfPages)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: MicaboFont.uiFont(9, weight: .semibold),
                .foregroundColor: UIColor(red: 0.45, green: 0.46, blue: 0.5, alpha: 1),
                .paragraphStyle: style,
            ]
            let size = (text as NSString).size(withAttributes: attributes)
            let rect = CGRect(x: footerRect.minX, y: footerRect.midY - size.height / 2, width: footerRect.width, height: size.height)
            (text as NSString).draw(in: rect, withAttributes: attributes)
        }
    }
}
