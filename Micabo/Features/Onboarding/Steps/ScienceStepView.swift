import SwiftUI

/// Écran 7 : la méthode, révélée bloc par bloc. Chaque appui découvre le bloc suivant ;
/// le bouton d'avancement n'apparaît qu'une fois les deux blocs à l'écran.
///
/// L'invitation en bas d'écran est un bouton, pas une décoration : elle a l'allure du
/// CTA principal, donc c'est là qu'on appuie en premier. Le second appui termine aussi
/// la lecture en cours du paragraphe, pour que rien ne reste à attendre.
struct ScienceStepView: View {
    @Environment(OnboardingModel.self) private var model

    /// Nombre de blocs découverts. Deux blocs en tout.
    @State private var revealed = 0
    /// Passe la mise en gras du paragraphe à la fin, sans attendre la lecture mot à mot.
    @State private var rushesParagraph = false

    private let blockCount = 2

    private var isComplete: Bool { revealed >= blockCount }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Répétition espacée",
            title: "La courbe de l'oubli, prise à contre-pied.",
            titleSize: 27,
            scrolls: false,
            surface: .ink
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if revealed >= 1 {
                    ForgettingParagraph(isRushed: rushesParagraph)
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
                OnboardingTapPrompt(action: revealNext)
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
        if revealed >= 1 {
            rushesParagraph = true
        }
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.42)) {
            revealed += 1
        }
    }
}

// MARK: - Bloc 1 : le constat d'Ebbinghaus

/// Le texte se met en gras mot après mot, au rythme d'une lecture normale.
/// `isRushed` termine la mise en gras d'un coup : un appui ne doit jamais obliger
/// à attendre la fin d'une animation.
private struct ForgettingParagraph: View {
    var isRushed: Bool = false

    private static let sentence = """
    Dès 1885, Ebbinghaus le mesure : sans y revenir, une leçon s'efface en un jour.
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
        .micaboGroup()
        .onAppear(perform: followReading)
        .onChange(of: isRushed) { _, rushed in
            guard rushed else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                readCount = words.count
            }
        }
    }

    private var paragraph: Text {
        var result = Text("")
        for index in words.indices {
            let isRead = index < readCount
            let isLast = index == words.count - 1
            let piece = isLast ? words[index] : words[index] + " "
            let weight: Font.Weight = isRead ? .bold : .regular
            let color: Color = isRead ? MicaboColor.ink : MicaboColor.inkTertiary

            result = result + Text(piece)
                .font(MicaboFont.hanken(15, weight: weight))
                .foregroundStyle(color)
        }
        return result
    }

    /// Un mot toutes les 75 ms : assez lent pour être suivi des yeux, assez rapide pour
    /// que la phrase entière soit lue en moins de deux secondes.
    private func followReading() {
        for index in words.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(index) * 0.075) {
                guard readCount < index + 1 else { return }
                readCount = index + 1
            }
        }
    }
}

// MARK: - Bloc 2 : les intervalles

/// Échelle verticale des intervalles. Un titre dit ce qu'on regarde, et chaque palier
/// porte son intervalle réel en pastille : la liste se comprend sans la lire en entier.
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
            Text("Voici les intervalles de révision optimaux pour ton cerveau")
                .font(MicaboFont.hanken(14, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            // Intervalle et légende sur une seule ligne : la liste se parcourt d'un
            // coup d'œil, et l'écran tient sans défilement même sur un petit iPhone.
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                HStack(alignment: .top, spacing: 12) {
                    rail(isLast: index == stages.count - 1, isActive: index < shown)

                    HStack(spacing: 9) {
                        Text(stage.interval)
                            .font(MicaboFont.hanken(13, weight: .bold))
                            .foregroundStyle(index < shown ? MicaboColor.accent : MicaboColor.inkTertiary)
                            .monospacedDigit()
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(
                                index < shown ? MicaboColor.accentSoft : MicaboColor.surfaceMuted,
                                in: Capsule()
                            )

                        Text(stage.caption)
                            .font(MicaboFont.hanken(12, weight: .regular))
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, index == stages.count - 1 ? 0 : 10)
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
        .micaboGroup()
        .onAppear(perform: revealStages)
    }

    private func rail(isLast: Bool, isActive: Bool) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(isActive ? MicaboColor.accent : MicaboColor.strokeStrong)
                .frame(width: 8, height: 8)
                .padding(.top, 9)

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
