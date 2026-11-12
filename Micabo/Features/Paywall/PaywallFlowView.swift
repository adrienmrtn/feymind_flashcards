import SwiftUI

/// Ce qui a ouvert le paywall.
///
/// Change **l'en-tête de l'écran, et rien d'autre** : l'accroche que dit Mika, et le premier
/// des trois bénéfices. Un paywall qui change de mécanique selon la porte qu'on vient de
/// pousser devient douze paywalls à maintenir, et l'un des douze finit par ne plus avoir de
/// sortie.
enum PaywallTrigger: String, Identifiable, CaseIterable {
    /// La fiche s'arrête aux sept dixièmes.
    case lockedSheet
    /// Un deuxième cours à importer.
    case secondCourse
    /// L'entraînement libre.
    case practice
    /// La cinquième carte d'une session.
    case sessionLimit
    /// Depuis les Réglages ou « Passer en Pro », sans rien avoir buté : on vient voir le
    /// prix. C'est l'en-tête « essai », comme à la fin du parcours d'accueil.
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

    /// La clé de l'accroche. Écrite en toutes lettres : le test des langues relit les
    /// sources, et une clé composée lui échapperait.
    ///
    /// **Lot 11 : chaque accroche dit ce qui vient de se passer et ce que Pro ouvre à cet
    /// endroit précis** (« Ta question offerte est posée. Les suivantes, j'y réponds avec
    /// Pro. »), au lieu d'une promesse générale.
    var hookKey: String {
        switch self {
        case .lockedSheet: "ios.pay11.hook.lockedSheet"
        case .secondCourse: "ios.pay11.hook.secondCourse"
        case .practice: "ios.pay11.hook.practice"
        case .sessionLimit: "ios.pay11.hook.sessionLimit"
        case .upgrade: "ios.pay11.hook.upgrade"
        case .openChapter: "ios.pay11.hook.openChapter"
        case .mika: "ios.pay11.hook.mika"
        case .generateCourse: "ios.pay11.hook.generateCourse"
        case .mockExam: "ios.pay11.hook.mockExam"
        case .lessonReady: "ios.pay11.hook.lessonReady"
        case .voiceRecall: "ios.pay11.hook.voiceRecall"
        case .exportSheet: "ios.pay11.hook.exportSheet"
        }
    }

    /// **L'accroche, dite par Mika** à la première personne : une phrase courte qui dit ce
    /// qu'il fera avec Pro, là où l'élève vient de buter. Telle qu'elle se lit, sans la
    /// marque de son mot-clé (`PaywallCopy.hook`).
    func hook(locale: UiLocale = .resolved()) -> String {
        PaywallCopy.hook(for: self, locale: locale).text
    }

    /// L'accroche, dans la langue de l'app.
    var headline: String { hook() }

    /// **L'en-tête « essai »** : le plan de l'élève et la chronologie de ses jours offerts.
    /// C'est celui de qui n'a buté sur rien — la fin du parcours d'accueil, « Passer en Pro ».
    /// Les autres portes ont l'en-tête « contexte » : l'accroche et trois bénéfices.
    static func showsTrialHeader(_ trigger: PaywallTrigger?) -> Bool {
        trigger == nil || trigger == .upgrade
    }

    /// **La ligne du tableau que cette porte ouvre** : celle sur laquelle l'élève vient de
    /// buter. Elle passe en tête du tableau, surlignée.
    var feature: PaywallFeature {
        switch self {
        case .lockedSheet, .secondCourse, .upgrade, .openChapter, .generateCourse, .lessonReady: .lessons
        case .mika: .mika
        case .mockExam: .exams
        case .practice, .sessionLimit, .voiceRecall: .practice
        case .exportSheet: .pdf
        }
    }
}

