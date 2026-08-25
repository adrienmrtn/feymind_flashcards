import SwiftUI

/// La dernière étape du parcours, et elle tient en **deux paywalls qui s'enchaînent**.
///
/// Le premier ne montre qu'une offre et qu'un prix ; sa croix n'entre pas dans l'app, elle
/// ouvre le second, qui compare ce que Pro ouvre et met les deux offres côte à côte. C'est
/// la croix du second qui entre dans l'app.
///
/// La règle de cet écran : **une croix ne ment jamais.** Elle est présente d'emblée, elle
/// réagit au premier appui, et le second appui sort pour de bon. Un paywall dont la sortie
/// se dérobe se ferme en fermant l'app, ce qui ne fait pas un abonné de plus mais un
/// utilisateur de moins.
///
/// Rien n'est encore branché sur une boutique : `PaywallPurchases` décrit ce qu'il reste à
/// faire, et tant qu'elle répond `unavailable`, l'abonnement laisse entrer dans l'app plutôt
/// que d'enfermer le parcours dans un écran sans issue.
struct PaywallStepView: View {
    var onFinish: () -> Void

    private enum Stage {
        case offer
        case plans
    }

    @State private var stage: Stage = .offer
    @State private var isPurchasing = false

    var body: some View {
        ZStack {
            switch stage {
            case .offer:
                PaywallOfferView(
                    plan: PaywallCatalog.recommended,
                    isPurchasing: isPurchasing,
                    onClose: showPlans,
                    onSeeAllPlans: showPlans,
                    onSubscribe: { Task { await buy(PaywallCatalog.recommended) } },
                    onRestore: { Task { await restore() } }
                )
                .transition(.paywallStage)

            case .plans:
                PaywallPlansView(
                    isPurchasing: isPurchasing,
                    onClose: finish,
                    onSubscribe: { plan in Task { await buy(plan) } },
                    onRestore: { Task { await restore() } }
                )
                .transition(.paywallStage)
            }
        }
        .animation(OnboardingMotion.page, value: stage)
        .micaboScreenBackground()
    }

    private func showPlans() {
        guard stage != .plans else { return }
        stage = .plans
    }

    /// L'achat entre dans l'app **aussi quand la boutique est muette**. Tant qu'aucun
    /// produit n'est publié, `unavailable` est la réponse normale : la traiter comme un
    /// échec laisserait le parcours coincé sur son dernier écran, sans issue et sans
    /// explication.
    @MainActor
    private func buy(_ plan: PaywallPlan) async {
        guard !isPurchasing else { return }
        isPurchasing = true

        let outcome = await PaywallPurchases.buy(plan)
        isPurchasing = false

        switch outcome {
        case .purchased, .unavailable:
            finish()
        case .cancelled:
            break
        }
    }

    @MainActor
    private func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true

        let outcome = await PaywallPurchases.restore()
        isPurchasing = false

        guard outcome == .purchased else { return }
        finish()
    }

    private func finish() {
        Haptics.success()
        onFinish()
    }
}

private extension AnyTransition {
    /// Le passage d'un paywall à l'autre. Un fondu et six points de montée : les deux
    /// écrans partagent leur croix et leur bouton, et les faire glisser latéralement
    /// donnerait l'impression d'avoir changé d'écran alors qu'on a déplié le même.
    static var paywallStage: AnyTransition {
        .opacity.combined(with: .offset(y: 6))
    }
}
