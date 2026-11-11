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
    /// Depuis les Réglages, sans rien avoir buté : on vient voir le prix.
    case upgrade
    /// Un chapitre qu'on touche dans le plan d'un deck : **la page du deck se voit sans
    /// abonnement**, ses chapitres sont dans Pro.
    case openChapter
    /// Une deuxième question à Mika : la première est offerte, les suivantes sont dans Pro.
    case mika
    /// « Générer mon cours », à la fin des questions d'un deck : la génération est dans Pro.
    case generateCourse
    /// Le deuxième examen blanc : le premier est offert.
    case mockExam
    /// **La leçon lue, à débloquer** : la leçon offerte a servi, Mika vient de lire les
    /// supports déposés sur l'appareil, et l'écriture de la leçon est dans Pro
    /// (`LessonAllowance.sendRoute`, `LockedLessonPreview`).
    case lessonReady
    /// **Réviser à voix haute**, après la séance offerte (`RevisionModeAllowance`, `docs/supports.md`).
    case voiceRecall
    /// **La fiche d'une leçon en PDF** (`RevisionModeAllowance`, `docs/supports.md`).
    case exportSheet

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .lockedSheet: L10n.t("ios.paywallLockedHeadline", locale: .resolved())
        case .secondCourse: L10n.t("app.import.secondCourse.title", locale: .resolved())
        case .practice: L10n.t("ios.paywallPracticeHeadline", locale: .resolved())
        case .sessionLimit: L10n.t("ios.paywallSessionHeadline", locale: .resolved())
        case .upgrade: L10n.t("ios.paywallUpgradeHeadline", locale: .resolved())
        case .openChapter: L10n.t("ios.paywallChapterHeadline", locale: .resolved())
        case .mika: L10n.t("ios.paywallMikaHeadline", locale: .resolved())
        case .generateCourse: L10n.t("ios.paywallGenerateHeadline", locale: .resolved())
        case .mockExam: L10n.t("ios.paywallMockHeadline", locale: .resolved())
        case .lessonReady: L10n.t("ios.conv.paywallLessonReady", locale: .resolved())
        case .voiceRecall: L10n.t("ios.sup.paywall.voice", locale: .resolved())
        case .exportSheet: L10n.t("ios.sup.paywall.export", locale: .resolved())
        }
    }
}

/// **Le paywall, et sa mécanique** : un seul écran (`PaywallScreen`), les deux offres côte à
/// côte, la croix là dès l'ouverture.
///
/// La règle : **une croix ne ment jamais.** Elle est présente d'emblée, elle réagit au
/// premier appui, et elle sort. Un paywall dont la sortie se dérobe se ferme en fermant
/// l'app, ce qui ne fait pas un abonné de plus mais un utilisateur de moins. Refermé sans
/// achat — par la croix ou d'un balayage —, il fait tomber le cadeau du tarif réduit
/// (`DiscountOffer.paywallClosed`, dans `onDisappear`).
struct PaywallFlowView: View {
    var trigger: PaywallTrigger?
    var onDismiss: () -> Void
    var onSubscribed: () -> Void

    /// Optionnel à dessein : la vue doit pouvoir se composer dans un aperçu sans que toute
    /// la chaîne d'injection soit montée.
    @Environment(ProAccess.self) private var pro: ProAccess?

