import SwiftUI
import UIKit

/// Aiguille chaque bloc vers sa représentation visuelle.
struct CourseBlockView: View {
    let payload: CourseBlockPayload
    let accent: Color
    var overlays: [InlineMarkup.OverlayHighlight] = []
    var onAsk: (String) -> Void
    var onHighlight: ((NSRange, HighlightColor) -> Void)? = nil
    var onClearHighlights: ((NSRange) -> Void)? = nil

    var body: some View {
        switch payload {
        case .heading(let block):
            HeadingBlockView(block: block, accent: accent)
        case .paragraph(let block):
            CourseText(
                source: block.text,
                overlays: overlays,
                onAsk: onAsk,
                onHighlight: onHighlight,
                onClearHighlights: onClearHighlights
            )
        case .list(let block):
            ListBlockView(block: block, accent: accent, onAsk: onAsk)
        case .keyPoints(let block):
            KeyPointsBlockView(block: block, accent: accent, onAsk: onAsk)
        case .callout(let block):
            CalloutBlockView(
                block: block,
                overlays: overlays,
                onAsk: onAsk,
                onHighlight: onHighlight,
                onClearHighlights: onClearHighlights
            )
        case .definition(let block):
            DefinitionBlockView(
                block: block,
                accent: accent,
                overlays: overlays,
                onAsk: onAsk,
                onHighlight: onHighlight,
                onClearHighlights: onClearHighlights
            )
        case .formula(let block):
            FormulaBlockView(block: block, accent: accent)
        case .table(let block):
            TableBlockView(block: block, accent: accent)
        case .quote(let block):
            QuoteBlockView(
                block: block,
                accent: accent,
                overlays: overlays,
                onAsk: onAsk,
                onHighlight: onHighlight,
                onClearHighlights: onClearHighlights
            )
        case .divider:
            DividerBlockView()
        case .flow(let block):
            FlowBlockView(block: block, accent: accent)
        case .cycle(let block):
            CycleBlockView(block: block, accent: accent)
        case .tree(let block):
            TreeBlockView(block: block, accent: accent)
        case .comparison(let block):
            ComparisonBlockView(block: block, accent: accent)
        case .timeline(let block):
            TimelineBlockView(block: block, accent: accent)
        case .chart(let block):
            ChartBlockView(block: block, accent: accent)
        }
    }
}

// MARK: - Titres

struct HeadingBlockView: View {
    let block: HeadingBlock
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if block.level <= 1 {
                Capsule()
                    .fill(accent)
                    .frame(width: 34, height: 4)
            }

            Text(InlineMarkup.plainText(block.text))
                .font(font)
                .foregroundStyle(FeyColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            if block.level == 2 {
                Rectangle()
                    .fill(FeyColor.stroke)
                    .frame(height: 1)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, block.level <= 1 ? FeySpacing.sm : FeySpacing.xs)
    }

    private var font: Font {
        switch block.level {
        case ...1: FeyFont.courseH1
        case 2: FeyFont.courseH2
        default: FeyFont.courseH3
        }
    }
}

// MARK: - Listes

struct ListBlockView: View {
    let block: ListBlock
    let accent: Color
    var onAsk: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            ForEach(Array(block.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: FeySpacing.sm) {
                    marker(for: index)
                    CourseText(source: item, onAsk: onAsk)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func marker(for index: Int) -> some View {
        if block.ordered {
            Text("\(index + 1)")
                .font(FeyFont.micro)
                .foregroundStyle(accent)
                .frame(width: 22, height: 22)
                .background(accent.opacity(0.12), in: Circle())
                .padding(.top, 1)
        } else {
            Circle()
                .fill(accent.opacity(0.55))
                .frame(width: 6, height: 6)
                .padding(.top, 9)
                .frame(width: 22, alignment: .center)
        }
    }
}

// MARK: - Points clés

struct KeyPointsBlockView: View {
    let block: KeyPointsBlock
    let accent: Color
    var onAsk: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(block.title ?? "À retenir")
                    .font(FeyFont.cardTitle)
            }
            .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: FeySpacing.sm) {
                ForEach(Array(block.items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: FeySpacing.xs) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(accent)
                            .padding(.top, 5)
                        CourseText(source: item, onAsk: onAsk)
                    }
                }
            }
        }
        .padding(FeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous)
                .strokeBorder(accent.opacity(0.18), lineWidth: 1)
        }
    }
}

// MARK: - Encadrés

