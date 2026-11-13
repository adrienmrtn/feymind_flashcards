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
    /// **Vrai dès que le paywall a été montré.** L'achat fait passer Pro avant que l'élève
    /// ait vu la bienvenue (`PaywallWelcomeScreen`) : si l'écran se démontait à ce moment-là,
    /// la bienvenue sautait et le parcours se terminait d'un coup. Une fois montré, le paywall
    /// reste en place jusqu'à ce qu'il rende la main (`onDismiss`, `onSubscribed`).
    @State private var didShowPaywall = false

    private var isPro: Bool { pro?.isPro ?? false }

    private var showsPaywall: Bool {
        PaywallTestMode.showsOnboardingPaywall(isPro: isPro, forcedByTest: forcedByTest, isInternal: BuildChannel.isInternal)
    }

    /// **L'aperçu** (lot 12) : un compte déjà Pro voit le même paywall, aux vrais prix, mais
    /// l'achat est neutralisé et une mention le dit. Lu une fois, à l'arrivée.
    @State private var previewsPro: Bool?

    /// Le paywall reste monté une fois montré, même si Pro s'ouvre entre-temps.
    private var keepsPaywall: Bool {
        Self.keepsPaywall(shows: showsPaywall, didShow: didShowPaywall)
    }

    /// **Garder le paywall à l'écran** : tant qu'il doit se montrer, et après, une fois montré.
    static func keepsPaywall(shows: Bool, didShow: Bool) -> Bool {
        shows || didShow
    }

    var body: some View {
        Group {
            if keepsPaywall {
                PaywallFlowView(showsFarewell: true, previewsPro: previewsPro ?? isPro, onDismiss: finishOnce, onSubscribed: finishOnce)
                    .onAppear { didShowPaywall = true }
            } else {
                V3Color.bg.ignoresSafeArea()
            }
        }
        .onAppear { if previewsPro == nil { previewsPro = isPro } }
        .onChange(of: showsPaywall, initial: true) { _, shows in
            // Un abonné qui arrive ici n'a rien à acheter : le parcours se termine. Un élève
            // qui vient d'acheter, lui, voit la bienvenue : c'est elle qui termine.
            guard !shows, !didShowPaywall else { return }
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
