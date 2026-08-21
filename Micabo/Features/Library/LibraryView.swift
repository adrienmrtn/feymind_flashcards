import SwiftUI

/// Disponibilité de la bibliothèque partagée. Elle attend l'authentification : tant
/// que ce drapeau est faux, le sous-onglet « Découvrir » de l'onglet Cours n'existe
/// pas — un onglet qui ne mène à rien est un appui perdu.
enum LibraryAccess {
    static let isAvailable = false
}

/// Bibliothèque publique des cours partagés, affichée en sous-onglet de Cours.
/// Le contenu est un aperçu : rien n'est cliquable tant que la bibliothèque dort.
struct LibraryView: View {
    private struct SubjectPreview: Identifiable {
        let name: String
        let emoji: String
        let background: Color
        var id: String { name }
    }

    private let previewSubjects: [SubjectPreview] = [
        SubjectPreview(name: "Sciences", emoji: "🧪", background: Color(hex: 0xE7EFE9)),
        SubjectPreview(name: "Histoire", emoji: "🏛️", background: Color(hex: 0xF5ECE3)),
        SubjectPreview(name: "Langues", emoji: "🗣️", background: Color(hex: 0xE8EDF3)),
        SubjectPreview(name: "Médecine", emoji: "🩺", background: Color(hex: 0xF3E9EE))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
            Text("Des milliers de jeux de cartes partagés, prêts à reprendre.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            subjectsPreview
            waitlistNote
        }
    }

    private var subjectsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Explorer par matière")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(previewSubjects) { subject in
                    VStack(alignment: .leading, spacing: 12) {
                        MicaboTile(glyph: .emoji(subject.emoji), background: subject.background, size: 40)

                        Text(subject.name)
                            .font(MicaboFont.rowTitle)
                            .foregroundStyle(MicaboColor.ink)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .micaboGroup(radius: MicaboRadius.md)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var waitlistNote: some View {
        MicaboRow(
            tile: MicaboTile(glyph: .emoji("🔒"), background: MicaboColor.surfaceMuted),
            title: "Connexion requise",
            subtitle: "La bibliothèque n'est pas encore ouverte.",
            accessory: .none
        )
        .padding(.vertical, 2)
        .micaboGroup()
    }
}
