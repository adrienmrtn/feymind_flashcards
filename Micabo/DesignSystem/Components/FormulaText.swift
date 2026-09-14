import SwiftUI

/// Texte d'une carte, formules comprises.
///
/// Deux rendus, et c'est la carte qui décide :
///
/// - une carte qui **est** une formule (`$\frac{-b \pm \sqrt{b^2-4ac}}{2a}$`, et rien
///   d'autre) est composée par le moteur, avec ses vraies barres de fraction et ses vrais
///   radicaux. C'est le cas des cartes de sciences, et c'est là que ça compte ;
/// - un texte où une formule est prise dans une phrase reste transposé en Unicode, en
///   italique à empattements. La raison est technique et assumée : un `Text` SwiftUI ne
///   sait pas contenir de vue, donc composer la formule voudrait dire sortir le paragraphe
///   du fil du texte pour l'empiler ligne par ligne. Une phrase hachée en trois morceaux
///   se lit moins bien qu'un `x²`.
struct FormulaText: View {
    /// La famille dans laquelle le texte est composé.
    ///
    /// Une carte porte les deux : le recto **nomme** — une question d'une ligne, qu'on lit
    /// d'un regard — et le verso **explique**, sur trois ou quatre lignes qu'on relit. C'est
    /// exactement le partage entre les deux polices de l'app, à l'intérieur d'un même objet.
    enum Family {
        /// Outfit : le recto d'une carte, un intitulé.
        case display
        /// Hanken Grotesk : le verso d'une carte, une proposition de QCM.
        case reading
    }

    let source: String
    var size: CGFloat = 15
    var weight: Font.Weight = .regular
    var color: Color = MicaboColor.ink
    var alignment: TextAlignment = .leading
    var family: Family = .display

    var body: some View {
        if let formula = MathTypesetter.soleFormula(in: source), MathTypesetter.canTypeset(formula) {
            MathFormula(
                latex: formula,
                fontSize: size + 2,
                color: color,
                isCentered: alignment == .center,
                isDisplayMode: false
            )
        } else {
            composed
                .foregroundStyle(color)
                .multilineTextAlignment(alignment)
        }
    }

    private var composed: Text {
        FormulaRenderer.segments(of: source).reduce(Text("")) { partial, segment in
            partial + Text(segment.text).font(segment.isMath ? mathFont : proseFont)
        }
    }

    private var proseFont: Font {
        switch family {
        case .display: MicaboFont.ui(size, weight: weight)
        case .reading: MicaboFont.reading(size, weight: weight)
        }
    }

    /// Empattements et italique : la convention typographique des mathématiques, et de
    /// quoi voir d'un coup d'œil où commence la formule.
    private var mathFont: Font {
        .system(size: size + 1, weight: weight, design: .serif).italic()
    }
}
