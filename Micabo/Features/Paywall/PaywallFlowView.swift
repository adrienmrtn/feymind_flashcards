import SwiftUI

/// Ce qui a ouvert le paywall.
///
/// Change **l'accroche du premier écran, et rien d'autre**. Un paywall qui change de
/// mécanique selon la porte qu'on vient de pousser devient cinq paywalls à maintenir, et
/// l'un des cinq finit par ne plus avoir de sortie.
enum PaywallTrigger: String, Identifiable, CaseIterable {
    /// La fiche s'arrête aux sept dixièmes.
    case lockedSheet
    /// Un deuxième cours à importer.
    case secondCourse
    /// L'entraînement libre.
    case practice
    /// La cinquième carte d'une session.
    case sessionLimit

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .lockedSheet: "La fin de ta fiche t'attend"
        case .secondCourse: "Ton deuxième cours t'attend"
        case .practice: "L'entraînement libre est dans Pro"
        case .sessionLimit: "Ta session t'attend"
        }
    }
}

/// **Les deux paywalls, et la mécanique qui les enchaîne.**
///
/// Le premier ne montre qu'une offre et qu'un prix ; sa croix n'annule pas, elle ouvre le
/// second, qui compare ce que Pro ouvre et met les deux offres côte à côte. C'est la croix
/// du second qui referme pour de bon.
///
/// La règle : **une croix ne ment jamais.** Elle est présente d'emblée, elle réagit au
/// premier appui, et le second appui sort. Un paywall dont la sortie se dérobe se ferme en
/// fermant l'app, ce qui ne fait pas un abonné de plus mais un utilisateur de moins.
struct PaywallFlowView: View {
    var trigger: PaywallTrigger?
    var onDismiss: () -> Void
    var onSubscribed: () -> Void

    /// Optionnel à dessein : la vue doit pouvoir se composer dans un aperçu sans que toute
    /// la chaîne d'injection soit montée.
    @Environment(ProAccess.self) private var pro: ProAccess?

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
                    headline: trigger?.headline,
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
                    onClose: onDismiss,
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

    /// L'achat ouvre l'app **aussi quand la boutique est muette**. Tant qu'aucun produit
    /// n'est publié, `unavailable` est la réponse normale : la traiter comme un échec
    /// rendrait le bouton inerte et tout le parcours d'abonnement intestable.
    ///
    /// À retirer le jour où RevenueCat répond : un échec réseau offrirait l'abonnement.
    @MainActor
    private func buy(_ plan: PaywallPlan) async {
        guard !isPurchasing else { return }
        isPurchasing = true

        let outcome = await PaywallPurchases.buy(plan)
        isPurchasing = false

        switch outcome {
        case .purchased, .unavailable:
            pro?.unlock()
            Haptics.success()
            onSubscribed()
        case .cancelled:
            break
        }
    }

    /// La restauration, elle, reste stricte : une restauration qui ouvrirait tout parce que
    /// la boutique ne répond pas serait un contournement d'un seul appui.
    @MainActor
    private func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true

        let outcome = await PaywallPurchases.restore()
        isPurchasing = false

        guard outcome == .purchased else { return }
        pro?.unlock()
        Haptics.success()
        onSubscribed()
    }
}

extension AnyTransition {
    /// Le passage d'un paywall à l'autre. Un fondu et six points de montée : les deux
    /// écrans partagent leur croix et leur bouton, et les faire glisser latéralement
    /// donnerait l'impression d'avoir changé d'écran alors qu'on a déplié le même.
    static var paywallStage: AnyTransition {
        .opacity.combined(with: .offset(y: 6))
    }
}

extension View {
    /// **Ouvre le paywall par-dessus l'écran courant.**
    ///
    /// En plein écran, et pas en feuille : une feuille se balaye vers le bas, et un paywall
    /// qu'on écarte du pouce sans l'avoir lu ne dit rien à personne. La croix reste la seule
    /// sortie, et elle est immédiate.
    func micaboPaywall(_ trigger: Binding<PaywallTrigger?>, onSubscribed: (() -> Void)? = nil) -> some View {
        fullScreenCover(item: trigger) { value in
            PaywallFlowView(
                trigger: value,
                onDismiss: { trigger.wrappedValue = nil },
                onSubscribed: {
                    trigger.wrappedValue = nil
                    onSubscribed?()
                }
            )
        }
    }
}
