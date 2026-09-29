import SwiftUI

// MARK: - La fiche de démonstration

/// **La fiche d'un chapitre de démonstration, avec ses objets riches.**
///
/// Les blocs ordinaires passent par le rendu de l'app (`SheetBlockView`) : mêmes titres,
/// mêmes paragraphes, mêmes surligneurs. Les objets riches — encadré, tableau, graphe,
/// frise, schéma, chiffre clé — sont dessinés ici, avec la typographie de la fiche, pour
/// qu'ils se lisent comme des morceaux de la même page et non comme des illustrations
/// rapportées.
struct DemoSheetView: View {
    let blocks: [DemoBlock]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                DemoBlockView(block: block, tint: tint)
                    .padding(.top, index == 0 ? 0 : Self.spacing(before: block))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func spacing(before block: DemoBlock) -> CGFloat {
        switch block {
        case .sheet(let inner): SheetBlockView.spacing(before: inner)
        case .callout, .table, .bars, .timeline, .figure, .keyFigure: SheetTypography.spaceBeforeSmallHeading
        }
    }
}

/// Un bloc de la fiche de démonstration.
struct DemoBlockView: View {
    let block: DemoBlock
    let tint: Color

    var body: some View {
        switch block {
        case .sheet(let inner):
            SheetBlockView(block: inner, tint: tint)
        case .callout(let title, let text, let tone):
            DemoCallout(title: title, text: text, tone: tone, tint: tint)
        case .table(let title, let headers, let rows):
            DemoTable(title: title, headers: headers, rows: rows, tint: tint)
        case .bars(let title, let unit, let bars):
            DemoBarChart(title: title, unit: unit, bars: bars, tint: tint)
        case .timeline(let title, let events):
            DemoTimeline(title: title, events: events, tint: tint)
        case .figure(let figure):
            DemoFigureView(figure: figure, tint: tint)
        case .keyFigure(let value, let label):
            DemoKeyFigure(value: value, label: label, tint: tint)
        }
    }
}

// MARK: - L'encadré

/// Un encadré à filet coloré : la définition en violet, l'idée en vert, l'erreur en ocre,
/// l'exemple en bleu. Le titre en gras, le texte balisé en dessous.
struct DemoCallout: View {
    let title: String
    let text: String
    let tone: DemoTone
    let tint: Color

    private var color: Color {
        switch tone {
        case .definition: MicaboColor.accent
        case .insight: MicaboColor.positive
        case .warning: MicaboColor.caution
        case .example: MicaboColor.info
        }
    }

    private var wash: Color {
        switch tone {
        case .definition: MicaboColor.accentSoft
        case .insight: MicaboColor.positiveSoft
        case .warning: MicaboColor.cautionSoft
        case .example: MicaboColor.infoSoft
        }
    }

    private var symbol: String {
        switch tone {
        case .definition: "text.book.closed.fill"
        case .insight: "lightbulb.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .example: "sparkles"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 3)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .bold))
                    Text(title.uppercased())
                        .font(MicaboFont.ui(11, weight: .bold))
                        .tracking(1.1)
                }
                .foregroundStyle(color)

                SheetInlineText(markup: text, style: .callout)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(wash, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
    }
}

// MARK: - Le tableau

/// Un tableau à filets : la ligne d'en-tête en gras sur fond gris, la première colonne en
/// gras, les cellules en corps réduit.
struct DemoTable: View {
    let title: String?
    let headers: [String]
    let rows: [[String]]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = title?.nilIfBlank {
                SheetInlineText(markup: title, style: .objectTitle)
            }

            VStack(spacing: 0) {
                if headers.contains(where: { !$0.isEmpty }) {
                    row(headers, isHeader: true)
                    MicaboHairline()
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                    row(cells, isHeader: false)
                    if index < rows.count - 1 {
                        MicaboHairline()
                    }
                }
            }
            .background(MicaboColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                    .strokeBorder(MicaboColor.stroke, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ cells: [String], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                SheetInlineText(markup: cell, style: .cell(emphasized: isHeader || index == 0))
                    .padding(.vertical, 9)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if index < cells.count - 1 {
                    Rectangle()
                        .fill(MicaboColor.hairline)
                        .frame(width: 1)
                }
            }
        }
        .background(isHeader ? MicaboColor.surfaceMuted : Color.clear)
    }
}

// MARK: - Le graphe à barres

/// Des barres horizontales, dans la teinte du cours, avec leur valeur au bout. Elles se
/// remplissent à l'apparition.
struct DemoBarChart: View {
    let title: String
    let unit: String?
    let bars: [DemoBar]
    let tint: Color

    @State private var isDrawn = false

