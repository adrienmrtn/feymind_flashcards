import Combine
import SwiftUI

/// Écran 16 : génération du parcours. Purement visuel — les réponses sont déjà
/// enregistrées — mais il ne doit jamais laisser croire que l'app a gelé.
///
/// C'est le seul écran vert plein cadre du parcours : après une série d'écrans crème,
/// il tranche. Sa mise en page tient en trois bandes qui ne bougent plus une fois posées :
/// l'accroche en haut, l'anneau au centre, les étapes en bas. La version précédente
/// empilait tout en haut de l'écran derrière un ressort, si bien que la hauteur du bloc
/// changeait à chaque phrase et que l'écran tremblait pendant qu'il travaillait.
///
/// **Le chargement dure quatre secondes et demie**, et c'est un plancher, pas une
/// approximation. Un écran qui annonce qu'il construit un parcours puis disparaît en une
/// seconde n'a rien construit : on ne lit ni ce qu'il dit ni ce qu'il coche, et la promesse
/// du parcours personnalisé passe pour du décor. Quatre phases lisibles, un anneau qui fait
/// son tour complet, et on arrive sur la suite en ayant vu le travail se faire.
struct PersonalizingStepView: View {
    @Environment(OnboardingModel.self) private var model

    private let surface = OnboardingStep.personalizing.surface

    private struct Phase {
        let headline: String
        let detail: String
        let step: String
    }

    private let phases: [Phase] = [
        Phase(
            headline: "On lit tes réponses.",
            detail: "Ton objectif, tes matières, ton rythme : tout est déjà là.",
            step: "Lecture de tes réponses"
        ),
        Phase(
            headline: "On calibre tes intervalles.",
            detail: "Les rappels s'ajustent au temps que tu t'accordes chaque jour.",
            step: "Calibrage de la répétition"
        ),
        Phase(
            headline: "On trace ton parcours.",
            detail: "Matière par matière, du premier jour jusqu'à tes examens.",
            step: "Tracé de ton parcours"
        ),
        Phase(
            headline: "On prépare ta première session.",
            detail: "Elle t'attendra dès l'ouverture de l'app.",
            step: "Préparation de ta session"
        )
    ]

    /// Durée du chargement, en secondes. Un plancher, et il est verrouillé par un test :
    /// un écran de génération qui passe en une seconde n'a rien généré aux yeux de
    /// personne.
    static let duration = 4.5

    @State private var elapsed = 0.0
    @State private var completed = 0
    @State private var didFinish = false

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    private var progress: Double {
        min(1, elapsed / Self.duration)
    }

    private var isDone: Bool {
        completed >= phases.count
    }

    private var current: Phase {
        phases[min(completed, phases.count - 1)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
            headline

            Spacer(minLength: 0)

            ring
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            stepList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.lg)
        .padding(.bottom, MicaboSpacing.xl)
        .background(surface.background.ignoresSafeArea(edges: .bottom))
        .environment(\.onboardingSurface, surface)
        .onReceive(ticker) { _ in
            tick()
        }
    }

    // MARK: - Accroche

    /// La hauteur du bloc est réservée d'avance : les quatre accroches n'ont pas le même
    /// nombre de lignes, et un titre qui se recompose à chaque phase fait sauter l'anneau.
    private var headline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERSONNALISATION")
                .font(MicaboFont.eyebrow)
                .tracking(MicaboTracking.caps)
                .foregroundStyle(MicaboColor.onInk.opacity(0.7))

            Text(isDone ? "Ton parcours est prêt." : current.headline)
                .font(MicaboFont.hanken(30, weight: .bold))
                .foregroundStyle(MicaboColor.onInk)
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.28), value: current.headline)

            Text(isDone ? "On y va." : current.detail)
                .font(MicaboFont.hanken(15, weight: .regular))
                .foregroundStyle(MicaboColor.onInk.opacity(0.78))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.28), value: current.detail)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
    }

    // MARK: - Anneau

    /// L'anneau fait son tour en même temps que le parcours se construit, et le
    /// pourcentage compte image par image : deux façons de dire la même chose, parce que
    /// c'est la seule chose que cet écran a à dire.
    ///
    /// Il est plafonné, pas fixé : sur un petit écran, il rend la place à l'accroche et aux
    /// étapes, qui elles doivent rester lisibles en entier.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0.005, progress))
                .stroke(MicaboColor.onInk, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(progress * 100)) %")
                    .font(MicaboFont.hanken(44, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .tracking(-1.4)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(isDone ? "Terminé" : "Micabo travaille")
                    .font(MicaboFont.hanken(12, weight: .medium))
                    .foregroundStyle(MicaboColor.onInk.opacity(0.72))
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 184, maxHeight: 184)
        .accessibilityElement()
        .accessibilityLabel("Génération de ton parcours")
        .accessibilityValue("\(Int(progress * 100)) %")
    }

    // MARK: - Étapes

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                HStack(spacing: 12) {
                    marker(isDone: index < completed, isActive: index == completed)

                    Text(phase.step)
                        .font(MicaboFont.hanken(15, weight: index <= completed ? .medium : .regular))
                        .foregroundStyle(MicaboColor.onInk.opacity(index <= completed ? 1 : 0.5))

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func marker(isDone: Bool, isActive: Bool) -> some View {
        ZStack {
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MicaboColor.accent)
                    .frame(width: 22, height: 22)
                    .background(MicaboColor.onInk, in: Circle())
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            } else if isActive {
                ProgressView()
                    .controlSize(.small)
                    .tint(MicaboColor.onInk)
            } else {
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }
        }
        .frame(width: 22, height: 22)
        .animation(OnboardingMotion.shift, value: isDone)
    }

    // MARK: - Déroulé

    private func tick() {
        guard elapsed < Self.duration else { return }
        elapsed = min(Self.duration, elapsed + 1.0 / 60.0)

        let reached = min(phases.count, Int(progress * Double(phases.count)))
        if reached > completed {
            withAnimation(.easeOut(duration: 0.25)) {
                completed = reached
            }
            Haptics.tick()
        }

        if elapsed >= Self.duration {
            finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        Haptics.success()

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            flow.advance()
        }
    }
}
