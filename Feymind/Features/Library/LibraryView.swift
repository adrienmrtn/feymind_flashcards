import SwiftUI

/// Bibliothèque publique des cours partagés.
/// Vide tant que l'authentification n'est pas branchée.
struct LibraryView: View {
    private struct SubjectPreview: Identifiable {
        let name: String
        let background: Color
        let swatch: Color
        let tint: Color
        var id: String { name }
    }

    private let previewSubjects: [SubjectPreview] = [
        SubjectPreview(name: "Sciences", background: Color(hex: 0xE4ECE6), swatch: Color(hex: 0xC3D5C8), tint: Color(hex: 0x47665A)),
        SubjectPreview(name: "Histoire", background: Color(hex: 0xEFE6E2), swatch: Color(hex: 0xDCC9BD), tint: Color(hex: 0x6B5548)),
        SubjectPreview(name: "Langues", background: Color(hex: 0xE6E9F0), swatch: Color(hex: 0xC7CEDE), tint: Color(hex: 0x4F5A72)),
        SubjectPreview(name: "Médecine", background: Color(hex: 0xF0E8EC), swatch: Color(hex: 0xDCC7D2), tint: Color(hex: 0x6E5566))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero

                    VStack(alignment: .leading, spacing: 18) {
                        subjectsPreview
                        waitlistNote
                    }
                    .padding(.horizontal, FeySpacing.screen)
                    .padding(.top, 18)
                    .padding(.bottom, FeySpacing.xl)
                }
            }
            .feyScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BIBLIOTHÈQUE")
                .font(FeyFont.hanken(12, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(Color(hex: 0x8F8B82))

            Text("Les cours de la communauté")
                .font(FeyFont.hanken(24, weight: .bold))
                .foregroundStyle(FeyColor.onInk)
                .tracking(-0.2)

            Text("Des milliers de jeux de cartes partagés, prêts à importer.")
                .font(FeyFont.body)
                .foregroundStyle(Color(hex: 0x9A958A))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, FeySpacing.screen)
        .padding(.top, 26)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FeyColor.ink)
    }

    private var subjectsPreview: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            Text("Explorer par matière")
                .font(FeyFont.hanken(14, weight: .semibold))
                .foregroundStyle(FeyColor.ink)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(previewSubjects) { subject in
                    VStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(subject.swatch)
                            .frame(width: 22, height: 22)

                        Spacer(minLength: 0)

                        Text(subject.name)
                            .font(FeyFont.hanken(13, weight: .semibold))
                            .foregroundStyle(subject.tint)
                    }
                    .padding(12)
                    .frame(height: 78, alignment: .topLeading)
                    .frame(maxWidth: .infinity)
                    .background(subject.background, in: RoundedRectangle(cornerRadius: FeyRadius.button, style: .continuous))
                }
            }
            .allowsHitTesting(false)
        }
    }

    private var waitlistNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FeyColor.inkSecondary)
                .frame(width: 34, height: 34)
                .background(Color(hex: 0xE0D9CC), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Connexion requise")
                    .font(FeyFont.hanken(13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x4A463F))
                Text("La bibliothèque n'est pas encore active.")
                    .font(FeyFont.hanken(12, weight: .regular))
                    .foregroundStyle(FeyColor.inkTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            FeyColor.surfaceMuted,
            in: RoundedRectangle(cornerRadius: FeyRadius.button, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.button, style: .continuous)
                .strokeBorder(Color(hex: 0xE8E2D6), lineWidth: 1)
        }
    }
}
