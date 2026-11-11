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
/// **La fin attend qu'on la touche.** À cent pour cent, un coup net, le blob rapetisse, et
/// le rond arrive. Enchaînée d'elle-même, la page suivante tombait sous un doigt qui
/// s'impatientait, et passait avant d'avoir été lue.
struct BuildingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Durée du chargement, en secondes. Verrouillée par un test.
    static let duration = 6.5
    /// Ce qu'on laisse lire « 100 % » avant que le rond n'arrive.
    private static let holdAtEnd = 0.5

    @State private var elapsed = 0.0
    @State private var didFinish = false
    @State private var didAdvance = false
    @State private var showsAction = false
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
        VStack(spacing: 0) {
            MikaLoadingView(
                progress: progress,
                // Mika s'est présenté à la question du prénom : ici, il remercie et se met
                // au travail.
                title: model.displayName.nilIfBlank.map { i18n.t("ios.onb5.building.title", ["name": $0]) }
                    ?? i18n.t("ios.mika.hello"),
                subtitle: i18n.t("ios.onb5.building.sub"),
                stepLabel: stepLabel,
                isDone: didFinish
            )

            OnboardingArrowBar {
                guard !didAdvance else { return }
                // Posé seulement si l'appui est pris : posé avant, un appui refusé (une page
                // qui glissait encore) laissait le rond mort pour de bon.
                didAdvance = model.advance()
            }
            .opacity(showsAction ? 1 : 0)
            .allowsHitTesting(showsAction)
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
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
            withAnimation(MicaboMotion.standard) { showsAction = true }
        }
    }
}