/// **Ce que Pro ouvre, ligne à ligne, face au gratuit** — le tableau du paywall.
///
/// La colonne « Gratuit » dit **la vraie limite de l'app**, lue dans son code : une leçon
/// offerte (`LessonAllowance`), une question à Mika (`MikaAllowance.freeQuestions`), une série
/// d'entraînement (`PracticeAllowance`), un examen blanc (`ExamAllowance`), et la fiche PDF
/// réservée à Pro (`RevisionModeAllowance`). La colonne « PRO » coche, sans écrire
/// « illimité » : le serveur garde des plafonds par jour (`MikaAllowance.proMessagesPerDay`,
/// `begin_extra`), et un « illimité » serait faux le jour où on les touche.
enum PaywallFeature: String, CaseIterable, Identifiable {
    case lessons
    case mika
    case exams
    case practice
    case pdf

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .lessons: "ios.pay11.row.lessons"
        case .mika: "ios.pay11.row.mika"
        case .exams: "ios.pay11.row.exams"
        case .practice: "ios.pay11.row.practice"
        case .pdf: "ios.pay11.row.pdf"
        }
    }

    /// Ce que le gratuit en donne : un nombre, ou rien (`nil` : réservé à Pro).
    var freeAllowance: Int? {
        switch self {
        case .lessons: 1
        case .mika: MikaAllowance.freeQuestions
        case .exams: 1
        case .practice: 1
        case .pdf: nil
        }
    }

    /// Le symbole du système qui la représente, sans « .fill » : l'icône se dessine en deux
    /// tons (`PaywallGlyph`).
    var symbol: String {
        switch self {
        case .lessons: "book.pages"
        case .mika: "bubble.left.and.text.bubble.right"
        case .exams: "list.clipboard"
        case .practice: "dumbbell"
        case .pdf: "doc.richtext"
        }
    }

    /// La teinte de son icône : une couleur par idée.
    var tone: Color {
        switch self {
        case .lessons: V3Color.iconBlue
        case .mika: V3Color.iconLilac
        case .exams: V3Color.iconPink
        case .practice: V3Color.iconGreen
        case .pdf: V3Color.iconOrange
        }
    }

    /// **Les lignes d'un paywall**, `count` au plus : celle de la porte d'abord, puis les
    /// autres dans l'ordre du tableau. Sans porte, l'ordre du tableau.
    static func shown(for trigger: PaywallTrigger?, count: Int = 4) -> [PaywallFeature] {
        let lead = trigger.map(\.feature)
        let rest = allCases.filter { $0 != lead }
        return Array(((lead.map { [$0] } ?? []) + rest).prefix(count))
    }
}

/// Par où l'on entre dans l'offre de réduction, hors d'un paywall refermé. Dans les deux cas
/// c'est le même écran : seul ce que les statistiques en retiennent change.
enum DiscountPresentation: String, Identifiable {
    /// **La section Test des réglages** : revoir l'offre à volonté, même abonné. La refermer
    /// ne compte pas pour un refus.
    case gift
    /// **L'offre, à la demande** : la pastille de la Home, la rangée des Réglages.
    case paywall

    var id: String { rawValue }
}

/// **Le paywall et sa mécanique**, de l'ouverture à la sortie, dans une seule présentation.
///
/// Trois temps, et l'écran passe de l'un à l'autre en fondu, sans se refermer :
/// - `paywall` : les deux offres (`PaywallScreen`) ;
/// - `offer` : l'offre de réduction, qui **remplace le paywall à l'instant où on le referme
///   sans acheter** quand elle est due (`DiscountOffer.paywallClosed`) — un seul écran, le
///   tarif réduit et son décompte ;
/// - `welcome` : l'achat a abouti, Mika fête ça, puis l'élève retourne d'où il vient.
///
/// La règle : **une croix ne ment jamais.** Elle est là d'emblée, elle réagit au premier
/// appui, et elle sort — celle du paywall comme celle de l'offre. Refusée, l'offre ne revient
/// pas de la session.
///
/// `onDismiss` est rappelé quand l'élève sort sans acheter ; `onSubscribed` quand il quitte
/// l'écran de bienvenue, Pro ouvert. Aucun des deux ne l'est avant.
struct PaywallFlowView: View {
    var trigger: PaywallTrigger?
    var onDismiss: () -> Void
    var onSubscribed: () -> Void

