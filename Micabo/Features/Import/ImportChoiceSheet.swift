import SwiftUI

enum ImportKind: String, CaseIterable, Identifiable {
    case pdf
    case photo
    case youtube
    case docx
    case text
    /// Pas un import : un paquet de cartes, sans document et sans fiche.
    case cards

    var id: String { rawValue }

    /// Vrai pour les quatre sources qui produisent une fiche. `cards` ne passe pas par
    /// l'écran d'import du tout : il n'y a rien à lire, donc rien à analyser.
    var producesSheet: Bool {
        self != .cards
    }

    var title: String {
        switch self {
        case .pdf: "Importer un PDF"
        case .photo: "Scanner ou photos"
        case .youtube: "Vidéo YouTube"
        case .docx: "Document Word"
        case .text: "Coller du texte"
        case .cards: "Créer des cartes"
        }
    }

    var subtitle: String {
        switch self {
        case .pdf: "Cours, polycopié, notes"
        case .photo: "Plusieurs pages, à la suite"
        case .youtube: "Un lien, ses sous-titres"
        case .docx: "Fichier .docx"
        case .text: "Tes notes, telles quelles"
        case .cards: "Un paquet, sans fiche"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: "doc"
        case .photo: "camera.viewfinder"
        case .youtube: "play.rectangle"
        case .docx: "doc.richtext"
        case .text: "text.alignleft"
        case .cards: "rectangle.on.rectangle.angled"
        }
    }

    var emoji: String {
        switch self {
        case .pdf: "📄"
        case .photo: "📸"
        case .youtube: "▶️"
        case .docx: "📝"
        case .text: "✍️"
        case .cards: "🃏"
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
        case .cards: Color(hex: 0xE3F1EA)
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
        case .cards: Color(hex: 0x2F6B57)
        }
    }

    var swatchBackground: Color {
        switch self {
        case .pdf: Color(hex: 0xE4ECE6)
        case .photo: Color(hex: 0xF3E6DC)
        case .youtube: Color(hex: 0xF1E0DD)
        case .docx: Color(hex: 0xE3EAF3)
        case .text: Color(hex: 0xE6E9F0)
        case .cards: Color(hex: 0xDFEEE7)
        }
    }

    var courseSource: CourseSource {
        switch self {
        case .pdf: .pdf
        case .photo: .photo
        case .youtube: .youtube
        case .docx: .docx
        case .text: .text
        case .cards: .deck
        }
    }
}

/// Panneau qui remonte du bas quand on touche le bouton « + ».
///
/// Deux blocs, et la séparation compte : les cinq premières entrées partent d'un document
/// et donnent une fiche, la dernière ne part de rien et ne donne que des cartes. C'est ce
/// qu'on veut quand on révise du vocabulaire, des dates ou des formules qu'on connaît déjà :
/// il n'y a pas de cours à ficher, il y a des choses à retenir.
struct ImportChoiceSheet: View {
    var onSelect: (ImportKind) -> Void
    /// Ouvre la bibliothèque. Absent quand elle n'est pas accessible — sans compte, la
    /// rangée mènerait à un rayon qui retombe sur « Tes cours », ce qui ressemble à une
    /// panne.
    var onLibrary: (() -> Void)?

    private let kinds: [ImportKind] = [.pdf, .photo, .youtube, .docx, .text]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                MicaboScreenHeader(title: "D'où part-on ?")
                    .padding(.top, 24)

                MicaboRowGroup(rows: kinds.map(row(for:)))

                VStack(alignment: .leading, spacing: 8) {
                    MicaboSectionCaption(text: "Sans cours")
                    MicaboRowGroup(rows: [row(for: .cards)])
                }

                if let onLibrary {
                    libraryRow(onLibrary)
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
    }

    private func row(for kind: ImportKind) -> MicaboRow {
        MicaboRow(
            tile: MicaboTile(glyph: .emoji(kind.emoji), background: kind.tilePastel),
            title: kind.title,
            subtitle: kind.subtitle,
            accessory: .chevron
        ) {
            onSelect(kind)
        }
    }

    /// **La bibliothèque n'est plus une promesse.** Elle était grisée avec une pastille
    /// « bientôt » ; le rayon « Découvrir » existe, il rend les cours qu'on a le droit de
    /// lire, et on peut les reprendre. Une option vraie affichée comme une option morte est
    /// une fonctionnalité qu'on a écrite pour personne.
    private func libraryRow(_ action: @escaping () -> Void) -> some View {
        MicaboRow(
            tile: MicaboTile(glyph: .emoji("🌍"), background: MicaboColor.tilePastels[3]),
            title: "Depuis la bibliothèque",
            subtitle: "Les cours de la communauté",
            accessory: .chevron,
            action: action
        )
        .padding(.vertical, 2)
        .micaboGroup()
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ImportChoiceSheet { _ in }
                .presentationDetents([.height(604)])
        }
}
