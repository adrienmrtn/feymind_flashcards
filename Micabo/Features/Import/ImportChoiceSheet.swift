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
        VStack(alignment: .leading, spacing: MicaboSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nouveau cours")
                    .font(MicaboFont.hanken(20, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-0.2)
            }
            .padding(.top, 22)

            VStack(spacing: MicaboSpacing.sm) {
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
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, MicaboSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboScreenBackground()
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
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                Text(kind.subtitle)
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: 0xC9C3B8))
        }
        .micaboCard(padding: 16, radius: MicaboRadius.button, elevated: false)
        .contentShape(Rectangle())
    }

    private var comingSoonRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
                .frame(width: 42, height: 42)
                .background(MicaboColor.surfaceSunken, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Depuis la bibliothèque")
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                Text("Bientôt disponible")
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        .opacity(0.6)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ImportChoiceSheet { _ in }
                .presentationDetents([.height(400)])
        }
}
