import SwiftData
import SwiftUI

/// **L'écran qui construit le deck.**
///
/// Il dure. Écrire une fiche sur quarante pages prend une vingtaine de secondes, les cartes
/// autant, et pendant ce temps il n'y a rien à faire. Deux choses rendent cette attente
/// tenable, et aucune des deux n'est décorative :
///
/// - **Chaque étape est nommée pendant qu'elle se fait.** « Micabo lit tes supports », puis
///   « écrit ton cours », puis « découpe les chapitres », puis « prépare tes cartes ». Une
///   jauge seule, sur quarante secondes, se lit comme un plantage ; une jauge qui dit à
///   quoi elle est occupée se lit comme un travail.
/// - **La jauge avance à son propre rythme**, et non au rythme des vraies étapes. Voir
///   `shown`.
///
/// **La tâche n'est pas annulable, et l'écran ne prétend pas qu'elle l'est.** La génération
/// est lancée et payée dès l'arrivée ; une croix qui laisserait croire qu'on peut revenir en
/// arrière sans rien perdre mentirait. C'est pourquoi l'en-tête du parcours masque sa sortie
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

    @State private var failure: String?
    @State private var didStart = false
    /// Le deck construit, en attente que l'étudiant l'ouvre. Voir `build()`.
    @State private var built: Course?
    /// Vrai une fois la jauge arrivée au bout : c'est là que le bouton s'allume.
    @State private var isReady = false

    /// **Ce que la jauge affiche n'est pas ce que le modèle fait, et c'est voulu.**
    ///
    /// Les quatre étapes réelles ne durent pas ce qu'elles annoncent : la lecture des
    /// supports est finie avant que l'écran apparaisse, le découpage est instantané, et les
    /// deux écritures prennent chacune une vingtaine de secondes sans donner de nouvelles.
    /// Suivre les vraies étapes donnait donc une jauge déjà entamée à l'arrivée, une
    /// première ligne déjà cochée, deux lignes cochées d'un coup à la fin, et une barre qui
    /// s'arrêtait avant le bout. Rien de tout ça ne se lit comme un travail qui avance.
    ///
    /// La jauge suit donc **son propre temps** : elle part de zéro, avance vite au début et
    /// de moins en moins — vers quatre-vingt-douze pour cent, qu'elle n'atteint jamais tant
    /// que le deck n'est pas là —, et les quatre lignes se cochent à mesure qu'elle passe
    /// leurs seuils. Quand le deck arrive, elle finit le chemin en une seconde, ligne après
    /// ligne, jusqu'à cent. C'est un mensonge sur le détail et une vérité sur l'essentiel :
    /// tant que rien n'est cassé, ça avance, et ce sera fini quand la barre sera pleine.
    @State private var shown: Double = 0

    /// Le plafond de la jauge tant que le deck n'est pas construit.
    private static let ceiling: Double = 0.92
    /// Les seuils auxquels chaque ligne se coche. Ils suivent la forme de l'asymptote :
    /// les premières lignes tombent vite, la dernière attend le vrai deck.
    private static let thresholds: [Double] = [0.22, 0.5, 0.74, 1.0]
    /// Les étapes telles qu'elles se lisent. `done` n'y est pas : « c'est prêt » n'est pas un
    /// travail qu'on attend, c'est la fin de la liste.
    private static let steps: [DeckBuilder.Stage] = [.reading, .writingSheet, .splitting, .writingCards]

    var body: some View {
        VStack(spacing: 0) {
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

            // **Le bouton attend que ce soit prêt, et c'est l'étudiant qui ouvre.**
            //
            // L'écran passait la main tout seul six dixièmes de seconde après la dernière
            // étape : le seul moment du parcours où l'on ait attendu quelque chose finissait
            // par un écran arraché sous les yeux, sans qu'on ait pu lire « c'est prêt ». Le
            // bouton occupe sa place dès le début, éteint, pour que rien ne saute quand il
            // s'allume.
            if failure == nil {
                MicaboBottomBar(background: MicaboColor.canvas) {
                    OnboardingContinueButton(
                        title: i18n.t("ios.deckBuild.seePlan"),
                        isEnabled: isReady,
                        isLoading: !isReady,
                        loadingTitle: i18n.t("ios.deckBuild.title"),
                        isShiny: isReady
                    ) {
                        if let built { onCreated(built) }
                    }
                }
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .task {
            guard !didStart else { return }
            didStart = true
            await build()
        }
        .task { await creep() }
    }

    // MARK: - Pendant

    /// **Les quatre étapes, cochées au fur et à mesure.**
    ///
    /// La liste garde ce qui est fait. Une coche verte derrière soi, un rond qui tourne
    /// devant, des ronds vides après : l'attente cesse d'être un temps mort pour devenir une
    /// progression qu'on peut lire d'un coup d'œil. Et c'est la même façon de dire un état
    /// que le plan d'un deck — coche pour ce qui est acquis, violet pour ce qui est en cours.
    private var buildingBody: some View {
        VStack(spacing: 26) {
            VStack(spacing: 9) {
                Text(i18n.t(isReady ? "ios.deckBuild.done" : "ios.deckBuild.title"))
                    .font(MicaboFont.ui(26, weight: .bold))
                    .contentTransition(.opacity)
                    .animation(.easeOut(duration: 0.25), value: isReady)
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
                percent: Int((shown * 100).rounded()),
                showsLabel: false,
                height: 6
            )
        }
    }

    /// Une ligne : cochée une fois son seuil passé, en cours entre le seuil précédent et le
    /// sien, vide avant.
    private func stepRow(_ item: DeckBuilder.Stage, isLast: Bool) -> some View {
        let index = Self.steps.firstIndex(of: item) ?? 0
        let threshold = Self.thresholds[index]
        let previous: Double = index == 0 ? 0 : Self.thresholds[index - 1]
        let isDone = shown >= threshold - 0.001
        let isCurrent = !isDone && shown >= previous - 0.001

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
            .animation(.easeOut(duration: 0.25), value: isDone)
            .animation(.easeOut(duration: 0.25), value: isCurrent)

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
                    shown = 0
                    Task {
                        await build()
                    }
                }
                .buttonStyle(MicaboPrimaryButtonStyle())

                Button(i18n.t("ios.deckBuild.back")) { onFailed() }
                    .buttonStyle(MicaboSecondaryButtonStyle())
            }
            .padding(.top, MicaboSpacing.xs)
        }
    }

    // MARK: - Le travail

    /// **L'asymptote.** Toutes les trois dixièmes de seconde, la jauge avance de deux pour
    /// cent de ce qui la sépare du plafond : vite au début, de moins en moins ensuite, sans
    /// jamais l'atteindre. Au bout de dix secondes elle est vers la moitié, au bout de
    /// quarante vers quatre-vingt-cinq. Elle s'arrête d'elle-même quand le deck est là ou
    /// que la construction a raté.
    @MainActor
    private func creep() async {
        while !Task.isCancelled, built == nil, failure == nil {
            let step = (Self.ceiling - shown) * 0.02
            withAnimation(.linear(duration: 0.3)) { shown += max(0.0006, step) }
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    /// **La fin du chemin, ligne après ligne.** Le deck est là : ce qui reste de la jauge se
    /// remplit en une seconde, par paliers qui franchissent un seuil à la fois, pour que
    /// les lignes restantes se cochent l'une après l'autre plutôt que d'un coup.
    @MainActor
    private func finishGauge() async {
        for target in Self.thresholds where target > shown {
            withAnimation(.easeOut(duration: 0.3)) { shown = target }
            try? await Task.sleep(for: .milliseconds(300))
        }
        try? await Task.sleep(for: .milliseconds(120))
        Haptics.success()
        withAnimation(.easeOut(duration: 0.3)) { isReady = true }
    }

    @MainActor
    private func build() async {
        do {
            let outcome = try await DeckBuilder.build(
                setup,
                using: aiService,
                in: modelContext
            )

            built = outcome.course
            await finishGauge()
        } catch {
            failure = error.localizedDescription
        }
    }
}
