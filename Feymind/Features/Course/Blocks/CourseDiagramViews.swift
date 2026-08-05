import SwiftUI

/// En-tête commun aux schémas : petit libellé et titre.
private struct DiagramHeader: View {
    let icon: String
    let kind: String
    let title: String?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(kind.uppercased())
                    .font(FeyFont.micro)
                    .kerning(0.6)
            }
            .foregroundStyle(accent.opacity(0.85))

            if let title = title?.nilIfBlank {
                Text(InlineMarkup.plainText(title))
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DiagramContainer<Content: View>: View {
    let icon: String
    let kind: String
    let title: String?
    let accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: FeySpacing.md) {
            DiagramHeader(icon: icon, kind: kind, title: title, accent: accent)
            content
        }
        .padding(FeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous)
                .strokeBorder(FeyColor.stroke, lineWidth: 1)
        }
    }
}

// MARK: - Enchaînement

struct FlowBlockView: View {
    let block: FlowBlock
    let accent: Color

    var body: some View {
        DiagramContainer(icon: "arrow.down.right.circle.fill", kind: "Enchaînement", title: block.title, accent: accent) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(block.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: FeySpacing.sm) {
                        VStack(spacing: 0) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(accent, in: Circle())

                            if index < block.steps.count - 1 {
                                Rectangle()
                                    .fill(accent.opacity(0.25))
                                    .frame(width: 2)
                                    .frame(minHeight: 22)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(InlineMarkup.plainText(step.label))
                                .font(FeyFont.bodyEmphasis)
                                .foregroundStyle(FeyColor.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            if let detail = step.detail?.nilIfBlank {
                                Text(InlineMarkup.plainText(detail))
                                    .font(.system(size: 14))
                                    .foregroundStyle(FeyColor.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.bottom, index < block.steps.count - 1 ? FeySpacing.md : 0)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

// MARK: - Cycle

struct CycleBlockView: View {
    let block: CycleBlock
    let accent: Color

    var body: some View {
        DiagramContainer(icon: "arrow.triangle.2.circlepath", kind: "Cycle", title: block.title, accent: accent) {
            VStack(spacing: FeySpacing.xs) {
                ForEach(Array(block.steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: FeySpacing.xs) {
                        HStack(alignment: .top, spacing: FeySpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(accent.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(InlineMarkup.plainText(step.label))
                                    .font(FeyFont.bodyEmphasis)
                                    .foregroundStyle(FeyColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let detail = step.detail?.nilIfBlank {
                                    Text(InlineMarkup.plainText(detail))
                                        .font(.system(size: 14))
                                        .foregroundStyle(FeyColor.inkSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(FeySpacing.sm)
                        .background(FeyColor.canvas, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))

                        Image(systemName: index == block.steps.count - 1 ? "arrow.counterclockwise" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(accent.opacity(0.6))
                    }
                }

                Text("Le cycle recommence")
                    .font(FeyFont.micro)
                    .foregroundStyle(FeyColor.inkTertiary)
            }
        }
    }
}

// MARK: - Arborescence

struct TreeBlockView: View {
    let block: TreeBlock
    let accent: Color

    var body: some View {
        DiagramContainer(icon: "point.topleft.down.curvedto.point.bottomright.up", kind: "Schéma", title: block.title, accent: accent) {
            VStack(alignment: .leading, spacing: FeySpacing.xs) {
                TreeNodeView(node: block.root, depth: 0, accent: accent, isLast: true)
            }
        }
    }
}

private struct TreeNodeView: View {
    let node: TreeNode
    let depth: Int
    let accent: Color
    let isLast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FeySpacing.xs) {
            HStack(alignment: .top, spacing: FeySpacing.xs) {
                if depth > 0 {
                    Rectangle()
                        .fill(accent.opacity(0.25))
                        .frame(width: 12, height: 1)
                        .padding(.top, 12)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(InlineMarkup.plainText(node.label))
                        .font(depth == 0 ? FeyFont.cardTitle : FeyFont.bodyEmphasis)
                        .foregroundStyle(depth == 0 ? .white : FeyColor.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = node.detail?.nilIfBlank {
                        Text(InlineMarkup.plainText(detail))
                            .font(.system(size: 13))
                            .foregroundStyle(depth == 0 ? Color.white.opacity(0.85) : FeyColor.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 7)
                .padding(.horizontal, FeySpacing.sm)
                .background(nodeBackground, in: RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous)
                        .strokeBorder(depth == 0 ? Color.clear : accent.opacity(0.16), lineWidth: 1)
                }
            }

            if let children = node.children, !children.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(accent.opacity(0.22))
                        .frame(width: 1)
                        .padding(.leading, depth == 0 ? 16 : 22)

                    VStack(alignment: .leading, spacing: FeySpacing.xs) {
                        ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                            TreeNodeView(
                                node: child,
                                depth: depth + 1,
                                accent: accent,
                                isLast: index == children.count - 1
                            )
                        }
                    }
                }
            }
        }
    }

    private var nodeBackground: Color {
        switch depth {
        case 0: accent
        case 1: accent.opacity(0.10)
        default: FeyColor.canvas
        }
    }
}

// MARK: - Comparaison

struct ComparisonBlockView: View {
    let block: ComparisonBlock
    let accent: Color

    private var columnTints: [Color] {
        [accent, FeyColor.amber, FeyColor.mint, FeyColor.sky]
    }

    var body: some View {
        DiagramContainer(icon: "rectangle.split.2x1.fill", kind: "Comparaison", title: block.title, accent: accent) {
            HStack(alignment: .top, spacing: FeySpacing.xs) {
                ForEach(Array(block.columns.enumerated()), id: \.offset) { index, column in
                    let tint = columnTints[index % columnTints.count]

                    VStack(alignment: .leading, spacing: FeySpacing.xs) {
                        Text(InlineMarkup.plainText(column.title))
                            .font(FeyFont.caption)
                            .foregroundStyle(tint)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 2)

                        ForEach(Array(column.items.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(tint.opacity(0.5))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)
                                Text(InlineMarkup.plainText(item))
                                    .font(.system(size: 14))
                                    .foregroundStyle(FeyColor.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(FeySpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
                }
            }
        }
    }
}

// MARK: - Frise

struct TimelineBlockView: View {
    let block: TimelineBlock
    let accent: Color

    var body: some View {
        DiagramContainer(icon: "calendar", kind: "Frise", title: block.title, accent: accent) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(block.events.enumerated()), id: \.offset) { index, event in
                    HStack(alignment: .top, spacing: FeySpacing.sm) {
                        Text(event.date)
                            .font(FeyFont.micro)
                            .foregroundStyle(accent)
                            .frame(width: 54, alignment: .trailing)
                            .padding(.top, 3)

                        VStack(spacing: 0) {
                            Circle()
                                .fill(accent)
                                .frame(width: 9, height: 9)
                                .padding(.top, 4)
                            if index < block.events.count - 1 {
                                Rectangle()
                                    .fill(accent.opacity(0.22))
                                    .frame(width: 2)
                                    .frame(minHeight: 26)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(InlineMarkup.plainText(event.label))
                                .font(FeyFont.bodyEmphasis)
                                .foregroundStyle(FeyColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if let detail = event.detail?.nilIfBlank {
                                Text(InlineMarkup.plainText(detail))
                                    .font(.system(size: 14))
                                    .foregroundStyle(FeyColor.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.bottom, index < block.events.count - 1 ? FeySpacing.md : 0)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

// MARK: - Graphique

struct ChartBlockView: View {
    let block: ChartBlock
    let accent: Color

    @State private var appeared = false

    private var maxValue: Double {
        max(block.bars.map(\.value).max() ?? 1, 0.0001)
    }

    var body: some View {
        DiagramContainer(icon: "chart.bar.fill", kind: "Graphique", title: block.title, accent: accent) {
            VStack(alignment: .leading, spacing: FeySpacing.sm) {
                ForEach(Array(block.bars.enumerated()), id: \.offset) { index, bar in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(InlineMarkup.plainText(bar.label))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(FeyColor.inkSecondary)
                            Spacer(minLength: FeySpacing.xs)
                            Text(formatted(bar))
                                .font(FeyFont.micro)
                                .foregroundStyle(FeyColor.ink)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(FeyColor.surfaceSunken)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [accent.opacity(0.75), accent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: appeared ? proxy.size.width * (bar.value / maxValue) : 0)
                                    .animation(
                                        .spring(response: 0.7, dampingFraction: 0.85).delay(Double(index) * 0.05),
                                        value: appeared
                                    )
                            }
                        }
                        .frame(height: 10)
                    }
                }

                if let caption = block.caption?.nilIfBlank {
                    Text(caption)
                        .font(FeyFont.caption)
                        .foregroundStyle(FeyColor.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
        .onAppear { appeared = true }
    }

    private func formatted(_ bar: ChartBar) -> String {
        let value = bar.value == bar.value.rounded()
            ? String(Int(bar.value))
            : String(format: "%.1f", bar.value)
        return value + (bar.unit.map { " \($0)" } ?? "")
    }
}
