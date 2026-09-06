import SwiftUI
import UIKit

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

        case .list(let items):
            list(items: items)

        case .definition(let term, let text):
            definition(term: term, text: text)

        case .callout(let tone, let text):
            callout(tone: tone, text: text)

        case .steps(let title, let items):
            steps(title: title, items: items)

        case .keypoints(let title, let items):
            SheetKeypointsView(title: title, items: items, tint: tint)

        case .quiz(let items):
            SheetQuizView(items: items, tint: tint, onExplain: onExplain)

        case .table(let table):
            SheetTableView(table: table, tint: tint)

        case .diagram(let diagram):
            SheetDiagramView(diagram: diagram, tint: tint)

        case .chart(let chart):
            SheetChartView(chart: chart, tint: tint)

        case .formula(let latex, let caption):
            formula(latex: latex, caption: caption)

        case .figure(let figure):
            SheetFigureView(figure: figure)
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

    // MARK: - Puces

    /// L'énumération est posée **à même la page**, comme le paragraphe qui l'amène : elle ne
    /// prend pas de surface.
    ///
    /// C'est ce qui la distingue d'une suite d'étapes, qui est encartée. Une liste dans un
    /// bloc blanc se lit comme un objet, donc comme quelque chose qui répond à une question ;
    /// une liste posée sur le papier se lit comme la suite du paragraphe, ce qu'elle est.
    /// La puce est un point rond, aligné sur la première ligne du texte.
    private func list(items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(tint.opacity(0.55))
                        .frame(width: 4, height: 4)
                        // La puce se cale sur la hauteur des minuscules de la première ligne,
                        // pas sur le haut du bloc de texte.
                        .padding(.top, SheetTypography.body * 0.42)

                    SheetProse(markup: item, style: .prose, onExplain: onExplain)
                }
            }
        }
        .padding(.leading, 2)
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

            VStack(alignment: .leading, spacing: 4) {
                SheetInlineText(
                    markup: term,
                    style: SheetTextStyle(
                        size: SheetTypography.objectTitle,
                        weight: .semibold,
                        color: MicaboColor.ink,
                        lineSpacing: SheetTypography.tightLineSpacing
                    )
                )

                SheetProse(markup: text, style: .compact, onExplain: onExplain)
            }
        }
        .padding(SheetTypography.objectPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup(radius: MicaboRadius.lg)
    }

    // MARK: - Encadré

    private func callout(tone: SheetCalloutTone, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .padding(SheetTypography.objectPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            calloutBackground(tone),
            in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
        )
    }

    /// Un encadré porte les couleurs de retour d'information de l'app, volontairement
    /// désaturées, et **quatre surfaces qui se distinguent** : le menthe de ce que la fiche
    /// met en avant, l'ambre de ce qui coûte des points, le gris d'un exemple, le bleu pâle
    /// d'un moyen de retenir. Les libellés, eux, restent à l'encre : un mot bleu se lit
    /// comme un lien.
    ///
    /// L'astuce était sur le vert de `positive`, à trois points de canal du menthe de
    /// l'essentiel : sur un écran, les deux encadrés étaient le même. Or l'essentiel est
    /// justement celui qu'on doit trouver sans le chercher.
    private func calloutForeground(_ tone: SheetCalloutTone) -> Color {
        switch tone {
        case .essentiel: MicaboColor.ink
        case .attention: MicaboColor.caution
        case .exemple: MicaboColor.inkSecondary
        case .astuce: MicaboColor.ink
        }
    }

    /// L'encadré « essentiel » portait le jaune du surligneur : c'était la même couleur pour
    /// deux choses différentes, et elle est partie avec lui. Il prend le vert pâle, qui est
    /// désormais la couleur de ce que la fiche met en avant.
    private func calloutBackground(_ tone: SheetCalloutTone) -> Color {
        switch tone {
        case .essentiel: MicaboColor.accentSoft
        case .attention: MicaboColor.cautionSoft
        case .exemple: MicaboColor.surfaceMuted
        case .astuce: MicaboColor.infoSoft
        }
    }

    // MARK: - Étapes

    private func steps(title: String?, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if let title = title?.nilIfBlank {
                SheetInlineText(markup: title, style: .objectTitle)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(MicaboFont.hanken(11, weight: .bold))
                            .foregroundStyle(MicaboColor.ink)
                            .frame(width: 19, height: 19)
                            .background(tint.lightened(by: 0.82), in: Circle())
                            .padding(.top, 1)

                        SheetProse(markup: item, style: .compact, onExplain: onExplain)
                    }
                }
            }
        }
        .padding(SheetTypography.objectPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup(radius: MicaboRadius.lg)
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

// MARK: - Figure recadrée

struct SheetFigureView: View {
    let figure: SheetFigure
    @State private var decoded: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = decoded {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.1), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }

            SheetInlineText(markup: figure.caption, style: .caption)
        }
        .padding(SheetTypography.objectPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup(radius: MicaboRadius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(SheetMarkup.plain(figure.caption))
        .task(id: figure.imageData?.count) {
            guard let data = figure.imageData else {
                decoded = nil
                return
            }
            decoded = await Task.detached(priority: .userInitiated) {
                UIImage(data: data)
            }.value
        }
    }
}

