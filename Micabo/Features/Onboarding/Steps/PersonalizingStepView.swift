import Combine
import SwiftUI

/// Génération du parcours. Purement visuel — les réponses sont déjà enregistrées — mais il
/// ne doit jamais laisser croire que l'app a gelé.
///
/// Sa mise en page tient en trois bandes qui ne bougent plus une fois posées : l'accroche en
/// haut, l'anneau au centre, les étapes en bas. La version précédente empilait tout en haut
/// de l'écran derrière un ressort, si bien que la hauteur du bloc changeait à chaque phrase
/// et que l'écran tremblait pendant qu'il travaillait.
///
/// **Le chargement dure cinq secondes**, et c'est un plancher, pas une approximation. Un
/// écran qui annonce qu'il construit un parcours puis disparaît en une seconde n'a rien
/// construit : on ne lit ni ce qu'il dit ni ce qu'il coche, et la promesse du parcours
/// personnalisé passe pour du décor. Quatre phases lisibles, un anneau qui fait son tour
/// complet, et on a vu le travail se faire.
///
/// **La fin ne se saute pas d'elle-même.** L'écran enchaînait tout seul sur le suivant six
/// dixièmes de seconde après le dernier coche : le seul moment du parcours où l'on ait
/// attendu quelque chose se terminait par un écran arraché sous les yeux, sans qu'on ait pu
/// lire « ton parcours est prêt ». C'est maintenant l'étudiant qui appuie. Le bouton occupe
/// sa place depuis le début, en attente, pour que rien ne saute quand il s'active.
///
/// Le fond est passé du vert plein au **vert pastel** : un aplat saturé tenu cinq secondes
/// derrière du texte blanc fatigue, et c'est précisément l'écran où l'on demande de patienter.
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
    static let duration = 5.0

    @State private var elapsed = 0.0
    @State private var completed = 0
    @State private var didRing = false

    /// Statique : recréé à chaque `body`, le publisher s'annulait et l'anneau restait à zéro.
    private static let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

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
        VStack(spacing: 0) {
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

            MicaboBottomBar(background: surface.background) {
                OnboardingContinueButton(
                    title: "Découvrir mon parcours",
                    // Éteint pendant le travail, et pas seulement inerte : un bouton à
                    // l'encre pleine qui avale les appuis pendant cinq secondes se lit
                    // comme un bouton cassé.
                    isEnabled: isDone,
                    isLoading: !isDone,
                    loadingTitle: "Micabo travaille…",
                    isShiny: isDone
                ) {
                    model.advance()
                }
            }
        }
        .background(surface.background.ignoresSafeArea(edges: .bottom))
        .environment(\.onboardingSurface, surface)
        .onReceive(Self.ticker) { _ in
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
                .foregroundStyle(surface.eyebrow)

            Text(isDone ? "Ton parcours est prêt." : current.headline)
                .font(MicaboFont.hanken(30, weight: .bold))
                .foregroundStyle(surface.title)
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.28), value: current.headline)

            Text(isDone ? "Quand tu veux." : current.detail)
                .font(MicaboFont.hanken(15, weight: .regular))
                .foregroundStyle(surface.prose)
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
                .stroke(MicaboColor.accent.opacity(0.16), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0.005, progress))
                .stroke(MicaboColor.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(progress * 100)) %")
                    .font(MicaboFont.number(44))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-1.4)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(isDone ? "Terminé" : "Micabo travaille")
                    .font(MicaboFont.hanken(12, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
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
                        .foregroundStyle(index <= completed ? MicaboColor.ink : MicaboColor.inkTertiary)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func marker(isDone: Bool, isActive: Bool) -> some View {
        ZStack {
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .frame(width: 22, height: 22)
                    .background(MicaboColor.accent, in: Circle())
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            } else if isActive {
                ProgressView()
                    .controlSize(.small)
                    .tint(MicaboColor.accent)
            } else {
                Circle()
                    .strokeBorder(MicaboColor.strokeStrong, lineWidth: 1.5)
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

        // Le seul rôle qui reste à la fin du compte : dire que c'est prêt. L'écran suivant
        // attend un appui.
        if elapsed >= Self.duration, !didRing {
            didRing = true
            Haptics.success()
        }
    }
}
