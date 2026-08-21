import Combine
import SwiftUI

/// Écran 15 : mise en place du profil. Purement visuel — les réponses sont déjà
/// enregistrées — mais il ne doit jamais laisser croire que l'app a gelé.
///
/// C'est le seul écran indigo plein cadre du parcours : après une série d'écrans crème,
/// il tranche. Trois signaux d'activité tournent en même temps : une barre qui avance en
/// continu, un pourcentage qui compte image par image, et une accroche qui change à
/// chaque étape.
struct PersonalizingStepView: View {
    @Environment(OnboardingModel.self) private var model

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
            headline: "On prépare ta première session.",
            detail: "Elle t'attendra dès l'ouverture de l'app.",
            step: "Préparation de ta session"
        )
    ]

    private let duration = 3.3

    @State private var elapsed = 0.0
    @State private var completed = 0
    @State private var didFinish = false

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    private var progress: Double {
        min(1, elapsed / duration)
    }

    private var isDone: Bool {
        completed >= phases.count
    }

    private var current: Phase {
        phases[min(completed, phases.count - 1)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
            VStack(alignment: .leading, spacing: 10) {
                Text("PERSONNALISATION")
                    .font(MicaboFont.eyebrow)
                    .tracking(MicaboTracking.caps)
                    .foregroundStyle(MicaboColor.onInk.opacity(0.7))

                Text(isDone ? "Ton profil est prêt." : current.headline)
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

            stepList

            Spacer(minLength: 0)

            gauge
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.lg)
        .padding(.bottom, MicaboSpacing.xl)
        .background(MicaboColor.accent.ignoresSafeArea(edges: .bottom))
        .onReceive(ticker) { _ in
            tick()
        }
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
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isDone)
    }

    // MARK: - Jauge

    /// La barre avance à chaque image : c'est elle qui dit que rien n'est figé.
    private var gauge: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))

                    Capsule()
                        .fill(MicaboColor.onInk)
                        .frame(width: max(6, proxy.size.width * progress))
                }
            }
            .frame(height: 8)

            HStack {
                Text(isDone ? "Terminé" : "Micabo travaille…")
                    .font(MicaboFont.hanken(13, weight: .medium))
                    .foregroundStyle(MicaboColor.onInk.opacity(0.75))

                Spacer()

                Text("\(Int(progress * 100)) %")
                    .font(MicaboFont.hanken(13, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Déroulé

    private func tick() {
        guard elapsed < duration else { return }
        elapsed = min(duration, elapsed + 1.0 / 60.0)

        let reached = min(phases.count, Int(progress * Double(phases.count)))
        if reached > completed {
            withAnimation(.easeOut(duration: 0.25)) {
                completed = reached
            }
            Haptics.tick()
        }

        if elapsed >= duration {
            finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        Haptics.success()

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            flow.advance()
        }
    }
}
