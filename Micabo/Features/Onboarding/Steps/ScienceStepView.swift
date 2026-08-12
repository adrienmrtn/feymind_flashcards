import SwiftUI

/// Écran 7 : la méthode et les travaux qui la soutiennent. Les sources sont réelles
/// et citées telles quelles, sans arrondir les résultats.
struct ScienceStepView: View {
    @Environment(OnboardingModel.self) private var model

    private struct Proof: Identifiable {
        let id = UUID()
        let headline: String
        let detail: String
        let source: String
    }

    private let proofs: [Proof] = [
        Proof(
            headline: "254 études",
            detail: "Passées en revue, plus de 14 000 participants : espacer ses révisions l'emporte sur le bachotage dans la quasi-totalité des expériences recensées.",
            source: "Cepeda, Pashler, Vul, Wixted & Rohrer — Psychological Bulletin, 2006"
        ),
        Proof(
            headline: "80 % contre 35 %",
            detail: "Une semaine après la leçon, les étudiants qui s'étaient testés en restituaient environ 80 %. Ceux qui s'étaient contentés de relire, environ 35 %.",
            source: "Karpicke & Roediger — Science, 2008"
        ),
        Proof(
            headline: "Note maximale",
            detail: "Sur dix méthodes d'apprentissage passées au crible, seules la pratique de rappel et l'espacement décrochent la mention « utilité élevée ».",
            source: "Dunlosky, Rawson, Marsh, Nathan & Willingham — Psychological Science in the Public Interest, 2013"
        )
    ]

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Répétition espacée",
            title: "La courbe de l'oubli, prise à contre-pied.",
            subtitle: "Ebbinghaus l'a mesurée dès 1885 : sans y revenir, une grande partie d'une leçon s'efface en vingt-quatre heures. Micabo repose chaque carte juste avant ce décrochage, avec des intervalles qui s'allongent à chaque réussite.",
            titleSize: 27
        ) {
            VStack(alignment: .leading, spacing: 18) {
                IntervalLadder()

                VStack(spacing: 10) {
                    ForEach(proofs) { proof in
                        ProofCard(headline: proof.headline, detail: proof.detail, source: proof.source)
                    }
                }
            }
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

/// Échelle des intervalles : 10 min, 1 jour, 3 jours, 1 semaine, 1 mois.
private struct IntervalLadder: View {
    private let steps = ["10 min", "1 jour", "3 jours", "1 sem.", "1 mois"]

    @State private var shown = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    if index > 0 {
                        Rectangle()
                            .fill(index < shown ? MicaboColor.ink : MicaboColor.stroke)
                            .frame(height: 1.5)
                            .frame(maxWidth: .infinity)
                    }

                    Text(step)
                        .font(MicaboFont.hanken(11, weight: .semibold))
                        .foregroundStyle(index < shown ? MicaboColor.onInk : MicaboColor.inkTertiary)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            index < shown ? MicaboColor.ink : MicaboColor.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .scaleEffect(index < shown ? 1 : 0.92)
                }
            }

            Text("Intervalles expansifs (Landauer & Bjork, 1978), calculés carte par carte par l'algorithme SM-2.")
                .font(MicaboFont.hanken(11, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .onAppear(perform: revealSteps)
    }

    private func revealSteps() {
        for index in steps.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(index) * 0.16) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.68)) {
                    shown = index + 1
                }
                Haptics.tick()
            }
        }
    }
}

private struct ProofCard: View {
    let headline: String
    let detail: String
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(headline)
                .font(MicaboFont.hanken(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.3)

            Text(detail)
                .font(MicaboFont.hanken(13, weight: .regular))
                .foregroundStyle(Color(hex: 0x4A463F))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(source)
                .font(MicaboFont.hanken(10, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }
}
