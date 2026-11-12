import SwiftUI

/// La dernière étape du parcours : les deux paywalls, sans accroche contextuelle.
///
/// C'est le seul endroit où l'on n'arrive de nulle part — on ne vient pas de buter sur une
/// porte, on termine une inscription — donc le seul où le premier écran n'a rien à
/// expliquer. La mécanique, elle, est celle de `PaywallFlowView` : la croix du premier
/// paywall ouvre le second, celle du second sort.
///
/// Ici, sortir veut dire entrer dans l'app : c'est la fin du parcours, pas un refus.
///
/// **Un abonné ne voit pas l'offre.** Quelqu'un qui réinstalle l'app, ou qui se connecte en
/// route à un compte déjà Pro, refait le parcours : lui proposer l'essai qu'il paie déjà se
/// lisait comme une erreur, ou comme une seconde facture. Pro ouvert, le parcours se termine
/// sans paywall ; et si Pro s'ouvre pendant qu'il est affiché (un droit relu en retard, un
/// achat confirmé après coup), il se termine aussi.
///
/// **Sauf en test** (lot 9) : « Refaire l'onboarding », dans la section Test des réglages de
/// TestFlight, demande le paywall même à un abonné (`PaywallTestMode`). C'est ce qui le
/// rendait invisible au compte du développeur, Pro à vie.
struct PaywallStepView: View {
    var onFinish: () -> Void

    @Environment(ProAccess.self) private var pro: ProAccess?

    /// Une seule fin : l'achat et le passage à Pro qu'il provoque arrivent tous deux ici.
    @State private var didFinish = false
    /// Lu une fois, à l'arrivée : le paywall demandé par le test reste jusqu'à sa croix.
    @State private var forcedByTest = PaywallTestMode.forcesOnboardingPaywall()

    private var isPro: Bool { pro?.isPro ?? false }

    private var showsPaywall: Bool {
        PaywallTestMode.showsOnboardingPaywall(isPro: isPro, forcedByTest: forcedByTest)
    }

    var body: some View {
        Group {
            if showsPaywall {
                PaywallFlowView(onDismiss: finishOnce, onSubscribed: finishOnce)
            } else {
                OnboardingPalette.white.ignoresSafeArea()
            }
        }
        .onChange(of: showsPaywall, initial: true) { _, shows in
            guard !shows else { return }
            finishOnce()
        }
    }

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        // Le test ne vaut que pour ce parcours-ci : le suivant redevient normal.
        PaywallTestMode.setForcesOnboardingPaywall(false)
        onFinish()
    }
}
