import SwiftUI

enum ImportKind: String, Identifiable {
    case text
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: "Coller du texte"
        case .pdf: "Importer un PDF"
        }
    }

    var subtitle: String {
        switch self {
        case .text: "Vos propres notes"
        case .pdf: "Cours, polycopié, notes"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "text.alignleft"
        case .pdf: "doc"
        }
    }

    var swatchTint: Color {
        switch self {
        case .text: Color(hex: 0x4F5A72)
        case .pdf: Color(hex: 0x47665A)
        }
    }

    var swatchBackground: Color {
        switch self {
        case .text: Color(hex: 0xE6E9F0)
        case .pdf: Color(hex: 0xE4ECE6)
        }
    }
}

/// Panneau qui remonte du bas quand on touche le bouton « + ».
struct ImportChoiceSheet: View {
    var onSelect: (ImportKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FeySpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nouveau cours")
                    .font(FeyFont.hanken(20, weight: .bold))
                    .foregroundStyle(FeyColor.ink)
                    .tracking(-0.2)
            }
            .padding(.top, 8)

            VStack(spacing: FeySpacing.sm) {
                ForEach([ImportKind.pdf, ImportKind.text]) { kind in
                    Button {
                        onSelect(kind)
                    } label: {
                        optionRow(kind)
                    }
                    .buttonStyle(.plain)
                }

                comingSoonRow
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FeySpacing.screen)
        .padding(.bottom, FeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .feyScreenBackground()
    }

    private func optionRow(_ kind: ImportKind) -> some View {
        HStack(spacing: 14) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(kind.swatchTint)
                .frame(width: 42, height: 42)
                .background(kind.swatchBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(FeyFont.hanken(15, weight: .semibold))
                    .foregroundStyle(FeyColor.ink)
                Text(kind.subtitle)
                    .font(FeyFont.hanken(12, weight: .regular))
                    .foregroundStyle(FeyColor.inkTertiary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0xC9C3B8))
        }
        .feyCard(padding: 16, radius: FeyRadius.button, elevated: false)
        .contentShape(Rectangle())
    }

    private var comingSoonRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(FeyColor.inkTertiary)
                .frame(width: 42, height: 42)
                .background(FeyColor.surfaceSunken, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Depuis la bibliothèque")
                    .font(FeyFont.hanken(15, weight: .semibold))
                    .foregroundStyle(FeyColor.inkSecondary)
                Text("Bientôt disponible")
                    .font(FeyFont.hanken(12, weight: .regular))
                    .foregroundStyle(FeyColor.inkTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(FeyColor.surfaceMuted, in: RoundedRectangle(cornerRadius: FeyRadius.button, style: .continuous))
        .opacity(0.6)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ImportChoiceSheet { _ in }
                .presentationDetents([.height(330)])
        }
}
