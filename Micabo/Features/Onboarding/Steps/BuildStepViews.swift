import Combine
import SwiftUI

// MARK: - Mika prépare le profil

/// **Le profil se prépare, et Mika se présente.** Le blob, « Salut, je suis Mika », ce qu'il
/// fait, le pourcentage, la grille de points, l'étape. Purement visuel — les réponses sont
/// déjà enregistrées — mais il ne doit jamais laisser croire que l'app a gelé.
///
/// **Il dure six secondes et demie**, et c'est un plancher, pas une approximation. Un écran
/// qui annonce qu'il prépare un profil puis disparaît en une seconde n'a rien préparé.
/// L'avancement n'est pas linéaire : il ralentit un peu à trois reprises, comme un travail
/// qui bute, sans les paliers francs de l'ancien écran qui se lisaient comme un script.
///
/// **La fin enchaîne d'elle-même.** À cent pour cent, un coup net, le blob rapetisse, et la
/// page suivante arrive : c'est Mika qui prend la parole, et personne n'attend un bouton
/// pour le laisser parler.
struct BuildingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Durée du chargement, en secondes. Verrouillée par un test.
    static let duration = 6.5
    /// Ce qu'on laisse lire « 100 % » avant d'enchaîner.
    private static let holdAtEnd = 0.7

    @State private var elapsed = 0.0
    @State private var didFinish = false
    @State private var didAdvance = false
    /// **Le compteur ne part qu'une fois la page posée.** Lancé à la construction de la
    /// vue, il tournait déjà pendant le glissement d'arrivée : les chiffres roulaient sur
    /// une page encore en mouvement, et ça se lisait comme un tremblement.
    @State private var hasLanded = false

    private static let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    /// **Le chargement ralentit trois fois, sans jamais s'arrêter.** Une barre parfaitement
    /// linéaire se lit comme une animation, pas comme un travail ; des paliers plats se
    /// lisent comme un script. Entre les deux : des passages lents, et des passages vifs.
    private static let curve: [(at: Double, reached: Double)] = [
        (0.00, 0.00), (0.10, 0.11), (0.20, 0.15), (0.38, 0.44), (0.46, 0.48),
        (0.66, 0.73), (0.74, 0.77), (0.90, 0.94), (1.00, 1.00),
    ]

    private var progress: Double {
        let time = min(1, elapsed / Self.duration)
        var previous = Self.curve[0]
        for point in Self.curve.dropFirst() {
            if time <= point.at {
                let span = point.at - previous.at
                let ratio = span > 0 ? (time - previous.at) / span : 1
                return previous.reached + (point.reached - previous.reached) * ratio
            }
            previous = point
        }
        return 1
    }

    /// Quatre étapes, aux quarts de l'avancement.
    private var stepLabel: String {
        let index = min(3, Int(progress * 4))
        return i18n.t("ios.mika.step\(index + 1)")
    }

    var body: some View {
        MikaLoadingView(
            progress: progress,
            title: i18n.t("ios.mika.hello"),
            subtitle: i18n.t("ios.mika.role"),
            stepLabel: stepLabel,
            isDone: didFinish
        )
        .environment(\.onboardingSurface, .canvas)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingMotion.slideDuration + 0.05) {
                hasLanded = true
            }
        }
        .onReceive(Self.ticker) { _ in tick() }
    }

    private func tick() {
        guard hasLanded, !didAdvance else { return }
        guard elapsed < Self.duration else {
            finishIfNeeded()
            return
        }
        elapsed = min(Self.duration, elapsed + 1.0 / 30.0)
        if elapsed >= Self.duration { finishIfNeeded() }
    }

    private func finishIfNeeded() {
        guard !didFinish else { return }
        didFinish = true
        Haptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdAtEnd) {
            guard !didAdvance else { return }
            didAdvance = true
            model.advance()
        }
    }
}

// MARK: - Mika prend la parole

/// **Une page pour une phrase de Mika.** Le blob, petit, en haut — celui du chargement,
/// qui vient de rapetisser — et la phrase qui se lit mot à mot dessous, avec le rond qui
/// n'arrive qu'une fois le dernier mot posé. Elle sert deux fois : avant les cinq écrans de
/// démonstration, et avant la fiche.
struct MikaSpeaksStepView: View {
    let text: String

    @Environment(OnboardingModel.self) private var model

    @State private var isReady = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                MikaBlob(size: 112, wobble: 0.14)
                    .padding(.bottom, 30)
                    .onboardingAppear(index: 1)

                OnboardingReadingText(
                    template: text,
                    size: 32,
                    wordDelay: 0.2,
                    startDelay: 0.6,
                    highlightsOnFinish: false,
                    onFinish: {
                        withAnimation(.easeOut(duration: 0.4)) { isReady = true }
                    }
                )
                .padding(.horizontal, MicaboSpacing.screen)

                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            OnboardingArrowBar {
                model.advance()
            }
            .opacity(isReady ? 1 : 0)
            .allowsHitTesting(isReady)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}
