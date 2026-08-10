import SwiftUI

/// Bibliothèque publique des cours partagés.
/// Vide tant que l'authentification n'est pas branchée.
struct LibraryView: View {
    private let previewSubjects = ["Mathématiques", "SVT", "Histoire", "Physique", "Droit", "Économie"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FeySpacing.lg) {
                    header
                    hero
                    subjectsPreview
                    waitlistNote
                }
                .padding(.horizontal, FeySpacing.screen)
                .padding(.top, FeySpacing.xs)
                .padding(.bottom, FeyLayout.tabBarClearance)
            }
            .feyScreenBackground()
            .feyTabBar()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Bientôt disponible")
                .font(FeyFont.caption)
                .foregroundStyle(FeyColor.inkTertiary)

            Text("Bibliothèque")
                .font(FeyFont.screenTitle)
                .foregroundStyle(FeyColor.ink)
                .tracking(FeyTracking.tight)
        }
        .padding(.top, FeySpacing.xs)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            Image(systemName: "globe.europe.africa")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(FeyColor.onInk)
                .frame(width: 46, height: 46)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: FeyRadius.sm, style: .continuous))

            Text("Les cours de la communauté")
                .font(FeyFont.pageTitle)
                .foregroundStyle(FeyColor.onInk)
                .tracking(FeyTracking.tight)

            Text("Parcourez les paquets partagés par les autres étudiants, importez-les en un geste et récupérez leurs flashcards.")
                .font(FeyFont.body)
                .foregroundStyle(Color.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FeyColor.ink, in: RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous))
        .feySoftShadow(strength: 0.12)
    }

    private var subjectsPreview: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            FeySectionHeader(title: "Explorer par matière", subtitle: "Aperçu de ce qui arrive")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: FeySpacing.sm), GridItem(.flexible(), spacing: FeySpacing.sm)],
                spacing: FeySpacing.sm
            ) {
                ForEach(previewSubjects, id: \.self) { subject in
                    HStack(spacing: FeySpacing.xs) {
                        Circle()
                            .fill(FeyColor.strokeStrong)
                            .frame(width: 7, height: 7)
                        Text(subject)
                            .font(FeyFont.caption)
                            .foregroundStyle(FeyColor.inkTertiary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 15)
                    .padding(.horizontal, FeySpacing.sm)
                    .background(FeyColor.surfaceMuted, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
                }
            }
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
        }
    }

    private var waitlistNote: some View {
        VStack(spacing: FeySpacing.xs) {
            Image(systemName: "lock")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(FeyColor.inkTertiary)
                .frame(width: 56, height: 56)
                .background(FeyColor.surfaceMuted, in: Circle())

            Text("Connexion requise")
                .font(FeyFont.cardTitle)
                .foregroundStyle(FeyColor.ink)
                .padding(.top, FeySpacing.xxs)

            Text("La bibliothèque partagée ouvrira avec les comptes Feymind. En attendant, tous vos cours restent sur votre appareil.")
                .font(FeyFont.body)
                .foregroundStyle(FeyColor.inkTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .feyCard(padding: FeySpacing.lg, radius: FeyRadius.xl, elevated: false)
    }
}

#Preview {
    LibraryView()
}
