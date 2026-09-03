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

    var title: String { title(locale: .resolved()) }

    func title(locale: UiLocale) -> String {
        switch self {
        case .pdf: L10n.t("ios.import.pdf", locale: locale)
        case .photo: L10n.t("ios.import.photo", locale: locale)
        case .youtube: L10n.t("ios.import.youtube", locale: locale)
        case .docx: L10n.t("ios.import.docx", locale: locale)
        case .text: L10n.t("ios.import.text", locale: locale)
        case .cards: L10n.t("ios.import.cards", locale: locale)
        }
    }

    var subtitle: String { subtitle(locale: .resolved()) }

    func subtitle(locale: UiLocale) -> String {
        switch self {
        case .pdf: L10n.t("ios.import.pdfHelp", locale: locale)
        case .photo: L10n.t("ios.import.photoHelp", locale: locale)
        case .youtube: L10n.t("ios.import.youtubeHelp", locale: locale)
        case .docx: L10n.t("ios.import.docxHelp", locale: locale)
        case .text: L10n.t("ios.import.textHelp", locale: locale)
        case .cards: L10n.t("ios.import.cardsHelp", locale: locale)
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
        case .pdf: Color(hex: 0xE8ECF1)
        case .photo: Color(hex: 0xF1F5F9)
        case .youtube: Color(hex: 0xDBEAFE)
        case .docx: Color(hex: 0xE8EDF3)
        case .text: Color(hex: 0xE0E7FF)
        case .cards: Color(hex: 0xE0F2FE)
        }
    }

    /// Le rouge de YouTube n'entre pas dans la palette de Micabo : la tuile porte une
    /// brique désaturée, comme les autres sources portent un vert ou un bleu éteints.
    var swatchTint: Color {
        switch self {
        case .pdf: Color(hex: 0x1E3A8A)
        case .photo: Color(hex: 0x2563EB)
        case .youtube: Color(hex: 0x1D4ED8)
        case .docx: Color(hex: 0x3D5A80)
        case .text: Color(hex: 0x4F46E5)
        case .cards: Color(hex: 0x0369A1)
        }
    }

    var swatchBackground: Color {
        switch self {
        case .pdf: Color(hex: 0xE8ECF1)
        case .photo: Color(hex: 0xF1F5F9)
        case .youtube: Color(hex: 0xDBEAFE)
        case .docx: Color(hex: 0xE3EAF3)
        case .text: Color(hex: 0xE0E7FF)
        case .cards: Color(hex: 0xE0F2FE)
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
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private let kinds: [ImportKind] = [.pdf, .photo, .youtube, .docx, .text]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                MicaboScreenHeader(title: i18n?.t("ios.importWhere") ?? "D'où part-on ?")
                    .padding(.top, 24)

                MicaboRowGroup(rows: kinds.map(row(for:)))

                VStack(alignment: .leading, spacing: 8) {
                    MicaboSectionCaption(text: i18n?.t("ios.withoutCourse") ?? "Sans cours")
                    MicaboRowGroup(rows: [row(for: .cards)])
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

}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ImportChoiceSheet { _ in }
                .presentationDetents([.height(604)])
        }
}
