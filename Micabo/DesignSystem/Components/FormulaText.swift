import SwiftUI

/// Texte d'une carte, formules comprises. Les fragments entre `$…$` sont transposés par
/// `FormulaRenderer` et composés dans une italique à empattements, pour qu'une formule se
/// distingue de la phrase qui l'entoure.
struct FormulaText: View {
    let source: String
    var size: CGFloat = 15
    var weight: Font.Weight = .regular
    var color: Color = MicaboColor.ink
    var alignment: TextAlignment = .leading

    var body: some View {
        composed
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
    }

    private var composed: Text {
        FormulaRenderer.segments(of: source).reduce(Text("")) { partial, segment in
            partial + Text(segment.text).font(segment.isMath ? mathFont : proseFont)
        }
    }

    private var proseFont: Font {
        MicaboFont.hanken(size, weight: weight)
    }

    /// Empattements et italique : la convention typographique des mathématiques, et de
    /// quoi voir d'un coup d'œil où commence la formule.
    private var mathFont: Font {
        .system(size: size + 1, weight: weight, design: .serif).italic()
    }
}
