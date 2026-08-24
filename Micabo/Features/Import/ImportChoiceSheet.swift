import SwiftUI

enum ImportKind: String, Identifiable {
    case pdf
    case photo
    case youtube
    case docx
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdf: "Importer un PDF"
        case .photo: "Scanner ou photos"
        case .youtube: "Vidéo YouTube"
        case .docx: "Document Word"
        case .text: "Coller du texte"
        }
    }

    var subtitle: String {
        switch self {
        case .pdf: "Cours, polycopié, notes"
        case .photo: "Plusieurs pages, à la suite"
        case .youtube: "Un lien, ses sous-titres"
        case .docx: "Fichier .docx"
        case .text: "Tes notes, telles quelles"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: "doc"
        case .photo: "camera.viewfinder"
        case .youtube: "play.rectangle"
        case .docx: "doc.richtext"
        case .text: "text.alignleft"
        }
    }

    var emoji: String {
        switch self {
        case .pdf: "📄"
        case .photo: "📸"
        case .youtube: "▶️"
        case .docx: "📝"
        case .text: "✍️"
        }
    }

    /// Pastel de la tuile dans la feuille d'import.
    var tilePastel: Color {
        switch self {
        case .pdf: Color(hex: 0xE7EFE9)
        case .photo: Color(hex: 0xF5ECE3)
        case .youtube: Color(hex: 0xF4E5E2)
        case .docx: Color(hex: 0xE8EDF3)
        case .text: Color(hex: 0xEDEAF7)
        }
    }

    /// Le rouge de YouTube n'entre pas dans la palette de Micabo : la tuile porte une
    /// brique désaturée, comme les autres sources portent un vert ou un bleu éteints.
    var swatchTint: Color {
        switch self {
        case .pdf: Color(hex: 0x47665A)
        case .photo: Color(hex: 0x8A5A3A)
        case .youtube: Color(hex: 0x8C4038)
        case .docx: Color(hex: 0x3D5A80)
        case .text: Color(hex: 0x4F5A72)
        }
    }

    var swatchBackground: Color {
        switch self {
        case .pdf: Color(hex: 0xE4ECE6)
        case .photo: Color(hex: 0xF3E6DC)
        case .youtube: Color(hex: 0xF1E0DD)
        case .docx: Color(hex: 0xE3EAF3)
        case .text: Color(hex: 0xE6E9F0)
        }
    }

    var courseSource: CourseSource {
        switch self {
        case .pdf: .pdf
        case .photo: .photo
        case .youtube: .youtube
        case .docx: .docx
        case .text: .text
        }
    }
}

/// Panneau qui remonte du bas quand on touche le bouton « + ».
struct ImportChoiceSheet: View {
    var onSelect: (ImportKind) -> Void

    private let kinds: [ImportKind] = [.pdf, .photo, .youtube, .docx, .text]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                MicaboScreenHeader(title: "D'où part-on ?", eyebrow: "Nouveau cours")
                    .padding(.top, 24)

                MicaboRowGroup(
                    rows: kinds.map { kind in
                        MicaboRow(
                            tile: MicaboTile(glyph: .emoji(kind.emoji), background: kind.tilePastel),
                            title: kind.title,
                            subtitle: kind.subtitle,
                            accessory: .chevron
                        ) {
                            onSelect(kind)
                        }
                    }
                )

                comingSoonRow
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
    }

    private var comingSoonRow: some View {
        MicaboRow(
            tile: MicaboTile(glyph: .emoji("🌍"), background: MicaboColor.surfaceMuted),
            title: "Depuis la bibliothèque",
            subtitle: "Les cours de la communauté",
            accessory: .badge("bientôt", .neutral)
        )
        .padding(.vertical, 2)
        .micaboGroup()
        .opacity(0.75)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ImportChoiceSheet { _ in }
                .presentationDetents([.height(604)])
        }
}
