import Combine
import SwiftUI

// MARK: - Mika calcule le parcours

/// **Avant la révélation, Mika construit le plan** — et c'est le seul écran qui le dit. Lot 7 :
/// il annonçait « On construit ton parcours … Ton parcours est prêt ! » juste avant « Ton plan
/// est prêt », après un premier chargement qui avait déjà « lu tes réponses » et « construit ton
/// plan ». Mika y parle maintenant comme partout ailleurs, à la première personne, de ce
/// qu'il fait de neuf : répartir les matières, régler le rythme, prévoir les révisions. Le même écran que le chargement du début — le
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
        return i18n.t("ios.onb7.planBuild.step\(index + 1)")
    }

    var body: some View {
        VStack(spacing: 0) {
            MikaLoadingView(
                progress: progress,
                title: i18n.t("ios.onb7.planBuild.title"),
                subtitle: i18n.t("ios.onb7.planBuild.role"),
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
