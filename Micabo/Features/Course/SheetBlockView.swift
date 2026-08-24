import SwiftUI

/// Rendu d'un bloc de fiche.
///
/// La règle de composition tient en une phrase : **le texte est posé à même le papier, les
/// objets sont dans des blocs.** Un paragraphe et un titre reposent sur l'ivoire, comme
/// sur une page ; une définition, un encadré, un tableau, un graphe et une formule sont des
/// objets et prennent une surface. C'est ce qui donne le rythme d'une fiche écrite à la
/// main, plutôt qu'une suite de cartes empilées de haut en bas.
struct SheetBlockView: View {
    let block: SheetBlock
    /// Teinte du cours : elle ne sert qu'aux filets et aux accents de la fiche.
    let tint: Color
    /// Appelé avec le passage sélectionné quand l'utilisateur choisit « Expliquer ».
    var onExplain: ((String) -> Void)?

    var body: some View {
        switch block {
        case .heading(let level, let text):
            heading(level: level, text: text)

        case .paragraph(let text):
            SheetProse(markup: text, style: .prose, onExplain: onExplain)

        case .definition(let term, let text):
            definition(term: term, text: text)

        case .callout(let tone, let text):
            callout(tone: tone, text: text)

        case .steps(let title, let items):
            steps(title: title, items: items)

        case .table(let table):
            SheetTableView(table: table, tint: tint)

        case .chart(let chart):
            SheetChartView(chart: chart, tint: tint)

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
        default:
            SheetTypography.blockSpacing
        }
    }

    // MARK: - Titres

    @ViewBuilder
    private func heading(level: Int, text: String) -> some View {
        if level == 1 {
            VStack(alignment: .leading, spacing: 11) {
                Capsule()
                    .fill(tint)
                    .frame(width: 26, height: 3)

                SheetInlineText(markup: text, style: .heading(level: 1))
            }
        } else {
            SheetInlineText(markup: text, style: .heading(level: 2))
        }
    }

    // MARK: - Définition

    private func definition(term: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            // Le filet doit courir sur toute la hauteur du bloc : sans cette hauteur
            // flexible, l'alignement en haut le réduirait à rien.
            Capsule()
                .fill(tint.opacity(0.55))
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 5) {
                SheetInlineText(
                    markup: term,
                    style: SheetTextStyle(size: 15, weight: .semibold, color: tint.darkened(by: 0.32), lineSpacing: 2)
                )

                SheetProse(markup: text, style: .compact, onExplain: onExplain)
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup(radius: MicaboRadius.lg)
    }

    // MARK: - Encadré

    private func callout(tone: SheetCalloutTone, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: tone.systemImage)
                    .font(.system(size: 9, weight: .bold))
                Text(tone.label.uppercased())
                    .font(MicaboFont.eyebrow)
                    .tracking(MicaboTracking.caps)
            }
            .foregroundStyle(calloutForeground(tone))

            SheetProse(markup: text, style: .callout, onExplain: onExplain)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            calloutBackground(tone),
            in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
        )
    }

    /// L'indigo n'apparaît pas ici : il ne sert qu'à ce qui est actif. Un encadré porte
    /// donc les couleurs de retour d'information de l'app, volontairement désaturées.
    private func calloutForeground(_ tone: SheetCalloutTone) -> Color {
        switch tone {
        case .essentiel: MicaboColor.ink
        case .attention: MicaboColor.caution
        case .exemple: MicaboColor.inkSecondary
        case .astuce: MicaboColor.positive
        }
    }

    private func calloutBackground(_ tone: SheetCalloutTone) -> Color {
        switch tone {
        case .essentiel: MicaboColor.marker.opacity(0.45)
        case .attention: MicaboColor.cautionSoft
        case .exemple: MicaboColor.surfaceMuted
        case .astuce: MicaboColor.positiveSoft
        }
    }

    // MARK: - Étapes

    private func steps(title: String?, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title?.nilIfBlank {
                SheetInlineText(markup: title, style: .objectTitle)
            }

            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 11) {
                        Text("\(index + 1)")
                            .font(MicaboFont.hanken(11.5, weight: .bold))
                            .foregroundStyle(tint.darkened(by: 0.3))
                            .frame(width: 21, height: 21)
                            .background(tint.lightened(by: 0.82), in: Circle())
                            .padding(.top, 1)

                        SheetProse(markup: item, style: .compact, onExplain: onExplain)
                    }
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup(radius: MicaboRadius.lg)
    }

    // MARK: - Formule

    private func formula(latex: String, caption: String?) -> some View {
        VStack(spacing: 9) {
            // Le balisage mathématique de l'app est celui des cartes : entre `$…$`, c'est
            // `FormulaRenderer` qui transpose, et la fiche n'a pas sa propre convention.
            SheetInlineText(
                markup: "$\(latex)$",
                style: SheetTextStyle(
                    size: SheetTypography.formula,
                    weight: .regular,
                    color: MicaboColor.ink,
                    lineSpacing: 3,
                    isCentered: true
                )
            )

            if let caption = caption?.nilIfBlank {
                SheetInlineText(markup: caption, style: .caption.with(centered: true))
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            MicaboColor.surfaceMuted,
            in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
        )
    }
}

