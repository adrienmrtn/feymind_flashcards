import SwiftUI

/// Le document d'exemple de la démonstration : un chapitre de SVT d'une page.
///
/// Le cycle de l'eau est vu partout, du collège au supérieur, et se dessine en trois
/// temps : c'est reconnaissable d'un coup d'œil, contrairement à un chapitre dense.
/// Rien n'est enregistré, aucune permission n'est demandée, aucun appel réseau n'est
/// fait : les trois écrans se traversent en avion.
enum OnboardingDemo {
    static let courseTitle = "Le cycle de l'eau"
    static let subject = "SVT"
    static let chapter = "Chapitre 4 · L'eau sur Terre"
    static let fileName = "Le cycle de l'eau.pdf"
    static let pageCount = 1

    /// Bleu d'eau : la vignette, la figure et les accents de la démonstration.
    static let accent = Color(hex: 0x3E6C8C)

    struct Card: Identifiable {
        let id = UUID()
        let front: String
        let back: String
    }

    /// Une ligne au recto, une ligne au verso : la démonstration se lit d'un coup d'œil.
    static let cards: [Card] = [
        Card(front: "Que fait le soleil à l'eau des océans ?", back: "Il la fait s'évaporer."),
        Card(front: "Que devient la vapeur en altitude ?", back: "Elle se condense en nuages."),
        Card(front: "Comment l'eau revient-elle au sol ?", back: "En pluie ou en neige.")
    ]

    /// Deux phrases courtes : la page doit rester lisible même en vignette.
    static let pageParagraphs: [String] = [
        "Chauffée par le soleil, l'eau des océans s'évapore et monte dans l'atmosphère.",
        "En altitude elle se condense en nuages, puis retombe en pluie ou en neige."
    ]

    /// Étapes cochées pendant la génération simulée.
    static let generationSteps = [
        "Lecture de la page",
        "Repérage des notions",
        "Rédaction des cartes"
    ]
}

// MARK: - La page

/// Première page du PDF d'exemple. Elle doit ressembler à un vrai document et non à
/// une maquette de traits gris : bandeau de fichier, titre, deux paragraphes et une
/// figure. Tout est dimensionné pour rester lisible en vignette.
struct DemoDocumentPage: View {
    var isScanning: Bool = false
    /// Position du balayage de lecture, de 0 (au-dessus de la page) à 1 (en dessous).
    var sweepProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            fileBar
            page
        }
        .background(MicaboColor.surface)
        .overlay(alignment: .top) { sweep }
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private var fileBar: some View {
        HStack(spacing: 6) {
            Text("PDF")
                .font(MicaboFont.hanken(8, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(MicaboColor.onInk)
                .padding(.vertical, 2)
                .padding(.horizontal, 5)
                .background(Color(hex: 0xB5573C), in: RoundedRectangle(cornerRadius: 3, style: .continuous))

            Text(OnboardingDemo.fileName)
                .font(MicaboFont.hanken(9, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text("\(OnboardingDemo.pageCount) page")
                .font(MicaboFont.hanken(8, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(MicaboColor.surfaceMuted)
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(OnboardingDemo.chapter.uppercased())
                .font(MicaboFont.hanken(6.5, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(MicaboColor.inkTertiary)

            Text(OnboardingDemo.courseTitle)
                .font(MicaboFont.hanken(13, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.2)

            ForEach(Array(OnboardingDemo.pageParagraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(MicaboFont.hanken(7.5, weight: .regular))
                    .foregroundStyle(Color(hex: 0x4A463F))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DemoWaterCycleFigure()
                .padding(.top, 2)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sweep: some View {
        if isScanning {
            GeometryReader { proxy in
                LinearGradient(
                    colors: [
                        MicaboColor.progress.opacity(0),
                        MicaboColor.progress.opacity(0.35),
                        MicaboColor.progress.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 46)
                .offset(y: sweepProgress * (proxy.size.height + 46) - 46)
            }
            .allowsHitTesting(false)
        }
    }
}

/// Figure de la page : les trois temps du cycle, avec la boucle du retour à la mer.
/// C'est ce qui fait qu'on reconnaît un cours de SVT sans lire une ligne.
struct DemoWaterCycleFigure: View {
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                stage(symbol: "sun.max.fill", label: "Évaporation", tint: MicaboColor.caution)
                arrow
                stage(symbol: "cloud.fill", label: "Condensation", tint: MicaboColor.inkSecondary)
                arrow
                stage(symbol: "cloud.rain.fill", label: "Précipitations", tint: OnboardingDemo.accent)
            }

            HStack(spacing: 5) {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 7, weight: .bold))

                Image(systemName: "water.waves")
                    .font(.system(size: 8, weight: .semibold))

                Text("Les rivières ramènent l'eau à la mer")
                    .font(MicaboFont.hanken(7, weight: .medium))
            }
            .foregroundStyle(OnboardingDemo.accent)
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity)
            .background(OnboardingDemo.accent.opacity(0.12), in: Capsule())

            Text("Figure 1 — Le cycle de l'eau en trois temps")
                .font(MicaboFont.hanken(6.5, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            OnboardingDemo.accent.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(MicaboColor.inkTertiary)
    }

    private func stage(symbol: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)

            Text(label)
                .font(MicaboFont.hanken(7, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Les cartes

/// Carte telle qu'elle sort de la page pendant la génération : une seule question,
/// sur une ligne ou deux.
struct DemoMiniCard: View {
    let index: Int
    let question: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CARTE \(index)")
                .font(MicaboFont.hanken(8, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(OnboardingDemo.accent)

            Text(question)
                .font(MicaboFont.hanken(14, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 6)
    }
}