    enum Stage: Equatable {
        case paywall
        case offer
        case welcome
    }

    /// Ce qui a mené à l'offre : c'est ce que les statistiques en retiennent.
    private enum OfferSource: String {
        /// Un paywall refermé sans achat.
        case paywall
        /// La pastille de la Home ou la rangée des Réglages.
        case direct
        /// La section Test des réglages.
        case test
    }

    /// Optionnel à dessein : la vue doit pouvoir se composer dans un aperçu sans que toute
    /// la chaîne d'injection soit montée.
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage: Stage
    @State private var offerSource: OfferSource
    /// L'élève a coché une autre offre que celle recommandée : la comparaison a eu lieu.
    /// C'est ce que `paywall_plans_seen` compte, et le `stage` de `paywall_dismissed`
    /// (« plans » ou « offre ») le suit.
    @State private var comparedPlans = false
    @State private var isPurchasing = false
    /// Quand l'écran s'est ouvert, et s'il a abouti. Un paywall refermé en deux secondes et
    /// un paywall lu pendant une minute ne se corrigent pas de la même façon, et un paywall
    /// qui a vendu ne se compte pas comme une fermeture.
    @State private var openedAt = Date()
    @State private var didSubscribe = false
    /// La dernière issue d'achat. Un achat en attente de validation n'est pas une fermeture :
    /// l'offre ne tombe pas derrière lui (`PaywallOutcome.countsAsDismissal`).
    @State private var lastOutcome: PaywallOutcome? = nil
    /// Ce que la boutique a répondu, quand ce n'est pas un achat : posé sous le bouton.
    @State private var notice: PaywallNotice? = nil
    /// La dernière réponse de la boutique qu'on a vue. Le cache des prix n'est pas
    /// observable : c'est ce numéro, relu après chaque demande, qui redessine l'écran quand
    /// le prix du pays ou l'essai arrivent après l'ouverture.
    @State private var storeRevision = PaywallStorePrices.revision
    /// Pourquoi les prix ne sont pas venus, une fois les demandes épuisées.
    @State private var priceFailure: String? = nil
    @State private var isLoadingPrices = false
    /// L'instant d'origine de la fenêtre de l'offre : celui de son premier affichage.
    @State private var startedAt: Date? = nil
    @State private var showsConfetti = false

    /// **Le paywall**, ouvert par une porte de l'app (`trigger`) ou par la fin du parcours
    /// d'accueil (sans `trigger`).
    init(
        trigger: PaywallTrigger? = nil,
        onDismiss: @escaping () -> Void,
        onSubscribed: @escaping () -> Void
    ) {
        self.trigger = trigger
        self.onDismiss = onDismiss
        self.onSubscribed = onSubscribed
        _stage = State(initialValue: .paywall)
        _offerSource = State(initialValue: .paywall)
    }

    /// **L'offre de réduction seule**, ouverte à la demande : la pastille de la Home, la
    /// rangée des Réglages, la section Test.
    init(
        offer: DiscountPresentation,
        onDismiss: @escaping () -> Void,
        onSubscribed: @escaping () -> Void
    ) {
        self.trigger = nil
        self.onDismiss = onDismiss
        self.onSubscribed = onSubscribed
        let source: OfferSource = offer == .gift ? .test : .direct
        _stage = State(initialValue: .offer)
        _offerSource = State(initialValue: source)
        // Une fenêtre qui court déjà : son décompte est juste dès la première image.
        _startedAt = State(initialValue: DiscountOffer.start().flatMap { DiscountOffer.isLive(startedAt: $0) ? $0 : nil })
    }

    private var isPro: Bool { pro?.isPro ?? false }
    private var firstName: String? { PaywallProfile.firstName(OnboardingPreferences.displayName) }

