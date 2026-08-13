import SwiftUI

/// Écran 7 : la méthode, révélée bloc par bloc. Chaque appui découvre le bloc suivant ;
/// le bouton d'avancement n'apparaît qu'une fois les deux blocs à l'écran.
struct ScienceStepView: View {
    @Environment(OnboardingModel.self) private var model

    /// Nombre de blocs découverts. Deux blocs en tout.
    @State private var revealed = 0

    private let blockCount = 2

    private var isComplete: Bool { revealed >= blockCount }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Répétition espacée",
            title: "La courbe de l'oubli, prise à contre-pied.",
            titleSize: 27,
            scrolls: false
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if revealed >= 1 {
                    ForgettingParagraph()
                        .transition(blockTransition)
                }

                if revealed >= 2 {
                    IntervalTimeline()
                        .transition(blockTransition)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture(perform: revealNext)
        } footer: {
            if isComplete {
                OnboardingContinueButton {
                    model.advance()
                }
                .transition(.opacity)
            } else {
                OnboardingHint(text: "Appuie pour découvrir la suite")
            }
        }
    }

    private var blockTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 14).combined(with: .opacity),
            removal: .opacity
        )
    }

    private func revealNext() {
        guard revealed < blockCount else { return }
        Haptics.soft()
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.42)) {
            revealed += 1
        }
    }
}

// MARK: - Bloc 1 : le constat d'Ebbinghaus

/// Le texte se met en gras mot après mot, au rythme d'une lecture normale.
private struct ForgettingParagraph: View {
    private static let sentence = """
    Dès 1885, Ebbinghaus mesure l'oubli : sans y revenir, une leçon s'efface presque \
    entièrement en vingt-quatre heures. Micabo repose chaque carte juste avant ce décrochage.
    """

    private let words = ForgettingParagraph.sentence.split(separator: " ").map(String.init)

    @State private var readCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EBBINGHAUS, 1885")
                .font(MicaboFont.hanken(10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(MicaboColor.inkTertiary)

            paragraph
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .onAppear(perform: followReading)
    }

    private var paragraph: Text {
        words.indices.reduce(Text("")) { partial, index in
            let isRead = index < readCount
            return partial + Text(words[index] + (index == words.count - 1 ? "" : " "))
                .font(MicaboFont.hanken(15, weight: isRead ? .bold : .regular))
                .foregroundStyle(isRead ? MicaboColor.ink : MicaboColor.inkTertiary)
        }
    }

    /// Un mot toutes les 110 ms : assez lent pour être suivi, assez court pour ne pas lasser.
    private func followReading() {
        for index in words.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28 + Double(index) * 0.11) {
                readCount = index + 1
            }
        }
    }
}

// MARK: - Bloc 2 : les intervalles

/// Échelle verticale des intervalles : chaque palier a la place d'être lu.
private struct IntervalTimeline: View {
    private struct Stage: Identifiable {
        let id = UUID()
        let interval: String
        let caption: String
    }

    private let stages: [Stage] = [
        Stage(interval: "10 min", caption: "Juste après la découverte"),
        Stage(interval: "1 jour", caption: "Avant la nuit qui efface"),
        Stage(interval: "1 semaine", caption: "La carte tient déjà mieux"),
        Stage(interval: "1 mois", caption: "C'est acquis")
    ]

    @State private var shown = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                HStack(alignment: .top, spacing: 12) {
                    rail(isLast: index == stages.count - 1, isActive: index < shown)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(stage.interval)
                            .font(MicaboFont.hanken(14, weight: .semibold))
                            .foregroundStyle(index < shown ? MicaboColor.ink : MicaboColor.inkTertiary)

                        Text(stage.caption)
                            .font(MicaboFont.hanken(12, weight: .regular))
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, index == stages.count - 1 ? 0 : 14)

                    Spacer(minLength: 0)
                }
                .opacity(index < shown ? 1 : 0.35)
            }

            Text("Intervalles expansifs (Landauer & Bjork, 1978), recalculés carte par carte.")
                .font(MicaboFont.hanken(11, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .onAppear(perform: revealStages)
    }

    private func rail(isLast: Bool, isActive: Bool) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(isActive ? MicaboColor.ink : MicaboColor.strokeStrong)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            if !isLast {
                Rectangle()
                    .fill(isActive ? MicaboColor.strokeStrong : MicaboColor.stroke)
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 3)
            }
        }
        .frame(width: 8)
    }

    private func revealStages() {
        for index in stages.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(index) * 0.14) {
                withAnimation(.easeOut(duration: 0.28)) {
                    shown = index + 1
                }
                Haptics.tick()
            }
        }
    }
}