    /// L'élève a coché une autre offre que celle recommandée : la comparaison a eu lieu.
    /// C'est ce que `paywall_plans_seen` compte depuis que les offres sont sur le même écran,
    /// et le `stage` de `paywall_dismissed` (« plans » ou « offre ») le suit.
    @State private var comparedPlans = false
    @State private var isPurchasing = false
    /// Quand le paywall s'est ouvert, et s'il a abouti. Les deux servent la même ligne :
    /// un paywall refermé en deux secondes et un paywall lu pendant une minute ne se
    /// corrigent pas de la même façon, et un paywall qui a vendu ne se compte pas comme
    /// une fermeture.
    @State private var openedAt = Date()
    @State private var didSubscribe = false
    /// La dernière issue d'achat. Un achat en attente de validation n'est pas une fermeture :
    /// le cadeau ne tombe pas derrière lui (`PaywallOutcome.countsAsDismissal`).
    @State private var lastOutcome: PaywallOutcome?
    /// Ce que la boutique n'a pas pu faire. Un bouton qui ne répond rien passe pour cassé.
    @State private var failure: String?
    /// Vrai quand la boutique attend une validation : on le dit, sans parler d'échec.
    @State private var showsPending = false
    /// La dernière réponse de la boutique qu'on a vue. Le cache des prix n'est pas
    /// observable : c'est ce numéro, relu après `refreshPrices()`, qui redessine les deux
    /// écrans quand le prix du pays ou l'essai arrivent après l'ouverture.
    @State private var storeRevision = PaywallStorePrices.revision