    /// Les produits dont chaque écran affiche le prix.
    private static let paywallProducts = PaywallCatalog.all.map(\.productID)
    private static let offerProducts = [DiscountOffer.plan.productID, DiscountOffer.reference.productID]

    private func motion(_ animation: Animation) -> Animation {
        MicaboMotion.resolved(animation, reduceMotion: reduceMotion)
    }

    var body: some View {
        ZStack {
            switch stage {
            case .paywall:
                paywallStage.transition(.opacity)
            case .offer:
                offerStage.transition(.opacity)
            case .welcome:
                welcomeStage.transition(.opacity)
            }

            if showsConfetti {
                ConfettiView(colors: [V3Color.accent, V3Color.yellow, V3Color.pink, V3Color.green, V3Color.lilac])
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .task { await loadPrices() }
        .onAppear(perform: opened)
        // **Un achat confirmé après coup mène à la bienvenue.** Un achat en attente (une
        // validation parentale, un droit que RevenueCat n'a pas encore vu) s'ouvre plus tard,
        // par le flux du SDK (`ProAccess.observePurchases`) : l'écran encore ouvert passe
        // alors à la bienvenue, au lieu de rester devant quelqu'un d'abonné.
        .onChange(of: pro?.isPro == true) { _, isPro in
            guard isPro, !didSubscribe else { return }
            subscribed()
        }
    }

    // MARK: - Les trois temps

    private var paywallStage: some View {
        PaywallScreen(
            trigger: trigger,
            name: firstName,
            isPurchasing: isPurchasing,
            storeRevision: storeRevision,
            onClose: closePaywall,
            onSubscribe: { plan in Task { await buy(plan, door: trigger?.rawValue ?? "inconnu") } },
            onRestore: { Task { await restore() } },
            onSelect: { _ in plansCompared() },
            prices: PaywallPriceLoading.state(for: Self.paywallProducts, failure: priceFailure),
            notice: notice,
            onRetry: { Task { await loadPrices() } }
        )
    }

    /// L'offre. Son décompte descend de l'instant où elle s'est affichée pour la première
    /// fois ; c'est l'horloge du système qui le fait tourner, dans sa seule pastille.
    private var offerStage: some View {
        DiscountOfferScreen(
            clock: startedAt.map(DiscountClock.since) ?? .fixed(DiscountOffer.windowSeconds),
            isPurchasing: isPurchasing,
            prices: PaywallPriceLoading.state(for: Self.offerProducts, failure: priceFailure),
            notice: notice,
            storeRevision: storeRevision,
            onClose: declineOffer,
            onBuy: { Task { await buy(DiscountOffer.plan, door: "discount") } },
            onRestore: { Task { await restore() } },
            onRetry: { Task { await loadPrices() } }
        )
    }

    private var welcomeStage: some View {
        PaywallWelcomeScreen(name: firstName, onContinue: onSubscribed)
    }

    /// Passe à un autre temps, en fondu. Le message d'une boutique qui a buté ne suit pas.
    private func show(_ next: Stage) {
        notice = nil
        withAnimation(motion(MicaboMotion.standard)) { stage = next }
    }

    // MARK: - Ouvrir, refermer

    private func opened() {
        openedAt = Date()
        switch stage {
        case .paywall:
            Analytics.track(.paywallOpened, [
                "trigger": .text(trigger?.rawValue ?? "inconnu"),
                "price_display": PriceDisplay.current.analyticsValue,
            ])
        case .offer:
            offerShown()
        case .welcome:
            break
        }
    }

    /// **L'offre s'affiche** : sa fenêtre de vingt-quatre heures démarre ici, à son premier
    /// affichage — ou continue, si elle court déjà. La pastille de la Home prend le relais.
    private func offerShown() {
        let already = DiscountOffer.start().map { DiscountOffer.isLive(startedAt: $0) } ?? false
        startedAt = DiscountOffer.begin()
        DiscountWindow.shared.refresh()
        // Les confettis fêtent l'arrivée de l'offre, pas chacune de ses réouvertures.
        showsConfetti = !already
        Analytics.track(.discountShown, [
            "source": .text(offerSource.rawValue),
            "fresh": .flag(!already),
        ])
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

    /// **La croix du paywall.** Refermé sans achat, il laisse la place à l'offre de réduction
    /// quand elle est due — dans le même écran, sans se refermer d'abord. Sinon il sort.
    private func closePaywall() {
        guard !isPurchasing else { return }
        // Un achat qui attend une validation n'est pas un refus : pas d'offre derrière lui,
        // et pas de fermeture à compter.
        guard lastOutcome?.countsAsDismissal != false else {
            onDismiss()
            return
        }
        Analytics.track(.paywallDismissed, [
            "trigger": .text(trigger?.rawValue ?? "inconnu"),
            "stage": .text(comparedPlans ? "plans" : "offre"),
            "seconds": .number((Date().timeIntervalSince(openedAt) * 10).rounded() / 10),
            "price_display": PriceDisplay.current.analyticsValue,
        ])

        // L'offre ne se montre que si elle peut se vendre : son prix et celui qu'elle barre
        // sont arrivés de la boutique. Une offre qui s'ouvrirait sur une attente serait pire
        // que pas d'offre.
        guard PaywallPriceLoading.hasPrices(for: Self.offerProducts),
              DiscountOffer.paywallClosed(isPro: isPro)
        else {
            onDismiss()
            return
        }
        offerSource = .paywall
        openedAt = Date()
        offerShown()
        show(.offer)
    }

    /// La croix de l'offre : elle sort, et l'offre ne revient pas d'elle-même de la session.
    /// La section Test ne compte pas pour un refus.
    private func declineOffer() {
        guard !isPurchasing, stage == .offer else { return }
        if offerSource != .test {
            DiscountOffer.declinedThisSession = true
        }
        Analytics.track(.discountDismissed, [
            "source": .text(offerSource.rawValue),
            "seconds": .number((Date().timeIntervalSince(openedAt) * 10).rounded() / 10),
        ])
        onDismiss()
    }

    // MARK: - Les prix

    /// **Demande les prix jusqu'à ce qu'ils soient là**, ou que les essais soient épuisés.
    ///
    /// Déjà là, ils sont relus quand même, sans rien cacher : l'essai d'un compte et un prix
    /// changé dans App Store Connect arrivent par la même réponse. Les pauses entre deux
    /// demandes sont celles d'un réseau qu'on laisse revenir, pas une mise en scène.
    @MainActor
    private func loadPrices() async {
        guard !isLoadingPrices else { return }
        isLoadingPrices = true
        defer { isLoadingPrices = false }
        priceFailure = nil

        var failure: PaywallFailure?
        for delay in PaywallPriceLoading.retryDelays {
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            if Task.isCancelled { return }
            failure = await PaywallPurchases.fetchPrices()
            storeRevision = PaywallStorePrices.revision
            if PaywallPriceLoading.hasPrices(for: stage == .offer ? Self.offerProducts : Self.paywallProducts) {
                return
            }
        }
        // La boutique a répondu sans ces produits : l'offre n'est pas ouverte dans ce pays.
        priceFailure = (failure ?? .productUnavailable).message
    }

    // MARK: - Acheter, restaurer

    /// **Seul un achat confirmé ouvre l'app.** `unavailable` veut dire « je n'ai pas pu
    /// vendre » — boutique muette, SDK absent, réseau tombé — et l'offrir ferait de chaque
    /// panne un abonnement gratuit. La phrase le dit sous le bouton, plutôt que de le laisser
    /// avoir l'air cassé.
    ///
    /// `door` est ce que les statistiques retiennent de la porte : le déclencheur du paywall,
    /// ou `discount` pour le tarif réduit.
    @MainActor
    private func buy(_ plan: PaywallPlan, door: String) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        notice = nil
        // L'essai tel qu'il était promis au moment d'acheter : la boutique peut répondre
        // autrement après coup, et c'est la promesse qu'on mesure.
        let promisedTrial = plan.hasTrial
        Analytics.track(.paywallPurchaseStarted, [
            "trigger": .text(door),
            "plan": .text(plan.productID),
            "trial": .flag(promisedTrial),
            "price_display": PriceDisplay.current.analyticsValue,
        ])

        let outcome = await PaywallPurchases.buy(plan)
        isPurchasing = false
        lastOutcome = outcome

        switch outcome {
        case .purchased:
            Analytics.track(.paywallPurchased, [
                "trigger": .text(door),
                "plan": .text(plan.productID),
                "trial": .flag(promisedTrial),
                "price_display": PriceDisplay.current.analyticsValue,
            ])
            if promisedTrial {
                // **Le rappel promis est posé** : la veille de la fin de l'essai, si les
                // notifications sont permises (`TrialEndReminder`).
                Task { await TrialEndReminder.schedule(trialDays: plan.trialDays) }
                Analytics.track(.paywallTrialStarted, [
                    "trigger": .text(door),
                    "plan": .text(plan.productID),
                    "price_display": PriceDisplay.current.analyticsValue,
                ])
            }
            subscribed()
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
            notice = outcome.failureMessage.map(PaywallNotice.error)
        case .cancelled:
            // L'élève a refermé la feuille d'Apple : rien ne bouge.
            Analytics.track(.paywallPurchaseCancelled, [
                "plan": .text(plan.productID),
                "price_display": PriceDisplay.current.analyticsValue,
            ])
        case .pending:
            // Ni échec ni achat : la validation viendra d'ailleurs, et Pro s'ouvrira seul.
            Analytics.track(.paywallPurchasePending, ["plan": .text(plan.productID)])
            notice = .info(L10n.t("ios.paywallPending", locale: .resolved()))
        }
    }

    /// La restauration : rien à restaurer se dit, sinon le bouton a l'air inerte.
    @MainActor
    private func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        notice = nil

        let outcome = await PaywallPurchases.restore()
        isPurchasing = false

        guard outcome == .purchased else {
            // Une panne (le réseau, la boutique) n'est pas « rien à restaurer ».
            if case .failed(let cause) = outcome {
                notice = .error(cause.message)
            } else {
                notice = .error(L10n.t("ios.paywallNoRestore", locale: .resolved()))
            }
            return
        }
        Analytics.track(.paywallRestored)
        subscribed()
    }

    /// **Pro est ouvert** : par un achat, une restauration, ou un droit confirmé après coup.
    /// L'écran passe à la bienvenue ; c'est elle qui rend la main (`onSubscribed`).
    private func subscribed() {
        didSubscribe = true
        pro?.unlock()
        DiscountWindow.shared.refresh()
        Haptics.success()
        show(.welcome)
    }
}

extension View {
    /// **Ouvre le paywall en plein écran**, par-dessus ce qu'on faisait.
    ///
    /// Un plein écran et pas une feuille : la croix est la seule sortie, et c'est elle qui
    /// laisse la place à l'offre de réduction, dans la même présentation. Une feuille se
    /// balaye, et un paywall balayé ne peut plus rien montrer à sa place.
    ///
    /// `onSubscribed` est rappelé une fois Pro ouvert **et** l'écran refermé : l'élève
    /// retrouve ce qu'il faisait, et ce qu'il demandait s'ouvre.
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

    /// **Ouvre l'offre de réduction en plein écran**, à la demande : la pastille de la Home,
    /// la rangée des Réglages, la section Test.
    func micaboDiscountOffer(_ presentation: Binding<DiscountPresentation?>) -> some View {
        fullScreenCover(item: presentation) { value in
            PaywallFlowView(
                offer: value,
                onDismiss: { presentation.wrappedValue = nil },
                onSubscribed: { presentation.wrappedValue = nil }
            )
        }
    }
}
