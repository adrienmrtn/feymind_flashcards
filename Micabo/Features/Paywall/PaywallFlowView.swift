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
    /// Ce que la boutique n'a pas pu faire. Un bouton qui ne répond rien passe pour cassé.
    @State private var failure: String?

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
        .alert("Oups", isPresented: .constant(failure != nil)) {
            Button("Fermer", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    private func showPlans() {
        guard stage != .plans else { return }
        stage = .plans
    }

    /// **Seul un achat confirmé ouvre l'app.** `unavailable` veut dire « je n'ai pas pu
    /// vendre » — boutique muette, SDK absent, réseau tombé — et l'offrir ferait de chaque
    /// panne un abonnement gratuit.
    ///
    /// Le message le dit, plutôt que de laisser le bouton avoir l'air cassé.
    @MainActor
    private func buy(_ plan: PaywallPlan) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        failure = nil

        let outcome = await PaywallPurchases.buy(plan)
        isPurchasing = false

        switch outcome {
        case .purchased:
            pro?.unlock()
            Haptics.success()
            onSubscribed()
        case .unavailable:
            failure = PaywallPurchases.isReady
                ? "L'achat n'a pas abouti. Réessaie dans un instant."
                : "L'abonnement n'est pas encore ouvert."
        case .cancelled:
            break
        }
    }

    /// La restauration : rien à restaurer se dit, sinon le bouton a l'air inerte.
    @MainActor
    private func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        failure = nil

        let outcome = await PaywallPurchases.restore()
        isPurchasing = false

        guard outcome == .purchased else {
            failure = "Aucun abonnement à restaurer sur ce compte."
            return
        }
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
    /// **Ouvre le paywall en feuille native**, balayable vers le bas.
    ///
    /// C'est une vraie feuille iOS — coin arrondi, poignée, geste de fermeture — plus un
    /// plein écran qui imitait une languette. La croix reste, et elle est immédiate.
    func micaboPaywall(_ trigger: Binding<PaywallTrigger?>, onSubscribed: (() -> Void)? = nil) -> some View {
        sheet(item: trigger) { value in
            PaywallFlowView(
                trigger: value,
                onDismiss: { trigger.wrappedValue = nil },
                onSubscribed: {
                    trigger.wrappedValue = nil
                    onSubscribed?()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MicaboRadius.sheet)
        }
    }
}