struct CalloutBlockView: View {
    let block: CalloutBlock
    var overlays: [InlineMarkup.OverlayHighlight] = []
    var onAsk: (String) -> Void
    var onHighlight: ((NSRange, HighlightColor) -> Void)? = nil
    var onClearHighlights: ((NSRange) -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(tint)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: block.variant.systemImage)
                        .font(.system(size: 12, weight: .bold))
                    Text(block.title?.nilIfBlank ?? block.variant.label)
                        .font(FeyFont.caption)
                }
                .foregroundStyle(tint)

                CourseText(
                    source: block.text,
                    options: bodyOptions,
                    overlays: overlays,
                    onAsk: onAsk,
                    onHighlight: onHighlight,
                    onClearHighlights: onClearHighlights
                )
            }
            .padding(.vertical, FeySpacing.sm)
            .padding(.horizontal, FeySpacing.md)
        }
        .background(background, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
    }

    private var bodyOptions: InlineMarkup.RenderOptions {
        var options = InlineMarkup.RenderOptions.courseBody
        options.fontSize = 16
        options.lineSpacing = 5
        return options
    }

    private var tint: Color {
        switch block.variant {
        case .info: FeyColor.sky
        case .important: FeyColor.accent
        case .warning: FeyColor.amber
        case .tip: FeyColor.mint
        case .example: FeyColor.accentDeep
        case .memo: FeyColor.accent
        }
    }

    private var background: Color {
        switch block.variant {
        case .info: FeyColor.skySoft
        case .important: FeyColor.accentSoft
        case .warning: FeyColor.amberSoft
        case .tip: FeyColor.mintSoft
        case .example: FeyColor.accentSoft
        case .memo: FeyColor.accentSoft
        }
    }
}

// MARK: - Définitions

struct DefinitionBlockView: View {
    let block: DefinitionBlock
    let accent: Color
    var overlays: [InlineMarkup.OverlayHighlight] = []
    var onAsk: (String) -> Void
    var onHighlight: ((NSRange, HighlightColor) -> Void)? = nil
    var onClearHighlights: ((NSRange) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: FeySpacing.xs) {
                FeyChip(text: "Définition", systemImage: "book.closed.fill", tint: accent)
                Text(InlineMarkup.plainText(block.term))
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.ink)
            }

            CourseText(
                source: block.text,
                overlays: overlays,
                onAsk: onAsk,
                onHighlight: onHighlight,
                onClearHighlights: onClearHighlights
            )
        }
        .feyCard(padding: FeySpacing.md, radius: FeyRadius.lg, elevated: false)
    }
}

// MARK: - Formules

struct FormulaBlockView: View {
    let block: FormulaBlock
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(block.expression)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(FeyColor.ink)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .padding(.vertical, FeySpacing.md)
                .padding(.horizontal, FeySpacing.md)
                .frame(maxWidth: .infinity)
                .background(FeyColor.surfaceMuted, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(accent.opacity(0.5))
                        .frame(width: 3)
                        .padding(.vertical, 10)
                        .padding(.leading, 6)
                }

            if let caption = block.caption?.nilIfBlank {
                Text(caption)
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Citations

struct QuoteBlockView: View {
    let block: QuoteBlock
    let accent: Color
    var overlays: [InlineMarkup.OverlayHighlight] = []
    var onAsk: (String) -> Void
    var onHighlight: ((NSRange, HighlightColor) -> Void)? = nil
    var onClearHighlights: ((NSRange) -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: FeySpacing.sm) {
            Capsule()
                .fill(accent.opacity(0.35))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                CourseText(
                    source: block.text,
                    options: quoteOptions,
                    overlays: overlays,
                    onAsk: onAsk,
                    onHighlight: onHighlight,
                    onClearHighlights: onClearHighlights
                )

                if let author = block.author?.nilIfBlank {
                    Text(author)
                        .font(FeyFont.caption)
                        .foregroundStyle(FeyColor.inkTertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var quoteOptions: InlineMarkup.RenderOptions {
        var options = InlineMarkup.RenderOptions.courseBody
        options.textColor = UIColor(FeyColor.inkSecondary)
        options.fontSize = 17
        return options
    }
}

// MARK: - Séparateur

struct DividerBlockView: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(FeyColor.strokeStrong)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FeySpacing.sm)
    }
}

// MARK: - Tableaux

struct TableBlockView: View {
    let block: TableBlock
    let accent: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                header
                ForEach(Array(block.rows.enumerated()), id: \.offset) { index, values in
                    rowView(values, index: index)
                }
            }
            .background(FeyColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous)
                    .strokeBorder(FeyColor.stroke, lineWidth: 1)
            }
        }
        .scrollClipDisabled()
    }

    private var header: some View {
        HStack(spacing: 0) {
            ForEach(Array(block.headers.enumerated()), id: \.offset) { _, title in
                Text(InlineMarkup.plainText(title))
                    .font(FeyFont.micro)
                    .foregroundStyle(accent)
                    .frame(width: columnWidth, alignment: .leading)
                    .padding(.vertical, 11)
                    .padding(.horizontal, FeySpacing.sm)
            }
        }
        .background(accent.opacity(0.09))
    }

    private func rowView(_ values: [String], index: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text(InlineMarkup.plainText(value))
                    .font(.system(size: 14))
                    .foregroundStyle(FeyColor.inkSecondary)
                    .frame(width: columnWidth, alignment: .leading)
                    .padding(.vertical, 11)
                    .padding(.horizontal, FeySpacing.sm)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(index.isMultiple(of: 2) ? FeyColor.surface : FeyColor.canvas)
        .overlay(alignment: .top) {
            Rectangle().fill(FeyColor.stroke).frame(height: 1)
        }
    }

    private var columnWidth: CGFloat {
        let count = max(1, block.headers.count)
        return count <= 2 ? 168 : 132
    }
}
