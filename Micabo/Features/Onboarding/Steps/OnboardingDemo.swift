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

    /// Largeurs relatives des fausses lignes de texte du document.
    static let pageLines: [CGFloat] = [
        1.0, 0.94, 0.98, 0.62,
        0.96, 1.0, 0.88, 0.97, 0.55,
        0.99, 0.92, 0.7
    ]
}

/// Page de document factice, avec un balayage lumineux pendant l'analyse.
struct DemoDocumentPage: View {
    var isScanning: Bool
    var isAnalyzed: Bool
    var sweepOffset: CGFloat

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
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isAnalyzed || isScanning ? MicaboColor.ink : MicaboColor.surfaceSunken)
                    .frame(width: 132, height: 11)
                    .padding(.bottom, 4)

                ForEach(Array(OnboardingDemo.pageLines.enumerated()), id: \.offset) { index, width in
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(lineColor(index: index))
                            .frame(width: proxy.size.width * width, height: 6)
                    }
                    .frame(height: 6)
                    .animation(
                        .easeOut(duration: 0.25).delay(Double(index) * 0.085),
                        value: isScanning
                    )
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MicaboColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .overlay(alignment: .top) {
            if isScanning {
                LinearGradient(
                    colors: [MicaboColor.accent.opacity(0), MicaboColor.accent.opacity(0.45), MicaboColor.accent.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 46)
                .offset(y: sweepOffset)
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 16, x: 0, y: 10)
    }

    private func lineColor(index: Int) -> Color {
        if isAnalyzed || isScanning {
            return index.isMultiple(of: 4) ? MicaboColor.inkSecondary : Color(hex: 0xC9C3B7)
        }
        return MicaboColor.surfaceSunken
    }
}