// MARK: - Chiffres clés

/// Les valeurs à connaître par cœur, posées en grand.
///
/// Le chiffre passe devant son libellé, et de loin : c'est lui qu'on vient chercher, et c'est
/// le seul bloc de la fiche où le contenu tient en trois caractères. Le libellé est en
/// dessous, en petit — l'inverse donnerait une rangée de légendes.
struct SheetKeypointsView: View {
    let title: String?
    let items: [SheetKeypoint]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = title?.nilIfBlank {
                SheetInlineText(markup: title, style: .objectTitle)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 9) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    tile(item)
                }
            }
        }
        .padding(SheetTypography.objectPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup(radius: MicaboRadius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Trois de front quand il y en a trois, deux sinon.
    ///
    /// Trois valeurs sur deux colonnes laissent une case vide au coin, et une case vide dans
    /// une grille se lit comme une donnée manquante. Au-delà de trois, deux colonnes : à
    /// quatre de front, « 0,05 » ne tient plus sur la largeur d'un téléphone.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 9), count: items.count == 3 ? 3 : 2)
    }

    private func tile(_ item: SheetKeypoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.value)
                .font(MicaboFont.hanken(19, weight: .bold))
                .foregroundStyle(tint.darkened(by: 0.32))
                .tracking(MicaboTracking.display)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            SheetInlineText(markup: item.label, style: .caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            tint.lightened(by: 0.9),
            in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous)
        )
    }

    private var accessibilityLabel: String {
        let heading = title?.nilIfBlank.map(SheetMarkup.plain) ?? L10n.t("app.sheet.keypoints", locale: .resolved())
        let values = items.map { "\(SheetMarkup.plain($0.label)) : \(SheetMarkup.plain($0.value))" }
        return ([heading] + values).joined(separator : ". ")
    }
}

// MARK: - Question

/// De quoi se tester sans quitter la fiche.
///
/// La réponse est **cachée par défaut**, et c'est tout l'intérêt du bloc : une question dont
/// la réponse est écrite juste en dessous ne se pose pas, elle se lit. Le geste reproduit
/// celui qu'on fait sur une fiche papier, le doigt posé sur la moitié droite de la feuille.
struct SheetQuizView: View {
    let items: [SheetQuestion]
    let tint: Color
    var onExplain: ((String) -> Void)?