    var body: some View {
        // **Les prix du pays, ou l'attente** : tant que la boutique n'a pas répondu, ni l'offre
        // ni les formules ne s'affichent avec les prix écrits en euros (`PaywallPriceGate`).
        PaywallPriceGate(
            productIDs: PaywallCatalog.all.map(\.productID),
            onClose: onDismiss,
            onRevision: { storeRevision = $0 }
        ) {
            PaywallScreen(
                trigger: trigger,
                name: HomeGreeting.firstName(OnboardingPreferences.displayName),
                isPurchasing: isPurchasing,
                storeRevision: storeRevision,
                onClose: onDismiss,
                onSubscribe: { plan in Task { await buy(plan) } },
                onRestore: { Task { await restore() } },
                onSelect: { _ in plansCompared() }
            )
        }
        // Le blanc de la scène sous la barre d'état et sous la poignée de la feuille, le papier
        // de l'app dessous : c'est ce qu'on voit quand on tire la page.
        .background {
            VStack(spacing: 0) {
                MicaboColor.surface.frame(height: 320)
                MicaboColor.canvas
            }
            .ignoresSafeArea()
        }
        .onAppear {
            openedAt = Date()
            Analytics.track(.paywallOpened, [
                "trigger": .text(trigger?.rawValue ?? "inconnu"),
                "price_display": PriceDisplay.current.analyticsValue,
            ])
        }
        // **Un achat confirmé après coup ferme le paywall.** Un achat en attente (une
        // validation parentale, un droit que RevenueCat n'a pas encore vu) s'ouvre plus tard,
        // par le flux du SDK (`ProAccess.observePurchases`) : le paywall encore ouvert se
        // referme alors comme après un achat, au lieu de rester devant quelqu'un d'abonné.
        .onChange(of: pro?.isPro == true) { _, isPro in
            guard isPro, !didSubscribe else { return }
            didSubscribe = true
            onSubscribed()
        }
        // `onDisappear` et non le bouton de fermeture : la feuille se referme aussi d'un
        // balayage, et une sortie qui ne se compte pas fait un entonnoir qui fuit.
        .onDisappear {
            guard !didSubscribe, lastOutcome?.countsAsDismissal != false else { return }
            // Refermé sans achat : le cadeau du tarif réduit tombe (`DiscountOffer`).
            DiscountOffer.paywallClosed(isPro: pro?.isPro ?? false)
            Analytics.track(.paywallDismissed, [
                "trigger": .text(trigger?.rawValue ?? "inconnu"),
                "stage": .text(comparedPlans ? "plans" : "offre"),
                "seconds": .number((Date().timeIntervalSince(openedAt) * 10).rounded() / 10),
                "price_display": PriceDisplay.current.analyticsValue,
            ])
        }
        .alert(L10n.t("app.common.oops", locale: .resolved()), isPresented: .constant(failure != nil)) {
            Button(L10n.t("app.a11y.close", locale: .resolved()), role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
        .alert(L10n.t("ios.paywallPendingTitle", locale: .resolved()), isPresented: $showsPending) {
            Button(L10n.t("ios.ok", locale: .resolved()), role: .cancel) {}
        } message: {
            Text(L10n.t("ios.paywallPending", locale: .resolved()))
        }
    }

    /// La première fois qu'une autre offre est cochée.
    private func plansCompared() {
        guard !comparedPlans else { return }
        comparedPlans = true
        Analytics.track(.paywallPlansSeen, [
            "trigger": .text(trigger?.rawValue ?? "inconnu"),
            "price_display": PriceDisplay.current.analyticsValue,
        ])
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
        // L'essai tel qu'il était promis au moment d'acheter : la boutique peut répondre
        // autrement après coup, et c'est la promesse qu'on mesure.
        let promisedTrial = plan.hasTrial
        Analytics.track(.paywallPurchaseStarted, [
            "trigger": .text(trigger?.rawValue ?? "inconnu"),
            "plan": .text(plan.productID),
            "trial": .flag(promisedTrial),
            "price_display": PriceDisplay.current.analyticsValue,
        ])

        let outcome = await PaywallPurchases.buy(plan)
        isPurchasing = false
        lastOutcome = outcome

        switch outcome {
        case .purchased:
            didSubscribe = true
            Analytics.track(.paywallPurchased, [
                "trigger": .text(trigger?.rawValue ?? "inconnu"),
                "plan": .text(plan.productID),
                "trial": .flag(promisedTrial),
                "price_display": PriceDisplay.current.analyticsValue,
            ])
            if promisedTrial {
                // **Le rappel promis est posé** : la veille de la fin de l'essai, si les
                // notifications sont permises (`TrialEndReminder`).
                Task { await TrialEndReminder.schedule(trialDays: plan.trialDays) }
                Analytics.track(.paywallTrialStarted, [
                    "trigger": .text(trigger?.rawValue ?? "inconnu"),
                    "plan": .text(plan.productID),
                    "price_display": PriceDisplay.current.analyticsValue,
                ])
            }
            pro?.unlock()
            Haptics.success()
            onSubscribed()
        case .unavailable, .failed:
            // Le motif distingue « la boutique a dit non » de « la boutique n'a pas
            // répondu », et le réseau de l'App Store : confondre les trois fait chercher au
            // mauvais endroit. La phrase suit la même cause.
            let reason: String
            if case .failed(let cause) = outcome {
                reason = cause.analyticsReason
            } else {
                reason = PaywallPurchases.isReady ? "refus" : "boutique_fermee"
            }
            Analytics.track(.paywallPurchaseFailed, [
                "plan": .text(plan.productID),
                "reason": .text(reason),
            ])
            failure = outcome.failureMessage
        case .cancelled:
            Analytics.track(.paywallPurchaseCancelled, [
                "plan": .text(plan.productID),
                "price_display": PriceDisplay.current.analyticsValue,
            ])
        case .pending:
            Analytics.track(.paywallPurchasePending, ["plan": .text(plan.productID)])
            showsPending = true
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
            // Une panne (le réseau, la boutique) n'est pas « rien à restaurer ».
            if case .failed(let cause) = outcome {
                failure = cause.message
            } else {
                failure = L10n.t("ios.paywallNoRestore", locale: .resolved())
            }
            return
        }
        didSubscribe = true
        Analytics.track(.paywallRestored)
        pro?.unlock()
        Haptics.success()
        onSubscribed()
    }
}

extension AnyTransition {
    /// Le passage d'un temps d'un paywall à l'autre (le cadeau, puis son offre). Un fondu et
    /// six points de montée : on déplie le même écran, on n'en change pas.
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
            // Les couleurs de l'app, jour ou nuit, comme l'écran d'où l'on vient.
            .presentationBackground(MicaboColor.canvas)
        }
    }
}
