import SwiftUI

extension Text {
    /// **Le mot-clé en bleu clair** : `highlight`, le groupe de mots à faire ressortir, est
    /// cherché dans `text` et peint dans `color` (le bleu clair `V3Color.accentBright`, sauf
    /// mention) ; le reste garde la couleur du texte. Un seul groupe de mots par phrase : c'est
    /// une signature, pas un surligneur.
    ///
    /// Sans `highlight` (ou s'il n'est pas dans la phrase, après une traduction par exemple), le
    /// texte s'écrit d'une seule couleur. Deux paires d'astérisques dans la phrase elle-même
    /// (`"Ton **objectif n°1** cette année ?"`) désignent aussi le mot-clé : une traduction peut
    /// ainsi porter le sien.
    init(v3 text: String, highlight: String? = nil, color: Color = V3Color.accentBright) {
        if let highlight, !highlight.isEmpty,
           let range = text.range(of: highlight)
            ?? text.range(of: highlight, options: [.caseInsensitive, .diacriticInsensitive]) {
            let before = String(text[..<range.lowerBound]).replacingOccurrences(of: "**", with: "")
            let keyword = String(text[range])
            let after = String(text[range.upperBound...]).replacingOccurrences(of: "**", with: "")
            self = Text(verbatim: before)
                + Text(verbatim: keyword).foregroundStyle(color)
                + Text(verbatim: after)
            return
        }
        let parts = text.components(separatedBy: "**")
        var result = Text(verbatim: "")
        for (index, part) in parts.enumerated() where !part.isEmpty {
            // Un nombre impair de marques laisse la dernière ouverte : elle ne colore rien.
            let isKeyword = index % 2 == 1 && index < parts.count - 1
            result = result + (isKeyword ? Text(verbatim: part).foregroundStyle(color) : Text(verbatim: part))
        }
        self = result
    }
}

extension String {
    /// La phrase sans ses marques de mot-clé, pour VoiceOver.
    var v3Plain: String {
        replacingOccurrences(of: "**", with: "")
    }
}

/// **Le titre d'un écran** : Sofia Sans Condensed Black, son mot-clé en bleu clair.
///
/// `size` choisit le palier : 40 pour le titre d'une story ou d'un grand moment, 34 ou 32 pour
/// un titre de page, 25 pour un titre d'écran secondaire. L'interlettrage suit la taille. Le
/// titre passe à la ligne et grossit avec « Taille du texte » ; il ne se coupe pas.
///
/// Un titre : douze mots au plus, et un seul groupe de mots en couleur. `highlightColor` change
/// cette couleur quand le mot-clé a un autre sens : le vert d'un objectif (`V3Color.green`), le
/// jaune d'une offre (`V3Color.yellow`).
struct V3Title: View {
    private let text: String
    private let highlight: String?
    private let size: CGFloat
    private let alignment: TextAlignment
    private let highlightColor: Color

    init(
        _ text: String,
        highlight: String? = nil,
        size: CGFloat = 34,
        alignment: TextAlignment = .leading,
        highlightColor: Color = V3Color.accentBright
    ) {
        self.text = text
        self.highlight = highlight
        self.size = size
        self.alignment = alignment
        self.highlightColor = highlightColor
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var body: some View {
        Text(v3: text, highlight: highlight, color: highlightColor)
            .font(V3Font.heading(size))
            .tracking(V3Tracking.heading(size))
            .foregroundStyle(V3Color.ink)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .accessibilityLabel(Text(text.v3Plain))
            .accessibilityAddTraits(.isHeader)
    }
}

/// **« PRO » dans sa pastille jaune** : des capitales droites, brun très sombre sur jaune —
/// jamais d'italique, jamais sur un fond d'accent. `prefix` l'amène : « Passer en » dans
/// l'en-tête de la Home, « Micabo » en tête du paywall. Sans préfixe, la pastille seule (une
/// tuile réservée à Pro).
struct V3ProBadge: View {
    private let prefix: String?
    private let size: CGFloat

    init(_ prefix: String? = nil) {
        self.prefix = prefix
        self.size = 22
    }

    /// La même, à une autre taille : 11 pour la pastille posée sur le coin d'une tuile.
    init(_ prefix: String? = nil, size: CGFloat) {
        self.prefix = prefix
        self.size = size
    }

    var body: some View {
        HStack(spacing: size * 0.22) {
            if let prefix, !prefix.isEmpty {
                Text(prefix)
                    .font(V3Font.heading(size))
                    .foregroundStyle(V3Color.ink)
            }
            Text(verbatim: "PRO")
                .font(V3Font.heading(size))
                .foregroundStyle(V3Color.onYellow)
                .padding(.horizontal, size * 0.36)
                .padding(.vertical, size * 0.05)
                .background(V3Color.yellow, in: RoundedRectangle(cornerRadius: size * 0.36, style: .continuous))
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}