    @State private var revealed: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(L10n.t("app.sheet.quiz", locale: .resolved()).uppercased())
                    .font(MicaboFont.eyebrow)
                    .tracking(MicaboTracking.caps)
            }
            .foregroundStyle(tint.darkened(by: 0.32))

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { MicaboHairline() }
                question(item, at: index)
            }
        }
        .padding(SheetTypography.objectPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup(radius: MicaboRadius.lg)
    }

    @ViewBuilder
    private func question(_ item: SheetQuestion, at index: Int) -> some View {
        let isRevealed = revealed.contains(index)

        VStack(alignment: .leading, spacing: 7) {
            SheetInlineText(markup: item.question, style: .objectTitle)

            if isRevealed {
                SheetProse(markup: item.answer, style: .compact, onExplain: onExplain)
                    .transition(.opacity)
            } else {
                Button {
                    Haptics.selection()
                    withAnimation(.easeOut(duration: 0.22)) { revealed.insert(index) }
                } label: {
                    Text(L10n.t("app.sheet.showAnswer", locale: .resolved()))
                        .font(MicaboFont.hanken(SheetTypography.cell, weight: .semibold))
                        .foregroundStyle(tint.darkened(by: 0.32))
                }
                .buttonStyle(.plain)
                .accessibilityHint(SheetMarkup.plain(item.question))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tableau

/// Tableau de fiche. Les colonnes sont de largeur égale : sur un écran de téléphone, une
/// colonne qui s'adapte à son contenu finit toujours par écraser sa voisine.
struct SheetTableView: View {
    let table: SheetTable
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        HStack(alignment: .top, spacing: 9) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                SheetInlineText(
                    markup: cell,
                    style: .cell(emphasized: isHeader || index == 0)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, isHeader ? 8 : 9)
        .padding(.horizontal, 11)
    }
}

// MARK: - Schéma

/// Le schéma de la fiche, dessiné.
///
/// **Tout est vertical, et ce n'est pas un pis-aller.** Un schéma de cours se dessine au
/// tableau de gauche à droite, mais une fiche se lit sur une colonne de trois cent quarante
/// points : quatre cases de front y font quatre-vingts points chacune, donc un mot par ligne
/// et trois lignes par case. La suite descend, comme le reste de la page, et le doigt qui
/// défile suit le sens de la lecture.
struct SheetDiagramView: View {
    let diagram: SheetDiagram
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = diagram.title?.nilIfBlank {
                SheetInlineText(markup: title, style: .objectTitle)
            }

            figure

            if let caption = diagram.caption?.nilIfBlank {
                SheetInlineText(markup: caption, style: .caption)
            }
        }
        .padding(SheetTypography.objectPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup(radius: MicaboRadius.lg)
        // Un schéma se lit d'un coup d'œil ou pas du tout : à VoiceOver, il est **une**
        // annonce, celle de sa version à plat, et non huit cases à parcourir une par une.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var figure: some View {
        switch diagram.layout {
        case .flow, .cycle:
            flow
        case .branch:
            branch
        case .timeline:
            timeline
        }
    }

    // MARK: Suite et boucle

    private var flow: some View {
        VStack(spacing: 0) {
            ForEach(Array(diagram.nodes.enumerated()), id: \.offset) { index, node in
                if index > 0 { connector(systemImage: "arrow.down") }
                card(node)
            }

            if diagram.layout == .cycle {
                // La boucle est **écrite**, pas dessinée : une flèche courbe qui remonte le
                // long de quatre cases empilées passe derrière elles ou déborde du bloc, et
                // dans les deux cas on ne voit plus qu'elle.
                connector(systemImage: "arrow.turn.left.up", label: L10n.t("app.sheet.backToStart", locale: .resolved()))
            }
        }
    }

    // MARK: Classification

    /// Un tronc, et ce qui s'y rattache : le filet vertical descend sous le tronc et chaque
    /// branche s'y accroche par un trait.
    private var branch: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let trunk = diagram.trunk {
                card(trunk, isTrunk: true)
            }

            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(tint.opacity(0.35))
                    .frame(width: 1.5)
                    .padding(.leading, 15)

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(diagram.branches.enumerated()), id: \.offset) { _, node in
                        HStack(alignment: .top, spacing: 0) {
                            Rectangle()
                                .fill(tint.opacity(0.35))
                                .frame(width: 11, height: 1.5)
                                .padding(.top, SheetTypography.secondary * 0.62)

                            card(node)
                        }
                    }
                }
            }
            .padding(.top, 7)
        }
    }

    // MARK: Frise

    /// Le détail d'un nœud est la **date** sur une frise : elle passe donc au-dessus du
    /// libellé et prend la couleur du cours, parce que c'est par les dates qu'on relit une
    /// chronologie.
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(diagram.nodes.enumerated()), id: \.offset) { index, node in
                HStack(alignment: .top, spacing: 11) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(tint)
                            .frame(width: 7, height: 7)
                            .padding(.top, 4)

                        if index < diagram.nodes.count - 1 {
                            Rectangle()
                                .fill(tint.opacity(0.3))
                                .frame(width: 1.5)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 7)

                    VStack(alignment: .leading, spacing: 1) {
                        if let detail = node.detail?.nilIfBlank {
                            Text(SheetMarkup.plain(detail))
                                .font(MicaboFont.hanken(SheetTypography.caption, weight: .bold))
                                .foregroundStyle(tint.darkened(by: 0.32))
                                .monospacedDigit()
                        }

                        SheetInlineText(
                            markup: node.label,
                            style: SheetTextStyle(
                                size: SheetTypography.secondary,
                                weight: .medium,
                                color: MicaboColor.ink,
                                lineSpacing: SheetTypography.tightLineSpacing
                            )
                        )
                    }
                    .padding(.bottom, index < diagram.nodes.count - 1 ? 11 : 0)
                }
            }
        }
    }

    // MARK: Pièces

    private func card(_ node: SheetDiagram.Node, isTrunk: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SheetInlineText(
                markup: node.label,
                style: SheetTextStyle(
                    size: SheetTypography.secondary,
                    weight: .semibold,
                    color: MicaboColor.ink,
                    lineSpacing: SheetTypography.tightLineSpacing
                )
            )

            if let detail = node.detail?.nilIfBlank {
                SheetInlineText(markup: detail, style: .caption)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tint.lightened(by: isTrunk ? 0.82 : 0.9),
            in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous)
        )
    }

    private func connector(systemImage: String, label: String? = nil) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))

            if let label {
                Text(label)
                    .font(MicaboFont.hanken(SheetTypography.caption, weight: .medium))
            }
        }
        .foregroundStyle(tint.opacity(0.75))
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: label == nil ? .center : .leading)
        .padding(.leading, label == nil ? 0 : 11)
    }

    private var accessibilityLabel: String {
        ([L10n.t("app.sheet.diagram", locale: .resolved())] + diagram.plainLines())
            .joined(separator: " : ")
    }
}

