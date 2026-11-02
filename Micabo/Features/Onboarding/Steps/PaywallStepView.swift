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
struct PaywallStepView: View {
    var onFinish: () -> Void

    @Environment(ProAccess.self) private var pro: ProAccess?

    /// Une seule fin : l'achat et le passage à Pro qu'il provoque arrivent tous deux ici.
    @State private var didFinish = false

    private var isPro: Bool { pro?.isPro ?? false }

    var body: some View {
        Group {
            if isPro {
                OnboardingPalette.white.ignoresSafeArea()
            } else {
                PaywallFlowView(onDismiss: finishOnce, onSubscribed: finishOnce)
            }
        }
        .onChange(of: isPro, initial: true) { _, isPro in
            guard isPro else { return }
            finishOnce()
        }
    }

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        onFinish()
    }
}
