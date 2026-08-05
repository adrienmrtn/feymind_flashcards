import SwiftUI

/// Quatrième page : bibliothèque publique de tous les cours partagés.
/// Vide tant que l'authentification n'est pas branchée.
struct LibraryView: View {
    private let previewSubjects = ["Mathématiques", "SVT", "Histoire", "Physique", "Droit", "Économie"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FeySpacing.lg) {
                    hero
                    subjectsPreview
                    waitlistNote
                }
                .padding(.horizontal, FeySpacing.screen)
                .padding(.top, FeySpacing.xs)
                .padding(.bottom, FeySpacing.xl)
            }
            .feyScreenBackground()
            .navigationTitle("Bibliothèque")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            HStack(spacing: FeySpacing.xs) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Les cours de la communauté")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Bientôt disponible")
                        .font(FeyFont.caption)
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                Spacer(minLength: 0)
            }

            Text("Parcourez les cours partagés par les autres étudiants, importez-les en un geste et récupérez leurs flashcards.")
                .font(FeyFont.body)
                .foregroundStyle(Color.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [FeyColor.accent, FeyColor.accentDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous)
        )
    }

    private var subjectsPreview: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            FeySectionHeader(title: "Explorer par matière", subtitle: "Aperçu de ce qui arrive")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: FeySpacing.sm), GridItem(.flexible(), spacing: FeySpacing.sm)],
                spacing: FeySpacing.sm
            ) {
                ForEach(Array(previewSubjects.enumerated()), id: \.offset) { index, subject in
                    let tint = FeyColor.courseAccents[index % FeyColor.courseAccents.count]

                    HStack(spacing: FeySpacing.xs) {
                        Circle()
                            .fill(tint.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text(subject)
                            .font(FeyFont.caption)
                            .foregroundStyle(FeyColor.inkTertiary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 13)
                    .padding(.horizontal, FeySpacing.sm)
                    .background(FeyColor.surfaceMuted.opacity(0.6), in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
                }
            }
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
        }
    }

    private var waitlistNote: some View {
        VStack(spacing: FeySpacing.sm) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 24))
                .foregroundStyle(FeyColor.accent)

            Text("Connexion requise")
                .font(FeyFont.cardTitle)
                .foregroundStyle(FeyColor.ink)

            Text("La bibliothèque partagée ouvrira avec les comptes Feymind. En attendant, tous vos cours restent sur votre appareil.")
                .font(FeyFont.body)
                .foregroundStyle(FeyColor.inkTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(FeySpacing.lg)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous)
                .strokeBorder(FeyColor.stroke, lineWidth: 1)
        }
    }
}

#Preview {
    LibraryView()
}
