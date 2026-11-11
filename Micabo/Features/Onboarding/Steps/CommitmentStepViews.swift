import Combine
import SwiftUI

// MARK: - Mika calcule le parcours

/// **Après la preuve sociale, Mika se met au travail** : il relit les réponses, règle le niveau
/// sur l'année déclarée, cale le rythme du jour. Le même écran que le chargement du début — le
/// blob, le pourcentage, la grille de points —, avec ses propres phrases, et le rond n'arrive
/// qu'à cent pour cent : personne ne doit sauter le moment où son parcours se construit.
struct PlanBuildingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    static let duration = 5.0

    @State private var elapsed = 0.0
    @State private var hasLanded = false
    @State private var didFinish = false
    @State private var showsAction = false

    private static let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    /// Deux ralentissements, comme un vrai calcul qui bute un peu.
    private var progress: Double {
        let time = min(1, elapsed / Self.duration)
        let eased = time < 0.5 ? 2 * time * time : 1 - pow(-2 * time + 2, 2) / 2
        return min(1, eased)
    }

    private var stepLabel: String {
        let index = min(3, Int(progress * 4))
        return i18n.t("ios.plan.step\(index + 1)")
    }

    var body: some View {
        VStack(spacing: 0) {
            MikaLoadingView(
                progress: progress,
                title: i18n.t("ios.plan.title"),
                subtitle: i18n.t("ios.plan.role"),
                stepLabel: stepLabel,
                isDone: didFinish
            )

            OnboardingArrowBar { model.advance() }
                .opacity(showsAction ? 1 : 0)
                .allowsHitTesting(showsAction)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingMotion.slideDuration + 0.05) {
                hasLanded = true
            }
        }
        .onReceive(Self.ticker) { _ in
            guard hasLanded, !didFinish else { return }
            elapsed = min(Self.duration, elapsed + 1.0 / 30.0)
            if elapsed >= Self.duration {
                didFinish = true
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(MicaboMotion.standard) { showsAction = true }
                }
            }
        }
    }
}