    private var maxValue: Double {
        max(1, bars.map(\.value).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetInlineText(markup: title, style: .objectTitle)

            VStack(spacing: 9) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                    HStack(spacing: 10) {
                        Text(bar.label)
                            .font(MicaboFont.reading(SheetTypography.cell, weight: .medium))
                            .foregroundStyle(MicaboColor.ink)
                            .lineLimit(2)
                            .frame(width: 96, alignment: .leading)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(MicaboColor.surfaceMuted)
                                Capsule()
                                    .fill(tint.opacity(0.85 - Double(index) * 0.05))
                                    .frame(width: isDrawn ? proxy.size.width * CGFloat(bar.value / maxValue) : 0)
                            }
                        }
                        .frame(height: 14)

                        Text(bar.valueText + (unit.map { " \($0)" } ?? ""))
                            .font(MicaboFont.ui(12, weight: .bold))
                            .foregroundStyle(MicaboColor.ink)
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
        }
        .padding(SheetTypography.objectPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surfaceMuted.opacity(0.6), in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) { isDrawn = true }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - La frise

/// Des dates le long d'un filet vertical, le point de chaque événement dans la teinte du
/// cours.
struct DemoTimeline: View {
    let title: String?
    let events: [DemoEvent]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = title?.nilIfBlank {
                SheetInlineText(markup: title, style: .objectTitle)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(tint)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().strokeBorder(MicaboColor.surface, lineWidth: 2))
                                .padding(.top, 4)
                            if index < events.count - 1 {
                                Rectangle()
                                    .fill(tint.opacity(0.3))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 12)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.date)
                                .font(MicaboFont.ui(12, weight: .bold))
                                .foregroundStyle(tint.readableInk())
                                .monospacedDigit()
                            Text(event.label)
                                .font(MicaboFont.reading(SheetTypography.secondary))
                                .foregroundStyle(MicaboColor.inkReading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, index < events.count - 1 ? 14 : 0)
                    }
                }
            }
            .padding(.leading, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Le chiffre clé

/// Un chiffre en très grand, et ce qu'il compte, en une ligne.
struct DemoKeyFigure: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(value)
                .font(MicaboFont.ui(34, weight: .bold))
                .tracking(-1)
                .foregroundStyle(tint.readableInk())
                .monospacedDigit()
                .fixedSize()

            Text(label)
                .font(MicaboFont.reading(SheetTypography.secondary))
                .foregroundStyle(MicaboColor.inkReading)
                .lineSpacing(SheetTypography.secondaryLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SheetTypography.objectPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surfaceMuted.opacity(0.6), in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Les schémas

/// Un schéma dessiné, dans un cadre à filet, avec son titre au-dessus.
struct DemoFigureView: View {
    let figure: DemoFigure
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SheetInlineText(markup: title, style: .objectTitle)

            drawing
                .frame(maxWidth: .infinity)
                .padding(SheetTypography.objectPadding)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                        .strokeBorder(MicaboColor.stroke, lineWidth: 1)
                }

            if let caption = caption?.nilIfBlank {
                SheetInlineText(markup: caption, style: .caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch figure {
        case .cycle(let title, _), .flow(let title, _), .split(let title, _, _), .plot(let title, _, _): title
        }
    }

    private var caption: String? {
        if case .plot(_, let caption, _) = figure { return caption }
        return nil
    }

    @ViewBuilder
    private var drawing: some View {
        switch figure {
        case .cycle(_, let nodes): DemoCycleFigure(nodes: nodes, tint: tint)
        case .flow(_, let steps): DemoFlowFigure(steps: steps, tint: tint)
        case .split(_, let left, let right): DemoSplitFigure(left: left, right: right, tint: tint)
        case .plot(_, _, let kind): DemoPlotFigure(kind: kind, tint: tint)
        }
    }
}

/// **Des étapes en cercle.** Chaque étape est une pastille posée sur un anneau, et des
/// flèches tournent de l'une à la suivante.
struct DemoCycleFigure: View {
    let nodes: [String]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.33
            let count = max(1, nodes.count)

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [5, 6]))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                ForEach(0..<count, id: \.self) { index in
                    let angle = -Double.pi / 2 + Double(index) / Double(count) * 2 * .pi
                    let next = -Double.pi / 2 + (Double(index) + 0.5) / Double(count) * 2 * .pi
                    let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
                    let arrow = CGPoint(x: center.x + radius * CGFloat(cos(next)), y: center.y + radius * CGFloat(sin(next)))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                        .rotationEffect(.radians(next + .pi / 2))
                        .position(arrow)

                    DemoNode(text: nodes[index], number: index + 1, tint: tint)
                        .frame(maxWidth: size.width * 0.42)
                        .position(point)
                }
            }
        }
        .frame(height: 230)
    }
}

/// **Des étapes en ligne**, reliées par des flèches, qui reviennent à la ligne quand
/// l'écran est étroit.
struct DemoFlowFigure: View {
    let steps: [String]
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                DemoNode(text: step, number: index + 1, tint: tint, wide: true)
                if index < steps.count - 1 {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tint)
                }
            }
        }
    }
}

