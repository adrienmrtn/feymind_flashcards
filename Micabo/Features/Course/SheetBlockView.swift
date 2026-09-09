import SwiftUI

/// Rendu d'un bloc de fiche.
///
/// La règle de composition tenait en une phrase : le texte à même le papier, les objets dans
/// des blocs. Il n'y a plus d'objets. Une fiche est du texte - des titres, des phrases, des
/// listes - et une formule quand le cours en pose une. Ce qu'un tableau ou un encadré disait
/// s'écrit maintenant **dans** le texte, en gras, en italique ou surligné.
///
/// Ce n'est pas un appauvrissement : c'est ce qui rend la fiche **modifiable**. On ne corrige
/// pas un histogramme à la main, et une fiche qu'on ne peut pas annoter est une fiche qu'on
/// recopie ailleurs.
struct SheetBlockView: View {
    let block: SheetBlock
    /// Teinte du cours : elle ne sert qu'aux filets et aux puces de la fiche.
    let tint: Color
    /// Appelé avec le passage sélectionné quand l'utilisateur choisit « Expliquer ».
    var onExplain: ((String) -> Void)?

    var body: some View {
        switch block {
        case .heading(let level, let text):
            heading(level: level, text: text)

        case .paragraph(let text):
            SheetProse(markup: text, style: .prose, onExplain: onExplain)

        case .list(let ordered, let items):
            list(ordered: ordered, items: items)

        case .formula(let latex, let caption):
            formula(latex: latex, caption: caption)
        }
    }

    /// L'espace qui précède un bloc. Un titre de partie respire beaucoup plus qu'un
    /// paragraphe : c'est cet écart, et non un filet ou une couleur, qui donne le plan.
    static func spacing(before block: SheetBlock) -> CGFloat {
        switch block {
        case .heading(let level, _):
            level == 1 ? SheetTypography.spaceBeforeLargeHeading : SheetTypography.spaceBeforeSmallHeading
        case .list:
            SheetTypography.spaceBeforeList
        default:
            SheetTypography.blockSpacing
        }
    }

    // MARK: - Titres

    @ViewBuilder
    private func heading(level: Int, text: String) -> some View {
        if level == 1 {
            VStack(alignment: .leading, spacing: 7) {
                Capsule()
                    .fill(tint)
                    .frame(width: 26, height: 3)

                SheetInlineText(markup: text, style: .heading(level: 1))
            }
        } else {
            SheetInlineText(markup: text, style: .heading(level: 2))
        }
    }

    // MARK: - Listes

    /// L'énumération est posée **à même la page**, comme le paragraphe qui l'amène : elle ne
    /// prend pas de surface. Une liste dans un bloc blanc se lit comme un objet, donc comme
    /// quelque chose qui répond à une question ; une liste posée sur le papier se lit comme
    /// la suite du paragraphe, ce qu'elle est.
    ///
    /// Numérotée quand l'ordre compte - un mécanisme, une méthode - et à puces sinon. C'est
    /// la seule différence, et elle est portée par le seul repère de gauche : le texte, lui,
    /// est composé pareil.
    private func list(ordered: Bool, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { entry in
                HStack(alignment: .top, spacing: 9) {
                    marker(ordered: ordered, index: entry.offset)

                    SheetProse(markup: entry.element, style: .prose, onExplain: onExplain)
                }
            }
        }
        .padding(.leading, 2)
    }

    @ViewBuilder
    private func marker(ordered: Bool, index: Int) -> some View {
        if ordered {
            Text("\(index + 1).")
                .font(MicaboFont.hanken(SheetTypography.body, weight: .semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
                // Deux chiffres tiennent dans la même gouttière que la puce : sans largeur
                // fixe, le texte de la dixième ligne se décalerait des neuf premières.
                .frame(width: 20, alignment: .trailing)
        } else {
            Circle()
                .fill(tint.opacity(0.55))
                .frame(width: 4, height: 4)
                // La puce se cale sur la hauteur des minuscules de la première ligne, pas
                // sur le haut du bloc de texte.
                .padding(.top, SheetTypography.body * 0.42)
        }
    }

    // MARK: - Formule

    private func formula(latex: String, caption: String?) -> some View {
        VStack(spacing: 7) {
            // Une formule posée seule est **composée**, en mode display : c'est ici que la
            // typographie change tout, parce qu'une somme y met ses bornes au-dessus et en
            // dessous de son signe. Sans le paquet de composition, `MathFormula` retombe
            // sur la transposition Unicode d'avant, et la fiche reste lisible.
            MathFormula(latex: latex)

            if let caption = caption?.nilIfBlank {
                SheetInlineText(markup: caption, style: .caption.with(centered: true))
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, SheetTypography.objectPadding)
        .frame(maxWidth: .infinity)
        .background(
            MicaboColor.surfaceMuted,
            in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
        )
    }
}
