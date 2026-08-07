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
        case .text: "Vos notes, un chapitre, un article"
        case .pdf: "Cours, polycopié, diaporama exporté"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "text.alignleft"
        case .pdf: "doc"
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
                    .font(FeyFont.screenTitle)
                    .foregroundStyle(FeyColor.ink)
                    .tracking(FeyTracking.tight)
                Text("Feymind transforme le contenu en flashcards à réviser.")
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)
            }
            .padding(.top, FeySpacing.md)

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
        HStack(spacing: FeySpacing.sm) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(FeyColor.ink)
                .frame(width: 46, height: 46)
                .background(FeyColor.surfaceMuted, in: RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title)
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.ink)
                Text(kind.subtitle)
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FeyColor.inkTertiary.opacity(0.7))
        }
        .feyCard(padding: FeySpacing.sm + 2, radius: FeyRadius.lg, elevated: false)
        .contentShape(Rectangle())
    }

    private var comingSoonRow: some View {
        HStack(spacing: FeySpacing.sm) {
            Image(systemName: "globe.europe.africa")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(FeyColor.inkTertiary)
                .frame(width: 46, height: 46)
                .background(FeyColor.surfaceMuted, in: RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Depuis la bibliothèque")
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.inkTertiary)
                Text("Disponible avec la connexion")
                    .font(FeyFont.caption)
                    .foregroundStyle(FeyColor.inkTertiary)
            }

            Spacer(minLength: 0)

            FeyChip(text: "Bientôt")
        }
        .padding(FeySpacing.sm + 2)
        .background(FeyColor.surfaceMuted.opacity(0.6), in: RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous))
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ImportChoiceSheet { _ in }
                .presentationDetents([.height(330)])
        }
}