// MARK: - Graphe

/// Le graphe de la fiche. Une échelle, des valeurs écrites en clair, et rien d'autre : pas
/// d'axes, pas de grille, pas de légende séparée. Un graphe de fiche sert à voir un ordre
/// de grandeur, pas à relever une mesure.
struct SheetChartView: View {
    let chart: SheetChart
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = chart.title?.nilIfBlank {
                SheetInlineText(markup: title, style: .objectTitle)
            }

            plot

            if let caption = chart.caption?.nilIfBlank {
                SheetInlineText(markup: caption, style: .caption)
            }
        }
        .padding(SheetTypography.objectPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup(radius: MicaboRadius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chart.plainLines().joined(separator: ". "))
    }

    @ViewBuilder
    private var plot: some View {
        switch chart.kind {
        case .bars: bars
        case .columns: columns
        case .line: line
        case .donut: donut
        }
    }

    // MARK: Barres couchées

    /// La forme par défaut, et celle qui tient le plus de libellés : le nom au-dessus de sa
    /// barre a toute la largeur de la colonne pour s'écrire.
    private var bars: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(chart.bars.enumerated()), id: \.offset) { _, entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.xs) {
                        SheetInlineText(markup: entry.label, style: .chartLabel)

                        Text(chart.formatted(entry.value))
                            .font(MicaboFont.hanken(SheetTypography.cell, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .monospacedDigit()
                            .fixedSize()
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(MicaboColor.surfaceSunken.opacity(0.55))

                            Capsule()
                                .fill(tint.opacity(0.85))
                                .frame(width: max(5, proxy.size.width * CGFloat(ratio(of: entry.value))))
                        }
                    }
                    .frame(height: 7)
                }
            }
        }
    }

    // MARK: Colonnes

    /// Les mêmes valeurs debout. C'est la forme qu'on attend d'un histogramme, mais elle
    /// coûte cher en largeur : le libellé est tronqué à deux lignes, donc elle ne vaut que
    /// pour des noms courts, et le prompt le dit.
    private var columns: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(chart.bars.enumerated()), id: \.offset) { _, entry in
                VStack(spacing: 5) {
                    Text(chart.formatted(entry.value))
                        .font(MicaboFont.hanken(SheetTypography.caption, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(tint.opacity(0.85))
                        .frame(height: max(4, Self.columnHeight * CGFloat(ratio(of: entry.value))))

                    SheetInlineText(markup: entry.label, style: .chartLabel.with(centered: true))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        // Les colonnes partent toutes de la même ligne de base : sans hauteur fixée, la plus
        // haute imposerait la sienne et les autres flotteraient.
        .frame(minHeight: Self.columnHeight)
    }

    private static let columnHeight = CGFloat(88)

    // MARK: Courbe

    /// Une évolution. Les points sont dans l'ordre où le modèle les a rendus : c'est le seul
    /// graphe où l'ordre du tableau de valeurs porte du sens.
    ///
    /// Pas d'axes, pas de grille : la valeur haute est écrite en haut, la basse en bas, et
    /// les deux bouts de l'abscisse sous la courbe. Une grille sur cent points de haut fait
    /// un papier millimétré, ce qui n'est pas ce qu'on relit la veille.
    private var line: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 9) {
                VStack(alignment: .trailing, spacing: 0) {
                    scaleLabel(chart.formatted(chart.maximum))
                    Spacer(minLength: 0)
                    scaleLabel(chart.formatted(0))
                }

                GeometryReader { proxy in
                    let points = Self.points(of: chart, in: proxy.size)

                    ZStack {
                        // L'aire sous la courbe donne le sens de lecture sans ajouter de
                        // trait : elle dit de quel côté est le « plus ».
                        Path { path in
                            guard let first = points.first, let last = points.last else { return }
                            path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                            for point in points { path.addLine(to: point) }
                            path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                            path.closeSubpath()
                        }
                        .fill(tint.opacity(0.12))

                        Path { path in
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for point in points.dropFirst() { path.addLine(to: point) }
                        }
                        .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                            Circle()
                                .fill(MicaboColor.surface)
                                .overlay(Circle().stroke(tint, lineWidth: 1.5))
                                .frame(width: 5, height: 5)
                                .position(point)
                        }
                    }
                }
                .frame(height: Self.columnHeight)
            }

            HStack(spacing: 0) {
                if let first = chart.bars.first {
                    SheetInlineText(markup: first.label, style: .chartLabel)
                }
                Spacer(minLength: 9)
                if let last = chart.bars.last, chart.bars.count > 1 {
                    SheetInlineText(markup: last.label, style: .chartLabel)
                        .frame(alignment: .trailing)
                }
            }
        }
    }

    /// Les points de la courbe, dans le repère de la vue : l'origine d'une vue est en haut à
    /// gauche, donc une valeur haute a un `y` bas.
    private static func points(of chart: SheetChart, in size: CGSize) -> [CGPoint] {
        let count = chart.bars.count
        guard count > 1 else {
            return chart.bars.map { _ in CGPoint(x: size.width / 2, y: size.height / 2) }
        }

        // Deux points de marge en haut et en bas : un maximum collé au bord se fait couper
        // son cercle en deux.
        let inset = CGFloat(3)
        let usable = max(inset, size.height - inset * 2)

        return chart.bars.enumerated().map { index, bar in
            let ratio = min(1, max(0, bar.value / chart.maximum))
            return CGPoint(
                x: size.width * CGFloat(index) / CGFloat(count - 1),
                y: inset + usable * CGFloat(1 - ratio)
            )
        }
    }

    private func scaleLabel(_ text: String) -> some View {
        Text(text)
            .font(MicaboFont.hanken(SheetTypography.caption, weight: .medium))
            .foregroundStyle(MicaboColor.inkTertiary)
            .monospacedDigit()
            .fixedSize()
    }

    // MARK: Anneau

    /// Une répartition. L'anneau ne porte aucun texte : les parts d'un camembert sont trop
    /// étroites pour être écrites dessus, et une étiquette avec sa ligne de rappel fait
    /// perdre plus de place qu'une légende posée dessous.
    private var donut: some View {
        HStack(alignment: .center, spacing: 13) {
            ZStack {
                ForEach(Array(shares.enumerated()), id: \.offset) { index, share in
                    Circle()
                        .trim(from: share.start, to: share.end)
                        .stroke(segmentColor(at: index), style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 76, height: 76)
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(chart.bars.enumerated()), id: \.offset) { index, entry in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Circle()
                            .fill(segmentColor(at: index))
                            .frame(width: 7, height: 7)
                            .padding(.top, 3)

                        SheetInlineText(markup: entry.label, style: .chartLabel)

                        Text(chart.formatted(entry.value))
                            .font(MicaboFont.hanken(SheetTypography.cell, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .monospacedDigit()
                            .fixedSize()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Les parts, en fractions de tour cumulées.
    private var shares: [(start: CGFloat, end: CGFloat)] {
        let total = chart.total
        guard total > 0 else { return [] }

        var cursor = CGFloat(0)
        return chart.bars.map { bar in
            let sweep = CGFloat(bar.value / total)
            let share = (start: cursor, end: min(1, cursor + sweep))
            cursor += sweep
            return share
        }
    }

    /// Les parts sont **la même couleur, éclaircie par crans**. Six couleurs franches sur une
    /// fiche feraient six sens à chercher, alors qu'une répartition ne dit qu'une chose :
    /// celle-ci est plus grosse que celle-là.
    private func segmentColor(at index: Int) -> Color {
        tint.lightened(by: min(0.72, Double(index) * 0.16))
    }

    private func ratio(of value: Double) -> Double {
        min(1, max(0, value / chart.maximum))
    }
}
