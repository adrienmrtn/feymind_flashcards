import Foundation

/// **Ce qu'une leçon contient, mis à plat pour les formats de révision construits sur
/// l'appareil** (`docs/supports.md`) : l'écoute, la carte mentale, la fiche en PDF.
///
/// Rien n'est demandé au modèle : on relit les notes de chaque thème (`ThemeNotes`), et à
/// défaut ses cartes. Une forme simple, sans SwiftData, que les tests construisent à la main.
struct LessonDigest: Equatable {
    struct Theme: Equatable {
        var title: String
        var notes: ThemeNotes?
        /// Recto et verso des cartes du thème, pour un thème sans notes.
        var cards: [(front: String, back: String)]

        static func == (lhs: Theme, rhs: Theme) -> Bool {
            lhs.title == rhs.title && lhs.notes == rhs.notes
                && lhs.cards.map(\.front) == rhs.cards.map(\.front)
                && lhs.cards.map(\.back) == rhs.cards.map(\.back)
        }
    }

    var title: String
    var subject: String?
    var takeaways: [String]
    var themes: [Theme]

    @MainActor
    init(course: Course) {
        title = course.title
        subject = course.subject?.nilIfBlank
        takeaways = course.lessonPath?.takeaways ?? []
        themes = course.orderedChapters.map { chapter in
            Theme(
                title: chapter.title,
                notes: chapter.notes,
                cards: chapter.orderedCards.prefix(40).map { card in
                    (front: LessonDigest.plain(card.front), back: LessonDigest.plain(card.back))
                }
            )
        }
    }

    init(title: String, subject: String? = nil, takeaways: [String] = [], themes: [Theme]) {
        self.title = title
        self.subject = subject
        self.takeaways = takeaways
        self.themes = themes
    }

    /// Un texte de notes sans son balisage : le gras (`**`), le surlignage, le trou d'une carte
    /// à trou, les dollars d'une formule.
    static func plain(_ text: String) -> String {
        var value = text.replacingOccurrences(of: ClozeGap.marker, with: "…")
        for marker in ["**", "==", "`", "$"] {
            value = value.replacingOccurrences(of: marker, with: "")
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        themes.allSatisfy { $0.notes == nil && $0.cards.isEmpty }
    }
}

// MARK: - La carte mentale

/// **Une carte mentale** : la leçon au centre, ses thèmes, et sous chaque thème ses notions
/// (les sous-titres, les termes définis, les dates), chacune avec quelques détails.
struct MindMapNode: Identifiable, Equatable {
    enum Level: Int, Equatable {
        case root
        case theme
        case notion
        case detail
    }

    var id: String
    var title: String
    var level: Level
    var children: [MindMapNode]

    var count: Int { 1 + children.reduce(0) { $0 + $1.count } }
}

enum MindMap {
    static let maximumNotions = 8
    static let maximumDetails = 4
    static let maximumLength = 90

    static func build(_ digest: LessonDigest) -> MindMapNode {
        let themes = digest.themes.enumerated().map { index, theme in
            MindMapNode(
                id: "t\(index)",
                title: clip(theme.title),
                level: .theme,
                children: notions(of: theme, prefix: "t\(index)")
            )
        }
        return MindMapNode(id: "root", title: clip(digest.title), level: .root, children: themes)
    }

    /// Les notions d'un thème. Un sous-titre ouvre une notion et range sous lui ce qui suit ;
    /// une définition, une date ou une formule légendée en sont une à elles seules.
    static func notions(of theme: LessonDigest.Theme, prefix: String) -> [MindMapNode] {
        var notions: [(title: String, details: [String])] = []
        func add(_ title: String, _ details: [String] = []) {
            let clean = clip(LessonDigest.plain(title))
            guard !clean.isEmpty, !notions.contains(where: { $0.title == clean }) else { return }
            notions.append((clean, details.map { clip(LessonDigest.plain($0)) }.filter { !$0.isEmpty }))
        }
        func attach(_ details: [String]) {
            guard !notions.isEmpty else {
                for item in details { add(item) }
                return
            }
            let clean = details.map { clip(LessonDigest.plain($0)) }.filter { !$0.isEmpty }
            notions[notions.count - 1].details += clean
        }

        if let notes = theme.notes {
            for block in notes.blocks {
                switch block {
                case .subtitle(let text):
                    add(text)
                case .definition(let term, let text):
                    add(term, [text])
                case .dates(let items):
                    for item in items { add(item.date, [item.text]) }
                case .formula(let latex, let caption):
                    if let caption { add(caption, [latex]) }
                case .list(let items), .steps(let items):
                    attach(items)
                case .callout(let kind, let title, let text):
                    if kind == .remember || kind == .mistake {
                        if let title = title?.nilIfBlank { add(title, [text]) } else { add(text) }
                    }
                case .paragraph, .example, .table, .quote:
                    break
                }
            }
            if notions.isEmpty {
                for takeaway in notes.takeaways { add(takeaway) }
            }
            if notions.isEmpty, !notes.oneLiner.isEmpty {
                add(notes.oneLiner)
            }
        } else {
            for card in theme.cards { add(card.front, [card.back]) }
        }

        return notions.prefix(maximumNotions).enumerated().map { index, notion in
            MindMapNode(
                id: "\(prefix).n\(index)",
                title: notion.title,
                level: .notion,
                children: notion.details.prefix(maximumDetails).enumerated().map { detail in
                    MindMapNode(id: "\(prefix).n\(index).d\(detail.offset)", title: detail.element, level: .detail, children: [])
                }
            )
        }
    }

    static func clip(_ text: String) -> String {
        let line = text.components(separatedBy: .newlines).first ?? text
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maximumLength else { return trimmed }
        return String(trimmed.prefix(maximumLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