/// Une pastille d'étape : le numéro dans un rond teinté, le texte à côté.
struct DemoNode: View {
    let text: String
    let number: Int
    let tint: Color
    var wide: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(MicaboFont.ui(11, weight: .heavy))
                .foregroundStyle(MicaboColor.onInk)
                .frame(width: 20, height: 20)
                .background(tint, in: Circle())

            Text(text)
                .font(MicaboFont.reading(12.5, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: wide ? .infinity : nil, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        }
    }
}

/// **Deux colonnes face à face**, chacune sous son titre, séparées par un filet.
struct DemoSplitFigure: View {
    let left: DemoColumn
    let right: DemoColumn
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column(left, color: tint)
            Rectangle()
                .fill(MicaboColor.hairline)
                .frame(width: 1)
            column(right, color: MicaboColor.negative)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func column(_ column: DemoColumn, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(column.title.uppercased())
                .font(MicaboFont.ui(11, weight: .bold))
                .tracking(1)
                .foregroundStyle(color.readableInk())

            ForEach(Array(column.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(color.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(item)
                        .font(MicaboFont.reading(12.5))
                        .foregroundStyle(MicaboColor.inkReading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// **Une courbe sur des axes** : une parabole et sa tangente, une courbe qui monte puis
/// descend avec le signe de la pente, ou une courbe qui plafonne.
struct DemoPlotFigure: View {
    let kind: DemoPlotKind
    let tint: Color

    @State private var drawn: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let inset: CGFloat = 14

            ZStack(alignment: .topLeading) {
                // Les axes.
                Path { path in
                    path.move(to: CGPoint(x: inset, y: inset))
                    path.addLine(to: CGPoint(x: inset, y: h - inset))
                    path.addLine(to: CGPoint(x: w - inset, y: h - inset))
                }
                .stroke(MicaboColor.inkTertiary, lineWidth: 1.2)

                curve(in: CGRect(x: inset, y: inset, width: w - 2 * inset, height: h - 2 * inset))
                    .trim(from: 0, to: drawn)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                extras(in: CGRect(x: inset, y: inset, width: w - 2 * inset, height: h - 2 * inset))
                    .opacity(Double(drawn))
            }
        }
        .frame(height: 170)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) { drawn = 1 }
        }
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x, y: rect.maxY - rect.height * y)
    }

    private func curve(in rect: CGRect) -> Path {
        var path = Path()
        let samples = 60
        for step in 0...samples {
            let x = CGFloat(step) / CGFloat(samples)
            let y: CGFloat
            switch kind {
            case .tangent:
                y = 0.08 + 0.85 * x * x
            case .variation:
                // Une cubique ramenée dans le cadre : elle monte, redescend, remonte.
                let t = x * 2 - 1
                y = 0.5 + 0.38 * (t * t * t * 0.9 - t * 1.1) * -0.9
            case .saturation:
                y = 0.06 + 0.86 * (1 - pow(2.718, -4 * x))
            }
            let p = point(x, min(0.98, max(0.02, y)), in: rect)
            if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        return path
    }

    @ViewBuilder
    private func extras(in rect: CGRect) -> some View {
        switch kind {
        case .tangent:
            // La tangente en x = 0,55 : la droite de pente 2·0,85·x qui touche la courbe.
            let a: CGFloat = 0.55
            let ya = 0.08 + 0.85 * a * a
            let slope = 2 * 0.85 * a
            let x0 = max(0, a - 0.35), x1 = min(1, a + 0.35)
            Path { path in
                path.move(to: point(x0, ya + slope * (x0 - a), in: rect))
                path.addLine(to: point(x1, ya + slope * (x1 - a), in: rect))
            }
            .stroke(MicaboColor.negative, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            Circle()
                .fill(MicaboColor.ink)
                .frame(width: 8, height: 8)
                .position(point(a, ya, in: rect))
            Text("a")
                .font(.system(size: 12, weight: .semibold, design: .serif).italic())
                .foregroundStyle(MicaboColor.inkSecondary)
                .position(x: point(a, 0, in: rect).x, y: rect.maxY + 9)
        case .variation:
            HStack(spacing: 0) {
                signLabel("+")
                signLabel("−")
                signLabel("+")
            }
            .frame(width: rect.width)
            .position(x: rect.midX, y: rect.minY + 6)
        case .saturation:
            Path { path in
                path.move(to: point(0, 0.92, in: rect))
                path.addLine(to: point(1, 0.92, in: rect))
            }
            .stroke(MicaboColor.inkTertiary, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
    }

    private func signLabel(_ sign: String) -> some View {
        Text(sign)
            .font(MicaboFont.ui(13, weight: .heavy))
            .foregroundStyle(sign == "−" ? MicaboColor.negative : MicaboColor.positive)
            .frame(maxWidth: .infinity)
    }
}
