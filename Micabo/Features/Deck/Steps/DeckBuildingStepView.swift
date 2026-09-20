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

    /// **Les quatre étapes, cochées au fur et à mesure.**
    ///
    /// L'écran montrait une jauge, une seule ligne de légende qui se remplaçait, et un bloc de
    /// quatre traits violets qui clignotaient en boucle. Trois objets qui disaient tous « ça
    /// travaille » et aucun qui disait **où on en est** : la légende effaçait l'étape
    /// précédente en s'affichant, donc au bout de trente secondes on n'avait vu qu'une phrase
    /// à la fois et on ne savait pas s'il en restait une ou trois.
    ///
    /// La liste garde ce qui est fait. Une coche verte derrière soi, un rond qui tourne
    /// devant, des ronds vides après : l'attente cesse d'être un temps mort pour devenir une
    /// progression qu'on peut lire d'un coup d'œil. Et c'est la même façon de dire un état
    /// que le plan d'un deck — coche pour ce qui est acquis, violet pour ce qui est en cours.
    private var buildingBody: some View {
        VStack(spacing: 26) {
            VStack(spacing: 9) {
                Text(i18n.t("ios.deckBuild.title"))
                    .font(MicaboFont.ui(26, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)

                // Ce qu'on a répondu, rappelé pendant l'attente : c'est ce qui fait que
                // l'écran parle du deck de quelqu'un plutôt que d'un traitement en cours.
                Text(setup.resolvedTitle)
                    .font(MicaboFont.ui(15, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            MicaboOutlineCard(padding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)) {
                VStack(spacing: 0) {
                    ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, item in
                        stepRow(item, isLast: index == Self.steps.count - 1)
                    }
                }
            }

            MicaboSlimProgress(
                percent: Int((stage.progress * 100).rounded()),
                showsLabel: false,
                height: 6
            )
            .animation(.easeInOut(duration: 0.5), value: stage)
        }
    }

    /// Les étapes telles qu'elles se lisent. `done` n'y est pas : « c'est prêt » n'est pas un
    /// travail qu'on attend, c'est la fin de la liste.
    private static let steps: [DeckBuilder.Stage] = [.reading, .writingSheet, .splitting, .writingCards]

    private func stepRow(_ item: DeckBuilder.Stage, isLast: Bool) -> some View {
        let isDone = item.progress < stage.progress
        let isCurrent = item == stage

        return VStack(spacing: 0) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(isDone ? MicaboColor.positiveSoft : (isCurrent ? MicaboColor.accentSoft : MicaboColor.surfaceMuted))

                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(MicaboColor.positive)
                    } else if isCurrent {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.62)
                            .tint(MicaboColor.accent)
                    }
                }
                .frame(width: 28, height: 28)

                Text(i18n.t(item.captionKey))
                    .font(MicaboFont.ui(14.5, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? MicaboColor.ink : MicaboColor.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 11)
            .animation(.easeOut(duration: 0.25), value: stage)

            if !isLast {
                MicaboHairline(inset: 41)
            }
        }
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
