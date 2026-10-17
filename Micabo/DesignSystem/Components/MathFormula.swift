import SwiftUI

/// Une formule posée seule : composée si le moteur est là, transposée sinon.
///
/// C'est la seule porte d'entrée de la composition mathématique dans l'interface. Elle
/// compile dans les deux états du dépôt, et le repli est **exactement** ce que la fiche
/// affichait avant : la transposition Unicode de `FormulaRenderer`, en italique à
/// empattements. Un lecteur ne doit pas pouvoir dire « il manque quelque chose », seulement
/// « c'est moins beau ».
///
/// Elle ne sert qu'aux formules **isolées** : un bloc `formula` de fiche, une carte qui est
/// une formule. Pour une formule au milieu d'une phrase, voir `SheetAttributedText`, qui
/// explique pourquoi elle reste transposée.
struct MathFormula: View {
    let latex: String
    var fontSize: CGFloat = SheetTypography.formula
    var color: Color = MicaboColor.ink
    var isCentered: Bool = true
    var isDisplayMode: Bool = true

    var body: some View {
        #if canImport(SwiftMath)
        if MathTypesetter.canTypeset(latex) {
            // Le moteur compose sur une seule ligne. Une formule qui tient reste posée (et
            // centrée par son parent) ; une formule plus large que la place offerte glisse
            // en travers, plutôt que de déborder de l'écran des deux côtés.
            ViewThatFits(in: .horizontal) {
                label
                ScrollView(.horizontal, showsIndicators: false) {
                    label
                        .fixedSize()
                        .padding(.vertical, 2)
                }
            }
        } else {
            transposed
        }
        #else
        transposed
        #endif
    }

    #if canImport(SwiftMath)
    private var label: MathLabel {
        MathLabel(
            latex: latex,
            fontSize: fontSize,
            color: color,
            isCentered: isCentered,
            isDisplayMode: isDisplayMode
        )
    }
    #endif

    /// Le plancher : le même rendu qu'avant le moteur.
    private var transposed: some View {
        SheetInlineText(
            markup: "$\(latex)$",
            style: SheetTextStyle(
                size: fontSize,
                weight: .regular,
                color: color,
                lineSpacing: SheetTypography.tightLineSpacing,
                isCentered: isCentered
            )
        )
    }
}
