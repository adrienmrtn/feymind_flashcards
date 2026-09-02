#if canImport(SwiftMath)
import SwiftMath
import SwiftUI
import UIKit

/// `MTMathUILabel` posé dans SwiftUI.
///
/// Ce fichier n'existe que si le paquet est résolu : personne ne l'appelle directement, on
/// passe par `MathFormula`, qui sait aussi quoi faire quand il n'est pas là.
///
/// SwiftMath 1.7.3 compose sur une seule ligne. On mesure la taille intrinsèque et on
/// coupe `clipsToBounds` : une équation trop large dépasse plutôt que de disparaître
/// à moitié, sans le moindre signe.
struct MathLabel: UIViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    let color: Color
    let isCentered: Bool
    /// Mode display : les bornes d'une somme passent au-dessus et en dessous du signe, et
    /// une fraction prend sa vraie hauteur. C'est le `$$` de LaTeX.
    let isDisplayMode: Bool

    func makeUIView(context: Context) -> MTMathUILabel {
        let view = MTMathUILabel()
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        // 1.7.3 compose sur une seule ligne et rogne par défaut. On laisse dépasser
        // plutôt que de couper une équation au milieu, sans signe.
        view.clipsToBounds = false
        // `MathFormula` a déjà vérifié que le LaTeX s'analyse. Si le typographe échoue
        // quand même, on préfère un vide à un message d'erreur rouge dans une fiche.
        view.displayErrorInline = false
        return view
    }

    func updateUIView(_ view: MTMathUILabel, context: Context) {
        // Poser `latex` reconstruit l'arbre de la formule : on ne le refait que s'il change,
        // sinon chaque passe de mise en page réanalyse la même expression.
        if view.latex != latex {
            view.latex = latex
        }
        view.fontSize = fontSize
        view.textColor = UIColor(color)
        view.labelMode = isDisplayMode ? .display : .text
        view.textAlignment = isCentered ? .center : .left
        view.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: MTMathUILabel,
        context: Context
    ) -> CGSize? {
        // `preferredMaxLayoutWidth` n'existe que sur le `main` de SwiftMath, pas dans
        // 1.7.3 — la dernière release que le paquet résout. Sur iOS, `sizeThatFits`
        // n'est pas non plus surchargé : il renverrait la contrainte telle quelle,
        // donc une hauteur infinie. On lit la taille naturelle.
        let size = uiView.intrinsicContentSize

        // La vue répond `-1` quand elle n'a rien à composer. Rendre ça à SwiftUI donnerait
        // une taille négative, et une taille négative traverse la mise en page en cassant
        // tout sur son passage.
        guard size.width >= 0, size.height >= 0 else { return nil }

        if let width = proposal.width, width.isFinite, width > 0, size.width > width {
            return CGSize(width: width, height: size.height)
        }
        return size
    }
}
#endif
