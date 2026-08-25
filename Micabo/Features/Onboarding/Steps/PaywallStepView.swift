import SwiftUI

/// La dernière étape du parcours : les deux paywalls, sans accroche contextuelle.
///
/// C'est le seul endroit où l'on n'arrive de nulle part — on ne vient pas de buter sur une
/// porte, on termine une inscription — donc le seul où le premier écran n'a rien à
/// expliquer. La mécanique, elle, est celle de `PaywallFlowView` : la croix du premier
/// paywall ouvre le second, celle du second sort.
///
/// Ici, sortir veut dire entrer dans l'app : c'est la fin du parcours, pas un refus.
struct PaywallStepView: View {
    var onFinish: () -> Void

    var body: some View {
        PaywallFlowView(onDismiss: onFinish, onSubscribed: onFinish)
    }
}
