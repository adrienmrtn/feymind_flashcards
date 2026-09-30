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

    /// L'étape en cours, telle que la grille de points la nomme.
    private var stepLabel: String {
        let index = Self.thresholds.firstIndex { shown < $0 - 0.001 } ?? Self.steps.count - 1
        return i18n.t(Self.steps[min(index, Self.steps.count - 1)].captionKey)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let failure {
                VStack(spacing: MicaboSpacing.xl) {
                    Spacer(minLength: 0)
                    failureBody(failure)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, MicaboSpacing.screen)
            } else {
                // **Le même écran que le parcours d'accueil** : le blob, « Mika écrit ton
                // cours », le nom du deck en dégradé, le pourcentage, la grille de points
                // et l'étape en cours. C'est le même travail, il a la même tête.
                MikaLoadingView(
                    progress: shown,
                    title: i18n.t("ios.mika.course.title"),
                    subtitle: setup.resolvedTitle,
                    stepLabel: stepLabel,
                    isDone: isReady
                )
            }

            // **Le bouton attend que ce soit prêt, et c'est l'étudiant qui ouvre.**
            //
            // L'écran passait la main tout seul six dixièmes de seconde après la dernière
            // étape : le seul moment du parcours où l'on ait attendu quelque chose finissait
            // par un écran arraché sous les yeux, sans qu'on ait pu lire « c'est prêt ». Le
            // bouton occupe sa place dès le début, éteint, pour que rien ne saute quand il
            // s'allume.
            if failure == nil {
                MicaboBottomBar(background: OnboardingPalette.white) {
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
        .background(OnboardingPalette.white.ignoresSafeArea())
        .task {
            guard !didStart else { return }
            didStart = true
            await build()
        }
        .task { await creep() }
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
