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
            MathLabel(
                latex: latex,
                fontSize: fontSize,
                color: color,
                isCentered: isCentered,
                isDisplayMode: isDisplayMode
            )
        } else {
            transposed
        }
        #else
        transposed
        #endif
    }

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