// MARK: - Tableau

/// Tableau de fiche. Les colonnes sont de largeur égale : sur un écran de téléphone, une
/// colonne qui s'adapte à son contenu finit toujours par écraser sa voisine.
struct SheetTableView: View {
    let table: SheetTable
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = table.title?.nilIfBlank {
                SheetInlineText(markup: title, style: .objectTitle)
            }

            VStack(spacing: 0) {
                row(cells: table.headers, isHeader: true)
                    .background(tint.lightened(by: 0.88))

                ForEach(Array(table.rows.enumerated()), id: \.offset) { _, cells in
                    MicaboHairline()
                    row(cells: cells, isHeader: false)
                }
            }
            .micaboGroup(radius: MicaboRadius.lg)

            if let caption = table.caption?.nilIfBlank {
                SheetInlineText(markup: caption, style: .caption)
                    .padding(.horizontal, 2)
            }
        }
    }

    private func row(cells: [String], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                SheetInlineText(
                    markup: cell,
                    style: .cell(emphasized: isHeader || index == 0)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, isHeader ? 10 : 11)
        .padding(.horizontal, 13)
    }
}

// MARK: - Graphe

/// Graphe en barres. Une échelle, des valeurs écrites en clair, et rien d'autre : pas
/// d'axes, pas de grille, pas de légende séparée. Un graphe de fiche sert à voir un ordre
/// de grandeur, pas à relever une mesure.
struct SheetChartView: View {
    let chart: SheetChart
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if let title = chart.title?.nilIfBlank {
                SheetInlineText(markup: title, style: .objectTitle)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(chart.bars.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.xs) {
                            SheetInlineText(
                                markup: entry.label,
                                style: SheetTextStyle(size: 13.5, weight: .medium, color: MicaboColor.ink, lineSpacing: 2)
                            )

                            Text(chart.formatted(entry.value))
                                .font(MicaboFont.hanken(13.5, weight: .semibold))
                                .foregroundStyle(MicaboColor.inkSecondary)
                                .monospacedDigit()
                                .fixedSize()
                        }

                        bar(for: entry.value)
                    }
                }
            }

            if let caption = chart.caption?.nilIfBlank {
                SheetInlineText(markup: caption, style: .caption)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup(radius: MicaboRadius.lg)
    }

    private func bar(for value: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MicaboColor.surfaceSunken.opacity(0.55))

                Capsule()
                    .fill(tint.opacity(0.85))
                    .frame(width: max(5, proxy.size.width * CGFloat(ratio(of: value))))
            }
        }
        .frame(height: 9)
    }

    private func ratio(of value: Double) -> Double {
        min(1, max(0, value / chart.maximum))
    }
}
