import SwiftUI

/// Le faux cours utilisé pendant la démonstration en trois temps.
/// Rien n'est enregistré : ces cartes ne rejoignent pas la base de l'utilisateur.
enum OnboardingDemo {
    static let courseTitle = "La Révolution française"
    static let subject = "Histoire"
    static let pageCount = 12
    static let accent = Color(hex: 0x6B5548)

    struct Card: Identifiable {
        let id = UUID()
        let front: String
        let back: String
    }

    static let cards: [Card] = [
        Card(
            front: "Quel événement ouvre la Révolution française ?",
            back: "La prise de la Bastille, le 14 juillet 1789."
        ),
        Card(
            front: "Que vote l'Assemblée le 26 août 1789 ?",
            back: "La Déclaration des droits de l'homme et du citoyen."
        ),
        Card(
            front: "Quand la Première République est-elle proclamée ?",
            back: "Le 22 septembre 1792, au lendemain de la victoire de Valmy."
        )
    ]

    /// Le contenu de la page affichée pendant la démonstration : du vrai texte de cours,
    /// pour que l'écran ressemble à un document et non à une maquette de traits gris.
    static let pageHeading = "Chapitre 3 · L'année 1789"

    static let pageParagraphs: [String] = [
        """
        Au printemps 1789, la convocation des États généraux réunit à Versailles les représentants \
        des trois ordres. Le tiers état, qui représente plus de 95 % de la population, réclame le \
        vote par tête et non par ordre.
        """,
        """
        Le 17 juin, les députés du tiers état se proclament Assemblée nationale. Trois jours plus \
        tard, réunis dans la salle du Jeu de paume, ils jurent de ne pas se séparer avant d'avoir \
        donné une constitution au royaume.
        """,
        """
        Le 14 juillet, la foule parisienne prend la Bastille, forteresse royale devenue le symbole \
        de l'arbitraire. Dans la nuit du 4 août, l'Assemblée abolit les privilèges ; le 26 août, \
        elle vote la Déclaration des droits de l'homme et du citoyen.
        """
    ]
}

/// Page de document factice, avec un balayage lumineux pendant l'analyse.
struct DemoDocumentPage: View {
    var isScanning: Bool
    var isAnalyzed: Bool
    /// Position du balayage, de 0 (au-dessus de la page) à 1 (en dessous).
    var sweepProgress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("PDF")
                    .font(MicaboFont.hanken(9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(MicaboColor.onInk)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(Color(hex: 0xB5573C), in: RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text("\(OnboardingDemo.courseTitle).pdf")
                    .font(MicaboFont.hanken(11, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("\(OnboardingDemo.pageCount) pages")
                    .font(MicaboFont.hanken(10, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(MicaboColor.surfaceMuted)

            VStack(alignment: .leading, spacing: 9) {
                Text(OnboardingDemo.courseTitle)
                    .font(MicaboFont.hanken(13, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)

                Text(OnboardingDemo.pageHeading)
                    .font(MicaboFont.hanken(9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .padding(.bottom, 2)

                ForEach(Array(OnboardingDemo.pageParagraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(MicaboFont.hanken(8.5, weight: .regular))
                        .foregroundStyle(bodyColor)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.35), value: isScanning)
        }
        .background(MicaboColor.surface)
        .overlay(alignment: .top) {
            if isScanning {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            MicaboColor.accent.opacity(0),
                            MicaboColor.accent.opacity(0.4),
                            MicaboColor.accent.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 54)
                    .offset(y: sweepProgress * (proxy.size.height + 54) - 54)
                }
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.07), radius: 16, x: 0, y: 10)
    }

    /// Le texte s'assombrit pendant la lecture : la page passe de « posée là » à « lue ».
    private var bodyColor: Color {
        isAnalyzed || isScanning ? Color(hex: 0x4A463F) : Color(hex: 0x9A958A)
    }
}
