import SwiftData
import SwiftUI

/// **L'écran qui construit le deck.**
///
/// Il dure. Écrire une fiche sur quarante pages prend une vingtaine de secondes, les cartes
/// autant, et pendant ce temps il n'y a rien à faire. Deux choses rendent cette attente
/// tenable, et aucune des deux n'est décorative :
///
/// - **Chaque étape est nommée pendant qu'elle se fait.** « Micabo lit tes documents », puis
///   « écrit ton cours », puis « découpe les chapitres », puis « prépare tes cartes ». Une
///   jauge seule, sur quarante secondes, se lit comme un plantage ; une jauge qui dit à
///   quoi elle est occupée se lit comme un travail.
/// - **La jauge n'avance pas à vitesse constante.** Les étapes ne durent pas pareil, et une
///   jauge qui saute de 25 % en 25 % s'arrête visiblement pendant vingt secondes. Les poids
///   de `DeckBuilder.Stage` suivent la durée réelle.
///
/// **La tâche n'est pas annulable, et l'écran ne prétend pas qu'elle l'est.** La génération
/// est lancée et payée dès l'arrivée ; une croix qui laisserait croire qu'on peut revenir en
/// arrière sans rien perdre mentirait. C'est pourquoi l'en-tête du parcours retire sa sortie
/// sur cet écran-là.
struct DeckBuildingStepView: View {
    let setup: DeckSetup
    var onCreated: (Course) -> Void
    /// Appelé quand la construction a échoué **avant** d'avoir rien créé : l'étudiant est
    /// renvoyé à l'écran des supports plutôt que laissé sur une jauge morte.
    var onFailed: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var stage: DeckBuilder.Stage = .reading
    @State private var failure: String?
    @State private var didStart = false

    var body: some View {
        VStack(spacing: MicaboSpacing.xl) {
            Spacer(minLength: 0)

            if let failure {
                failureBody(failure)
            } else {
                buildingBody
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, MicaboSpacing.screen)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .task {
            guard !didStart else { return }
            didStart = true
            await build()
        }
    }

    // MARK: - Pendant

    private var buildingBody: some View {
        VStack(spacing: MicaboSpacing.lg) {
            DeckBuildingGlyph()

            VStack(spacing: 8) {
                Text(i18n.t("ios.deckBuild.title"))
                    .font(MicaboFont.ui(24, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)

                Text(i18n.t(stage.captionKey))
                    .font(MicaboFont.ui(15, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .id(stage)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: stage)
            }

            MicaboProgressBar(
                progress: stage.progress,
                tint: MicaboColor.accent,
                track: MicaboColor.stroke
            )
            .frame(height: 6)
            .padding(.horizontal, MicaboSpacing.xl)

            // Ce qu'on a répondu, rappelé pendant l'attente. Ce n'est pas du remplissage :
            // c'est ce qui fait que l'écran parle du deck de quelqu'un plutôt que d'un
            // traitement en cours.
            summary
        }
    }

    private var summary: some View {
        VStack(spacing: 6) {
            Text(setup.resolvedTitle)
                .font(MicaboFont.ui(15, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)

            if let deadline = setup.deadline {
                Text(deadline.formatted(date: .long, time: .omitted))
                    .font(MicaboFont.ui(13, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
        .padding(.top, MicaboSpacing.sm)
    }

    // MARK: - Quand ça rate

    private func failureBody(_ message: String) -> some View {
        VStack(spacing: MicaboSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(MicaboColor.ratingAgain)

            Text(i18n.t("ios.deckBuild.failed"))
                .font(MicaboFont.ui(22, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)

            Text(message)
                .font(MicaboFont.ui(14, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(i18n.t("ios.retry")) {
                    failure = nil
                    Task { await build() }
                }
                .buttonStyle(MicaboPrimaryButtonStyle())

                Button(i18n.t("ios.deckBuild.back")) { onFailed() }
                    .buttonStyle(MicaboSecondaryButtonStyle())
            }
            .padding(.top, MicaboSpacing.xs)
        }
    }

    // MARK: - Le travail

    @MainActor
    private func build() async {
        do {
            let outcome = try await DeckBuilder.build(
                setup,
                using: aiService,
                in: modelContext
            ) { stage in
                self.stage = stage
            }

            // Un temps d'arrêt sur « c'est prêt » avant de passer la main. Sans lui, la
            // dernière étape s'affiche et disparaît dans la même image : on a l'impression
            // que l'écran a sauté, pas qu'il a fini.
            try? await Task.sleep(for: .milliseconds(650))
            onCreated(outcome.course)
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// Trois traits qui se remplissent en boucle : une fiche en train de s'écrire, sans
/// illustration ni mascotte. L'attente n'a pas besoin d'un personnage, elle a besoin de
/// quelque chose qui bouge et qui ressemble à ce qui se fabrique.
private struct DeckBuildingGlyph: View {
    @State private var phase = 0.0

    private static let widths: [CGFloat] = [1, 0.72, 0.88, 0.55]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(Self.widths.enumerated()), id: \.offset) { index, width in
                Capsule()
                    .fill(MicaboColor.accent)
                    .frame(height: 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: width, anchor: .leading)
                    .opacity(opacity(for: index))
            }
        }
        .frame(width: 148)
        .padding(20)
        .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    /// Les lignes s'allument en décalé : c'est ce qui donne le sens de l'écriture, de haut
    /// en bas, plutôt qu'un clignotement d'ensemble.
    private func opacity(for index: Int) -> Double {
        let base = 0.25 + Double(index) * 0.12
        return base + phase * (0.95 - base)
    }
}
