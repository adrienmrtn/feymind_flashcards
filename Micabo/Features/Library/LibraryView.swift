import SwiftUI

/// Bibliothèque publique des cours partagés.
/// Vide tant que l'authentification n'est pas branchée.
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    header
                    subjectsPreview
                    waitlistNote
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .micaboTabBar()
            .reportsPaging(for: .library, depth: 0)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            MicaboScreenHeader(title: "Bibliothèque", eyebrow: "Communauté")

            Text("Des milliers de jeux de cartes partagés, prêts à importer.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, MicaboSpacing.xs)
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
            subtitle: "La bibliothèque n'est pas encore active.",
            accessory: .none
        )
        .padding(.vertical, 2)
        .micaboGroup()
    }
}
